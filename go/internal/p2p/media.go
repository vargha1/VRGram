package p2p

import (
	"context"
	"fmt"
	"io"

	"github.com/libp2p/go-libp2p/core/network"
	"github.com/libp2p/go-libp2p/core/peer"
)

const mediaProtocolID = "/vrgram/media/1.0.0"

// MediaCallback is called when a file is received via libp2p.
type MediaCallback func(peerID string, fileName string, mimeType string, data []byte)

type MediaTransport struct {
	host     *P2PHost
	callback MediaCallback
}

func NewMediaTransport(host *P2PHost, cb MediaCallback) *MediaTransport {
	t := &MediaTransport{host: host, callback: cb}
	host.Host.SetStreamHandler(mediaProtocolID, t.handleStream)
	return t
}

func (t *MediaTransport) handleStream(s network.Stream) {
	defer s.Close()

	// Read file name (first 2 bytes = length, then name)
	lenBuf := make([]byte, 2)
	if _, err := io.ReadFull(s, lenBuf); err != nil {
		return
	}
	nameLen := int(lenBuf[0])<<8 | int(lenBuf[1])
	nameBuf := make([]byte, nameLen)
	if _, err := io.ReadFull(s, nameBuf); err != nil {
		return
	}
	fileName := string(nameBuf)

	// Read mime type (next 2 bytes = length)
	if _, err := io.ReadFull(s, lenBuf); err != nil {
		return
	}
	mimeLen := int(lenBuf[0])<<8 | int(lenBuf[1])
	mimeBuf := make([]byte, mimeLen)
	if _, err := io.ReadFull(s, mimeBuf); err != nil {
		return
	}
	mimeType := string(mimeBuf)

	// Read file data
	data, err := io.ReadAll(s)
	if err != nil {
		return
	}

	if t.callback != nil {
		t.callback(s.Conn().RemotePeer().String(), fileName, mimeType, data)
	}
}

func (t *MediaTransport) SendFile(ctx context.Context, peerID string, fileName string, mimeType string, data []byte) error {
	pid, err := peer.Decode(peerID)
	if err != nil {
		return fmt.Errorf("decode peer id: %w", err)
	}

	s, err := t.host.Host.NewStream(ctx, pid, mediaProtocolID)
	if err != nil {
		return fmt.Errorf("new stream: %w", err)
	}
	defer s.Close()

	// Write file name (2-byte length prefix + name)
	nameBytes := []byte(fileName)
	if _, err := s.Write([]byte{byte(len(nameBytes) >> 8), byte(len(nameBytes))}); err != nil {
		return fmt.Errorf("write name len: %w", err)
	}
	if _, err := s.Write(nameBytes); err != nil {
		return fmt.Errorf("write name: %w", err)
	}

	// Write mime type
	mimeBytes := []byte(mimeType)
	if _, err := s.Write([]byte{byte(len(mimeBytes) >> 8), byte(len(mimeBytes))}); err != nil {
		return fmt.Errorf("write mime len: %w", err)
	}
	if _, err := s.Write(mimeBytes); err != nil {
		return fmt.Errorf("write mime: %w", err)
	}

	// Write file data, then half-close
	if _, err := s.Write(data); err != nil {
		return fmt.Errorf("write data: %w", err)
	}
	if err := s.CloseWrite(); err != nil {
		return fmt.Errorf("close write: %w", err)
	}

	return nil
}
