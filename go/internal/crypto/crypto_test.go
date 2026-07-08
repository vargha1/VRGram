package crypto

import (
    "bytes"
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

    // Alice encrypts for Bob
    aliceSecret, err := SharedSecret(alice.PrivateKey, bob.PublicKey)
    if err != nil {
        t.Fatal(err)
    }
    plaintext := []byte("hello from alice to bob, this is a secret message")
    ciphertext, nonce, err := EncryptMessage(aliceSecret, plaintext)
    if err != nil {
        t.Fatal(err)
    }

    // Bob decrypts from Alice
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

    // Eve tries to decrypt with her own secret
    eveSecret, _ := SharedSecret(eve.PrivateKey, alice.PublicKey)
    _, err := DecryptMessage(eveSecret, nonce, ciphertext)
    if err == nil {
        t.Fatal("expected decryption to fail with wrong key, got nil")
    }
}

func TestSaveLoadIdentity(t *testing.T) {
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
}
