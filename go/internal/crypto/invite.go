package crypto

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/base32"
	"fmt"
	"strings"

	"golang.org/x/crypto/chacha20poly1305"
	"golang.org/x/crypto/hkdf"
)

var base32hex = base32.HexEncoding.WithPadding(base32.NoPadding)

// GenerateInviteCode creates a one-way invite code from a pubkey and nickname.
// Format: v1:<base32(pubkey)>:<base32(nonce_8)>:<base32(nickname)>
// Returns the code and the generated nonce.
func GenerateInviteCode(pubkey []byte, nickname string) (string, []byte, error) {
	if len(pubkey) != 32 {
		return "", nil, fmt.Errorf("pubkey must be 32 bytes, got %d", len(pubkey))
	}
	nonce := make([]byte, 8)
	if _, err := rand.Read(nonce); err != nil {
		return "", nil, fmt.Errorf("generate nonce: %w", err)
	}
	code := fmt.Sprintf("v1:%s:%s:%s",
		base32hex.EncodeToString(pubkey),
		base32hex.EncodeToString(nonce),
		base32hex.EncodeToString([]byte(nickname)),
	)
	return code, nonce, nil
}

// ParseInviteCode decodes an invite code into pubkey, nonce, and nickname.
func ParseInviteCode(code string) (pubkey []byte, nonce []byte, nickname string, err error) {
	parts := strings.SplitN(code, ":", 4)
	if len(parts) != 4 || parts[0] != "v1" {
		return nil, nil, "", fmt.Errorf("invalid invite code format")
	}
	pubkey, err = base32hex.DecodeString(parts[1])
	if err != nil || len(pubkey) != 32 {
		return nil, nil, "", fmt.Errorf("invalid pubkey in invite code")
	}
	nonce, err = base32hex.DecodeString(parts[2])
	if err != nil || len(nonce) != 8 {
		return nil, nil, "", fmt.Errorf("invalid nonce in invite code")
	}
	nickBytes, err := base32hex.DecodeString(parts[3])
	if err != nil {
		return nil, nil, "", fmt.Errorf("invalid nickname in invite code")
	}
	return pubkey, nonce, string(nickBytes), nil
}

// DeriveHelloKey derives a 32-byte XChaCha20 key from the invite nonce.
// Uses HKDF-SHA256 with a fixed context string.
func DeriveHelloKey(nonce []byte) []byte {
	hkdf := hkdf.New(sha256.New, nonce, nil, []byte("vrgram-hello-v1"))
	key := make([]byte, 32)
	hkdf.Read(key)
	return key
}

// EncryptHello encrypts a plaintext payload with the hello key using XChaCha20-Poly1305.
// Format: nonce_24bytes + ciphertext
func EncryptHello(helloKey []byte, payload []byte) ([]byte, error) {
	aead, err := chacha20poly1305.NewX(helloKey)
	if err != nil {
		return nil, fmt.Errorf("new xchacha20: %w", err)
	}
	nonce := make([]byte, chacha20poly1305.NonceSizeX)
	if _, err := rand.Read(nonce); err != nil {
		return nil, fmt.Errorf("generate nonce: %w", err)
	}
	ciphertext := aead.Seal(nil, nonce, payload, nil)
	return append(nonce, ciphertext...), nil
}

// DecryptHello decrypts a ciphertext encrypted with EncryptHello.
func DecryptHello(helloKey []byte, data []byte) ([]byte, error) {
	aead, err := chacha20poly1305.NewX(helloKey)
	if err != nil {
		return nil, fmt.Errorf("new xchacha20: %w", err)
	}
	if len(data) < chacha20poly1305.NonceSizeX {
		return nil, fmt.Errorf("ciphertext too short")
	}
	nonce := data[:chacha20poly1305.NonceSizeX]
	ciphertext := data[chacha20poly1305.NonceSizeX:]
	return aead.Open(nil, nonce, ciphertext, nil)
}
