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

	// Try TCP first (carrier networks intercept UDP:53 and return fake NXDOMAIN).
	// Fall back to UDP if TCP fails.
	if !useTCP {
		// Try TCP first
		tcpClient := &dns.Client{Timeout: defaultTimeout, Net: "tcp"}
		resp, _, err := tcpClient.Exchange(m, addr)
		if err == nil && resp.Rcode == dns.RcodeSuccess {
			return nil
		}
		// TCP failed or returned error — try UDP once
		slog.Debug("dns tcp failed or bad rcode, trying udp", "error", err)
		udpClient := &dns.Client{Timeout: defaultTimeout, Net: "udp"}
		resp, _, err = udpClient.Exchange(m, addr)
		if err == nil && resp.Rcode == dns.RcodeSuccess {
			return nil
		}
		// UDP also failed — try TCP once more (in case truncated or transient)
		if err != nil {
			slog.Debug("dns udp failed, final tcp retry", "error", err)
			tcpClient2 := &dns.Client{Timeout: defaultTimeout, Net: "tcp"}
			resp, _, err = tcpClient2.Exchange(m, addr)
			if err == nil && resp.Rcode == dns.RcodeSuccess {
				return nil
			}
		}
		if err != nil {
			return fmt.Errorf("dns exchange failed (tcp+udp): %w", err)
		}
		return fmt.Errorf("dns response code: %d", resp.Rcode)
	}

	// useTCP explicitly requested
	client := &dns.Client{Timeout: defaultTimeout, Net: "tcp"}
	resp, _, err := client.Exchange(m, addr)
	if err != nil {
		return fmt.Errorf("dns tcp exchange failed: %w", err)
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

	// TCP first (carrier UDP intercept), fall back to UDP, then final TCP retry
	tcpClient := &dns.Client{Timeout: defaultTimeout, Net: "tcp"}
	resp, _, err := tcpClient.Exchange(m, addr)
	if err == nil && resp.Rcode == dns.RcodeSuccess && len(resp.Answer) > 0 {
		txt, ok := resp.Answer[0].(*dns.TXT)
		if ok {
			allLabels := append(txt.Txt, zone)
			return encoding.DecodeChunkFromLabels(allLabels, zone)
		}
	}

	// TCP failed — try UDP once
	slog.Debug("dns query tcp failed or bad response, trying udp", "error", err)
	udpClient := &dns.Client{Timeout: defaultTimeout, Net: "udp"}
	resp, _, err = udpClient.Exchange(m, addr)
	if err == nil && resp.Rcode == dns.RcodeSuccess && len(resp.Answer) > 0 {
		txt, ok := resp.Answer[0].(*dns.TXT)
		if ok {
			allLabels := append(txt.Txt, zone)
			return encoding.DecodeChunkFromLabels(allLabels, zone)
		}
	}

	// UDP also failed — final TCP retry (handles truncated responses)
	slog.Debug("dns query udp failed, final tcp retry", "error", err)
	tcpClient2 := &dns.Client{Timeout: defaultTimeout, Net: "tcp"}
	resp, _, err = tcpClient2.Exchange(m, addr)
	if err != nil {
		return nil, fmt.Errorf("dns query failed (tcp+udp): %w", err)
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
