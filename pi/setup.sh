#!/usr/bin/env bash
set -euo pipefail

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
