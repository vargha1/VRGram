package store

import (
	"sync"
	"time"

	"github.com/user/dns-transport/internal/encoding"
)

// DefaultTTL is the default TTL for stored chunks (7 days).
const DefaultTTL = 7 * 24 * time.Hour

// DefaultGCInterval is the default garbage collection interval.
const DefaultGCInterval = 60 * time.Second

type messageBuf struct {
	chunks    map[uint16]*encoding.Chunk
	total     uint16
	createdAt time.Time
}

type ChunkStore struct {
	mu           sync.RWMutex
	messages     map[[8]byte]*messageBuf
	gcInterval   time.Duration
	ttl          time.Duration
	done         chan struct{}

	// Per-peer storage tracking
	peerMu       sync.RWMutex
	peerMessages map[string]int     // peerID -> number of message buffers
	messageOwner map[[8]byte]string // msgID -> peerID
	maxPerPeer   int                // max message buffers per peer (0 = unlimited)
}

func NewChunkStore(gcInterval, ttl time.Duration) *ChunkStore {
	s := &ChunkStore{
		messages:     make(map[[8]byte]*messageBuf),
		gcInterval:   gcInterval,
		ttl:          ttl,
		done:         make(chan struct{}),
		peerMessages: make(map[string]int),
		messageOwner: make(map[[8]byte]string),
		maxPerPeer:   100,
	}
	if gcInterval > 0 {
		go s.gcLoop()
	}
	return s
}

func (s *ChunkStore) SetMaxPerPeer(limit int) {
	s.peerMu.Lock()
	defer s.peerMu.Unlock()
	s.maxPerPeer = limit
}

func (s *ChunkStore) SetMessageOwner(msgID [8]byte, peerID string) {
	s.peerMu.Lock()
	defer s.peerMu.Unlock()
	if _, exists := s.messageOwner[msgID]; !exists {
		s.messageOwner[msgID] = peerID
		s.peerMessages[peerID]++
	}
}

func (s *ChunkStore) PeerMessageCount(peerID string) int {
	s.peerMu.RLock()
	defer s.peerMu.RUnlock()
	return s.peerMessages[peerID]
}

func (s *ChunkStore) TotalPeers() int {
	s.peerMu.RLock()
	defer s.peerMu.RUnlock()
	return len(s.peerMessages)
}

func (s *ChunkStore) ListPeerMessages(peerID string) [][8]byte {
	s.peerMu.RLock()
	defer s.peerMu.RUnlock()
	var ids [][8]byte
	for id, pid := range s.messageOwner {
		if pid == peerID {
			ids = append(ids, id)
		}
	}
	return ids
}

func (s *ChunkStore) Store(chunk *encoding.Chunk) (bool, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	buf, ok := s.messages[chunk.MsgID]
	if !ok {
		buf = &messageBuf{
			chunks:    make(map[uint16]*encoding.Chunk),
			total:     chunk.TotalChunks,
			createdAt: time.Now(),
		}
		s.messages[chunk.MsgID] = buf
	}

	buf.chunks[chunk.ChunkIdx] = chunk

	if len(buf.chunks) == int(buf.total) {
		return true, nil
	}
	return false, nil
}

func (s *ChunkStore) GetChunk(msgID [8]byte, chunkIdx uint16) (*encoding.Chunk, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	buf, ok := s.messages[msgID]
	if !ok {
		return nil, nil
	}
	return buf.chunks[chunkIdx], nil
}

func (s *ChunkStore) GetCompleteMessage(msgID [8]byte) ([]byte, error) {
	s.mu.RLock()
	buf, ok := s.messages[msgID]
	s.mu.RUnlock()
	if !ok {
		return nil, nil
	}

	chunks := make([]*encoding.Chunk, 0, len(buf.chunks))
	for _, c := range buf.chunks {
		chunks = append(chunks, c)
	}
	return encoding.ReassembleMessage(chunks)
}

func (s *ChunkStore) PendingCount() int {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return len(s.messages)
}

func (s *ChunkStore) Stop() {
	close(s.done)
}

func (s *ChunkStore) gcLoop() {
	ticker := time.NewTicker(s.gcInterval)
	defer ticker.Stop()
	for {
		select {
		case <-ticker.C:
			s.gc()
		case <-s.done:
			return
		}
	}
}

func (s *ChunkStore) gc() {
	s.mu.Lock()
	defer s.mu.Unlock()
	now := time.Now()
	for id, buf := range s.messages {
		if now.Sub(buf.createdAt) > s.ttl {
			delete(s.messages, id)
			s.peerMu.Lock()
			if peerID, ok := s.messageOwner[id]; ok {
				s.peerMessages[peerID]--
				if s.peerMessages[peerID] <= 0 {
					delete(s.peerMessages, peerID)
				}
				delete(s.messageOwner, id)
			}
			s.peerMu.Unlock()
		}
	}
}
