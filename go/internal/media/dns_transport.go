package media

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http"
	"time"

	"github.com/user/dns-transport/internal/encoding"
)

const (
	// MaxDNSChunkSize is the max payload per DNS chunk for media (slightly smaller
	// than text to leave room for media chunk header overhead).
	MaxDNSChunkSize = 200
	// MediaDNSSizeThreshold is the max file size sent via DNS before TCP is required.
	MediaDNSSizeThreshold = 240 * 1024 // 240 KB
	// MediaMaxHardCap is the max file size that can be sent via media transport.
	MediaMaxHardCap = 10 * 1024 * 1024 // 10 MB
)

// DNSTransport handles sending media files over DNS chunks.
type DNSTransport struct {
	dnsEngine DNSChunkSender
}

// DNSChunkSender is the interface the DNS engine must implement.
type DNSChunkSender interface {
	SendMessage(ctx context.Context, plaintext []byte) ([8]byte, int, error)
	// For media chunks, recipientPubkey is not needed.
}

// SendMessageAdapter wraps a DNSClientEngine that has the 3-param SendMessage.
type SendMessageAdapter struct {
	Engine interface {
		SendMessage(ctx context.Context, plaintext []byte, recipientPubkey string) ([8]byte, int, error)
	}
}

func (a *SendMessageAdapter) SendMessage(ctx context.Context, plaintext []byte) ([8]byte, int, error) {
	return a.Engine.SendMessage(ctx, plaintext, "")
}

// NewDNSTransport creates a DNS transport for media using the given chunk sender.
func NewDNSTransport(sender DNSChunkSender) *DNSTransport {
	return &DNSTransport{dnsEngine: sender}
}

// SendChunks sends a file over DNS, returning the metadata message and file key.
// Returns the metadata message, file key, and error.
func (t *DNSTransport) SendChunks(ctx context.Context, msgID [8]byte, fileData []byte, fileName string, mimeType string, mediaType MediaType) (*MediaMessage, error) {
	// I5: Enforce hard cap on DNS file size
	if len(fileData) > MediaMaxHardCap {
		return nil, fmt.Errorf("file exceeds max DNS size (%d bytes > %d bytes)", len(fileData), MediaMaxHardCap)
	}

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
	chunks := encoding.ChunkMessage(msgID, encrypted, MaxDNSChunkSize, "")

	// 4. Send each chunk via DNS
	for _, chunk := range chunks {
		if _, _, err := t.dnsEngine.SendMessage(ctx, chunk.Payload); err != nil {
			return nil, fmt.Errorf("send chunk: %w", err)
		}
	}

	// 5. Build metadata message (this is also sent via DNS as a text-like message)
	meta := &MediaMessage{
		MessageID:  fmt.Sprintf("%x", msgID),
		Timestamp:  time.Now().UnixMilli(), // I3: set real timestamp
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

// TCPTransport handles sending media files over HTTP to relay server.
type TCPTransport struct {
	relayAddr string // relay IP:port (e.g., "1.2.3.4:9877")
	client    *http.Client
}

// NewTCPTransport creates a TCP transport for media using the relay's HTTP endpoint.
func NewTCPTransport(relayAddr string) *TCPTransport {
	// Remove :53 DNS port if present, use default media port
	host := relayAddr
	if _, _, err := net.SplitHostPort(relayAddr); err == nil {
		host, _, _ = net.SplitHostPort(relayAddr)
	}
	return &TCPTransport{
		relayAddr: host + ":9877",
		client:    &http.Client{Timeout: 5 * time.Minute},
	}
}

// TCPUploadResponse is the response from the relay's /upload endpoint.
type TCPUploadResponse struct {
	FileID string `json:"file_id"`
}

// SendChunks uploads a file via TCP to the relay server.
func (t *TCPTransport) SendChunks(ctx context.Context, msgID [8]byte, fileData []byte, fileName string, mimeType string, mediaType MediaType) (*MediaMessage, error) {
	// I5: Enforce hard cap (same as DNS)
	if len(fileData) > MediaMaxHardCap {
		return nil, fmt.Errorf("file exceeds max size (%d bytes > %d bytes)", len(fileData), MediaMaxHardCap)
	}

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

	// 3. Upload via HTTP POST
	url := "http://" + t.relayAddr + "/upload"
	req, err := http.NewRequestWithContext(ctx, "POST", url, bytes.NewReader(encrypted))
	if err != nil {
		return nil, fmt.Errorf("create request: %w", err)
	}
	req.Header.Set("Content-Type", "application/octet-stream")

	resp, err := t.client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("upload failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("upload failed: %s", resp.Status)
	}

	var uploadResp TCPUploadResponse
	if err := json.NewDecoder(resp.Body).Decode(&uploadResp); err != nil {
		return nil, fmt.Errorf("decode response: %w", err)
	}

	// 4. Build metadata message
	meta := &MediaMessage{
		MessageID:  fmt.Sprintf("%x", msgID),
		Timestamp:  time.Now().UnixMilli(),
		MediaType:  mediaType,
		FileName:   fileName,
		MimeType:   mimeType,
		FileSize:   int64(len(fileData)),
		Chunks:     0, // not chunked over TCP
		ChunkSize:  0,
		FileKeyB64: base64.StdEncoding.EncodeToString(fileKey),
		Checksum:   fmt.Sprintf("sha256:%x", sha256Hash(fileData)),
		Transport:  "tcp",
		FileID:     uploadResp.FileID,
	}

	return meta, nil
}

// DownloadFile downloads a file from the relay via TCP.
func (t *TCPTransport) DownloadFile(ctx context.Context, fileID string) ([]byte, error) {
	url := "http://" + t.relayAddr + "/download/" + fileID
	req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
	if err != nil {
		return nil, fmt.Errorf("create request: %w", err)
	}

	resp, err := t.client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("download failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode == http.StatusNotFound {
		return nil, fmt.Errorf("file not found")
	}
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("download failed: %s", resp.Status)
	}

	return io.ReadAll(resp.Body)
}