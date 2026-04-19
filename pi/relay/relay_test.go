package main

import (
	"net"
	"os"
	"runtime"
	"strings"
	"testing"
	"time"
)

func isRunningOnDarwin() bool { return runtime.GOOS == "darwin" }

func TestLoadConfig(t *testing.T) {
	yaml := `
ssid: TestNet
password: test1234
channels:
  - id: 1
    name: "English → Spanish"
  - id: 2
    name: "English → Portuguese"
`
	f, err := os.CreateTemp("", "config-*.yaml")
	if err != nil {
		t.Fatal(err)
	}
	defer os.Remove(f.Name())
	f.WriteString(yaml)
	f.Close()

	cfg, err := loadConfig(f.Name())
	if err != nil {
		t.Fatalf("loadConfig error: %v", err)
	}
	if cfg.SSID != "TestNet" {
		t.Errorf("expected SSID TestNet, got %s", cfg.SSID)
	}
	if len(cfg.Channels) != 2 {
		t.Errorf("expected 2 channels, got %d", len(cfg.Channels))
	}
	if cfg.Channels[0].ID != 1 {
		t.Errorf("expected channel ID 1, got %d", cfg.Channels[0].ID)
	}
	if cfg.Channels[1].Name != "English → Portuguese" {
		t.Errorf("unexpected channel name: %s", cfg.Channels[1].Name)
	}
}

func TestRelayForwardsPacket(t *testing.T) {
	// Multicast loopback is unreliable on macOS; test is validated on Linux (Pi).
	if isRunningOnDarwin() {
		t.Skip("multicast loopback not supported on macOS; verify on Raspberry Pi")
	}
	multicastAddr := "239.0.0.9:6009"
	laddr, err := net.ResolveUDPAddr("udp4", multicastAddr)
	if err != nil {
		t.Fatal(err)
	}
	conn, err := net.ListenMulticastUDP("udp4", nil, laddr)
	if err != nil {
		t.Skipf("multicast not available in this environment: %v", err)
	}
	defer conn.Close()
	conn.SetReadDeadline(time.Now().Add(2 * time.Second))

	ch := Channel{ID: 9, Name: "test"}
	relay := newChannelRelay(ch)
	go relay.start()
	defer relay.stop()

	time.Sleep(50 * time.Millisecond)
	dst, _ := net.ResolveUDPAddr("udp4", "127.0.0.1:5009")
	sender, _ := net.DialUDP("udp4", nil, dst)
	defer sender.Close()

	payload := []byte("hello-relay-test")
	sender.Write(payload)

	buf := make([]byte, 1500)
	n, _, err := conn.ReadFromUDP(buf)
	if err != nil {
		t.Fatalf("did not receive forwarded packet: %v", err)
	}
	if string(buf[:n]) != string(payload) {
		t.Errorf("forwarded payload mismatch: got %q want %q", buf[:n], payload)
	}
}

func TestRegistryRespondsWithChannels(t *testing.T) {
	channels := []Channel{
		{ID: 1, Name: "English → Spanish"},
		{ID: 2, Name: "English → Portuguese"},
	}
	reg := newRegistry(channels)
	go reg.start()
	defer reg.stop()

	time.Sleep(50 * time.Millisecond)

	conn, err := net.Dial("udp4", "127.0.0.1:4999")
	if err != nil {
		t.Fatal(err)
	}
	defer conn.Close()
	conn.SetDeadline(time.Now().Add(2 * time.Second))

	conn.Write([]byte("list"))

	buf := make([]byte, 4096)
	n, err := conn.Read(buf)
	if err != nil {
		t.Fatalf("no response from registry: %v", err)
	}

	body := string(buf[:n])
	if !strings.Contains(body, `"English → Spanish"`) {
		t.Errorf("expected channel name in response, got: %s", body)
	}
	if !strings.Contains(body, `"id":1`) {
		t.Errorf("expected channel id in response, got: %s", body)
	}
}
