package media

import (
	"bytes"
	"testing"
)

func TestEncryptDecryptRoundTrip(t *testing.T) {
	key, err := GenerateFileKey()
	if err != nil {
		t.Fatalf("GenerateFileKey failed: %v", err)
	}

	if len(key) != 32 {
		t.Fatalf("expected 32-byte key, got %d", len(key))
	}

	plaintext := []byte("hello, this is a test message for media encryption round-trip")

	ciphertext, err := EncryptFile(key, plaintext)
	if err != nil {
		t.Fatalf("EncryptFile failed: %v", err)
	}

	// Ciphertext must be different from plaintext
	if bytes.Equal(ciphertext, plaintext) {
		t.Error("encrypted data should not equal plaintext")
	}

	// Ciphertext must be longer (nonce + tag overhead)
	if len(ciphertext) <= len(plaintext) {
		t.Errorf("encrypted data (%d bytes) should be longer than plaintext (%d bytes)", len(ciphertext), len(plaintext))
	}

	decrypted, err := DecryptFile(key, ciphertext)
	if err != nil {
		t.Fatalf("DecryptFile failed: %v", err)
	}

	if !bytes.Equal(decrypted, plaintext) {
		t.Errorf("decrypted data does not match original: got %q, want %q", string(decrypted), string(plaintext))
	}
}

func TestEncryptDecryptEmptyData(t *testing.T) {
	key, err := GenerateFileKey()
	if err != nil {
		t.Fatalf("GenerateFileKey failed: %v", err)
	}

	plaintext := []byte{}

	ciphertext, err := EncryptFile(key, plaintext)
	if err != nil {
		t.Fatalf("EncryptFile failed on empty data: %v", err)
	}

	decrypted, err := DecryptFile(key, ciphertext)
	if err != nil {
		t.Fatalf("DecryptFile failed on empty data: %v", err)
	}

	if len(decrypted) != 0 {
		t.Errorf("expected empty decrypted data, got %d bytes", len(decrypted))
	}
}

func TestEncryptDecryptLargeData(t *testing.T) {
	key, err := GenerateFileKey()
	if err != nil {
		t.Fatalf("GenerateFileKey failed: %v", err)
	}

	plaintext := make([]byte, 1024*1024) // 1 MB
	for i := range plaintext {
		plaintext[i] = byte(i & 0xff)
	}

	ciphertext, err := EncryptFile(key, plaintext)
	if err != nil {
		t.Fatalf("EncryptFile failed on large data: %v", err)
	}

	decrypted, err := DecryptFile(key, ciphertext)
	if err != nil {
		t.Fatalf("DecryptFile failed on large data: %v", err)
	}

	if !bytes.Equal(decrypted, plaintext) {
		t.Error("decrypted large data does not match original")
	}
}

func TestDecryptWithWrongKey(t *testing.T) {
	key, err := GenerateFileKey()
	if err != nil {
		t.Fatalf("GenerateFileKey failed: %v", err)
	}

	wrongKey := make([]byte, 32)
	wrongKey[0] = 42 // different key

	plaintext := []byte("test data")
	ciphertext, err := EncryptFile(key, plaintext)
	if err != nil {
		t.Fatalf("EncryptFile failed: %v", err)
	}

	_, err = DecryptFile(wrongKey, ciphertext)
	if err == nil {
		t.Error("expected error when decrypting with wrong key, got nil")
	}
}

func TestGenerateFileKeyLength(t *testing.T) {
	key, err := GenerateFileKey()
	if err != nil {
		t.Fatalf("GenerateFileKey failed: %v", err)
	}

	if len(key) != 32 {
		t.Errorf("expected 32-byte key, got %d bytes", len(key))
	}

	// Verify keys are random (extremely unlikely to get same key twice)
	key2, err := GenerateFileKey()
	if err != nil {
		t.Fatalf("GenerateFileKey failed: %v", err)
	}

	if bytes.Equal(key, key2) {
		t.Error("consecutive GenerateFileKey calls returned identical keys")
	}
}

func TestDecryptShortCiphertext(t *testing.T) {
	key := make([]byte, 32) // zero key

	// Ciphertext shorter than nonce size
	_, err := DecryptFile(key, []byte{1, 2, 3})
	if err == nil {
		t.Error("expected error for ciphertext too short, got nil")
	}
}
