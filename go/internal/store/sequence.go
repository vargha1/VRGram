package store

import (
	"encoding/binary"
	"fmt"

	bolt "go.etcd.io/bbolt"
)

var sequenceBucket = []byte("sequences")

// SequenceCounter provides monotonic per-recipient sequence numbers,
// persisted to a BoltDB file. Survives process restarts.
type SequenceCounter struct {
	db *bolt.DB
}

// NewSequenceCounter opens (or creates) a BoltDB file for sequence tracking.
func NewSequenceCounter(dbPath string) (*SequenceCounter, error) {
	db, err := bolt.Open(dbPath, 0600, nil)
	if err != nil {
		return nil, fmt.Errorf("open sequence db: %w", err)
	}
	// Ensure bucket exists
	err = db.Update(func(tx *bolt.Tx) error {
		_, err := tx.CreateBucketIfNotExists(sequenceBucket)
		return err
	})
	if err != nil {
		db.Close()
		return nil, fmt.Errorf("create sequence bucket: %w", err)
	}
	return &SequenceCounter{db: db}, nil
}

// Next atomically increments and returns the next sequence number for peerID.
func (sc *SequenceCounter) Next(peerID string) (uint64, error) {
	var seq uint64
	err := sc.db.Update(func(tx *bolt.Tx) error {
		b := tx.Bucket(sequenceBucket)
		key := []byte(peerID)
		current := b.Get(key)
		if current != nil {
			seq = binary.BigEndian.Uint64(current)
		}
		seq++
		buf := make([]byte, 8)
		binary.BigEndian.PutUint64(buf, seq)
		return b.Put(key, buf)
	})
	return seq, err
}

// GetLast returns the current (most recent) sequence number for peerID.
// Returns 0 if no sequence has been assigned.
func (sc *SequenceCounter) GetLast(peerID string) (uint64, error) {
	var seq uint64
	err := sc.db.View(func(tx *bolt.Tx) error {
		b := tx.Bucket(sequenceBucket)
		val := b.Get([]byte(peerID))
		if val != nil {
			seq = binary.BigEndian.Uint64(val)
		}
		return nil
	})
	return seq, err
}

// Close closes the underlying BoltDB.
func (sc *SequenceCounter) Close() error {
	return sc.db.Close()
}

// PeerIDFromPubkey derives a short peer ID string from a base64 pubkey
// for use as the sequence counter key. Uses first 8 chars — collisions
// are harmless (shared sequence space is fine).
func PeerIDFromPubkey(pubkey string) string {
	if len(pubkey) > 8 {
		return pubkey[:8]
	}
	return pubkey
}
