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

// SendMessage sends all chunks over DNS relays. recipientPubkey is used for
// server-side recipient indexing so the recipient can poll for messages.
func (e *DNSClientEngine) SendMessage(ctx context.Context, plaintext []byte, recipientPubkey string) ([8]byte, int, error) {
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

	relays := e.discoverActiveRelays(ctx)
	if len(relays) > 0 {
		if err := e.sendParallel(ctx, chunks, relays); err != nil {
			return msgID, 0, err
		}
	} else {
		for _, chunk := range chunks {
			if err := e.sendWithRetry(ctx, chunk); err != nil {
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

		client := &mdns.Client{Timeout: 5 * time.Second}
	resp, _, err := client.Exchange(m, resolved)
	if err != nil {
		// UDP failed — retry once (transient packet loss on mobile)
		slog.Debug("poll udp failed, retrying udp", "error", err)
		client.Net = "udp"
		resp, _, err = client.Exchange(m, resolved)
	}
	if err != nil {
		// UDP still fails (NAT/firewall). Try TCP.
		slog.Debug("poll udp retry failed, trying tcp", "error", err)
		client.Net = "tcp"
		resp, _, err = client.Exchange(m, resolved)
		if err != nil {
			return nil, fmt.Errorf("dns poll failed (udp+tcp): %w", err)
		}
	}
	if resp.Rcode != mdns.RcodeSuccess {
		return nil, fmt.Errorf("dns response code: %d", resp.Rcode)
	}

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
	return msgIDs, nil
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
		data, err := fetchAndReassemble(relays[0], e.zone, msgID)
		if err != nil {
			slog.Warn("fetch message failed", "msgID", msgID, "error", err)
			continue
		}
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
	total := len(chunks) * len(relays)
	if total == 0 {
		return nil
	}

	sem := make(chan struct{}, parallelism)
	var wg sync.WaitGroup
	errCh := make(chan error, total)

	sendCtx, cancel := context.WithCancel(ctx)
	defer cancel()

	for _, chunk := range chunks {
		for _, relay := range relays {
			wg.Add(1)
			chunk := chunk
			relay := relay
			go func() {
				defer wg.Done()
				select {
				case sem <- struct{}{}:
				case <-sendCtx.Done():
					return
				}
				defer func() { <-sem }()
				select {
				case <-sendCtx.Done():
					return
				default:
				}
				if err := dns.SendChunk(relay, e.zone, chunk, false); err != nil {
					errCh <- fmt.Errorf("send to %s: %w", relay, err)
					cancel()
				}
			}()
		}
	}

	wg.Wait()
	close(errCh)

	for err := range errCh {
		if err != nil {
			return err
		}
	}
	return nil
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