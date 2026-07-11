package media

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"encoding/json"
	"fmt"
)

type MediaType int32
const (
	MediaTypeText  MediaType = 0
	MediaTypeVoice MediaType = 1
	MediaTypeImage MediaType = 2
	MediaTypeFile  MediaType = 3
	MediaTypeVideo MediaType = 4
)

// MediaMessage is the JSON metadata sent alongside (or before) media payload.
type MediaMessage struct {
	MessageID string   `json:"message_id"`
	Timestamp int64    `json:"timestamp"`
	MediaType MediaType `json:"media_type"`
	// File info (present for all non-text types)
	FileName string `json:"file_name,omitempty"`
	MimeType string `json:"mime_type,omitempty"`
	FileSize int64  `json:"file_size,omitempty"`
	Chunks   int32  `json:"chunks,omitempty"`   // total DNS chunks (0 = sent via TCP)
	ChunkSize int32 `json:"chunk_size,omitempty"`
	FileKeyB64 string `json:"file_key_b64,omitempty"` // base64 AES-256 key
	Checksum   string `json:"checksum,omitempty"`     // "sha256:hex"
	HasThumbnail bool `json:"has_thumbnail,omitempty"`
	Thumbnail    *ThumbnailInfo `json:"thumbnail,omitempty"`
	// TCP transport fields
	Transport string `json:"transport,omitempty"` // "dns" or "tcp"
	FileID     string `json:"file_id,omitempty"`   // file ID on relay (TCP transport)
}

type ThumbnailInfo struct {
	Mime   string `json:"mime"`
	Size   int64  `json:"size"`
	Chunks int32  `json:"chunks"`
	Data   []byte `json:"data,omitempty"` // inline thumbnail for DNS path
}

// EncryptFile encrypts data with AES-256-GCM using the given 32-byte key.
func EncryptFile(key []byte, plaintext []byte) ([]byte, error) {
	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, fmt.Errorf("new cipher: %w", err)
	}
	aesgcm, err := cipher.NewGCM(block)
	if err != nil {
		return nil, fmt.Errorf("new gcm: %w", err)
	}
	nonce := make([]byte, aesgcm.NonceSize())
	if _, err := rand.Read(nonce); err != nil {
		return nil, fmt.Errorf("nonce: %w", err)
	}
	return aesgcm.Seal(nonce, nonce, plaintext, nil), nil
}

// DecryptFile decrypts data with AES-256-GCM using the given 32-byte key.
func DecryptFile(key []byte, ciphertext []byte) ([]byte, error) {
	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, fmt.Errorf("new cipher: %w", err)
	}
	aesgcm, err := cipher.NewGCM(block)
	if err != nil {
		return nil, fmt.Errorf("new gcm: %w", err)
	}
	nonceSize := aesgcm.NonceSize()
	if len(ciphertext) < nonceSize {
		return nil, fmt.Errorf("ciphertext too short")
	}
	nonce, ciphertext := ciphertext[:nonceSize], ciphertext[nonceSize:]
	return aesgcm.Open(nil, nonce, ciphertext, nil)
}

// GenerateFileKey returns a random 32-byte AES-256 key.
func GenerateFileKey() ([]byte, error) {
	k := make([]byte, 32)
	if _, err := rand.Read(k); err != nil {
		return nil, fmt.Errorf("generate file key: %w", err)
	}
	return k, nil
}

// Serialize and deserialize helpers
func (m *MediaMessage) Marshal() ([]byte, error) {
	return json.Marshal(m)
}

func UnmarshalMediaMessage(data []byte) (*MediaMessage, error) {
	var m MediaMessage
	if err := json.Unmarshal(data, &m); err != nil {
		return nil, err
	}
	return &m, nil
}
