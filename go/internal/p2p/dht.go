package p2p

import (
	"context"
	"fmt"
	"time"

	"github.com/ipfs/go-cid"
	dht "github.com/libp2p/go-libp2p-kad-dht"
	"github.com/libp2p/go-libp2p/core/peer"
	"github.com/multiformats/go-multiaddr"
	"github.com/multiformats/go-multihash"
)

const (
	relayNamespace = "/vrgram/relays"
	dhtTimeout     = 30 * time.Second
)

type DHTClient struct {
	dht       *dht.IpfsDHT
	host      *P2PHost
	bootstrap []peer.AddrInfo
}

func NewDHT(host *P2PHost, bootstrapAddrs []string) (*DHTClient, error) {
	bootstrap := make([]peer.AddrInfo, 0, len(bootstrapAddrs))
	for _, addr := range bootstrapAddrs {
		maddr, err := multiaddr.NewMultiaddr(addr)
		if err != nil {
			return nil, fmt.Errorf("parse bootstrap addr %s: %w", addr, err)
		}
		pi, err := peer.AddrInfoFromP2pAddr(maddr)
		if err != nil {
			return nil, fmt.Errorf("addr info from %s: %w", addr, err)
		}
		bootstrap = append(bootstrap, *pi)
	}

	kad, err := dht.New(context.Background(), host.Host,
		dht.Mode(dht.ModeServer),
		dht.BootstrapPeers(bootstrap...),
	)
	if err != nil {
		return nil, fmt.Errorf("create DHT: %w", err)
	}

	return &DHTClient{dht: kad, host: host, bootstrap: bootstrap}, nil
}

func (d *DHTClient) Start(ctx context.Context) error {
	if err := d.dht.Bootstrap(ctx); err != nil {
		return fmt.Errorf("bootstrap DHT: %w", err)
	}

	// Wait for initial bootstrap to connect to at least some peers
	time.Sleep(2 * time.Second)
	return nil
}

func (d *DHTClient) Stop() error {
	return d.dht.Close()
}

func (d *DHTClient) ConnectedPeers() int {
	return len(d.dht.RoutingTable().ListPeers())
}

func (d *DHTClient) FindRelayProviders(ctx context.Context, limit int) ([]peer.AddrInfo, error) {
	ctx, cancel := context.WithTimeout(ctx, dhtTimeout)
	defer cancel()

	nsCid := namespaceToCid(relayNamespace)
	peers, err := d.dht.FindProviders(ctx, nsCid)
	if err != nil {
		return nil, fmt.Errorf("find providers: %w", err)
	}

	if limit > 0 && len(peers) > limit {
		peers = peers[:limit]
	}

	return peers, nil
}

func (d *DHTClient) AnnounceRelay(ctx context.Context) error {
	ctx, cancel := context.WithTimeout(ctx, dhtTimeout)
	defer cancel()

	nsCid := namespaceToCid(relayNamespace)
	if err := d.dht.Provide(ctx, nsCid, true); err != nil {
		return fmt.Errorf("announce relay: %w", err)
	}
	return nil
}

func namespaceToCid(namespace string) cid.Cid {
	hash, _ := multihash.Sum([]byte(namespace), multihash.SHA2_256, -1)
	return cid.NewCidV1(cid.Raw, hash)
}

func (d *DHTClient) RefreshProviders(ctx context.Context) {
	ticker := time.NewTicker(30 * time.Minute)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			_ = d.AnnounceRelay(ctx)
		}
	}
}
