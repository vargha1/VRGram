package crypto

import (
	"bytes"
	"encoding/base64"
	"os"
	"testing"
)

func TestKeyGeneration(t *testing.T) {
	kp, err := GenerateKeyPair()
	if err != nil {
		t.Fatal(err)
	}
	if len(kp.PublicKey) != 32 {
		t.Fatalf("expected 32-byte public key, got %d", len(kp.PublicKey))
	}
	if len(kp.PrivateKey) != 32 {
		t.Fatalf("expected 32-byte private key, got %d", len(kp.PrivateKey))
	}
	if len(kp.Ed25519PublicKey) != 32 {
		t.Fatalf("expected 32-byte Ed25519 public key, got %d", len(kp.Ed25519PublicKey))
	}
	if len(kp.Ed25519PrivateKey) != 64 {
		t.Fatalf("expected 64-byte Ed25519 private key, got %d", len(kp.Ed25519PrivateKey))
	}
}

func TestSignVerify(t *testing.T) {
	alice, err := GenerateKeyPair()
	if err != nil {
		t.Fatal(err)
	}

	message := []byte("hello from alice")
	sig := SignMessage(alice, message)
	if sig == nil {
		t.Fatal("signature should not be nil")
	}
	if len(sig) != SignatureLen {
		t.Fatalf("expected 64-byte signature, got %d", len(sig))
	}

	if !VerifySignature(alice.Ed25519PublicKey, message, sig) {
		t.Fatal("signature verification failed")
	}

	// Wrong message should fail
	if VerifySignature(alice.Ed25519PublicKey, []byte("tampered"), sig) {
		t.Fatal("tampered message should not verify")
	}
}

func TestBuildAndParseSignedPayload(t *testing.T) {
	alice, err := GenerateKeyPair()
	if err != nil {
		t.Fatal(err)
	}

	original := []byte("hello bob, this is alice")
	payload := BuildSignedPayload(alice, original)

	sender, edPub, plaintext, verified, err := ParseSignedPayload(payload)
	if err != nil {
		t.Fatal(err)
	}
	if !verified {
		t.Fatal("signature should verify")
	}
	if sender != base64.StdEncoding.EncodeToString(alice.PublicKey) {
		t.Fatal("sender pubkey mismatch")
	}
	if !bytes.Equal(edPub, alice.Ed25519PublicKey) {
		t.Fatal("Ed25519 pubkey mismatch")
	}
	if !bytes.Equal(plaintext, original) {
		t.Fatal("plaintext mismatch")
	}

	// Tampered payload (change a byte in plaintext)
	tampered := make([]byte, len(payload))
	copy(tampered, payload)
	tampered[len(tampered)-1] ^= 1
	_, _, _, tamperedVerified, _ := ParseSignedPayload(tampered)
	if tamperedVerified {
		t.Fatal("tampered payload should not verify")
	}
}

func TestEncryptDecrypt(t *testing.T) {
	alice, err := GenerateKeyPair()
	if err != nil {
		t.Fatal(err)
	}
	bob, err := GenerateKeyPair()
	if err != nil {
		t.Fatal(err)
	}

	aliceSecret, err := SharedSecret(alice.PrivateKey, bob.PublicKey)
	if err != nil {
		t.Fatal(err)
	}
	plaintext := []byte("hello from alice to bob, this is a secret message")
	ciphertext, nonce, err := EncryptMessage(aliceSecret, plaintext)
	if err != nil {
		t.Fatal(err)
	}

	bobSecret, err := SharedSecret(bob.PrivateKey, alice.PublicKey)
	if err != nil {
		t.Fatal(err)
	}
	decrypted, err := DecryptMessage(bobSecret, nonce, ciphertext)
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(plaintext, decrypted) {
		t.Fatal("decrypted message does not match original")
	}
}

func TestWrongKeyFails(t *testing.T) {
	alice, _ := GenerateKeyPair()
	bob, _ := GenerateKeyPair()
	eve, _ := GenerateKeyPair()

	aliceSecret, _ := SharedSecret(alice.PrivateKey, bob.PublicKey)
	plaintext := []byte("secret")
	ciphertext, nonce, _ := EncryptMessage(aliceSecret, plaintext)

	eveSecret, _ := SharedSecret(eve.PrivateKey, alice.PublicKey)
	_, err := DecryptMessage(eveSecret, nonce, ciphertext)
	if err == nil {
		t.Fatal("expected decryption to fail with wrong key, got nil")
	}
}

func TestSaveLoadIdentityV2(t *testing.T) {
	kp, _ := GenerateKeyPair()
	path := t.TempDir() + "/identity.key"
	if err := SaveIdentity(path, kp); err != nil {
		t.Fatal(err)
	}
	loaded, err := LoadIdentity(path)
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(kp.PublicKey, loaded.PublicKey) {
		t.Fatal("public key mismatch after save/load")
	}
	if !bytes.Equal(kp.PrivateKey, loaded.PrivateKey) {
		t.Fatal("private key mismatch after save/load")
	}
	if !bytes.Equal(kp.Ed25519PublicKey, loaded.Ed25519PublicKey) {
		t.Fatal("Ed25519 public key mismatch after save/load")
	}
	// Signing with loaded key
	msg := []byte("test message")
	sig := SignMessage(loaded, msg)
	if !VerifySignature(loaded.Ed25519PublicKey, msg, sig) {
		t.Fatal("sign/verify failed after loading identity")
	}
}

func TestLoadV1UpgradesToV2(t *testing.T) {
	v1kp, _ := GenerateKeyPair()
	v1Pub := base64.StdEncoding.EncodeToString(v1kp.PublicKey)
	v1Priv := base64.StdEncoding.EncodeToString(v1kp.PrivateKey)
	v1Content := KeyFileMagicV1 + "\npub:" + v1Pub + "\npriv:" + v1Priv + "\n"

	path := t.TempDir() + "/identity_v1.key"
	if err := os.WriteFile(path, []byte(v1Content), 0600); err != nil {
		t.Fatal(err)
	}

	loaded, err := LoadIdentity(path)
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(v1kp.PublicKey, loaded.PublicKey) {
		t.Fatal("public key mismatch")
	}
	if len(loaded.Ed25519PublicKey) != 32 {
		t.Fatal("Ed25519 public key should be derived")
	}

	msg := []byte("hello")
	sig := SignMessage(loaded, msg)
	if !VerifySignature(loaded.Ed25519PublicKey, msg, sig) {
		t.Fatal("derived Ed25519 key cannot sign/verify")
	}
}

func TestBackwardCompatOldPayload(t *testing.T) {
	oldPayload := []byte("sender_base64\nhello world")
	sender, edPub, plaintext, verified, err := ParseSignedPayload(oldPayload)
	if err != nil {
		t.Fatal(err)
	}
	if sender != "sender_base64" {
		t.Fatal("sender mismatch")
	}
	if edPub != nil {
		t.Fatal("ed25519 pubkey should be nil for old format")
	}
	if string(plaintext) != "hello world" {
		t.Fatal("plaintext mismatch")
	}
	if verified {
		t.Fatal("old format should not be marked as verified")
	}
}

func TestDerivedEd25519Consistency(t *testing.T) {
	// Same X25519 key should always produce same Ed25519 keys
	kp1, _ := GenerateKeyPair()
	kp2, _ := GenerateKeyPair()

	// Different keys should have different Ed25519 keys
	if bytes.Equal(kp1.Ed25519PublicKey, kp2.Ed25519PublicKey) {
		t.Fatal("different X25519 keys should produce different Ed25519 keys")
	}

	// Same key reloaded should produce same Ed25519
	path := t.TempDir() + "/identity.key"
	if err := SaveIdentity(path, kp1); err != nil {
		t.Fatal(err)
	}
	loaded, err := LoadIdentity(path)
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(kp1.Ed25519PublicKey, loaded.Ed25519PublicKey) {
		t.Fatal("Ed25519 key should be consistent after save/load")
	}
}
