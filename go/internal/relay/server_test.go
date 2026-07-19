package relay

import (
	"crypto/rand"
	"testing"
	"time"

	"github.com/user/dns-transport/internal/dns"
	"github.com/user/dns-transport/internal/encoding"
	"github.com/user/dns-transport/internal/ratelimit"
	"github.com/user/dns-transport/internal/store"
)

func TestServerStoreAndQuery(t *testing.T) {
	s := store.NewChunkStore(time.Minute, time.Minute)
	rl := ratelimit.NewIPRateLimiter(100, 200)

	go func() {
		if err := RunServer("127.0.0.1:5354", "msg.local-domain", "", s, rl); err != nil {
			t.Log(err)
		}
	}()

	time.Sleep(100 * time.Millisecond)

	var msgID [8]byte
	rand.Read(msgID[:])
	chunk := encoding.NewChunk(msgID, 0, 2, []byte("first chunk"))

		err := dns.SendChunk("127.0.0.1:5354", "msg.local-domain", chunk, dns.TransportAuto)
	if err != nil {
		t.Fatal(err)
	}

		retrieved, err := dns.QueryChunk("127.0.0.1:5354", "msg.local-domain", msgID, 0, dns.TransportAuto)
	if err != nil {
		t.Fatal(err)
	}

	if string(retrieved.Payload) != "first chunk" {
		t.Fatalf("got %s, want first chunk", retrieved.Payload)
	}
}
