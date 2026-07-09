package client

import (
	"context"
	"time"

	"github.com/user/dns-transport/internal/bridge"
)

// NetworkMode represents the current network connectivity state.
type NetworkMode int

const (
	ModeNormal   NetworkMode = 0
	ModeBlackout NetworkMode = 1
)

// Detector probes network connectivity to determine the current mode.
type Detector struct {
	forceBlackout bool
	mode          NetworkMode
	checkInterval time.Duration
	bridgeCli     *bridge.Client
}

// NewDetector creates a new Detector with the given forceBlackout flag and optional bridge client.
func NewDetector(forceBlackout bool, cli *bridge.Client) *Detector {
	return &Detector{
		forceBlackout: forceBlackout,
		mode:          ModeNormal,
		checkInterval: 60 * time.Second,
		bridgeCli:     cli,
	}
}

// CurrentMode returns the current network mode without probing.
func (d *Detector) CurrentMode() NetworkMode {
	if d.forceBlackout {
		return ModeBlackout
	}
	return d.mode
}

// Check probes the network and updates the mode accordingly.
func (d *Detector) Check() NetworkMode {
	if d.forceBlackout {
		d.mode = ModeBlackout
		return ModeBlackout
	}
	if d.bridgeCli == nil {
		d.mode = ModeBlackout
		return ModeBlackout
	}
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	status, err := d.bridgeCli.GetTransportStatus(ctx)
	if err != nil || !status.DHTConnected || status.DiscoveredRelays == 0 {
		d.mode = ModeBlackout
	} else {
		d.mode = ModeNormal
	}
	return d.mode
}
