package bridge

import (
	"context"
	"fmt"
	"sync"
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
			s.incomingCh <- &pb.DNSPacket{
				Raw:          pkt.Raw,
				RemotePeerId: pkt.RemotePeerID,
			}
		}
	}()

	return s
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
		update.Added = append(update.Added, &pb.RelayInfo{
			PeerId:     p.ID.String(),
			Multiaddrs: addrs,
			LastSeen:   time.Now().Unix(),
		})
	}
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
	if err := s.dnsFwd.Forward(ctx, pkt.RemotePeerId, pkt.Raw); err != nil {
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
	// Send query to remote peer, get response
	if err := s.dnsFwd.Forward(ctx, pkt.RemotePeerId, pkt.Raw); err != nil {
		return nil, fmt.Errorf("relay DNS: %w", err)
	}

	// Read response from incoming stream
	select {
	case resp := <-s.incomingCh:
		return resp, nil
	case <-ctx.Done():
		return nil, ctx.Err()
	case <-time.After(30 * time.Second):
		return nil, fmt.Errorf("timeout waiting for DNS response")
	}
}

func (s *Server) GetTransportStatus(ctx context.Context, _ *pb.Empty) (*pb.TransportStatus, error) {
	return &pb.TransportStatus{
		DhtConnected:     s.dht.ConnectedPeers() > 0,
		PeersInDht:       int32(s.dht.ConnectedPeers()),
		DiscoveredRelays: 0,
		Libp2PDirect:     false,
		Libp2PCircuit:    true,
		DnsMode:          "normal",
	}, nil
}
