package main

import (
	"fmt"
	"log"
	"net"
)

type channelRelay struct {
	channel    Channel
	listenConn *net.UDPConn
	multiConn  *net.UDPConn
	done       chan struct{}
}

func newChannelRelay(ch Channel) *channelRelay {
	return &channelRelay{
		channel: ch,
		done:    make(chan struct{}),
	}
}

func (r *channelRelay) start() {
	listenAddr := fmt.Sprintf("0.0.0.0:%d", 5000+r.channel.ID)
	laddr, err := net.ResolveUDPAddr("udp4", listenAddr)
	if err != nil {
		log.Printf("[ch%d] resolve listen addr: %v", r.channel.ID, err)
		return
	}
	r.listenConn, err = net.ListenUDP("udp4", laddr)
	if err != nil {
		log.Printf("[ch%d] listen UDP: %v", r.channel.ID, err)
		return
	}
	defer r.listenConn.Close()

	multicastAddr := fmt.Sprintf("239.0.0.%d:%d", r.channel.ID, 6000+r.channel.ID)
	maddr, err := net.ResolveUDPAddr("udp4", multicastAddr)
	if err != nil {
		log.Printf("[ch%d] resolve multicast addr: %v", r.channel.ID, err)
		return
	}
	r.multiConn, err = net.DialUDP("udp4", nil, maddr)
	if err != nil {
		log.Printf("[ch%d] dial multicast: %v", r.channel.ID, err)
		return
	}
	defer r.multiConn.Close()

	log.Printf("[ch%d] %s: relaying %s → %s", r.channel.ID, r.channel.Name, listenAddr, multicastAddr)

	buf := make([]byte, 4096)
	for {
		select {
		case <-r.done:
			return
		default:
		}
		n, _, err := r.listenConn.ReadFromUDP(buf)
		if err != nil {
			select {
			case <-r.done:
				return
			default:
				log.Printf("[ch%d] read error: %v", r.channel.ID, err)
				continue
			}
		}
		if _, err := r.multiConn.Write(buf[:n]); err != nil {
			log.Printf("[ch%d] multicast write error: %v", r.channel.ID, err)
		}
	}
}

func (r *channelRelay) stop() {
	close(r.done)
	if r.listenConn != nil {
		r.listenConn.Close()
	}
}
