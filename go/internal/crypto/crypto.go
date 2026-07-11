package crypto

import (
	"crypto/ed25519"
	"crypto/rand"
	"crypto/sha512"
	"encoding/base64"
	"errors"
	"fmt"
	"os"
	"strings"

	"golang.org/x/crypto/chacha20poly1305"
	"golang.org/x/crypto/curve25519"
)

const (
	KeyLength        = 32
	NonceLength      = 24
	KeyFileMagicV1   = "RELAYD IDENTITY KEY v1"
	KeyFileMagicV2   = "RELAYD IDENTITY KEY v2"
	SignatureLen     = ed25519.SignatureSize // 64
	Ed25519SeedLen   = 32
)

type KeyPair struct {
	PublicKey  []byte // X25519 public key (32 bytes)
	PrivateKey []byte // X25519 private key (32 bytes)

	// Ed25519 signing key (optional, derived or loaded from identity file)
	Ed25519PublicKey  []byte // Ed25519 public key (32 bytes)
	Ed25519PrivateKey []byte // Ed25519 private key seed (32 bytes) — full priv key derived from this
}

// GenerateKeyPair generates a new X25519 keypair and derives Ed25519 signing keys.
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

	kp := &KeyPair{PublicKey: publicKey, PrivateKey: privateKey}
	deriveEd25519(kp)
	return kp, nil
}

// deriveEd25519 derives Ed25519 signing keys from the X25519 private key.
// Uses SHA512(x25519_priv) as the Ed25519 seed so it's deterministic.
func deriveEd25519(kp *KeyPair) {
	seed := sha512.Sum512(kp.PrivateKey)
	edSeed := seed[:Ed25519SeedLen]
	edPriv := ed25519.NewKeyFromSeed(edSeed)
	kp.Ed25519PrivateKey = edPriv
	kp.Ed25519PublicKey = make([]byte, ed25519.PublicKeySize)
	copy(kp.Ed25519PublicKey, edPriv[32:]) // last 32 bytes of private key are the public key
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

// SignMessage signs a message with the sender's Ed25519 private key.
// Returns the signature (64 bytes).
func SignMessage(kp *KeyPair, message []byte) []byte {
	if len(kp.Ed25519PrivateKey) == 0 {
		return nil
	}
	return ed25519.Sign(kp.Ed25519PrivateKey, message)
}

// VerifySignature checks a message signature against an Ed25519 public key.
func VerifySignature(publicKey, message, signature []byte) bool {
	if len(publicKey) != ed25519.PublicKeySize || len(signature) != ed25519.SignatureSize {
		return false
	}
	return ed25519.Verify(publicKey, message, signature)
}

// BuildSignedPayload constructs the encrypted payload with sender identity and signature.
// Format: senderX25519Pubkey_b64\nsenderEd25519Pubkey_b64\nsignature_b64\nplaintext
func BuildSignedPayload(kp *KeyPair, plaintext []byte) []byte {
	senderX25519 := base64.StdEncoding.EncodeToString(kp.PublicKey)
	senderEd25519 := base64.StdEncoding.EncodeToString(kp.Ed25519PublicKey)

	// Sign: ed25519_pubkey\nplaintext
	sigData := []byte(senderEd25519 + "\n")
	sigData = append(sigData, plaintext...)
	sig := SignMessage(kp, sigData)
	sigB64 := base64.StdEncoding.EncodeToString(sig)

	return []byte(senderX25519 + "\n" + senderEd25519 + "\n" + sigB64 + "\n" + string(plaintext))
}

// ParseSignedPayload extracts sender info and verifies signature from a decrypted payload.
// Returns senderX25519Pubkey, plaintext, verified (bool), error.
// For backward compatibility, payloads without signature (old format) are accepted as verified=false.
func ParseSignedPayload(payload []byte) (senderX25519Pubkey string, senderEd25519Pubkey []byte, plaintext []byte, verified bool, err error) {
	parts := strings.SplitN(string(payload), "\n", 4)

	if len(parts) == 2 {
		// Old format: senderX25519\nplaintext — no signature
		return parts[0], nil, []byte(parts[1]), false, nil
	}

	if len(parts) < 4 {
		return "", nil, nil, false, errors.New("invalid payload format")
	}

	senderX25519Pubkey = parts[0]
	ed25519PubB64 := parts[1]
	sigB64 := parts[2]
	plaintext = []byte(parts[3])

	// Decode Ed25519 public key
	ed25519Pub, err := base64.StdEncoding.DecodeString(ed25519PubB64)
	if err != nil || len(ed25519Pub) != ed25519.PublicKeySize {
		return senderX25519Pubkey, nil, plaintext, false, nil
	}

	// Decode signature
	sig, err := base64.StdEncoding.DecodeString(sigB64)
	if err != nil || len(sig) != ed25519.SignatureSize {
		return senderX25519Pubkey, ed25519Pub, plaintext, false, nil
	}

	// Verify: signature is over ed25519_pubkey\nplaintext
	sigData := []byte(ed25519PubB64 + "\n")
	sigData = append(sigData, plaintext...)
	verified = VerifySignature(ed25519Pub, sigData, sig)

	return senderX25519Pubkey, ed25519Pub, plaintext, verified, nil
}

func SaveIdentity(path string, kp *KeyPair) error {
	pubB64 := base64.StdEncoding.EncodeToString(kp.PublicKey)
	privB64 := base64.StdEncoding.EncodeToString(kp.PrivateKey)
	edB64 := base64.StdEncoding.EncodeToString(kp.Ed25519PrivateKey[:Ed25519SeedLen])
	magic := KeyFileMagicV2
	data := fmt.Sprintf("%s\npub:%s\npriv:%s\ned25519:%s\n", magic, pubB64, privB64, edB64)
	return os.WriteFile(path, []byte(data), 0600)
}

func LoadIdentity(path string) (*KeyPair, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	lines := strings.Split(strings.TrimSpace(string(data)), "\n")
	if len(lines) < 3 {
		return nil, errors.New("invalid identity file format")
	}

	magic := lines[0]
	kp := &KeyPair{}

	switch magic {
	case KeyFileMagicV1:
		// Old v1 format — no Ed25519 keys, derive from X25519
		pubB64 := strings.TrimPrefix(lines[1], "pub:")
		privB64 := strings.TrimPrefix(lines[2], "priv:")
		kp.PublicKey, err = base64.StdEncoding.DecodeString(pubB64)
		if err != nil {
			return nil, fmt.Errorf("invalid public key: %w", err)
		}
		kp.PrivateKey, err = base64.StdEncoding.DecodeString(privB64)
		if err != nil {
			return nil, fmt.Errorf("invalid private key: %w", err)
		}
		// Derive Ed25519 keys from X25519 private key
		deriveEd25519(kp)

	case KeyFileMagicV2:
		if len(lines) < 4 {
			return nil, errors.New("invalid v2 identity file format")
		}
		pubB64 := strings.TrimPrefix(lines[1], "pub:")
		privB64 := strings.TrimPrefix(lines[2], "priv:")
		edB64 := strings.TrimPrefix(lines[3], "ed25519:")
		kp.PublicKey, err = base64.StdEncoding.DecodeString(pubB64)
		if err != nil {
			return nil, fmt.Errorf("invalid public key: %w", err)
		}
		kp.PrivateKey, err = base64.StdEncoding.DecodeString(privB64)
		if err != nil {
			return nil, fmt.Errorf("invalid private key: %w", err)
		}
		// Restore Ed25519 from seed
		edSeed, err := base64.StdEncoding.DecodeString(edB64)
		if err != nil || len(edSeed) != Ed25519SeedLen {
			// Fall back to derivation if seed is invalid
			deriveEd25519(kp)
			break
		}
			edPriv := ed25519.NewKeyFromSeed(edSeed)
			kp.Ed25519PrivateKey = edPriv
			kp.Ed25519PublicKey = make([]byte, ed25519.PublicKeySize)
			copy(kp.Ed25519PublicKey, edPriv[32:])

	default:
		return nil, errors.New("unknown identity file format")
	}

	return kp, nil
}
