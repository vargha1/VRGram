package dns

import (
	"fmt"
	"log/slog"
	"strings"
	"time"

	"github.com/miekg/dns"
	"github.com/user/dns-transport/internal/encoding"
)

const defaultTimeout = 5 * time.Second

type Handler interface {
	HandleChunk(chunk *encoding.Chunk) error
	QueryChunk(msgID [8]byte, chunkIdx uint16) (*encoding.Chunk, error)
}

func SendChunk(addr, zone string, chunk *encoding.Chunk, useTCP bool) error {
	labels := chunk.EncodeToLabels(zone)
	name := strings.Join(labels, ".")

	m := new(dns.Msg)
	m.SetQuestion(dns.Fqdn(name), dns.TypeTXT)
	m.RecursionDesired = false
	m.SetEdns0(4096, true)

	client := &dns.Client{
		Timeout: defaultTimeout,
		Net:     "udp",
	}
	if useTCP {
		client.Net = "tcp"
	}

	resp, _, err := client.Exchange(m, addr)
	if err != nil {
		// UDP failed — retry once (transient packet loss)
		slog.Debug("dns udp failed, retrying udp", "error", err)
		client.Net = "udp"
		resp, _, err = client.Exchange(m, addr)
	}
	if err != nil {
		// UDP still fails (NAT/firewall). Retry via TCP.
		slog.Debug("dns udp retry failed, trying tcp", "error", err)
		client.Net = "tcp"
		resp, _, err = client.Exchange(m, addr)
		if err != nil {
			return fmt.Errorf("dns exchange failed (udp+tcp): %w", err)
		}
	}
	if resp.MsgHdr.Truncated {
		client.Net = "tcp"
		resp, _, err = client.Exchange(m, addr)
		if err != nil {
			return fmt.Errorf("dns tcp fallback failed: %w", err)
		}
	}
	if resp.Rcode != dns.RcodeSuccess {
		return fmt.Errorf("dns response code: %d", resp.Rcode)
	}
	return nil
}

func QueryChunk(addr, zone string, msgID [8]byte, chunkIdx uint16) (*encoding.Chunk, error) {
	enc := encoding.NewChunk(msgID, chunkIdx, 0, nil)
	labels := enc.EncodeToLabels(zone)
	name := strings.Join(labels, ".")

	m := new(dns.Msg)
	m.SetQuestion(dns.Fqdn(name), dns.TypeTXT)
	m.RecursionDesired = false

	client := &dns.Client{Timeout: defaultTimeout}
	resp, _, err := client.Exchange(m, addr)
	if err != nil {
		// UDP failed — retry once (transient packet loss)
		slog.Debug("dns query udp failed, retrying udp", "error", err)
		client.Net = "udp"
		resp, _, err = client.Exchange(m, addr)
	}
	if err != nil {
		// UDP still fails (NAT/firewall). Try TCP.
		slog.Debug("dns query udp retry failed, trying tcp", "error", err)
		client.Net = "tcp"
		resp, _, err = client.Exchange(m, addr)
		if err != nil {
			return nil, fmt.Errorf("dns query failed (udp+tcp): %w", err)
		}
	}
	if resp.Rcode != dns.RcodeSuccess {
		return nil, fmt.Errorf("dns response code: %d", resp.Rcode)
	}
	if len(resp.Answer) == 0 {
		return nil, fmt.Errorf("no answer in response")
	}
	txt, ok := resp.Answer[0].(*dns.TXT)
	if !ok {
		return nil, fmt.Errorf("answer is not TXT record")
	}
	allLabels := append(txt.Txt, zone)
	return encoding.DecodeChunkFromLabels(allLabels, zone)
}

func ListenAndServe(addr, zone string, handler Handler) error {
	mux := dns.NewServeMux()
	mux.HandleFunc(zone, func(w dns.ResponseWriter, r *dns.Msg) {
		m := new(dns.Msg)
		m.SetReply(r)
		m.Authoritative = true

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

		// DecodeChunkFromLabels expects the zone as the last label.
		// We stripped it above, so append it back.
		labels = append(labels, zoneClean)

		chunk, err := encoding.DecodeChunkFromLabels(labels, zoneClean)
		if err != nil {
			m.Rcode = dns.RcodeFormatError
			w.WriteMsg(m)
			return
		}

		if chunk.TotalChunks == 0 {
			storedChunk, err := handler.QueryChunk(chunk.MsgID, chunk.ChunkIdx)
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

		if err := handler.HandleChunk(chunk); err != nil {
			m.Rcode = dns.RcodeServerFailure
			w.WriteMsg(m)
			return
		}

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
