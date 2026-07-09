package relay

import (
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

		// Append zone back for DecodeChunkFromLabels
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

		// Store chunk
		complete, err := s.Store(chunk)
		if err != nil {
			slog.Error("store failed", "error", err)
			m.Rcode = dns.RcodeServerFailure
			w.WriteMsg(m)
			return
		}

		slog.Info("stored chunk",
			"msgID", chunk.MsgID,
			"idx", chunk.ChunkIdx,
			"total", chunk.TotalChunks,
			"complete", complete)

		// Acknowledge
		ackLabels := []string{
			labels[0], // msgID
			labels[1], // chunkIdx
			"OK",
		}
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
