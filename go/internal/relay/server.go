package relay

import (
	"crypto/sha256"
	"crypto/subtle"
	"encoding/base32"
	"encoding/binary"
	"encoding/hex"
	"fmt"
	"io"
	"log/slog"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/miekg/dns"
	"github.com/user/dns-transport/internal/encoding"
	"github.com/user/dns-transport/internal/ratelimit"
	"github.com/user/dns-transport/internal/store"
)

// DefaultChunkTTL is the default TTL for stored chunks (7 days).
const DefaultChunkTTL = 7 * 24 * time.Hour

// Media server constants.
const (
	maxUploadSize   = 50 << 20 // 50 MB
	mediaServerName = "vrgram-relay"
)

var base32hex = base32.HexEncoding.WithPadding(base32.NoPadding)

// mediaToken holds the auth token for media HTTP endpoints, loaded from env.
var mediaToken string

func init() {
	mediaToken = os.Getenv("RELAY_MEDIA_TOKEN")
	if mediaToken == "" {
		mediaToken = os.Getenv("RELAYD_MEDIA_TOKEN")
	}
}

// RunServer starts the DNS relay server and optionally an HTTP media server.
// If mediaPort is non-empty, starts HTTP server on that port for file upload/download.
func RunServer(addr, zone, mediaPort string, s *store.ChunkStore, rl *ratelimit.IPRateLimiter) error {
	slog.Info("relay server starting", "addr", addr, "zone", zone, "mediaPort", mediaPort)
	zone = dns.Fqdn(zone)

	mux := dns.NewServeMux()
	mux.HandleFunc(zone, func(w dns.ResponseWriter, r *dns.Msg) {
		m := new(dns.Msg)
		m.SetReply(r)
		m.Authoritative = true

		// Rate limit by remote IP
		remoteIP := extractIP(w.RemoteAddr())
		if !rl.Allow(remoteIP) {
			slog.Warn("rate limit exceeded", "ip", remoteIP)
			m.Rcode = dns.RcodeRefused
			w.WriteMsg(m)
			return
		}

		if len(r.Question) == 0 {
			m.Rcode = dns.RcodeFormatError
			w.WriteMsg(m)
			return
		}

		qname := r.Question[0].Name
		name := strings.TrimSuffix(dns.Fqdn(qname), ".")
		zoneClean := strings.TrimSuffix(zone, ".")
		if !strings.HasSuffix(name, zoneClean) {
			m.Rcode = dns.RcodeRefused
			w.WriteMsg(m)
			return
		}

		body := strings.TrimSuffix(name, "."+zoneClean)
		labels := strings.Split(body, ".")

		// Check for POLL query: POLL.recipientHash.zone
			if labels[0] == "POLL" {
				if len(labels) < 2 {
					m.Rcode = dns.RcodeFormatError
					w.WriteMsg(m)
					return
				}
				peerHash := labels[1]
				msgIDs := s.ListPeerMessages(peerHash)
				var pending []string
				for _, id := range msgIDs {
					// Extended format: base32hex(msgID):base32hex(timestamp):base32hex(sequence)
					// Backward compatible: old clients parse base32hex(msgID) and ignore the rest
					if ts, seq, ok := s.GetMessageMeta(id); ok && ts > 0 {
						tsBytes := make([]byte, 8)
						binary.BigEndian.PutUint64(tsBytes, uint64(ts))
						seqBytes := make([]byte, 8)
						binary.BigEndian.PutUint64(seqBytes, seq)
						pending = append(pending, fmt.Sprintf("%s:%s:%s",
							base32hex.EncodeToString(id[:]),
							base32hex.EncodeToString(tsBytes),
							base32hex.EncodeToString(seqBytes),
						))
					} else {
						pending = append(pending, base32hex.EncodeToString(id[:]))
					}
				}
				m.Answer = append(m.Answer, &dns.TXT{
					Hdr: dns.RR_Header{
						Name:   qname,
						Rrtype: dns.TypeTXT,
						Class:  dns.ClassINET,
						Ttl:    60,
					},
					Txt: pending,
				})
				w.WriteMsg(m)
				return
			}

		labels = append(labels, zoneClean)
		chunk, err := encoding.DecodeChunkFromLabels(labels, zoneClean)
		if err != nil {
			m.Rcode = dns.RcodeFormatError
			w.WriteMsg(m)
			return
		}

		if chunk.TotalChunks == 0 {
			// Query: retrieve stored chunk
			storedChunk, err := s.GetChunk(chunk.MsgID, chunk.ChunkIdx)
			if err != nil || storedChunk == nil {
				m.Rcode = dns.RcodeNameError
				w.WriteMsg(m)
				return
			}
			respLabels := storedChunk.EncodeToLabels(zoneClean)
			m.Answer = append(m.Answer, &dns.TXT{
				Hdr: dns.RR_Header{
					Name:   qname,
					Rrtype: dns.TypeTXT,
					Class:  dns.ClassINET,
					Ttl:    300,
				},
				Txt: respLabels[:len(respLabels)-1],
			})
			w.WriteMsg(m)
			return
		}

		// Store chunk; associate with recipient if provided
		complete, err := s.Store(chunk)
		if err != nil {
			slog.Error("store failed", "error", err)
			m.Rcode = dns.RcodeServerFailure
			w.WriteMsg(m)
			return
		}
		if len(chunk.RecipientHash) > 0 {
			peerID := base32hex.EncodeToString(chunk.RecipientHash)
			s.SetMessageOwner(chunk.MsgID, peerID)
		}

		slog.Info("stored chunk",
			"msgID", chunk.MsgID,
			"idx", chunk.ChunkIdx,
			"total", chunk.TotalChunks,
			"complete", complete)

		// Acknowledge
		ackMsgID := base32hex.EncodeToString(chunk.MsgID[:])
		ackIdx := base32hex.EncodeToString([]byte{byte(chunk.ChunkIdx >> 8), byte(chunk.ChunkIdx)})
		ackLabels := []string{ackMsgID, ackIdx, "OK"}
		m.Answer = append(m.Answer, &dns.TXT{
			Hdr: dns.RR_Header{
				Name:   qname,
				Rrtype: dns.TypeTXT,
				Class:  dns.ClassINET,
				Ttl:    60,
			},
			Txt: ackLabels,
		})
		w.WriteMsg(m)
	})

	// Start HTTP media server if mediaPort specified
	if mediaPort != "" {
		go startMediaServer(mediaPort)
	}

	server := &dns.Server{
		Addr:    addr,
		Net:     "udp",
		Handler: mux,
	}

	// Also listen on TCP for clients behind NAT that lose UDP responses.
	go func() {
		tcpServer := &dns.Server{
			Addr:    addr,
			Net:     "tcp",
			Handler: mux,
		}
		slog.Info("relay TCP server starting", "addr", addr)
		if err := tcpServer.ListenAndServe(); err != nil {
			slog.Error("relay TCP server failed", "error", err)
		}
	}()

	// Also listen on fallback port 5353 (carriers often block port 53).
	go func() {
		altUDP := &dns.Server{Addr: ":5353", Net: "udp", Handler: mux}
		slog.Info("relay fallback UDP server starting", "addr", ":5353")
		if err := altUDP.ListenAndServe(); err != nil {
			slog.Error("relay fallback UDP server failed", "error", err)
		}
	}()
	go func() {
		altTCP := &dns.Server{Addr: ":5353", Net: "tcp", Handler: mux}
		slog.Info("relay fallback TCP server starting", "addr", ":5353")
		if err := altTCP.ListenAndServe(); err != nil {
			slog.Error("relay fallback TCP server failed", "error", err)
		}
	}()

	return server.ListenAndServe()
}

func startMediaServer(port string) {
	mediaDir := filepath.Join(os.Getenv("HOME"), ".config", "relayd", "media")
	if err := os.MkdirAll(mediaDir, 0700); err != nil {
		slog.Error("failed to create media dir", "error", err)
		return
	}

	// Cleanup old files (older than 7 days)
	go func() {
		ticker := time.NewTicker(24 * time.Hour)
		defer ticker.Stop()
		for range ticker.C {
			entries, _ := os.ReadDir(mediaDir)
			for _, e := range entries {
				info, _ := e.Info()
				if time.Since(info.ModTime()) > 7*24*time.Hour {
					os.Remove(filepath.Join(mediaDir, e.Name()))
				}
			}
		}
	}()

	mux := http.NewServeMux()
	mux.HandleFunc("/upload", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "POST only", 405)
			return
		}

		// Auth check
		if !checkMediaAuth(r) {
			http.Error(w, "unauthorized", 401)
			return
		}

		// Size limit
		r.Body = http.MaxBytesReader(w, r.Body, maxUploadSize)

		data, err := io.ReadAll(r.Body)
		if err != nil {
			if strings.Contains(err.Error(), "http: request body too large") {
				http.Error(w, "file too large", 413)
				return
			}
			http.Error(w, "read failed", 500)
			return
		}
		hash := sha256.Sum256(data)
		fileID := hex.EncodeToString(hash[:])
		if err := os.WriteFile(filepath.Join(mediaDir, fileID), data, 0600); err != nil {
			http.Error(w, "write failed", 500)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(`{"file_id":"` + fileID + `"}`))
	})

	mux.HandleFunc("/download/", func(w http.ResponseWriter, r *http.Request) {
		fileID := strings.TrimPrefix(r.URL.Path, "/download/")
		if fileID == "" {
			http.NotFound(w, r)
			return
		}
		// Auth check
		if !checkMediaAuth(r) {
			http.Error(w, "unauthorized", 401)
			return
		}
		// Validate fileID is hex
		if _, err := hex.DecodeString(fileID); err != nil {
			http.NotFound(w, r)
			return
		}
		path := filepath.Join(mediaDir, fileID)
		if _, err := os.Stat(path); err != nil {
			http.NotFound(w, r)
			return
		}
		http.ServeFile(w, r, path)
	})

	slog.Info("media HTTP server starting", "port", port, "auth", mediaToken != "")
	if err := http.ListenAndServe(":"+port, mux); err != nil {
		slog.Error("media server failed", "error", err)
	}
}

// checkMediaAuth validates the X-Auth-Token header against the configured token.
// If no token is configured, auth is disabled (backward compatible).
func checkMediaAuth(r *http.Request) bool {
	if mediaToken == "" {
		return true // auth disabled
	}
	provided := r.Header.Get("X-Auth-Token")
	if provided == "" {
		return false
	}
	return subtle.ConstantTimeCompare([]byte(mediaToken), []byte(provided)) == 1
}

func extractIP(addr net.Addr) string {
	switch a := addr.(type) {
	case *net.UDPAddr:
		return a.IP.String()
	case *net.TCPAddr:
		return a.IP.String()
	}
	return addr.String()
}
