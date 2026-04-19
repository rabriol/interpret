# Church Translator App — Design Spec

**Date:** 2026-04-18
**Status:** Approved

---

## Overview

A real-time audio translation system for church services. One Flutter app runs in two modes — Translator and Listener. A Raspberry Pi Zero 2W acts as a local Wi-Fi access point and audio relay server. No internet required. No commercial infrastructure. ~27ms end-to-end latency.

---

## Requirements

- **Listeners:** 100+ simultaneous, BYOD (iOS and Android)
- **Languages:** 4+ simultaneous translation channels
- **Venue:** Single room, all devices within ~30–50m
- **Network:** No internet. No existing infrastructure. Pi creates its own Wi-Fi AP.
- **Latency:** ≤30ms target (simultaneous interpretation use case)
- **Interpreter types:** Both simultaneous and consecutive
- **Translator devices:** One dedicated device per language, iOS or Android (platform-agnostic)
- **Listener devices:** Personal phones, iOS or Android

---

## System Components

### 1. Flutter Mobile App (iOS + Android)

Single codebase, two runtime modes selected on first launch:

**Translator mode:**
- User selects their language channel (e.g. "English → Spanish")
- Captures microphone audio in always-on mode by default; push-to-talk available as a toggle for consecutive interpretation
- Encodes audio with Opus at 10ms frames, 16–32kbps
- Sends RTP/UDP packets to Pi relay server (unicast, port 500N for channel N)
- Displays live audio level meter and connection status

**Listener mode:**
- Fetches available language channels from Pi on connect
- User selects preferred language
- Joins corresponding UDP multicast group (239.0.0.N:600N)
- Decodes Opus frames and plays audio through earphones
- Volume control, channel switching at any time

**Shared UX:**
- On launch: detects if connected to `ChurchTranslator` Wi-Fi
- If not connected: shows prompt "Join ChurchTranslator Wi-Fi to begin"
- No login, no account, no pairing required
- Role (Translator/Listener) stored in local preferences, changeable in settings

### 2. Raspberry Pi Relay Server

**Hardware:**
- Raspberry Pi Zero 2W (~$15–20)
- MicroSD card 8GB+ with Raspberry Pi OS Lite
- USB battery bank (5V, any capacity ≥5000mAh for 8+ hours)

**Software services (all auto-start on boot):**
- `hostapd` — Wi-Fi access point, SSID: `ChurchTranslator`, WPA2 password
- `dnsmasq` — DHCP server, assigns IPs to all connected devices (192.168.4.x)
- Relay server (Go binary) — receives unicast UDP per channel, rebroadcasts via UDP multicast

**Relay server behavior:**
- Listens on UDP ports 5001–500N (one per language channel)
- For each received RTP packet on port 500N, rebroadcasts to multicast group 239.0.0.N:600N
- Exposes a simple UDP/JSON channel registry on port 4999 so listener apps can discover available channels dynamically

**Configuration:** single `config.yaml` file:
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

**Operator workflow:** plug Pi into USB battery bank → wait 30 seconds → ready. No screen, no interaction needed.

### 3. Audio Pipeline

| Stage | Detail |
|---|---|
| Codec | Opus, voice mode (`OPUS_APPLICATION_VOIP`) |
| Frame size | 10ms (minimum Opus frame — lowest latency) |
| Bitrate | 16kbps (voice, low bandwidth) |
| Transport | RTP over UDP |
| Latency budget | Mic capture ~10ms + encode ~10ms + WiFi ~2ms + relay ~1ms + decode ~5ms = **~28ms** |
| Packet loss handling | Opus built-in FEC (Forward Error Correction), small jitter buffer (20ms) |

---

## Data Flow

```
Translator mic
  → Opus encode (10ms frames)
  → RTP/UDP unicast → Pi:500N

Pi relay
  → receives on port 500N
  → rebroadcasts to multicast 239.0.0.N:600N

Listener
  → joins multicast group 239.0.0.N:600N
  → Opus decode
  → audio output (earphones)
```

Channel mapping example:
- Channel 1 (ES): Translator → Pi:5001 → multicast 239.0.0.1:6001 → all ES listeners
- Channel 2 (PT): Translator → Pi:5002 → multicast 239.0.0.2:6002 → all PT listeners

---

## Technology Stack

| Layer | Technology |
|---|---|
| Mobile app | Flutter (Dart) |
| Audio capture | `record` package (actively maintained, iOS + Android) |
| Audio playback | `just_audio` package |
| Opus encoding | `opus_dart` or FFI bindings to libopus |
| UDP sockets | `dart:io` RawDatagramSocket |
| Pi OS | Raspberry Pi OS Lite (64-bit) |
| Pi Wi-Fi AP | hostapd |
| Pi DHCP | dnsmasq |
| Pi relay server | Go (single static binary, minimal deps) |
| Configuration | YAML |

---

## Project Structure

```
translator/
├── app/                        # Flutter app
│   ├── lib/
│   │   ├── main.dart
│   │   ├── role_selection/     # First-launch role picker
│   │   ├── translator/         # Translator mode screens + audio capture
│   │   ├── listener/           # Listener mode screens + audio playback
│   │   ├── audio/              # Opus encode/decode, RTP packetization
│   │   ├── network/            # UDP socket management, multicast, channel discovery
│   │   └── shared/             # Wi-Fi detection, settings, UI components
│   ├── android/
│   └── ios/
├── pi/                         # Raspberry Pi relay server
│   ├── relay/                  # Go relay server source
│   ├── config.yaml             # Channel configuration
│   └── setup.sh                # One-time Pi setup script
└── docs/
    └── superpowers/specs/
        └── 2026-04-18-church-translator-design.md
```

---

## Out of Scope

- Recording or playback of past services
- Text transcription
- Internet fallback
- Web admin dashboard
- Authentication beyond Wi-Fi password

---

## Open Questions / Decisions to Revisit During Implementation

- **Opus FFI on Flutter:** validate `opus_dart` package works on both iOS and Android without native compilation issues; fallback is manual FFI bindings to libopus
- **UDP multicast on Android:** some Android versions require `MulticastLock` to be acquired — handle in network layer
- **iOS background audio:** app must declare audio background mode in `Info.plist` to keep streaming when screen locks
- **Pi Zero 2W CPU headroom:** relay server is forwarding only (no encode/decode), so load should be minimal; verify under 4+ simultaneous streams
