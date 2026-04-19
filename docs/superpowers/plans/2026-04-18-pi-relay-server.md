# Pi Relay Server Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and deploy a Go UDP relay server on Raspberry Pi Zero 2W that receives per-channel unicast audio streams and rebroadcasts them via UDP multicast, with hostapd/dnsmasq for local Wi-Fi AP.

**Architecture:** A single statically-compiled Go binary listens on UDP ports 5001–500N (one per channel), forwards every received packet to multicast group 239.0.0.N:600N, and exposes a JSON channel registry on UDP port 4999. Systemd manages the binary as a service. A one-time `setup.sh` installs and configures hostapd, dnsmasq, and the service.

**Tech Stack:** Go 1.22, `gopkg.in/yaml.v3`, hostapd, dnsmasq, systemd, Raspberry Pi OS Lite 64-bit

---

## File Map

```
pi/
├── relay/
│   ├── main.go              # Entry point: loads config, starts relay
│   ├── config.go            # Config struct + YAML loading
│   ├── relay.go             # Per-channel UDP listener → multicast forwarder
│   ├── registry.go          # UDP/JSON channel registry on port 4999
│   └── relay_test.go        # Unit tests for relay and registry logic
├── config.yaml              # Channel definitions (SSID, password, channels)
├── setup.sh                 # One-time Pi setup script
├── church-translator.service # systemd unit file
└── hostapd.conf             # hostapd AP configuration template
```

---

## Task 1: Project Scaffold + Config Loading

**Files:**
- Create: `pi/relay/config.go`
- Create: `pi/relay/main.go`
- Create: `pi/config.yaml`
- Create: `pi/relay/relay_test.go`

- [ ] **Step 1: Initialize Go module**

```bash
cd /Users/rafaelbrito/Developer/translator/pi/relay
go mod init github.com/church-translator/relay
go get gopkg.in/yaml.v3
```

Expected output: `go.mod` and `go.sum` created.

- [ ] **Step 2: Write the failing test for config loading**

Create `pi/relay/relay_test.go`:

```go
package main

import (
	"os"
	"testing"
)

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
```

- [ ] **Step 3: Run test to verify it fails**

```bash
cd /Users/rafaelbrito/Developer/translator/pi/relay
go test ./... -run TestLoadConfig -v
```

Expected: FAIL — `undefined: loadConfig`

- [ ] **Step 4: Implement config.go**

Create `pi/relay/config.go`:

```go
package main

import (
	"os"

	"gopkg.in/yaml.v3"
)

type Channel struct {
	ID   int    `yaml:"id"`
	Name string `yaml:"name"`
}

type Config struct {
	SSID     string    `yaml:"ssid"`
	Password string    `yaml:"password"`
	Channels []Channel `yaml:"channels"`
}

func loadConfig(path string) (*Config, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var cfg Config
	if err := yaml.Unmarshal(data, &cfg); err != nil {
		return nil, err
	}
	return &cfg, nil
}
```

- [ ] **Step 5: Create minimal main.go**

Create `pi/relay/main.go`:

```go
package main

import (
	"log"
	"os"
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
	log.Printf("loaded %d channels from %s", len(cfg.Channels), cfgPath)
}
```

- [ ] **Step 6: Create pi/config.yaml**

```yaml
ssid: ChurchTranslator
password: church1234
channels:
  - id: 1
    name: "English → Spanish"
  - id: 2
    name: "English → Portuguese"
  - id: 3
    name: "English → Chinese"
  - id: 4
    name: "English → French"
```

- [ ] **Step 7: Run test to verify it passes**

```bash
cd /Users/rafaelbrito/Developer/translator/pi/relay
go test ./... -run TestLoadConfig -v
```

Expected: PASS

- [ ] **Step 8: Commit**

```bash
git -C /Users/rafaelbrito/Developer/translator add pi/
git -C /Users/rafaelbrito/Developer/translator commit -m "feat(pi): scaffold relay module with config loading"
```

---

## Task 2: UDP Relay Core (Unicast → Multicast)

**Files:**
- Create: `pi/relay/relay.go`
- Modify: `pi/relay/relay_test.go` (add relay tests)

- [ ] **Step 1: Write failing tests for relay logic**

Append to `pi/relay/relay_test.go`:

```go
import (
	"net"
	"time"
)

func TestRelayForwardsPacket(t *testing.T) {
	// Start a multicast listener to receive forwarded packets
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

	// Start relay for channel 9
	ch := Channel{ID: 9, Name: "test"}
	relay := newChannelRelay(ch)
	go relay.start()
	defer relay.stop()

	// Send a test packet to the relay's unicast port
	time.Sleep(50 * time.Millisecond) // let relay bind
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
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /Users/rafaelbrito/Developer/translator/pi/relay
go test ./... -run TestRelayForwardsPacket -v
```

Expected: FAIL — `undefined: newChannelRelay`

- [ ] **Step 3: Implement relay.go**

Create `pi/relay/relay.go`:

```go
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
```

- [ ] **Step 4: Run test to verify it passes**

```bash
cd /Users/rafaelbrito/Developer/translator/pi/relay
go test ./... -run TestRelayForwardsPacket -v
```

Expected: PASS (or SKIP if multicast is not available on macOS — that's acceptable; it will be tested on Pi)

- [ ] **Step 5: Commit**

```bash
git -C /Users/rafaelbrito/Developer/translator add pi/relay/relay.go pi/relay/relay_test.go
git -C /Users/rafaelbrito/Developer/translator commit -m "feat(pi): UDP unicast-to-multicast relay core"
```

---

## Task 3: Channel Registry (UDP/JSON on port 4999)

**Files:**
- Create: `pi/relay/registry.go`
- Modify: `pi/relay/relay_test.go` (add registry test)

- [ ] **Step 1: Write failing test for channel registry**

Append to `pi/relay/relay_test.go`:

```go
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
```

Add `"strings"` to the import block at the top of relay_test.go.

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /Users/rafaelbrito/Developer/translator/pi/relay
go test ./... -run TestRegistryRespondsWithChannels -v
```

Expected: FAIL — `undefined: newRegistry`

- [ ] **Step 3: Implement registry.go**

Create `pi/relay/registry.go`:

```go
package main

import (
	"encoding/json"
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
	ID           int    `json:"id"`
	Name         string `json:"name"`
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
			ID:           ch.ID,
			Name:         ch.Name,
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
```

Add `"fmt"` to the import block in registry.go.

- [ ] **Step 4: Run test to verify it passes**

```bash
cd /Users/rafaelbrito/Developer/translator/pi/relay
go test ./... -run TestRegistryRespondsWithChannels -v
```

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git -C /Users/rafaelbrito/Developer/translator add pi/relay/registry.go pi/relay/relay_test.go
git -C /Users/rafaelbrito/Developer/translator commit -m "feat(pi): UDP channel registry on port 4999"
```

---

## Task 4: Wire Everything Together in main.go

**Files:**
- Modify: `pi/relay/main.go`

- [ ] **Step 1: Update main.go to start all relays and registry**

Replace the contents of `pi/relay/main.go`:

```go
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
```

- [ ] **Step 2: Build and verify it compiles**

```bash
cd /Users/rafaelbrito/Developer/translator/pi/relay
go build -o relay-server .
```

Expected: binary `relay-server` created with no errors.

- [ ] **Step 3: Run all tests**

```bash
cd /Users/rafaelbrito/Developer/translator/pi/relay
go test ./... -v
```

Expected: all tests PASS (TestRelayForwardsPacket may SKIP on macOS — that's fine)

- [ ] **Step 4: Clean up build artifact**

```bash
rm /Users/rafaelbrito/Developer/translator/pi/relay/relay-server
```

- [ ] **Step 5: Commit**

```bash
git -C /Users/rafaelbrito/Developer/translator add pi/relay/main.go
git -C /Users/rafaelbrito/Developer/translator commit -m "feat(pi): wire relay and registry in main"
```

---

## Task 5: Cross-Compile for ARM64 + Systemd Service Unit

**Files:**
- Create: `pi/church-translator.service`
- Modify: `pi/relay/main.go` (no change needed)

- [ ] **Step 1: Cross-compile for Pi Zero 2W (ARM64)**

```bash
cd /Users/rafaelbrito/Developer/translator/pi/relay
GOOS=linux GOARCH=arm64 go build -o ../church-translator-relay .
```

Expected: `pi/church-translator-relay` binary created.

- [ ] **Step 2: Create systemd service unit**

Create `pi/church-translator.service`:

```ini
[Unit]
Description=Church Translator Relay Server
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/church-translator-relay /etc/church-translator/config.yaml
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

- [ ] **Step 3: Commit**

```bash
git -C /Users/rafaelbrito/Developer/translator add pi/church-translator-relay pi/church-translator.service
git -C /Users/rafaelbrito/Developer/translator commit -m "feat(pi): cross-compiled ARM64 binary and systemd unit"
```

---

## Task 6: Pi Setup Script

**Files:**
- Create: `pi/setup.sh`
- Create: `pi/hostapd.conf`
- Create: `pi/dnsmasq.conf`

- [ ] **Step 1: Create hostapd.conf template**

Create `pi/hostapd.conf`:

```
interface=wlan0
driver=nl80211
ssid=ChurchTranslator
hw_mode=g
channel=6
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=church1234
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
```

- [ ] **Step 2: Create dnsmasq.conf**

Create `pi/dnsmasq.conf`:

```
interface=wlan0
dhcp-range=192.168.4.2,192.168.4.200,255.255.255.0,24h
domain=local
address=/gw.local/192.168.4.1
```

- [ ] **Step 3: Create setup.sh**

Create `pi/setup.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Must run as root on the Pi
if [ "$(id -u)" != "0" ]; then
  echo "Run as root: sudo bash setup.sh"
  exit 1
fi

echo "==> Installing packages..."
apt-get update -q
apt-get install -y hostapd dnsmasq

echo "==> Stopping services during config..."
systemctl stop hostapd dnsmasq || true
systemctl unmask hostapd

echo "==> Configuring static IP on wlan0..."
cat >> /etc/dhcpcd.conf << 'EOF'

interface wlan0
    static ip_address=192.168.4.1/24
    nohook wpa_supplicant
EOF

echo "==> Writing hostapd config..."
cp "$(dirname "$0")/hostapd.conf" /etc/hostapd/hostapd.conf
echo 'DAEMON_CONF="/etc/hostapd/hostapd.conf"' > /etc/default/hostapd

echo "==> Writing dnsmasq config..."
mv /etc/dnsmasq.conf /etc/dnsmasq.conf.bak || true
cp "$(dirname "$0")/dnsmasq.conf" /etc/dnsmasq.conf

echo "==> Installing relay binary..."
cp "$(dirname "$0")/church-translator-relay" /usr/local/bin/church-translator-relay
chmod +x /usr/local/bin/church-translator-relay

echo "==> Installing relay config..."
mkdir -p /etc/church-translator
cp "$(dirname "$0")/config.yaml" /etc/church-translator/config.yaml

echo "==> Installing systemd service..."
cp "$(dirname "$0")/church-translator.service" /etc/systemd/system/
systemctl daemon-reload
systemctl enable church-translator

echo "==> Enabling hostapd and dnsmasq..."
systemctl enable hostapd
systemctl enable dnsmasq

echo ""
echo "Setup complete. Reboot the Pi: sudo reboot"
echo "After reboot, the Pi will broadcast 'ChurchTranslator' Wi-Fi and run the relay."
```

- [ ] **Step 4: Make setup.sh executable**

```bash
chmod +x /Users/rafaelbrito/Developer/translator/pi/setup.sh
```

- [ ] **Step 5: Commit**

```bash
git -C /Users/rafaelbrito/Developer/translator add pi/setup.sh pi/hostapd.conf pi/dnsmasq.conf
git -C /Users/rafaelbrito/Developer/translator commit -m "feat(pi): setup script, hostapd and dnsmasq config"
```

---

## Self-Review Checklist

**Spec requirements covered:**
- [x] hostapd Wi-Fi AP (SSID: ChurchTranslator, WPA2) — Task 6
- [x] dnsmasq DHCP (192.168.4.x) — Task 6
- [x] Go relay: unicast port 500N → multicast 239.0.0.N:600N — Task 2
- [x] Channel registry on port 4999 (UDP/JSON) — Task 3
- [x] config.yaml with SSID, password, channels — Task 1
- [x] Systemd auto-start on boot — Task 5
- [x] Cross-compiled ARM64 binary — Task 5
- [x] One-time setup script — Task 6
- [x] Operator workflow: plug in → 30 seconds → ready — Task 6 (reboot once after setup)

**Open question from spec:** Pi Zero 2W CPU headroom under 4+ streams — the relay is pure packet forwarding (no encode/decode), so load is minimal. No action needed until tested on hardware.
