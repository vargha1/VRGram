package p2p

import (
	"crypto/rand"
	"fmt"
	"os"
	"path/filepath"

	"github.com/libp2p/go-libp2p"
	"github.com/libp2p/go-libp2p/core/crypto"
	"github.com/libp2p/go-libp2p/core/host"
	"github.com/libp2p/go-libp2p/p2p/transport/tcp"
)

type P2PHost struct {
	Host    host.Host
	dataDir string
	port    int
}

type HostConfig struct {
	Port    int
	DataDir string
}

func NewHost(cfg HostConfig) (*P2PHost, error) {
	if err := os.MkdirAll(cfg.DataDir, 0700); err != nil {
		return nil, fmt.Errorf("create data dir: %w", err)
	}

	keyPath := filepath.Join(cfg.DataDir, "p2p.key")
	privKey, err := loadOrGenerateKey(keyPath)
	if err != nil {
		return nil, fmt.Errorf("load or generate key: %w", err)
	}

	// Build minimal host: TCP only, no NAT, no auto-detection.
	// Full libp2p features (QUIC, NAT, hole-punching) crash on Android
	// due to SELinux restrictions on netlink_route_socket access.
	h, err := libp2p.New(
		libp2p.Identity(privKey),
		libp2p.ListenAddrStrings(
			fmt.Sprintf("/ip4/127.0.0.1/tcp/%d", cfg.Port),
		),
		libp2p.Transport(tcp.NewTCPTransport),
		libp2p.NoTransports,
		libp2p.DisableRelay(),
	)
	if err != nil {
		return nil, fmt.Errorf("create libp2p host: %w", err)
	}

	return &P2PHost{Host: h, dataDir: cfg.DataDir, port: cfg.Port}, nil
}

func (h *P2PHost) PeerID() string {
	return h.Host.ID().String()
}

func (h *P2PHost) Multiaddrs() []string {
	addrs := h.Host.Addrs()
	result := make([]string, 0, len(addrs))
	for _, a := range addrs {
		result = append(result, a.String())
	}
	return result
}

func (h *P2PHost) Start() {
	fmt.Printf("P2P host started: %s\n", h.Host.ID().String())
}

func (h *P2PHost) Stop() error {
	return h.Host.Close()
}

func loadOrGenerateKey(path string) (crypto.PrivKey, error) {
	data, err := os.ReadFile(path)
	if err == nil {
		return crypto.UnmarshalPrivateKey(data)
	}
	if !os.IsNotExist(err) {
		return nil, fmt.Errorf("read key file: %w", err)
	}

	priv, _, err := crypto.GenerateEd25519Key(rand.Reader)
	if err != nil {
		return nil, fmt.Errorf("generate key: %w", err)
	}

	raw, err := crypto.MarshalPrivateKey(priv)
	if err != nil {
		return nil, fmt.Errorf("marshal key: %w", err)
	}

	if err := os.WriteFile(path, raw, 0600); err != nil {
		return nil, fmt.Errorf("write key file: %w", err)
	}

	return priv, nil
}
