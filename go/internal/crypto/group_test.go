package crypto

import (
	"bytes"
	"testing"
)

func TestGroupKeyGeneration(t *testing.T) {
	key, err := GenerateGroupKey()
	if err != nil {
		t.Fatalf("GenerateGroupKey: %v", err)
	}
	if len(key) != 32 {
		t.Errorf("expected 32 bytes, got %d", len(key))
	}
}

func TestGroupEncryptDecrypt(t *testing.T) {
	key, _ := GenerateGroupKey()
	plaintext := []byte("hello group")
	ciphertext, err := EncryptGroupMessage(key, plaintext)
	if err != nil {
		t.Fatalf("EncryptGroupMessage: %v", err)
	}
	got, err := DecryptGroupMessage(key, ciphertext)
	if err != nil {
		t.Fatalf("DecryptGroupMessage: %v", err)
	}
	if !bytes.Equal(got, plaintext) {
		t.Errorf("round-trip mismatch")
	}
}

func TestGroupKeyRotation(t *testing.T) {
	key1, _ := GenerateGroupKey()
	key2, err := RotateGroupKey(key1)
	if err != nil {
		t.Fatalf("RotateGroupKey: %v", err)
	}
	if bytes.Equal(key1, key2) {
		t.Errorf("rotated key should differ from original")
	}
	if len(key2) != 32 {
		t.Errorf("expected 32 bytes, got %d", len(key2))
	}
}

func TestGroupEncryptDecryptWrongKey(t *testing.T) {
	key1, _ := GenerateGroupKey()
	key2, _ := GenerateGroupKey()
	plaintext := []byte("secret group message")
	ciphertext, _ := EncryptGroupMessage(key1, plaintext)
	_, err := DecryptGroupMessage(key2, ciphertext)
	if err == nil {
		t.Errorf("expected error with wrong key")
	}
}
