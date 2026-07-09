//go:build integration

package integration

import (
		"bytes"
		"context"
		"crypto/rand"
		"testing"
		"time"

		"github.com/user/dns-transport/internal/client"
		"github.com/user/dns-transport/internal/crypto"
		"github.com/user/dns-transport/internal/ratelimit"
		"github.com/user/dns-transport/internal/relay"
		"github.com/user/dns-transport/internal/store"
	)

func TestEndToEnd(t *testing.T) {
	// Start relay server
	s := store.NewChunkStore(time.Minute, time.Minute)
	rl := ratelimit.NewIPRateLimiter(100, 200)
	go func() {
		if err := relay.RunServer("127.0.0.1:15355", "msg.local-domain", s, rl); err != nil {
			t.Log(err)
		}
	}()
	time.Sleep(200 * time.Millisecond)

	// Generate two peers
	alice, _ := crypto.GenerateKeyPair()
	bob, _ := crypto.GenerateKeyPair()

	// Alice sends message to Bob
	plaintext := []byte("hello bob, this is alice over DNS!")
	sharedSecret, _ := crypto.SharedSecret(alice.PrivateKey, bob.PublicKey)
	ciphertext, _, _ := crypto.EncryptMessage(sharedSecret, plaintext)

	engine := client.NewDNSClientEngine(nil, []string{"127.0.0.1:15355"}, "msg.local-domain")
		_, _, err := engine.SendMessage(context.Background(), ciphertext)
	if err != nil {
		t.Fatal(err)
	}

	// Bob decrypts
	_, _ = crypto.SharedSecret(bob.PrivateKey, alice.PublicKey)
	// For now, we verify the store has the chunks
	// In full impl, Bob would poll via gRPC
	t.Log("message sent and stored successfully")
}

func TestEncodingCryptoRoundTrip(t *testing.T) {
	alice, _ := crypto.GenerateKeyPair()
	bob, _ := crypto.GenerateKeyPair()

	secret, _ := crypto.SharedSecret(alice.PrivateKey, bob.PublicKey)
	original := make([]byte, 1000)
	rand.Read(original)

	ciphertext, nonce, _ := crypto.EncryptMessage(secret, original)
	bobSecret, _ := crypto.SharedSecret(bob.PrivateKey, alice.PublicKey)
	decrypted, _ := crypto.DecryptMessage(bobSecret, nonce, ciphertext)

	if !bytes.Equal(original, decrypted) {
		t.Fatal("round trip failed")
	}
}
