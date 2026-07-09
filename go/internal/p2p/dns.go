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
}

func (f *DNSForwarder) Forward(ctx context.Context, peerID string, packet []byte) error {
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

	// For bidirectional, read response
	_ = s.SetReadDeadline(time.Now().Add(30 * time.Second))
	response, err := io.ReadAll(s)
	if err != nil {
		return fmt.Errorf("read response: %w", err)
	}

	// Store response for retrieval
	_ = response // will be used in relayd DNS response path
	return nil
}

func (f *DNSForwarder) IncomingPackets() <-chan *DNSPacket {
	return f.incomingCh
}
