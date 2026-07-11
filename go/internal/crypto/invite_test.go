package crypto

import (
	"bytes"
	"encoding/base32"
	"testing"
)

var testBase32 = base32.HexEncoding.WithPadding(base32.NoPadding)

func TestGenerateAndParseInviteCode(t *testing.T) {
	pubkey := []byte("0123456789abcdef0123456789abcdef") // 32 bytes
	code, nonce, err := GenerateInviteCode(pubkey, "Alice")
	if err != nil {
		t.Fatalf("GenerateInviteCode: %v", err)
	}
	if len(code) < 50 {
		t.Errorf("code too short: %d chars", len(code))
	}
	if len(nonce) != 8 {
		t.Errorf("expected nonce 8 bytes, got %d", len(nonce))
	}

	gotPubkey, gotNonce, gotNickname, err := ParseInviteCode(code)
	if err != nil {
		t.Fatalf("ParseInviteCode: %v", err)
	}
	if !bytes.Equal(gotPubkey, pubkey) {
		t.Errorf("pubkey mismatch")
	}
	if !bytes.Equal(gotNonce, nonce) {
		t.Errorf("nonce mismatch")
	}
	if gotNickname != "Alice" {
		t.Errorf("expected nickname Alice, got %s", gotNickname)
	}
}

func TestDeriveHelloKey(t *testing.T) {
	nonce := []byte{1, 2, 3, 4, 5, 6, 7, 8}
	key1 := DeriveHelloKey(nonce)
	key2 := DeriveHelloKey(nonce)
	if len(key1) != 32 {
		t.Errorf("expected key 32 bytes, got %d", len(key1))
	}
	if !bytes.Equal(key1, key2) {
		t.Errorf("keys should be deterministic")
	}
}

func TestHelloEncryptDecrypt(t *testing.T) {
	key := DeriveHelloKey([]byte("testnonce"))
	payload := []byte(`{"type":"hello","pubkey":"abc123","nickname":"Bob"}`)
	ciphertext, err := EncryptHello(key, payload)
	if err != nil {
		t.Fatalf("EncryptHello: %v", err)
	}
	plaintext, err := DecryptHello(key, ciphertext)
	if err != nil {
		t.Fatalf("DecryptHello: %v", err)
	}
	if !bytes.Equal(plaintext, payload) {
		t.Errorf("round-trip mismatch")
	}
}

func TestHelloWrongKey(t *testing.T) {
	key := DeriveHelloKey([]byte("nonce1"))
	payload := []byte("hello")
	ciphertext, _ := EncryptHello(key, payload)
	wrongKey := DeriveHelloKey([]byte("nonce2"))
	_, err := DecryptHello(wrongKey, ciphertext)
	if err == nil {
		t.Errorf("expected error with wrong key")
	}
}
