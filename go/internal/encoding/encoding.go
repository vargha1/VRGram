package encoding

import (
    "encoding/binary"
    "errors"
    "fmt"
    "strings"

    "encoding/base32"
)

var base32hex = base32.HexEncoding.WithPadding(base32.NoPadding)

type Chunk struct {
    MsgID       [8]byte
    ChunkIdx    uint16
    TotalChunks uint16
    Checksum    uint16
    Payload     []byte
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

func ChunkMessage(msgID [8]byte, plaintext []byte, maxChunkSize int) []*Chunk {
    if maxChunkSize <= 0 {
        maxChunkSize = 220
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
    // Sort by index
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

// EncodeToLabels serializes chunk to DNS labels: msgID.chunkIdx.total.checksum.payloadLabels.zone
func (c *Chunk) EncodeToLabels(zone string) []string {
    msgIDStr := base32hex.EncodeToString(c.MsgID[:])
    idxStr := base32hex.EncodeToString(binary.BigEndian.AppendUint16(nil, c.ChunkIdx))
    totalStr := base32hex.EncodeToString(binary.BigEndian.AppendUint16(nil, c.TotalChunks))
    cksumStr := base32hex.EncodeToString(binary.BigEndian.AppendUint16(nil, c.Checksum))
    payloadLabels := EncodePayload(c.Payload)

    labels := make([]string, 0, 4+len(payloadLabels)+1)
    labels = append(labels, msgIDStr, idxStr, totalStr, cksumStr)
    labels = append(labels, payloadLabels...)
    labels = append(labels, zone)
    return labels
}

// DecodeChunkFromLabels parses DNS labels into a Chunk
func DecodeChunkFromLabels(labels []string, zone string) (*Chunk, error) {
    // Remove zone suffix (last label)
    if len(labels) < 5 {
        return nil, errors.New("too few labels for chunk")
    }
    if labels[len(labels)-1] != zone {
        // Try stripping the zone from the last label if it contains it
        // For simplicity, just check the last label matches zone
        return nil, fmt.Errorf("zone mismatch: got %s, want %s", labels[len(labels)-1], zone)
    }
    body := labels[:len(labels)-1]
    if len(body) < 4 {
        return nil, errors.New("too few labels for chunk metadata")
    }

    msgID, err := base32hex.DecodeString(body[0])
    if err != nil || len(msgID) != 8 {
        return nil, fmt.Errorf("invalid msgID: %w", err)
    }
    idxBytes, err := base32hex.DecodeString(body[1])
    if err != nil || len(idxBytes) != 2 {
        return nil, fmt.Errorf("invalid chunkIdx: %w", err)
    }
    totalBytes, err := base32hex.DecodeString(body[2])
    if err != nil || len(totalBytes) != 2 {
        return nil, fmt.Errorf("invalid totalChunks: %w", err)
    }
    cksumBytes, err := base32hex.DecodeString(body[3])
    if err != nil || len(cksumBytes) != 2 {
        return nil, fmt.Errorf("invalid checksum: %w", err)
    }

    payloadLabels := body[4:]
    payload, err := DecodePayload(payloadLabels)
    if err != nil {
        return nil, fmt.Errorf("invalid payload: %w", err)
    }

    var mid [8]byte
    copy(mid[:], msgID)

    return &Chunk{
        MsgID:       mid,
        ChunkIdx:    binary.BigEndian.Uint16(idxBytes),
        TotalChunks: binary.BigEndian.Uint16(totalBytes),
        Checksum:    binary.BigEndian.Uint16(cksumBytes),
        Payload:     payload,
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
