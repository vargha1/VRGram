package store

import (
	"path/filepath"
	"testing"
	"time"

	"github.com/user/dns-transport/internal/encoding"
)

func TestChunkStore_MessageMeta(t *testing.T) {
	dir := t.TempDir()
	sc, err := NewSequenceCounter(filepath.Join(dir, "seq.db"))
	if err != nil {
		t.Fatalf("NewSequenceCounter: %v", err)
	}
	defer sc.Close()

	store := NewChunkStore(0, 0) // no GC for test
	store.SetSequenceCounter(sc)

	var msgID [8]byte
	msgID[0] = 0x42
	chunk := encoding.NewChunk(msgID, 0, 1, []byte("hello"))
	chunk.RecipientHash = []byte("recipient-pubkey-hash-32bytes")

	before := time.Now().UnixMilli()
	_, err = store.Store(chunk)
	if err != nil {
		t.Fatalf("Store: %v", err)
	}
	after := time.Now().UnixMilli()

	ts, seq, ok := store.GetMessageMeta(msgID)
	if !ok {
		t.Fatal("GetMessageMeta: not found")
	}
	if ts < before || ts > after {
		t.Errorf("timestamp %d not in range [%d, %d]", ts, before, after)
	}
	if seq != 1 {
		t.Errorf("expected sequence 1, got %d", seq)
	}

	var msgID2 [8]byte
	msgID2[0] = 0x99
	chunk2 := encoding.NewChunk(msgID2, 0, 1, []byte("world"))
	chunk2.RecipientHash = []byte("recipient-pubkey-hash-32bytes")
	store.Store(chunk2)

	_, seq2, _ := store.GetMessageMeta(msgID2)
	if seq2 != 2 {
		t.Errorf("expected sequence 2 for second message, got %d", seq2)
	}
}

func TestChunkStore_MessageMetaNoSequence(t *testing.T) {
	store := NewChunkStore(0, 0)

	var msgID [8]byte
	chunk := encoding.NewChunk(msgID, 0, 1, []byte("hello"))
	store.Store(chunk)

	ts, seq, ok := store.GetMessageMeta(msgID)
	if !ok {
		t.Fatal("GetMessageMeta: not found")
	}
	if ts == 0 {
		t.Error("expected non-zero timestamp")
	}
	if seq != 0 {
		t.Errorf("expected sequence 0 (no counter), got %d", seq)
	}
}

func TestChunkStore_GetMessageMetaNotFound(t *testing.T) {
	store := NewChunkStore(0, 0)
	var unknown [8]byte
	_, _, ok := store.GetMessageMeta(unknown)
	if ok {
		t.Error("expected false for unknown msgID")
	}
}
