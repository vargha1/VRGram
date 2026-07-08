package client

import (
	"crypto/rand"
	"fmt"
	"log/slog"
	"math"
	"sync"
	"time"

	"github.com/user/dns-transport/internal/dns"
	"github.com/user/dns-transport/internal/encoding"
)

const (
	maxRetries  = 3
	baseBackoff = 500 * time.Millisecond
	maxJitter   = 0.25
)

// DNSClientEngine sends chunked messages over DNS with retry and failover.
type DNSClientEngine struct {
	mu     sync.RWMutex
	relays []string
	zone   string
}

// NewDNSClientEngine creates a new DNS client engine.
func NewDNSClientEngine(relays []string, zone string) *DNSClientEngine {
	return &DNSClientEngine{
		relays: relays,
		zone:   zone,
	}
}

// SetRelays updates the relay list under a write lock.
func (e *DNSClientEngine) SetRelays(relays []string) {
	e.mu.Lock()
	defer e.mu.Unlock()
	e.relays = relays
}

// GetRelays returns a copy of the relay list.
func (e *DNSClientEngine) GetRelays() []string {
	e.mu.RLock()
	defer e.mu.RUnlock()
	r := make([]string, len(e.relays))
	copy(r, e.relays)
	return r
}

// SendMessage sends all chunks of a message over DNS relays.
// Returns the message ID, number of chunks sent, or an error.
func (e *DNSClientEngine) SendMessage(plaintext []byte) ([8]byte, int, error) {
	var msgID [8]byte
	rand.Read(msgID[:])

	// Pad plaintext with 0-64 random bytes for traffic analysis protection
	padLenBuf := make([]byte, 1)
	rand.Read(padLenBuf)
	padLen := int(padLenBuf[0]) % 65
	padding := make([]byte, padLen)
	rand.Read(padding)
	plaintext = append(plaintext, padding...)

	chunks := encoding.ChunkMessage(msgID, plaintext, 220)

	for _, chunk := range chunks {
		if err := e.sendWithRetry(chunk); err != nil {
			return msgID, 0, err
		}
		// Random jitter between chunks to avoid flooding
		jitter := time.Duration(float64(500) * (1 + (randFloat64()-0.5)*2*maxJitter))
		time.Sleep(jitter * time.Millisecond)
	}
	return msgID, len(chunks), nil
}

func (e *DNSClientEngine) sendWithRetry(chunk *encoding.Chunk) error {
	relays := e.GetRelays()
	for attempt := 0; attempt < maxRetries; attempt++ {
		for _, relay := range relays {
			err := dns.SendChunk(relay, e.zone, chunk, false)
			if err == nil {
				return nil
			}
			slog.Warn("send chunk failed", "relay", relay, "attempt", attempt, "error", err)
		}
		// Exponential backoff with jitter
		sleepMs := float64(baseBackoff/time.Millisecond) * math.Pow(2, float64(attempt)) * (1 + (randFloat64()-0.5)*2*maxJitter)
		time.Sleep(time.Duration(sleepMs) * time.Millisecond)
	}
	return fmt.Errorf("all relays failed after %d attempts", maxRetries)
}

// PollRelays queries all relays for pending messages (PoC: returns empty).
func (e *DNSClientEngine) PollRelays() ([][8]byte, error) {
	return nil, nil
}

func randFloat64() float64 {
	b := make([]byte, 8)
	rand.Read(b)
	return float64(b[0]) / 256.0
}
