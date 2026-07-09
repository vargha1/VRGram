package bridge

import (
	"context"
	"fmt"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"github.com/user/dns-transport/internal/p2p"
	pb "github.com/user/dns-transport/pkg/bridgepb"
)

type Server struct {
	pb.UnimplementedP2PBridgeServer
	host   *p2p.P2PHost
	dht    *p2p.DHTClient
	zone   string
	dnsFwd *p2p.DNSForwarder

	mu         sync.RWMutex
	relaySubs  map[string]chan *pb.RelayUpdate
	incomingCh chan *pb.DNSPacket

	discoveredRelayCount atomic.Int32
}

func NewServer(host *p2p.P2PHost, dht *p2p.DHTClient, zone string) *Server {
	s := &Server{
		host:       host,
		dht:        dht,
		zone:       zone,
		relaySubs:  make(map[string]chan *pb.RelayUpdate),
		incomingCh: make(chan *pb.DNSPacket, 100),
		dnsFwd:     p2p.NewDNSForwarder(host),
	}

	// Start polling incoming DNS packets from libp2p
	go func() {
		for pkt := range s.dnsFwd.IncomingPackets() {
			select {
			case s.incomingCh <- &pb.DNSPacket{
				Raw:          pkt.Raw,
				RemotePeerId: pkt.RemotePeerID,
			}:
			default:
				// drop if consumer slow, same as DNSForwarder
			}
		}
	}()

	return s
}

// dnsAddressFromMultiaddrs extracts a DNS address from a peer's multiaddrs.
// For IP-based addresses, returns "IP:53". For circuit relay addresses
// (containing /p2p-circuit/), returns "peerID.circuit". Returns empty string
// if no usable address is found.
func dnsAddressFromMultiaddrs(addrs []string, peerID string) string {
	for _, addr := range addrs {
		if strings.Contains(addr, "/p2p-circuit/") {
			return peerID + ".circuit"
		}
		var ip string
		if strings.HasPrefix(addr, "/ip4/") {
			rest := strings.TrimPrefix(addr, "/ip4/")
			parts := strings.SplitN(rest, "/", 2)
			if len(parts) > 0 {
				ip = parts[0]
			}
		} else if strings.HasPrefix(addr, "/ip6/") {
			rest := strings.TrimPrefix(addr, "/ip6/")
			parts := strings.SplitN(rest, "/", 2)
			if len(parts) > 0 {
				ip = parts[0]
			}
		}
		if ip != "" {
			return ip + ":53"
		}
	}
	return ""
}

func (s *Server) DiscoverRelays(req *pb.DiscoverRequest, stream pb.P2PBridge_DiscoverRelaysServer) error {
	peers, err := s.dht.FindRelayProviders(stream.Context(), int(req.MaxRelays))
	if err != nil {
		return fmt.Errorf("find relays: %w", err)
	}

	update := &pb.RelayUpdate{
		InitialBatch: true,
		Added:        make([]*pb.RelayInfo, 0, len(peers)),
	}
		for _, p := range peers {
			addrs := make([]string, len(p.Addrs))
			for i, a := range p.Addrs {
				addrs[i] = a.String()
			}
			dnsAddr := dnsAddressFromMultiaddrs(addrs, p.ID.String())
			update.Added = append(update.Added, &pb.RelayInfo{
				PeerId:     p.ID.String(),
				DnsAddress: dnsAddr,
				Multiaddrs: addrs,
				LastSeen:   time.Now().Unix(),
			})
		}
		s.discoveredRelayCount.Store(int32(len(peers)))
	if err := stream.Send(update); err != nil {
		return err
	}

	if !req.Subscribe {
		return nil
	}

	subID := fmt.Sprintf("%d", time.Now().UnixNano())
	ch := make(chan *pb.RelayUpdate, 10)
	s.mu.Lock()
	s.relaySubs[subID] = ch
	s.mu.Unlock()

	defer func() {
		s.mu.Lock()
		delete(s.relaySubs, subID)
		s.mu.Unlock()
	}()

	for {
		select {
		case <-stream.Context().Done():
			return nil
		case update := <-ch:
			if err := stream.Send(update); err != nil {
				return err
			}
		}
	}
}

func (s *Server) AdvertiseRelay(ctx context.Context, req *pb.AdvertiseRequest) (*pb.AdvertiseResponse, error) {
	if err := s.dht.AnnounceRelay(ctx); err != nil {
		return &pb.AdvertiseResponse{Success: false}, err
	}

	dnsAddr := fmt.Sprintf("%s.circuit", s.host.PeerID())
	return &pb.AdvertiseResponse{
		Success:       true,
		PublicDnsAddr: dnsAddr,
	}, nil
}

func (s *Server) ForwardDNSPacket(ctx context.Context, pkt *pb.DNSPacket) (*pb.Empty, error) {
	if err := s.dnsFwd.ForwardOneWay(ctx, pkt.RemotePeerId, pkt.Raw); err != nil {
		return nil, fmt.Errorf("forward DNS: %w", err)
	}
	return &pb.Empty{}, nil
}

func (s *Server) IncomingDNS(_ *pb.Empty, stream pb.P2PBridge_IncomingDNSServer) error {
	for {
		select {
		case <-stream.Context().Done():
			return nil
		case pkt := <-s.incomingCh:
			if err := stream.Send(pkt); err != nil {
				return err
			}
		}
	}
}

func (s *Server) RelayDNSPacket(ctx context.Context, pkt *pb.DNSPacket) (*pb.DNSPacket, error) {
	// PLACEHOLDER: Real bidirectional DNS relay not yet implemented.
	// Currently ForwardRPC sends the DNS query and reads back a 1-byte ack
	// written by handleStream in p2p/dns.go. This ack is returned as if it
	// were a real DNS response. Replace with full bidirectional stream relay.
	resp, err := s.dnsFwd.ForwardRPC(ctx, pkt.RemotePeerId, pkt.Raw)
	if err != nil {
		return nil, fmt.Errorf("relay DNS: %w", err)
	}

	return &pb.DNSPacket{
		Raw:          resp,
		RemotePeerId: pkt.RemotePeerId,
	}, nil
}

func (s *Server) GetTransportStatus(ctx context.Context, _ *pb.Empty) (*pb.TransportStatus, error) {
	return &pb.TransportStatus{
		DhtConnected:     s.dht.ConnectedPeers() > 0,
		PeersInDht:       int32(s.dht.ConnectedPeers()),
		DiscoveredRelays: s.discoveredRelayCount.Load(),
		Libp2PDirect:     false,
		Libp2PCircuit:    true,
		DnsMode:          "normal",
	}, nil
}
