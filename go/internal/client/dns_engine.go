package client

import (
	"context"
	"crypto/rand"
	"fmt"
	"log/slog"
	"math"
	"sync"
	"time"

	"github.com/user/dns-transport/internal/bridge"
	"github.com/user/dns-transport/internal/dns"
	"github.com/user/dns-transport/internal/encoding"
)

const (
	maxRetries     = 3
	baseBackoff    = 500 * time.Millisecond
	maxJitter      = 0.25
	parallelism    = 15 // max concurrent goroutines (5 relays x 3 concurrency)
	maxRelays      = 5
	chunkSize      = 220
)

// DNSClientEngine sends chunked messages over DNS with retry and failover.
// Supports parallel sending across dynamically discovered relays via bridge client.
type DNSClientEngine struct {
	mu            sync.RWMutex
	relays        []string       // mutable, managed via SetRelays/GetRelays for daemon
	fallbackRelays []string      // static fallback when bridgeCli is nil
	bridgeCli     *bridge.Client // optional, for dynamic relay discovery
	zone          string
}

// NewDNSClientEngine creates a new DNS client engine.
// bridgeCli can be nil (disables parallel pipeline, falls back to serial sending).
// fallbackRelays are used when bridgeCli is nil or discovery fails.
func NewDNSClientEngine(bridgeCli *bridge.Client, fallbackRelays []string, zone string) *DNSClientEngine {
	relays := make([]string, len(fallbackRelays))
	copy(relays, fallbackRelays)
	return &DNSClientEngine{
		bridgeCli:      bridgeCli,
		fallbackRelays: fallbackRelays,
		relays:         relays,
		zone:           zone,
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
// If bridge client is available, discovers relays dynamically and sends in parallel.
// Otherwise falls back to serial sending with configured relays.
func (e *DNSClientEngine) SendMessage(ctx context.Context, plaintext []byte) ([8]byte, int, error) {
	var msgID [8]byte
	rand.Read(msgID[:])

	// Pad plaintext with 0-64 random bytes for traffic analysis protection
	padLenBuf := make([]byte, 1)
	rand.Read(padLenBuf)
	padLen := int(padLenBuf[0]) % 65
	padding := make([]byte, padLen)
	rand.Read(padding)
	plaintext = append(plaintext, padding...)

	chunks := encoding.ChunkMessage(msgID, plaintext, chunkSize)

	relays := e.discoverActiveRelays(ctx)
	if e.bridgeCli != nil && len(relays) > 0 {
		// Parallel send across discovered relays
		if err := e.sendParallel(ctx, chunks, relays); err != nil {
			return msgID, 0, err
		}
	} else {
		// Fallback serial sending (backward compatible)
		for _, chunk := range chunks {
			if err := e.sendWithRetry(ctx, chunk); err != nil {
				return msgID, 0, err
			}
			// Random jitter between chunks to avoid flooding
			jitter := time.Duration(float64(500) * (1 + (randFloat64()-0.5)*2*maxJitter))
			time.Sleep(jitter * time.Millisecond)
		}
	}
	return msgID, len(chunks), nil
}

// discoverActiveRelays returns up to maxRelays relay DNS addresses.
// Uses bridge client for dynamic discovery when available.
// Falls back to fallbackRelays or the mutable relay list.
func (e *DNSClientEngine) discoverActiveRelays(ctx context.Context) []string {
	if e.bridgeCli != nil {
		ch, err := e.bridgeCli.DiscoverRelays(ctx, maxRelays, false)
		if err == nil {
			select {
			case upd, ok := <-ch:
				if ok && len(upd.Added) > 0 {
					addrs := make([]string, 0, len(upd.Added))
					for _, r := range upd.Added {
						if r.DNSAddress != "" {
							addrs = append(addrs, r.DNSAddress)
						}
					}
					if len(addrs) > 0 {
						return addrs
					}
				}
			case <-ctx.Done():
				slog.Warn("relay discovery cancelled", "error", ctx.Err())
				return nil
			}
		} else {
			slog.Warn("bridge relay discovery failed", "error", err)
		}
	}

	// Fallback to static relays
	if len(e.fallbackRelays) > 0 {
		return e.fallbackRelays
	}
	return e.GetRelays()
}

// sendParallel sends all chunks to all relays concurrently.
// Semaphore caps at parallelism (15) goroutines.
// Cancels remaining goroutines on first error (early abort).
func (e *DNSClientEngine) sendParallel(ctx context.Context, chunks []*encoding.Chunk, relays []string) error {
	total := len(chunks) * len(relays)
	if total == 0 {
		return nil
	}

	sem := make(chan struct{}, parallelism)
	var wg sync.WaitGroup
	errCh := make(chan error, total)

	// Cancellable context for early abort on first error
	sendCtx, cancel := context.WithCancel(ctx)
	defer cancel()

	for _, chunk := range chunks {
		for _, relay := range relays {
			wg.Add(1)
			chunk := chunk // capture loop var
			relay := relay
			go func() {
				defer wg.Done()

				// Respect context / cancellation before acquiring semaphore
				select {
				case sem <- struct{}{}:
				case <-sendCtx.Done():
					return
				}
				defer func() { <-sem }()

				// Check context before sending
				select {
				case <-sendCtx.Done():
					return
				default:
				}

				if err := dns.SendChunk(relay, e.zone, chunk, false); err != nil {
					errCh <- fmt.Errorf("send to %s: %w", relay, err)
					cancel() // signal remaining goroutines to abort
				}
			}()
		}
	}

	wg.Wait()
	close(errCh)

	// Collect errors, return first
	for err := range errCh {
		if err != nil {
			return err
		}
	}
	return nil
}

// sendWithRetry tries each relay in sequence with exponential backoff.
// Retained for fallback when bridge client is unavailable.
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
		// Exponential backoff with jitter
		sleepMs := float64(baseBackoff/time.Millisecond) * math.Pow(2, float64(attempt)) * (1 + (randFloat64()-0.5)*2*maxJitter)
		time.Sleep(time.Duration(sleepMs) * time.Millisecond)
	}
	return fmt.Errorf("all relays failed after %d attempts", maxRetries)
}

// PollRelays queries all discovered relays for pending messages (PoC: stub).
func (e *DNSClientEngine) PollRelays() ([][8]byte, error) {
	return nil, nil
}

func randFloat64() float64 {
	b := make([]byte, 8)
	rand.Read(b)
	return float64(b[0]) / 256.0
}
