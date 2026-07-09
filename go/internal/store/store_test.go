package store

import (
	"crypto/rand"
	"testing"
	"time"

	"github.com/user/dns-transport/internal/encoding"
)

func TestStoreAndReassemble(t *testing.T) {
	s := NewChunkStore(time.Minute, time.Minute)
	var msgID [8]byte
	rand.Read(msgID[:])
	plaintext := []byte("hello from test message")
	chunks := encoding.ChunkMessage(msgID, plaintext, 50, "")

	for _, c := range chunks {
		complete, err := s.Store(c)
		if err != nil {
			t.Fatal(err)
		}
		if complete {
			msg, err := s.GetCompleteMessage(msgID)
			if err != nil {
				t.Fatal(err)
			}
			if string(msg) != string(plaintext) {
				t.Fatalf("got %s, want %s", msg, plaintext)
			}
		}
	}
}

func TestGC(t *testing.T) {
	s := NewChunkStore(10*time.Millisecond, 50*time.Millisecond)
	var msgID [8]byte
	rand.Read(msgID[:])
	chunk := encoding.NewChunk(msgID, 0, 2, []byte("half message"))
	s.Store(chunk)

	time.Sleep(100 * time.Millisecond)
	if s.PendingCount() != 0 {
		t.Fatal("expected GC to clean up incomplete message")
	}
}
