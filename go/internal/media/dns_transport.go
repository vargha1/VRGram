package media

import (
	"context"
	"crypto/sha256"
	"encoding/base64"
	"fmt"

	"github.com/user/dns-transport/internal/encoding"
)

const (
	// MaxDNSChunkSize is the max payload per DNS chunk for media (slightly smaller
	// than text to leave room for media chunk header overhead).
	MaxDNSChunkSize = 200
	// MediaDNSSizeThreshold is the max file size sent via DNS before libp2p is required.
	MediaDNSSizeThreshold = 240 * 1024 // 240 KB
	// MediaLibp2pHardCap is the max file size that can be sent via DNS at all.
	MediaLibp2pHardCap = 10 * 1024 * 1024 // 10 MB
)

// DNSTransport handles sending media files over DNS chunks.
type DNSTransport struct {
	dnsEngine DNSChunkSender
}

// DNSChunkSender is the interface the DNS engine must implement.
type DNSChunkSender interface {
	SendMessage(ctx context.Context, plaintext []byte) ([8]byte, int, error)
}

func NewDNSTransport(sender DNSChunkSender) *DNSTransport {
	return &DNSTransport{dnsEngine: sender}
}

// SendChunks sends a file over DNS, returning the metadata message and file key.
// Returns the metadata message, file key, and error.
func (t *DNSTransport) SendChunks(ctx context.Context, msgID [8]byte, fileData []byte, fileName string, mimeType string, mediaType MediaType) (*MediaMessage, error) {
	// 1. Generate per-file key
	fileKey, err := GenerateFileKey()
	if err != nil {
		return nil, fmt.Errorf("generate key: %w", err)
	}

	// 2. Encrypt file
	encrypted, err := EncryptFile(fileKey, fileData)
	if err != nil {
		return nil, fmt.Errorf("encrypt: %w", err)
	}

	// 3. Chunk encrypted data
	chunks := encoding.ChunkMessage(msgID, encrypted, MaxDNSChunkSize)

	// 4. Send each chunk via DNS
	for _, chunk := range chunks {
		if _, _, err := t.dnsEngine.SendMessage(ctx, chunk.Payload); err != nil {
			return nil, fmt.Errorf("send chunk: %w", err)
		}
	}

	// 5. Build metadata message (this is also sent via DNS as a text-like message)
	meta := &MediaMessage{
		MessageID:  fmt.Sprintf("%x", msgID),
		Timestamp:  0, // filled by sender
		MediaType:  mediaType,
		FileName:   fileName,
		MimeType:   mimeType,
		FileSize:   int64(len(fileData)),
		Chunks:     int32(len(chunks)),
		ChunkSize:  MaxDNSChunkSize,
		FileKeyB64: base64.StdEncoding.EncodeToString(fileKey),
		Checksum:   fmt.Sprintf("sha256:%x", sha256Hash(fileData)),
	}

	return meta, nil
}

func sha256Hash(data []byte) []byte {
	h := sha256.Sum256(data)
	return h[:]
}
