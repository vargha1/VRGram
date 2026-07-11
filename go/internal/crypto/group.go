package crypto

import (
	"crypto/rand"
	"crypto/sha256"
	"fmt"

	"golang.org/x/crypto/chacha20poly1305"
)

// GenerateGroupKey generates a random 32-byte group key.
func GenerateGroupKey() ([]byte, error) {
	key := make([]byte, 32)
	if _, err := rand.Read(key); err != nil {
		return nil, fmt.Errorf("generate group key: %w", err)
	}
	return key, nil
}

// EncryptGroupMessage encrypts plaintext with the group key using XChaCha20-Poly1305.
// Format: nonce_24bytes + ciphertext
func EncryptGroupMessage(groupKey []byte, plaintext []byte) ([]byte, error) {
	aead, err := chacha20poly1305.NewX(groupKey)
	if err != nil {
		return nil, fmt.Errorf("new xchacha20: %w", err)
	}
	nonce := make([]byte, chacha20poly1305.NonceSizeX)
	if _, err := rand.Read(nonce); err != nil {
		return nil, fmt.Errorf("generate nonce: %w", err)
	}
	ciphertext := aead.Seal(nil, nonce, plaintext, nil)
	return append(nonce, ciphertext...), nil
}

// DecryptGroupMessage decrypts a ciphertext with the group key.
func DecryptGroupMessage(groupKey []byte, data []byte) ([]byte, error) {
	aead, err := chacha20poly1305.NewX(groupKey)
	if err != nil {
		return nil, fmt.Errorf("new xchacha20: %w", err)
	}
	if len(data) < chacha20poly1305.NonceSizeX {
		return nil, fmt.Errorf("ciphertext too short")
	}
	return aead.Open(nil, data[:chacha20poly1305.NonceSizeX], data[chacha20poly1305.NonceSizeX:], nil)
}

// RotateGroupKey derives a new group key from the old one using SHA256.
// Used for epoch-based key rotation when membership changes.
func RotateGroupKey(oldKey []byte) ([]byte, error) {
	h := sha256.Sum256(append(oldKey, []byte("group-rotation-v1")...))
	return h[:], nil
}
