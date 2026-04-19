package main

import (
	"log"
	"os"
	"os/signal"
	"syscall"
)

func main() {
	cfgPath := "config.yaml"
	if len(os.Args) > 1 {
		cfgPath = os.Args[1]
	}
	cfg, err := loadConfig(cfgPath)
	if err != nil {
		log.Fatalf("failed to load config: %v", err)
	}
	log.Printf("starting relay for SSID=%s with %d channels", cfg.SSID, len(cfg.Channels))

	relays := make([]*channelRelay, len(cfg.Channels))
	for i, ch := range cfg.Channels {
		relays[i] = newChannelRelay(ch)
		go relays[i].start()
	}

	reg := newRegistry(cfg.Channels)
	go reg.start()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Println("shutting down...")
	for _, r := range relays {
		r.stop()
	}
	reg.stop()
}
