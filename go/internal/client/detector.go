package client

import (
	"github.com/user/dns-transport/internal/p2p"
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
	dhtClient     *p2p.DHTClient
	relayCount    int
}

// NewDetector creates a new Detector.
func NewDetector(forceBlackout bool, cli *p2p.DHTClient, relayCount int) *Detector {
	return &Detector{
		forceBlackout: forceBlackout,
		mode:          ModeNormal,
		dhtClient:     cli,
		relayCount:    relayCount,
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
	// If we have static relays, consider it normal mode regardless of DHT.
	if d.relayCount > 0 {
		d.mode = ModeNormal
		return ModeNormal
	}
	if d.dhtClient == nil {
		d.mode = ModeBlackout
		return ModeBlackout
	}
	if d.dhtClient.ConnectedPeers() > 0 {
		d.mode = ModeNormal
	} else {
		d.mode = ModeBlackout
	}
	return d.mode
}
