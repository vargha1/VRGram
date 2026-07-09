package encoding

import (
    "bytes"
    "crypto/rand"
    "testing"
)

func TestPayloadRoundTrip(t *testing.T) {
    original := []byte("hello world this is a test payload for DNS transport encoding")
    labels := EncodePayload(original)
    decoded, err := DecodePayload(labels)
    if err != nil {
        t.Fatal(err)
    }
    if !bytes.Equal(original, decoded) {
        t.Fatalf("round trip mismatch: got %x, want %x", decoded, original)
    }
}

func TestChunkRoundTrip(t *testing.T) {
    var msgID [8]byte
    rand.Read(msgID[:])
    payload := make([]byte, 200)
    rand.Read(payload)

    chunk := NewChunk(msgID, 0, 5, payload)
    labels := chunk.EncodeToLabels("msg.local-domain")
    parsed, err := DecodeChunkFromLabels(labels, "msg.local-domain")
    if err != nil {
        t.Fatal(err)
    }
    if !bytes.Equal(chunk.MsgID[:], parsed.MsgID[:]) {
        t.Fatal("msgID mismatch")
    }
    if chunk.ChunkIdx != parsed.ChunkIdx || chunk.TotalChunks != parsed.TotalChunks {
        t.Fatal("index mismatch")
    }
    if chunk.Checksum != parsed.Checksum {
        t.Fatal("checksum mismatch")
    }
    if !bytes.Equal(chunk.Payload, parsed.Payload) {
        t.Fatal("payload mismatch")
    }
}

func TestChunkMessageReassemble(t *testing.T) {
    var msgID [8]byte
    rand.Read(msgID[:])
    original := make([]byte, 1000)
    rand.Read(original)

    chunks := ChunkMessage(msgID, original, 220, "")
    if len(chunks) != 5 { // ceil(1000/220)
        t.Fatalf("expected 5 chunks, got %d", len(chunks))
    }

    reassembled, err := ReassembleMessage(chunks)
    if err != nil {
        t.Fatal(err)
    }
    if !bytes.Equal(original, reassembled) {
        t.Fatal("reassembled message does not match original")
    }
}

func TestChecksumMismatch(t *testing.T) {
    var msgID [8]byte
    chunk := NewChunk(msgID, 0, 1, []byte("test"))
    // Corrupt payload after creation
    chunk.Payload[0] ^= 0xFF
    _, err := ReassembleMessage([]*Chunk{chunk})
    if err == nil {
        t.Fatal("expected checksum error, got nil")
    }
}
