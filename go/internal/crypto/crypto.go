package crypto

import (
    "crypto/rand"
    "encoding/base64"
    "fmt"
    "os"
    "strings"

    "golang.org/x/crypto/chacha20poly1305"
    "golang.org/x/crypto/curve25519"
)

const (
    KeyLength   = 32
    NonceLength = 24
)

type KeyPair struct {
    PublicKey  []byte
    PrivateKey []byte
}

func GenerateKeyPair() (*KeyPair, error) {
    privateKey := make([]byte, KeyLength)
    if _, err := rand.Read(privateKey); err != nil {
        return nil, fmt.Errorf("failed to generate private key: %w", err)
    }
    // Clamp for X25519
    privateKey[0] &= 248
    privateKey[31] &= 127
    privateKey[31] |= 64

    publicKey, err := curve25519.X25519(privateKey, curve25519.Basepoint)
    if err != nil {
        return nil, fmt.Errorf("failed to derive public key: %w", err)
    }
    return &KeyPair{PublicKey: publicKey, PrivateKey: privateKey}, nil
}

func SharedSecret(privateKey, peerPublicKey []byte) ([]byte, error) {
    if len(privateKey) != KeyLength {
        return nil, fmt.Errorf("invalid private key length: %d", len(privateKey))
    }
    if len(peerPublicKey) != KeyLength {
        return nil, fmt.Errorf("invalid public key length: %d", len(peerPublicKey))
    }
    secret, err := curve25519.X25519(privateKey, peerPublicKey)
    if err != nil {
        return nil, fmt.Errorf("shared secret derivation failed: %w", err)
    }
    return secret, nil
}

func EncryptMessage(sharedSecret []byte, plaintext []byte) (ciphertext, nonce []byte, err error) {
    aead, err := chacha20poly1305.NewX(sharedSecret)
    if err != nil {
        return nil, nil, fmt.Errorf("failed to create cipher: %w", err)
    }
    nonce = make([]byte, NonceLength)
    if _, err := rand.Read(nonce); err != nil {
        return nil, nil, fmt.Errorf("failed to generate nonce: %w", err)
    }
    ciphertext = aead.Seal(nil, nonce, plaintext, nil)
    return ciphertext, nonce, nil
}

func DecryptMessage(sharedSecret, nonce, ciphertext []byte) ([]byte, error) {
    aead, err := chacha20poly1305.NewX(sharedSecret)
    if err != nil {
        return nil, fmt.Errorf("failed to create cipher: %w", err)
    }
    if len(nonce) != NonceLength {
        return nil, fmt.Errorf("invalid nonce length: %d", len(nonce))
    }
    plaintext, err := aead.Open(nil, nonce, ciphertext, nil)
    if err != nil {
        return nil, fmt.Errorf("decryption failed: %w", err)
    }
    return plaintext, nil
}

func SaveIdentity(path string, kp *KeyPair) error {
    var b strings.Builder
    b.WriteString(base64.StdEncoding.EncodeToString(kp.PrivateKey))
    b.WriteString(":")
    b.WriteString(base64.StdEncoding.EncodeToString(kp.PublicKey))
    return os.WriteFile(path, []byte(b.String()), 0600)
}

func LoadIdentity(path string) (*KeyPair, error) {
    data, err := os.ReadFile(path)
    if err != nil {
        return nil, err
    }
    parts := strings.SplitN(strings.TrimSpace(string(data)), ":", 2)
    if len(parts) != 2 {
        return nil, fmt.Errorf("invalid identity file format")
    }
    privateKey, err := base64.StdEncoding.DecodeString(parts[0])
    if err != nil {
        return nil, fmt.Errorf("failed to decode private key: %w", err)
    }
    publicKey, err := base64.StdEncoding.DecodeString(parts[1])
    if err != nil {
        return nil, fmt.Errorf("failed to decode public key: %w", err)
    }
    return &KeyPair{PublicKey: publicKey, PrivateKey: privateKey}, nil
}
