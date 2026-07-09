package p2p

import (
	"context"
	"fmt"
	"io"
	"time"

	"github.com/libp2p/go-libp2p/core/network"
	"github.com/libp2p/go-libp2p/core/peer"
)

const dnsProtocolID = "/vrgram/dns/1.0.0"

type DNSForwarder struct {
	host       *P2PHost
	incomingCh chan *DNSPacket
}

type DNSPacket struct {
	Raw          []byte
	RemotePeerID string
}

func NewDNSForwarder(host *P2PHost) *DNSForwarder {
	f := &DNSForwarder{
		host:       host,
		incomingCh: make(chan *DNSPacket, 100),
	}
	host.Host.SetStreamHandler(dnsProtocolID, f.handleStream)
	return f
}

func (f *DNSForwarder) handleStream(s network.Stream) {
	defer s.Close()

	data, err := io.ReadAll(s)
	if err != nil {
		return
	}

	pkt := &DNSPacket{
		Raw:          data,
		RemotePeerID: s.Conn().RemotePeer().String(),
	}

	select {
	case f.incomingCh <- pkt:
	default:
		// drop if buffer full
	}

	// Write ack so the caller's ReadAll in ForwardRPC completes
	_, _ = s.Write([]byte{0})
}

// ForwardRPC sends a DNS packet to a remote peer and waits for a response.
// Closes the write side so the remote can detect EOF and reply.
func (f *DNSForwarder) ForwardRPC(ctx context.Context, peerID string, packet []byte) ([]byte, error) {
	pid, err := peer.Decode(peerID)
	if err != nil {
		return nil, fmt.Errorf("decode peer id: %w", err)
	}

	s, err := f.host.Host.NewStream(ctx, pid, dnsProtocolID)
	if err != nil {
		return nil, fmt.Errorf("new stream: %w", err)
	}
	defer s.Close()

	if _, err := s.Write(packet); err != nil {
		return nil, fmt.Errorf("write: %w", err)
	}

	// Half-close so the remote reader sees EOF
	if err := s.CloseWrite(); err != nil {
		return nil, fmt.Errorf("close write: %w", err)
	}

	if err := s.SetReadDeadline(time.Now().Add(30 * time.Second)); err != nil {
		return nil, fmt.Errorf("set read deadline: %w", err)
	}

	response, err := io.ReadAll(s)
	if err != nil {
		return nil, fmt.Errorf("read response: %w", err)
	}

	return response, nil
}

// ForwardOneWay sends a DNS packet to a remote peer without waiting for a response.
func (f *DNSForwarder) ForwardOneWay(ctx context.Context, peerID string, packet []byte) error {
	pid, err := peer.Decode(peerID)
	if err != nil {
		return fmt.Errorf("decode peer id: %w", err)
	}

	s, err := f.host.Host.NewStream(ctx, pid, dnsProtocolID)
	if err != nil {
		return fmt.Errorf("new stream: %w", err)
	}
	defer s.Close()

	if _, err := s.Write(packet); err != nil {
		return fmt.Errorf("write: %w", err)
	}

	// CloseWrite so remote knows we're done; don't wait for response
	_ = s.CloseWrite()
	return nil
}

func (f *DNSForwarder) IncomingPackets() <-chan *DNSPacket {
	return f.incomingCh
}
