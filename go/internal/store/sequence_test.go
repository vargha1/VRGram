package store

import (
	"path/filepath"
	"testing"
)

func TestSequenceCounter_Incrementing(t *testing.T) {
	dir := t.TempDir()
	dbPath := filepath.Join(dir, "seq.db")
	sc, err := NewSequenceCounter(dbPath)
	if err != nil {
		t.Fatalf("NewSequenceCounter: %v", err)
	}
	defer sc.Close()

	// First call for peer A should return 1
	seq, err := sc.Next("peerA")
	if err != nil {
		t.Fatalf("Next: %v", err)
	}
	if seq != 1 {
		t.Errorf("expected 1, got %d", seq)
	}

	// Second call for peer A should return 2
	seq, err = sc.Next("peerA")
	if err != nil {
		t.Fatalf("Next: %v", err)
	}
	if seq != 2 {
		t.Errorf("expected 2, got %d", seq)
	}

	// First call for peer B should return 1 (independent counter)
	seq, err = sc.Next("peerB")
	if err != nil {
		t.Fatalf("Next: %v", err)
	}
	if seq != 1 {
		t.Errorf("expected 1, got %d", seq)
	}
}

func TestSequenceCounter_Persistence(t *testing.T) {
	dir := t.TempDir()
	dbPath := filepath.Join(dir, "seq.db")

	// Write some sequences
	sc, _ := NewSequenceCounter(dbPath)
	sc.Next("peerA")
	sc.Next("peerA")
	sc.Next("peerA")
	sc.Close()

	// Reopen and verify continuation
	sc2, err := NewSequenceCounter(dbPath)
	if err != nil {
		t.Fatalf("NewSequenceCounter reopen: %v", err)
	}
	defer sc2.Close()

	seq, _ := sc2.Next("peerA")
	if seq != 4 {
		t.Errorf("expected 4 after reopen, got %d", seq)
	}
}

func TestSequenceCounter_GetLast(t *testing.T) {
	dir := t.TempDir()
	dbPath := filepath.Join(dir, "seq.db")
	sc, _ := NewSequenceCounter(dbPath)
	defer sc.Close()

	// GetLast on unknown peer returns 0
	seq, err := sc.GetLast("unknown")
	if err != nil {
		t.Fatalf("GetLast: %v", err)
	}
	if seq != 0 {
		t.Errorf("expected 0, got %d", seq)
	}

	sc.Next("peerA")
	sc.Next("peerA")

	seq, _ = sc.GetLast("peerA")
	if seq != 2 {
		t.Errorf("expected 2, got %d", seq)
	}
}
