package encoding

import (
	"crypto/sha256"
	"encoding/base32"
	"encoding/binary"
	"errors"
	"fmt"
	"strings"
)

var base32hex = base32.HexEncoding.WithPadding(base32.NoPadding)

type Chunk struct {
	MsgID         [8]byte
	ChunkIdx      uint16
	TotalChunks   uint16
	Checksum      uint16
	Payload       []byte
	RecipientHash []byte // optional: SHA256 of recipient pubkey (32 bytes)
}

func NewChunk(msgID [8]byte, idx, total uint16, payload []byte) *Chunk {
	return &Chunk{
		MsgID:       msgID,
		ChunkIdx:    idx,
		TotalChunks: total,
		Checksum:    crc16(payload),
		Payload:     payload,
	}
}

// ChunkMessage splits plaintext into chunks. If recipientPubkey is non-empty,
// its SHA256 hash is included in each chunk for server-side recipient indexing.
func ChunkMessage(msgID [8]byte, plaintext []byte, maxChunkSize int, recipientPubkey string) []*Chunk {
	if maxChunkSize <= 0 {
		maxChunkSize = 220
	}
	var recipientHash []byte
	if recipientPubkey != "" {
		h := sha256.Sum256([]byte(recipientPubkey))
		recipientHash = h[:]
	}
	total := (len(plaintext) + maxChunkSize - 1) / maxChunkSize
	chunks := make([]*Chunk, 0, total)
	for i := 0; i < total; i++ {
		start := i * maxChunkSize
		end := start + maxChunkSize
		if end > len(plaintext) {
			end = len(plaintext)
		}
		chunk := NewChunk(msgID, uint16(i), uint16(total), plaintext[start:end])
		chunk.RecipientHash = recipientHash
		chunks = append(chunks, chunk)
	}
	return chunks
}

func ReassembleMessage(chunks []*Chunk) ([]byte, error) {
	if len(chunks) == 0 {
		return nil, errors.New("no chunks to reassemble")
	}
	total := int(chunks[0].TotalChunks)
	if len(chunks) != total {
		return nil, fmt.Errorf("expected %d chunks, got %d", total, len(chunks))
	}
	sorted := make([]*Chunk, total)
	for _, c := range chunks {
		if int(c.ChunkIdx) >= total {
			return nil, fmt.Errorf("chunk index %d out of range", c.ChunkIdx)
		}
		if sorted[c.ChunkIdx] != nil {
			return nil, fmt.Errorf("duplicate chunk index %d", c.ChunkIdx)
		}
		sorted[c.ChunkIdx] = c
	}
	var result []byte
	for _, c := range sorted {
		if c == nil {
			return nil, fmt.Errorf("missing chunk index")
		}
		expected := crc16(c.Payload)
		if c.Checksum != expected {
			return nil, fmt.Errorf("checksum mismatch at chunk %d: got %04x, expected %04x",
				c.ChunkIdx, c.Checksum, expected)
		}
		result = append(result, c.Payload...)
	}
	return result, nil
}

// EncodePayload splits bytes into base32hex labels (max 63 chars each)
func EncodePayload(payload []byte) []string {
	encoded := base32hex.EncodeToString(payload)
	var labels []string
	for i := 0; i < len(encoded); i += 63 {
		end := i + 63
		if end > len(encoded) {
			end = len(encoded)
		}
		labels = append(labels, encoded[i:end])
	}
	return labels
}

// DecodePayload joins base32hex labels and decodes
func DecodePayload(labels []string) ([]byte, error) {
	joined := strings.Join(labels, "")
	return base32hex.DecodeString(joined)
}

// EncodeToLabels serializes chunk to DNS labels:
// [recipientHash] + msgID + chunkIdx + total + checksum + payloadLabels + zone
// recipientHash is only included when present (len > 0).
func (c *Chunk) EncodeToLabels(zone string) []string {
	labels := make([]string, 0, 5+len(c.Payload)/44+2)

	if len(c.RecipientHash) > 0 {
		labels = append(labels, base32hex.EncodeToString(c.RecipientHash))
	}
	labels = append(labels, base32hex.EncodeToString(c.MsgID[:]))
	labels = append(labels, base32hex.EncodeToString(binary.BigEndian.AppendUint16(nil, c.ChunkIdx)))
	labels = append(labels, base32hex.EncodeToString(binary.BigEndian.AppendUint16(nil, c.TotalChunks)))
	labels = append(labels, base32hex.EncodeToString(binary.BigEndian.AppendUint16(nil, c.Checksum)))
	labels = append(labels, EncodePayload(c.Payload)...)
	labels = append(labels, zone)
	return labels
}

// DecodeChunkFromLabels parses DNS labels into a Chunk.
// Supports optional recipientHash prefix (52 base32hex chars = 32 bytes).
func DecodeChunkFromLabels(labels []string, zone string) (*Chunk, error) {
	if len(labels) < 2 {
		return nil, errors.New("too few labels")
	}
	if labels[len(labels)-1] != zone {
		return nil, fmt.Errorf("zone mismatch: got %s, want %s", labels[len(labels)-1], zone)
	}
	body := labels[:len(labels)-1]
	if len(body) < 4 {
		return nil, errors.New("too few labels")
	}

	// Check if first label is a recipient hash (52 base32hex chars = 32 bytes)
	var idxStart int
	var recipientHash []byte
	if len(body[0]) == 52 {
		var err error
		recipientHash, err = base32hex.DecodeString(body[0])
		if err != nil {
			return nil, fmt.Errorf("invalid recipientHash: %w", err)
		}
		if len(recipientHash) != 32 {
			return nil, fmt.Errorf("invalid recipientHash: decoded %d bytes, want 32", len(recipientHash))
		}
		idxStart = 1
	} else {
		idxStart = 0
	}

	if len(body)-idxStart < 4 {
		return nil, errors.New("too few labels after recipientHash")
	}

	msgID, err := base32hex.DecodeString(body[idxStart])
	if err != nil {
		return nil, fmt.Errorf("invalid msgID: %w", err)
	}
	if len(msgID) != 8 {
		return nil, fmt.Errorf("invalid msgID: decoded %d bytes, want 8", len(msgID))
	}
	idxBytes, err := base32hex.DecodeString(body[idxStart+1])
	if err != nil {
		return nil, fmt.Errorf("invalid chunkIdx: %w", err)
	}
	if len(idxBytes) != 2 {
		return nil, fmt.Errorf("invalid chunkIdx: decoded %d bytes, want 2", len(idxBytes))
	}
	totalBytes, err := base32hex.DecodeString(body[idxStart+2])
	if err != nil {
		return nil, fmt.Errorf("invalid totalChunks: %w", err)
	}
	if len(totalBytes) != 2 {
		return nil, fmt.Errorf("invalid totalChunks: decoded %d bytes, want 2", len(totalBytes))
	}
	cksumBytes, err := base32hex.DecodeString(body[idxStart+3])
	if err != nil {
		return nil, fmt.Errorf("invalid checksum: %w", err)
	}
	if len(cksumBytes) != 2 {
		return nil, fmt.Errorf("invalid checksum: decoded %d bytes, want 2", len(cksumBytes))
	}

	payloadLabels := body[idxStart+4:]
	payload, err := DecodePayload(payloadLabels)
	if err != nil {
		return nil, fmt.Errorf("invalid payload: %w", err)
	}

	var mid [8]byte
	copy(mid[:], msgID)

	return &Chunk{
		MsgID:         mid,
		ChunkIdx:      binary.BigEndian.Uint16(idxBytes),
		TotalChunks:   binary.BigEndian.Uint16(totalBytes),
		Checksum:      binary.BigEndian.Uint16(cksumBytes),
		Payload:       payload,
		RecipientHash: recipientHash,
	}, nil
}

// CRC16 (CCITT) for payload integrity
func crc16(data []byte) uint16 {
	var crc uint16 = 0xFFFF
	for _, b := range data {
		crc ^= uint16(b) << 8
		for i := 0; i < 8; i++ {
			if crc&0x8000 != 0 {
				crc = (crc << 1) ^ 0x1021
			} else {
				crc <<= 1
			}
		}
	}
	return crc ^ 0xFFFF
}
