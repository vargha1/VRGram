package client

import (
	"context"
	"net"
	"time"
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
	probeDomain   string
}

// NewDetector creates a new Detector with the given forceBlackout flag.
func NewDetector(forceBlackout bool) *Detector {
	return &Detector{
		forceBlackout: forceBlackout,
		mode:          ModeNormal,
		checkInterval: 60 * time.Second,
		probeDomain:   "google.com",
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
	lookupCtx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	_, err := net.DefaultResolver.LookupHost(lookupCtx, d.probeDomain)
	if err != nil {
		d.mode = ModeBlackout
	} else {
		d.mode = ModeNormal
	}
	return d.mode
}
