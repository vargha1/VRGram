package crypto

import (
    "crypto/rand"
    "encoding/base64"
    "errors"
    "fmt"
    "os"
    "strings"

    "golang.org/x/crypto/chacha20poly1305"
    "golang.org/x/crypto/curve25519"
)

const (
    KeyLength    = 32
    NonceLength  = 24
    KeyFileMagic = "RELAYD IDENTITY KEY v1"
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
	pubB64 := base64.StdEncoding.EncodeToString(kp.PublicKey)
	privB64 := base64.StdEncoding.EncodeToString(kp.PrivateKey)
	data := fmt.Sprintf("%s\npub:%s\npriv:%s\n", KeyFileMagic, pubB64, privB64)
	return os.WriteFile(path, []byte(data), 0600)
}

func LoadIdentity(path string) (*KeyPair, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	lines := strings.Split(strings.TrimSpace(string(data)), "\n")
	if len(lines) < 3 || lines[0] != KeyFileMagic {
		return nil, errors.New("invalid identity file format")
	}
	pubB64 := strings.TrimPrefix(lines[1], "pub:")
	privB64 := strings.TrimPrefix(lines[2], "priv:")
	pub, err := base64.StdEncoding.DecodeString(pubB64)
	if err != nil {
		return nil, fmt.Errorf("invalid public key: %w", err)
	}
	priv, err := base64.StdEncoding.DecodeString(privB64)
	if err != nil {
		return nil, fmt.Errorf("invalid private key: %w", err)
	}
	return &KeyPair{PublicKey: pub, PrivateKey: priv}, nil
}
