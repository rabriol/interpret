package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net"
)

type registry struct {
	channels []Channel
	conn     *net.UDPConn
	done     chan struct{}
}

func newRegistry(channels []Channel) *registry {
	return &registry{channels: channels, done: make(chan struct{})}
}

type channelInfo struct {
	ID            int    `json:"id"`
	Name          string `json:"name"`
	MulticastAddr string `json:"multicast_addr"`
	MulticastPort int    `json:"multicast_port"`
}

func (r *registry) start() {
	addr, err := net.ResolveUDPAddr("udp4", "0.0.0.0:4999")
	if err != nil {
		log.Printf("[registry] resolve: %v", err)
		return
	}
	r.conn, err = net.ListenUDP("udp4", addr)
	if err != nil {
		log.Printf("[registry] listen: %v", err)
		return
	}
	defer r.conn.Close()
	log.Println("[registry] listening on :4999")

	infos := make([]channelInfo, len(r.channels))
	for i, ch := range r.channels {
		infos[i] = channelInfo{
			ID:            ch.ID,
			Name:          ch.Name,
			MulticastAddr: fmt.Sprintf("239.0.0.%d", ch.ID),
			MulticastPort: 6000 + ch.ID,
		}
	}
	response, _ := json.Marshal(infos)

	buf := make([]byte, 256)
	for {
		select {
		case <-r.done:
			return
		default:
		}
		n, remote, err := r.conn.ReadFromUDP(buf)
		if err != nil {
			select {
			case <-r.done:
				return
			default:
				log.Printf("[registry] read: %v", err)
				continue
			}
		}
		_ = n
		if _, err := r.conn.WriteToUDP(response, remote); err != nil {
			log.Printf("[registry] write: %v", err)
		}
	}
}

func (r *registry) stop() {
	close(r.done)
	if r.conn != nil {
		r.conn.Close()
	}
}
