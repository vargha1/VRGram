package p2p

import (
	"context"
	"fmt"

	"github.com/libp2p/go-libp2p/p2p/protocol/circuitv2/relay"
)

func (h *P2PHost) EnableCircuitRelay(ctx context.Context) error {
	_, err := relay.New(h.Host)
	if err != nil {
		return fmt.Errorf("enable circuit relay: %w", err)
	}
	fmt.Println("Circuit relay enabled")
	return nil
}
