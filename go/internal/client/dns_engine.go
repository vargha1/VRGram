package client

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base32"
	"encoding/binary"
	"fmt"
	"log/slog"
	"math"
	"net"
	"os"
	"strings"
	"sync"
	"time"

	mdns "github.com/miekg/dns"
	"github.com/user/dns-transport/internal/dns"
	"github.com/user/dns-transport/internal/encoding"
)

const (
	maxRetries     = 3
	baseBackoff    = 500 * time.Millisecond
	maxJitter      = 0.25
	parallelism    = 15
	maxRelays      = 5
	defaultChunkSize = 75
)

var base32hex = base32.HexEncoding.WithPadding(base32.NoPadding)

// DNSChunkSender is the interface for sending data as DNS chunks.
type DNSChunkSender interface {
	SendMessage(ctx context.Context, plaintext []byte) ([8]byte, int, error)
}

// DNSClientEngine sends chunked messages over DNS with retry and failover.
type DNSClientEngine struct {
	mu             sync.RWMutex
	relays         []string
	fallbackRelays []string
	zone           string
	dnsResolver    string // custom DNS resolver for domain relay addresses (e.g., "8.8.8.8:53")

	fetchedMu sync.Mutex
	fetched   map[[8]byte]bool // msgIDs already downloaded, to avoid redundant fetch

	debugLogPath    string          // path to relayd_debug.log for diagnostics
	transportMode   dns.TransportMode // user-selectable: Auto, TCP, UDP
	chunkSize       int               // user-configurable DNS chunk payload size (default 75)
}

// NewDNSClientEngine creates a new DNS client engine.
func NewDNSClientEngine(fallbackRelays []string, zone string) *DNSClientEngine {
	relays := make([]string, len(fallbackRelays))
	copy(relays, fallbackRelays)
	return &DNSClientEngine{
		fallbackRelays: fallbackRelays,
		relays:         relays,
		zone:           zone,
		dnsResolver:    "8.8.8.8:53",
		fetched:        make(map[[8]byte]bool),
		chunkSize:      defaultChunkSize,
	}
}

func (e *DNSClientEngine) SetRelays(relays []string) {
	e.mu.Lock()
	defer e.mu.Unlock()
	e.relays = relays
}

func (e *DNSClientEngine) GetRelays() []string {
	e.mu.RLock()
	defer e.mu.RUnlock()
	r := make([]string, len(e.relays))
	copy(r, e.relays)
	return r
}

func (e *DNSClientEngine) SetDNSResolver(resolver string) {
	e.mu.Lock()
	defer e.mu.Unlock()
	e.dnsResolver = resolver
}

// SetDebugLogPath sets the path for the debug log file.
func (e *DNSClientEngine) SetTransportMode(mode dns.TransportMode) {
	e.mu.Lock()
	defer e.mu.Unlock()
	e.transportMode = mode
}

func (e *DNSClientEngine) GetTransportMode() dns.TransportMode {
	e.mu.RLock()
	defer e.mu.RUnlock()
	return e.transportMode
}

func (e *DNSClientEngine) SetChunkSize(size int) {
	e.mu.Lock()
	defer e.mu.Unlock()
	if size < 32 {
		size = 32 // minimum safe for DNS label overhead
	}
	if size > 200 {
		size = 200 // hard cap to prevent excessively large DNS names
	}
	e.chunkSize = size
}

func (e *DNSClientEngine) GetChunkSize() int {
	e.mu.RLock()
	defer e.mu.RUnlock()
	return e.chunkSize
}

func (e *DNSClientEngine) SetDebugLogPath(path string) {
	e.debugLogPath = path
}

// debugWrite appends a line to the debug log file.
func (e *DNSClientEngine) debugWrite(format string, args ...interface{}) {
	if e.debugLogPath == "" {
		return
	}
	f, err := os.OpenFile(e.debugLogPath, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0644)
	if err != nil {
		return
	}
	defer f.Close()
	fmt.Fprintf(f, "[%s] ", time.Now().Format("15:04:05.000"))
	fmt.Fprintf(f, format, args...)
	fmt.Fprintf(f, "\n")
}

func (e *DNSClientEngine) GetDNSResolver() string {
	e.mu.RLock()
	defer e.mu.RUnlock()
	return e.dnsResolver
}

func (e *DNSClientEngine) GetZone() string {
	e.mu.RLock()
	defer e.mu.RUnlock()
	return e.zone
}

// resolveAddr resolves a domain:port to IP:port using custom DNS resolver.
// If already IP:port, returns as-is.
func (e *DNSClientEngine) resolveAddr(addr string) (string, error) {
	host, port, err := net.SplitHostPort(addr)
	if err != nil {
		return addr, err
	}
	if ip := net.ParseIP(host); ip != nil {
		return addr, nil // already IP
	}

	e.mu.RLock()
	resolver := e.dnsResolver
	e.mu.RUnlock()

	if resolver == "" {
		resolver = "8.8.8.8:53"
	}

	client := &mdns.Client{Timeout: 5 * time.Second}
	msg := new(mdns.Msg)
	msg.SetQuestion(mdns.Fqdn(host), mdns.TypeA)
	msg.RecursionDesired = true

	resp, _, err := client.Exchange(msg, resolver)
	if err != nil {
		return "", fmt.Errorf("dns resolve failed: %w", err)
	}
	if resp.Rcode != mdns.RcodeSuccess || len(resp.Answer) == 0 {
		return "", fmt.Errorf("no A record for %s", host)
	}
	for _, ans := range resp.Answer {
		if a, ok := ans.(*mdns.A); ok {
			return net.JoinHostPort(a.A.String(), port), nil
		}
	}
	return "", fmt.Errorf("no A record for %s", host)
}

// SendMessage sends all chunks over DNS relays with a 10s deadline.
// recipientPubkey is used for server-side recipient indexing so the
// recipient can poll for messages.
func (e *DNSClientEngine) SendMessage(ctx context.Context, plaintext []byte, recipientPubkey string) ([8]byte, int, error) {
	slog.Debug("SendMessage start", "plaintext_len", len(plaintext), "relays", e.discoverActiveRelays(ctx))
	// Overall deadline: 10s for all chunks across all relays
	sendCtx, cancel := context.WithTimeout(ctx, 10*time.Second)
	defer cancel()

	var msgID [8]byte
	rand.Read(msgID[:])

	chunks := encoding.ChunkMessage(msgID, plaintext, e.GetChunkSize(), recipientPubkey)

	relays := e.discoverActiveRelays(sendCtx)
	if len(relays) > 0 {
		if err := e.sendParallel(sendCtx, chunks, relays); err != nil {
			return msgID, 0, err
		}
	} else {
		for _, chunk := range chunks {
			if err := e.sendWithRetry(sendCtx, chunk); err != nil {
				return msgID, 0, err
			}
			jitter := time.Duration(float64(500) * (1 + (randFloat64()-0.5)*2*maxJitter))
			time.Sleep(jitter * time.Millisecond)
		}
	}
	return msgID, len(chunks), nil
}

// PollRelays queries ALL relays for pending messages with metadata.
// Returns all unique PolledMessages (with relay-stamped timestamp + sequence)
// from all relays (client-side federation).
func (e *DNSClientEngine) PollRelays(recipientPubkey string) ([]PolledMessage, error) {
	if recipientPubkey == "" {
		return nil, nil
	}
	relays := e.discoverActiveRelays(nil)
	if len(relays) == 0 {
		e.debugWrite("PollRelays: no relays configured — cannot poll")
		return nil, nil
	}
	e.debugWrite("PollRelays: polling %d relays for %s", len(relays), recipientPubkey[:min(16, len(recipientPubkey))])

	hash := sha256.Sum256([]byte(recipientPubkey))
	peerID := base32hex.EncodeToString(hash[:])

	var allMsgs []PolledMessage
	seen := make(map[[8]byte]bool)

	for _, relay := range relays {
		msgs, err := e.pollRelayWithMeta(relay, peerID)
		if err != nil {
			slog.Warn("poll relay failed", "relay", relay, "error", err)
			continue
		}
		for _, m := range msgs {
			if !seen[m.MsgID] {
				seen[m.MsgID] = true
				allMsgs = append(allMsgs, m)
			}
		}
	}
	e.debugWrite("PollRelays: total unique msgIDs found=%d", len(allMsgs))
	return allMsgs, nil
}

// pollRelayWithMeta sends a POLL query and returns PolledMessages with metadata.
func (e *DNSClientEngine) pollRelayWithMeta(addr, peerID string) ([]PolledMessage, error) {
	resolved, err := e.resolveAddr(addr)
	if err != nil {
		return nil, fmt.Errorf("resolve %s: %w", addr, err)
	}

	queryLabels := []string{"POLL", peerID, e.zone}
	name := strings.Join(queryLabels, ".")

	m := new(mdns.Msg)
	m.SetQuestion(mdns.Fqdn(name), mdns.TypeTXT)
	m.RecursionDesired = false

	var resp *mdns.Msg
	mode := e.GetTransportMode()
	switch mode {
	case dns.TransportTCP:
		tcpClient := &mdns.Client{Timeout: 5 * time.Second, Net: "tcp"}
		resp, _, err = tcpClient.Exchange(m, resolved)
		if err != nil {
			return nil, fmt.Errorf("dns tcp poll failed: %w", err)
		}
	case dns.TransportUDP:
		udpClient := &mdns.Client{Timeout: 5 * time.Second, Net: "udp"}
		resp, _, err = udpClient.Exchange(m, resolved)
		if err != nil {
			return nil, fmt.Errorf("dns udp poll failed: %w", err)
		}
	default: // TransportAuto
		tcpClient := &mdns.Client{Timeout: 5 * time.Second, Net: "tcp"}
		resp, _, err = tcpClient.Exchange(m, resolved)
		if err == nil && resp.Rcode == mdns.RcodeSuccess {
			return parsePollResponseWithMeta(resp), nil
		}
		e.debugWrite("pollRelay TCP failed relay=%s err=%v trying UDP", resolved, err)
		udpClient := &mdns.Client{Timeout: 5 * time.Second, Net: "udp"}
		resp, _, err = udpClient.Exchange(m, resolved)
		if err == nil && resp.Rcode == mdns.RcodeSuccess {
			return parsePollResponseWithMeta(resp), nil
		}
		e.debugWrite("pollRelay UDP failed relay=%s err=%v final TCP", resolved, err)
		tcpClient2 := &mdns.Client{Timeout: 5 * time.Second, Net: "tcp"}
		resp, _, err = tcpClient2.Exchange(m, resolved)
		if err != nil {
			return nil, fmt.Errorf("dns poll failed (tcp+udp): %w", err)
		}
	}
	if resp.Rcode != mdns.RcodeSuccess {
		return nil, fmt.Errorf("dns response code: %d", resp.Rcode)
	}
	return parsePollResponseWithMeta(resp), nil
}

// parsePollResponseWithMeta parses a POLL TXT response, handling both
// old (base32hex(msgID)) and extended (base32hex(msgID):timestamp:sequence) formats.
func parsePollResponseWithMeta(resp *mdns.Msg) []PolledMessage {
	var msgs []PolledMessage
	for _, ans := range resp.Answer {
		txt, ok := ans.(*mdns.TXT)
		if !ok {
			continue
		}
		for _, t := range txt.Txt {
			pm := parsePollRecord(t)
			if pm != nil {
				msgs = append(msgs, *pm)
			}
		}
	}
	return msgs
}

// parsePollRecord parses a single TXT record from a POLL response.
// Supports old format: base32hex(msgID)
// Extended format: base32hex(msgID):base32hex(timestamp):base32hex(sequence)
func parsePollRecord(record string) *PolledMessage {
	parts := strings.SplitN(record, ":", 3)

	idBytes, err := base32hex.DecodeString(parts[0])
	if err != nil || len(idBytes) != 8 {
		return nil
	}
	var mid [8]byte
	copy(mid[:], idBytes)

	pm := &PolledMessage{MsgID: mid}

	// Parse optional extended metadata
	if len(parts) == 3 {
		if tsBytes, err := base32hex.DecodeString(parts[1]); err == nil && len(tsBytes) == 8 {
			pm.Timestamp = int64(binary.BigEndian.Uint64(tsBytes))
		}
		if seqBytes, err := base32hex.DecodeString(parts[2]); err == nil && len(seqBytes) == 8 {
			pm.Sequence = binary.BigEndian.Uint64(seqBytes)
		}
	}

	return pm
}

// parsePollResponse extracts msgIDs from a POLL TXT response (old format, no metadata).
func parsePollResponse(resp *mdns.Msg) [][8]byte {
	var msgIDs [][8]byte
	for _, ans := range resp.Answer {
		txt, ok := ans.(*mdns.TXT)
		if !ok {
			continue
		}
		for _, t := range txt.Txt {
			idBytes, err := base32hex.DecodeString(t)
			if err != nil || len(idBytes) != 8 {
				continue
			}
			var mid [8]byte
			copy(mid[:], idBytes)
			msgIDs = append(msgIDs, mid)
		}
	}
	return msgIDs
}

// PolledMessage holds a reassembled message with relay-stamped metadata.
type PolledMessage struct {
	MsgID     [8]byte
	Data      []byte
	Timestamp int64  // relay-stamped UnixMilli
	Sequence  uint64 // monotonic per-recipient
}

// PollMessages fetches and reassembles all pending messages for a recipient.
// Returns each message with its relay-stamped timestamp and sequence number.
func (e *DNSClientEngine) PollMessages(recipientPubkey string) ([]PolledMessage, error) {
	polledMeta, err := e.PollRelays(recipientPubkey)
	if err != nil || len(polledMeta) == 0 {
		e.debugWrite("PollMessages: no msgIDs from relays count=%d err=%v", len(polledMeta), err)
		return nil, err
	}
	e.debugWrite("PollMessages: got %d msgIDs from relays", len(polledMeta))

	relays := e.discoverActiveRelays(nil)
	if len(relays) == 0 {
		return nil, fmt.Errorf("no relays to fetch from")
	}

	var messages []PolledMessage
	for _, pm := range polledMeta {
		// Skip already-fetched messages (dedup)
		e.fetchedMu.Lock()
		if e.fetched[pm.MsgID] {
			e.fetchedMu.Unlock()
			continue
		}
		e.fetchedMu.Unlock()

		var data []byte
		var fetchErr error
		for _, relay := range relays {
			data, fetchErr = fetchAndReassemble(relay, e.zone, pm.MsgID, e.GetTransportMode())
			if fetchErr == nil {
				break
			}
			e.debugWrite("fetch from relay failed relay=%s msgID=%x err=%v", relay, pm.MsgID, fetchErr)
		}
		if fetchErr != nil {
			e.debugWrite("fetch message failed from all relays msgID=%x err=%v", pm.MsgID, fetchErr)
			continue
		}
		e.debugWrite("fetch message OK msgID=%x data_len=%d", pm.MsgID, len(data))
		// Mark as fetched to avoid re-download
		e.fetchedMu.Lock()
		e.fetched[pm.MsgID] = true
		e.fetchedMu.Unlock()

		messages = append(messages, PolledMessage{
			MsgID:     pm.MsgID,
			Data:      data,
			Timestamp: pm.Timestamp,
			Sequence:  pm.Sequence,
		})
	}
	return messages, nil
}

// fetchAndReassemble retrieves all chunks for a msgID from a relay and reassembles.
func fetchAndReassemble(relayAddr, zone string, msgID [8]byte, mode dns.TransportMode) ([]byte, error) {
	firstChunk, err := dns.QueryChunk(relayAddr, zone, msgID, 0, mode)
	if err != nil {
		return nil, fmt.Errorf("fetch chunk 0: %w", err)
	}
	total := int(firstChunk.TotalChunks)
	allChunks := make([]*encoding.Chunk, total)
	allChunks[0] = firstChunk
	for i := 1; i < total; i++ {
		chunk, err := dns.QueryChunk(relayAddr, zone, msgID, uint16(i), mode)
		if err != nil {
			return nil, fmt.Errorf("fetch chunk %d: %w", i, err)
		}
		allChunks[i] = chunk
	}
	return encoding.ReassembleMessage(allChunks)
}

func (e *DNSClientEngine) discoverActiveRelays(ctx context.Context) []string {
	if len(e.fallbackRelays) > 0 {
		return e.fallbackRelays
	}
	return e.GetRelays()
}

func (e *DNSClientEngine) sendParallel(ctx context.Context, chunks []*encoding.Chunk, relays []string) error {
	if len(chunks) == 0 || len(relays) == 0 {
		return nil
	}

	// Track per-chunk delivery: true if at least one relay accepted it
	chunkDelivered := make([]bool, len(chunks))
	var mu sync.Mutex

	childCtx, cancel := context.WithCancel(ctx)
	defer cancel()

	sem := make(chan struct{}, parallelism)
	var wg sync.WaitGroup

	for i, chunk := range chunks {
		for _, relay := range relays {
			wg.Add(1)
			i := i
			chunk := chunk
			relay := relay
			go func() {
				defer wg.Done()
				select {
				case sem <- struct{}{}:
				case <-childCtx.Done():
					return
				}
				defer func() { <-sem }()
				select {
				case <-childCtx.Done():
					return
				default:
				}
				mode := e.GetTransportMode()
				if err := dns.SendChunk(relay, e.zone, chunk, mode); err != nil {
					slog.Warn("send chunk failed", "relay", relay, "chunk", i, "error", err)
					return
				}
				mu.Lock()
				chunkDelivered[i] = true
				mu.Unlock()
			}()
		}
	}

	// Monitor: cancel early when all chunks delivered
	done := make(chan struct{})
	go func() {
		wg.Wait()
		close(done)
	}()

	// Poll delivery status periodically
	ticker := time.NewTicker(300 * time.Millisecond)
	defer ticker.Stop()

	for {
		select {
		case <-done:
			// All goroutines finished — check delivery
			var undelivered []int
			for i, ok := range chunkDelivered {
				if !ok {
					undelivered = append(undelivered, i)
				}
			}
			if len(undelivered) > 0 {
				return fmt.Errorf("%d chunks undelivered to any relay: %v", len(undelivered), undelivered)
			}
			return nil
		case <-childCtx.Done():
			// Parent cancelled (timeout from SendMessage) — wait for in-flight, then fail
			<-done
			var undelivered []int
			for i, ok := range chunkDelivered {
				if !ok {
					undelivered = append(undelivered, i)
				}
			}
			return fmt.Errorf("send timeout: %d/%d chunks delivered",
				len(chunks)-len(undelivered), len(chunks))
		case <-ticker.C:
			// Check if all chunks delivered early — cancel to wake up blocked goroutines
			mu.Lock()
			all := true
			for _, ok := range chunkDelivered {
				if !ok {
					all = false
					break
				}
			}
			mu.Unlock()
			if all {
				cancel()
				<-done
				return nil
			}
		}
	}
}

func (e *DNSClientEngine) sendWithRetry(ctx context.Context, chunk *encoding.Chunk) error {
	relays := e.GetRelays()
	for attempt := 0; attempt < maxRetries; attempt++ {
		for _, relay := range relays {
			select {
			case <-ctx.Done():
				return ctx.Err()
			default:
			}
			mode := e.GetTransportMode()
			err := dns.SendChunk(relay, e.zone, chunk, mode)
			if err == nil {
				return nil
			}
			slog.Warn("send chunk failed", "relay", relay, "attempt", attempt, "error", err)
		}
		sleepMs := float64(baseBackoff/time.Millisecond) * math.Pow(2, float64(attempt)) * (1 + (randFloat64()-0.5)*2*maxJitter)
		time.Sleep(time.Duration(sleepMs) * time.Millisecond)
	}
	return fmt.Errorf("all relays failed after %d attempts", maxRetries)
}

func randFloat64() float64 {
	b := make([]byte, 8)
	rand.Read(b)
	return float64(b[0]) / 256.0
}