package dns

import (
	"crypto/rand"
	"sync"
	"testing"
	"time"

	"github.com/user/dns-transport/internal/encoding"
)

const testAddr = "127.0.0.1:15353"
const testZone = "msg.local-domain"

func TestChunkQueryRoundTrip(t *testing.T) {
	var msgID [8]byte
	rand.Read(msgID[:])
	chunk := encoding.NewChunk(msgID, 0, 1, []byte("test payload"))

	// Start a test server
	handler := &testHandler{chunks: make(map[[8]byte][]*encoding.Chunk)}
	go func() {
		if err := ListenAndServe(testAddr, testZone, handler); err != nil {
			t.Log(err)
		}
	}()

	// Give server time to start
	time.Sleep(100 * time.Millisecond)

	// Send the chunk
	err := SendChunk(testAddr, testZone, chunk, false)
	if err != nil {
		t.Fatal(err)
	}

	// Verify the handler received the chunk
	handler.mu.Lock()
	received, ok := handler.chunks[msgID]
	handler.mu.Unlock()
	if !ok {
		t.Fatal("chunk not received by handler")
	}
	if len(received) != 1 {
		t.Fatalf("expected 1 chunk, got %d", len(received))
	}
	if string(received[0].Payload) != "test payload" {
		t.Fatalf("expected payload 'test payload', got '%s'", string(received[0].Payload))
	}
}

type testHandler struct {
	mu     sync.Mutex
	chunks map[[8]byte][]*encoding.Chunk
}

func (h *testHandler) HandleChunk(chunk *encoding.Chunk) error {
	h.mu.Lock()
	defer h.mu.Unlock()
	h.chunks[chunk.MsgID] = append(h.chunks[chunk.MsgID], chunk)
	return nil
}

func (h *testHandler) QueryChunk(msgID [8]byte, chunkIdx uint16) (*encoding.Chunk, error) {
	h.mu.Lock()
	defer h.mu.Unlock()
	chunks := h.chunks[msgID]
	if int(chunkIdx) >= len(chunks) {
		return nil, nil
	}
	return chunks[chunkIdx], nil
}
