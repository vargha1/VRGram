package client

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base32"
	"fmt"
	"log/slog"
	"math"
	"net"
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
	chunkSize      = 220
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

func (e *DNSClientEngine) GetDNSResolver() string {
	e.mu.RLock()
	defer e.mu.RUnlock()
	return e.dnsResolver
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

	// Random padding 0-64 bytes for traffic analysis protection
	padLenBuf := make([]byte, 1)
	rand.Read(padLenBuf)
	padLen := int(padLenBuf[0]) % 65
	padding := make([]byte, padLen)
	rand.Read(padding)
	plaintext = append(plaintext, padding...)

	chunks := encoding.ChunkMessage(msgID, plaintext, chunkSize, recipientPubkey)

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

// PollRelays queries ALL relays for pending msgIDs for the given recipient pubkey.
// Returns all unique msgIDs from all relays (client-side federation).
func (e *DNSClientEngine) PollRelays(recipientPubkey string) ([][8]byte, error) {
	if recipientPubkey == "" {
		return nil, nil
	}
	relays := e.discoverActiveRelays(nil)
	if len(relays) == 0 {
		return nil, nil
	}

	hash := sha256.Sum256([]byte(recipientPubkey))
	peerID := base32hex.EncodeToString(hash[:])

	var allMsgIDs [][8]byte
	seen := make(map[[8]byte]bool)

	for _, relay := range relays {
		msgIDs, err := e.pollRelay(relay, peerID)
		if err != nil {
			slog.Warn("poll relay failed", "relay", relay, "error", err)
			continue
		}
		for _, id := range msgIDs {
			if !seen[id] {
				seen[id] = true
				allMsgIDs = append(allMsgIDs, id)
			}
		}
	}
	return allMsgIDs, nil
}

// pollRelay sends a POLL query to a relay server and returns pending msgIDs.
func (e *DNSClientEngine) pollRelay(addr, peerID string) ([][8]byte, error) {
	// Resolve relay address if it's a domain
	resolved, err := e.resolveAddr(addr)
	if err != nil {
		return nil, fmt.Errorf("resolve %s: %w", addr, err)
	}

	queryLabels := []string{"POLL", peerID, e.zone}
	name := strings.Join(queryLabels, ".")

	m := new(mdns.Msg)
	m.SetQuestion(mdns.Fqdn(name), mdns.TypeTXT)
	m.RecursionDesired = false

	// TCP first (carrier UDP intercept), fall back to UDP
	tcpClient := &mdns.Client{Timeout: 5 * time.Second, Net: "tcp"}
	resp, _, err := tcpClient.Exchange(m, resolved)
	if err == nil && resp.Rcode == mdns.RcodeSuccess {
		return parsePollResponse(resp), nil
	}

	// TCP failed — try UDP once
	slog.Debug("poll tcp failed, trying udp", "error", err)
	udpClient := &mdns.Client{Timeout: 5 * time.Second, Net: "udp"}
	resp, _, err = udpClient.Exchange(m, resolved)
	if err == nil && resp.Rcode == mdns.RcodeSuccess {
		return parsePollResponse(resp), nil
	}

	// UDP also failed — final TCP retry
	slog.Debug("poll udp failed, final tcp retry", "error", err)
	tcpClient2 := &mdns.Client{Timeout: 5 * time.Second, Net: "tcp"}
	resp, _, err = tcpClient2.Exchange(m, resolved)
	if err != nil {
		return nil, fmt.Errorf("dns poll failed (tcp+udp): %w", err)
	}
	if resp.Rcode != mdns.RcodeSuccess {
		return nil, fmt.Errorf("dns response code: %d", resp.Rcode)
	}
	return parsePollResponse(resp), nil
}

// parsePollResponse extracts msgIDs from a POLL TXT response.
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

// PolledMessage holds a reassembled message and its original DNS msgID.
type PolledMessage struct {
	MsgID [8]byte
	Data  []byte
}

// PollMessages fetches and reassembles all pending messages for a recipient.
// Returns each message with its original DNS msgID for client-side dedup.
func (e *DNSClientEngine) PollMessages(recipientPubkey string) ([]PolledMessage, error) {
	msgIDs, err := e.PollRelays(recipientPubkey)
	if err != nil || len(msgIDs) == 0 {
		return nil, err
	}

	relays := e.discoverActiveRelays(nil)
	if len(relays) == 0 {
		return nil, fmt.Errorf("no relays to fetch from")
	}

	var messages []PolledMessage
	for _, msgID := range msgIDs {
		// Skip already-fetched messages (dedup)
		e.fetchedMu.Lock()
		if e.fetched[msgID] {
			e.fetchedMu.Unlock()
			continue
		}
		e.fetchedMu.Unlock()

		var data []byte
		var fetchErr error
		for _, relay := range relays {
			data, fetchErr = fetchAndReassemble(relay, e.zone, msgID)
			if fetchErr == nil {
				break
			}
			slog.Debug("fetch from relay failed, trying next", "relay", relay, "error", fetchErr)
		}
		if fetchErr != nil {
			slog.Warn("fetch message failed from all relays", "msgID", msgID, "error", fetchErr)
			continue
		}
		// Mark as fetched to avoid re-download
		e.fetchedMu.Lock()
		e.fetched[msgID] = true
		e.fetchedMu.Unlock()

		messages = append(messages, PolledMessage{MsgID: msgID, Data: data})
	}
	return messages, nil
}

// fetchAndReassemble retrieves all chunks for a msgID from a relay and reassembles.
func fetchAndReassemble(relayAddr, zone string, msgID [8]byte) ([]byte, error) {
	firstChunk, err := dns.QueryChunk(relayAddr, zone, msgID, 0)
	if err != nil {
		return nil, fmt.Errorf("fetch chunk 0: %w", err)
	}
	total := int(firstChunk.TotalChunks)
	allChunks := make([]*encoding.Chunk, total)
	allChunks[0] = firstChunk
	for i := 1; i < total; i++ {
		chunk, err := dns.QueryChunk(relayAddr, zone, msgID, uint16(i))
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
				if err := dns.SendChunk(relay, e.zone, chunk, false); err != nil {
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
			err := dns.SendChunk(relay, e.zone, chunk, false)
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