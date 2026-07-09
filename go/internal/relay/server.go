package relay

import (
	"encoding/base32"
	"log/slog"
	"net"
	"strings"
	"time"

	"github.com/miekg/dns"
	"github.com/user/dns-transport/internal/encoding"
	"github.com/user/dns-transport/internal/ratelimit"
	"github.com/user/dns-transport/internal/store"
)

// DefaultChunkTTL is the default TTL for stored chunks (7 days).
const DefaultChunkTTL = 7 * 24 * time.Hour

var base32hex = base32.HexEncoding.WithPadding(base32.NoPadding)

func RunServer(addr, zone string, s *store.ChunkStore, rl *ratelimit.IPRateLimiter) error {
	slog.Info("relay server starting", "addr", addr, "zone", zone)
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
					pending = append(pending, base32hex.EncodeToString(id[:]))
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
		// Re-encode labels without zone for the ack
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

	server := &dns.Server{
		Addr:    addr,
		Net:     "udp",
		Handler: mux,
	}
	return server.ListenAndServe()
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
