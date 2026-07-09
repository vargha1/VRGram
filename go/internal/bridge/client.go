package bridge

import (
	"context"
	"fmt"
	"net"

	pb "github.com/user/dns-transport/pkg/bridgepb"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
)

type Client struct {
	conn   *grpc.ClientConn
	pbCli  pb.P2PBridgeClient
	socket string
}

type RelayUpdate struct {
	InitialBatch bool
	Added        []RelayInfo
	Removed      []string
}

type RelayInfo struct {
	PeerID     string
	DNSAddress string
	Multiaddrs []string
	Load       int32
	LastSeen   int64
}

type TransportStatus struct {
	DHTConnected     bool
	PeersInDHT       int32
	DiscoveredRelays int32
	Libp2pDirect     bool
	Libp2pCircuit    bool
	DNSMode          string
}

func NewClient(socketPath string) (*Client, error) {
	conn, err := grpc.Dial(
		socketPath,
		grpc.WithTransportCredentials(insecure.NewCredentials()),
		grpc.WithContextDialer(func(ctx context.Context, addr string) (net.Conn, error) {
			var d net.Dialer
			return d.DialContext(ctx, "unix", addr)
		}),
	)
	if err != nil {
		return nil, fmt.Errorf("dial bridge: %w", err)
	}

	return &Client{
		conn:   conn,
		pbCli:  pb.NewP2PBridgeClient(conn),
		socket: socketPath,
	}, nil
}

func (c *Client) Close() error {
	return c.conn.Close()
}

func (c *Client) DiscoverRelays(ctx context.Context, maxRelays int, subscribe bool) (<-chan RelayUpdate, error) {
	stream, err := c.pbCli.DiscoverRelays(ctx, &pb.DiscoverRequest{
		MaxRelays: int32(maxRelays),
		Subscribe: subscribe,
	})
	if err != nil {
		return nil, fmt.Errorf("discover relays: %w", err)
	}

	ch := make(chan RelayUpdate, 10)
	go func() {
		defer close(ch)
		for {
			upd, err := stream.Recv()
			if err != nil {
				return
			}
			ru := RelayUpdate{
				InitialBatch: upd.InitialBatch,
				Added:        make([]RelayInfo, len(upd.Added)),
				Removed:      upd.RemovedPeerIds,
			}
			for i, a := range upd.Added {
				ru.Added[i] = RelayInfo{
					PeerID:     a.PeerId,
					DNSAddress: a.DnsAddress,
					Multiaddrs: a.Multiaddrs,
					Load:       a.Load,
					LastSeen:   a.LastSeen,
				}
			}
			ch <- ru
		}
	}()
	return ch, nil
}

func (c *Client) AdvertiseRelay(ctx context.Context, zone string) error {
	_, err := c.pbCli.AdvertiseRelay(ctx, &pb.AdvertiseRequest{
		Zone:       zone,
		ListenAddr: "",
	})
	return err
}

func (c *Client) GetTransportStatus(ctx context.Context) (*TransportStatus, error) {
	resp, err := c.pbCli.GetTransportStatus(ctx, &pb.Empty{})
	if err != nil {
		return nil, err
	}
	return &TransportStatus{
		DHTConnected:     resp.DhtConnected,
		PeersInDHT:       resp.PeersInDht,
		DiscoveredRelays: resp.DiscoveredRelays,
		Libp2pDirect:     resp.Libp2PDirect,
		Libp2pCircuit:    resp.Libp2PCircuit,
		DNSMode:          resp.DnsMode,
	}, nil
}
