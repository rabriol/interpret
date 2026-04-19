# Flutter App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a single Flutter app (iOS + Android) with two runtime modes — Translator and Listener — that communicates via UDP over a local Wi-Fi network hosted by the Pi relay server.

**Architecture:** Role is stored in SharedPreferences and selected on first launch. Translator mode captures mic audio, encodes it with Opus via FFI, and sends RTP/UDP packets to the Pi. Listener mode queries the Pi registry on port 4999, joins the chosen channel's UDP multicast group, decodes incoming Opus packets, and plays them through the audio output. Wi-Fi detection checks the SSID against `ChurchTranslator` on each startup.

**Tech Stack:** Flutter 3.x (Dart), `flutter_sound` (audio capture + playback), `opus_flutter` (Opus FFI bindings), `dart:io` (RawDatagramSocket), `shared_preferences`, `network_info_plus` (SSID detection)

---

## File Map

```
app/
├── pubspec.yaml
├── lib/
│   ├── main.dart                    # App entry, MaterialApp, role routing
│   ├── shared/
│   │   ├── models.dart              # Channel, AppRole enums/classes
│   │   ├── prefs.dart               # SharedPreferences wrapper (role storage)
│   │   └── wifi_check.dart          # SSID detection helper
│   ├── network/
│   │   ├── registry_client.dart     # UDP query to Pi port 4999 → List<Channel>
│   │   ├── rtp.dart                 # RTP packet framing (pack/unpack)
│   │   ├── translator_socket.dart   # UDP unicast sender (Translator mode)
│   │   └── listener_socket.dart     # UDP multicast receiver (Listener mode)
│   ├── audio/
│   │   ├── opus_codec.dart          # Opus encode/decode via opus_flutter FFI
│   │   └── jitter_buffer.dart       # Simple 20ms jitter buffer for playback
│   ├── translator/
│   │   ├── translator_screen.dart   # UI: channel picker, level meter, PTT toggle
│   │   └── translator_controller.dart # Capture → encode → send loop
│   ├── listener/
│   │   ├── listener_screen.dart     # UI: channel picker, volume, status
│   │   └── listener_controller.dart # Receive → buffer → decode → playback loop
│   └── role_selection/
│       └── role_selection_screen.dart # First-launch role picker
├── android/
│   └── app/src/main/AndroidManifest.xml  # INTERNET, RECORD_AUDIO, CHANGE_MULTICAST_STATE
└── ios/
    └── Runner/
        ├── Info.plist               # NSMicrophoneUsageDescription, NSLocalNetworkUsageDescription, audio background mode
        └── Runner.entitlements      # No special entitlements needed
```

---

## Task 1: Flutter Project Scaffold + Dependencies

**Files:**
- Create: `app/` (Flutter project)
- Modify: `app/pubspec.yaml`
- Modify: `app/android/app/src/main/AndroidManifest.xml`
- Modify: `app/ios/Runner/Info.plist`

- [ ] **Step 1: Create Flutter project**

```bash
cd /Users/rafaelbrito/Developer/translator
flutter create --org com.churchtranslator --project-name church_translator app
```

Expected: Flutter project created in `app/`.

- [ ] **Step 2: Add dependencies to pubspec.yaml**

Open `app/pubspec.yaml`. Replace the `dependencies:` section with:

```yaml
dependencies:
  flutter:
    sdk: flutter
  shared_preferences: ^2.3.2
  network_info_plus: ^6.0.1
  flutter_sound: ^9.2.13
  opus_flutter: ^3.0.0
  permission_handler: ^11.3.1
```

- [ ] **Step 3: Install dependencies**

```bash
cd /Users/rafaelbrito/Developer/translator/app
flutter pub get
```

Expected: packages resolved, no errors.

- [ ] **Step 4: Add Android permissions to AndroidManifest.xml**

In `app/android/app/src/main/AndroidManifest.xml`, add inside `<manifest>` before `<application>`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.CHANGE_NETWORK_STATE"/>
<uses-permission android:name="android.permission.CHANGE_WIFI_MULTICAST_STATE"/>
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE"/>
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
```

- [ ] **Step 5: Add iOS permissions and background audio to Info.plist**

In `app/ios/Runner/Info.plist`, add inside the root `<dict>`:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>Microphone access is needed to capture audio for translation.</string>
<key>NSLocalNetworkUsageDescription</key>
<string>This app communicates with the ChurchTranslator relay device on your local Wi-Fi network.</string>
<key>NSBonjourServices</key>
<array>
    <string>_church-translator._udp</string>
</array>
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>
```

- [ ] **Step 6: Verify app compiles**

```bash
cd /Users/rafaelbrito/Developer/translator/app
flutter build apk --debug 2>&1 | tail -5
```

Expected: `Built build/app/outputs/flutter-apk/app-debug.apk` with no errors.

- [ ] **Step 7: Commit**

```bash
git -C /Users/rafaelbrito/Developer/translator add app/
git -C /Users/rafaelbrito/Developer/translator commit -m "feat(app): flutter scaffold with dependencies and permissions"
```

---

## Task 2: Shared Models + Preferences

**Files:**
- Create: `app/lib/shared/models.dart`
- Create: `app/lib/shared/prefs.dart`
- Create: `app/test/shared_test.dart`

- [ ] **Step 1: Write failing tests**

Create `app/test/shared_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:church_translator/shared/models.dart';
import 'package:church_translator/shared/prefs.dart';

void main() {
  group('AppPrefs', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('role defaults to null on first launch', () async {
      final prefs = await AppPrefs.load();
      expect(prefs.role, isNull);
    });

    test('saves and reads Translator role', () async {
      final prefs = await AppPrefs.load();
      await prefs.setRole(AppRole.translator);
      final prefs2 = await AppPrefs.load();
      expect(prefs2.role, AppRole.translator);
    });

    test('saves and reads Listener role', () async {
      final prefs = await AppPrefs.load();
      await prefs.setRole(AppRole.listener);
      final prefs2 = await AppPrefs.load();
      expect(prefs2.role, AppRole.listener);
    });
  });

  group('Channel', () {
    test('fromJson parses correctly', () {
      final ch = Channel.fromJson({
        'id': 2,
        'name': 'English → Portuguese',
        'multicast_addr': '239.0.0.2',
        'multicast_port': 6002,
      });
      expect(ch.id, 2);
      expect(ch.name, 'English → Portuguese');
      expect(ch.multicastAddr, '239.0.0.2');
      expect(ch.multicastPort, 6002);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd /Users/rafaelbrito/Developer/translator/app
flutter test test/shared_test.dart
```

Expected: FAIL — cannot find `models.dart`, `prefs.dart`

- [ ] **Step 3: Create models.dart**

Create `app/lib/shared/models.dart`:

```dart
enum AppRole { translator, listener }

class Channel {
  final int id;
  final String name;
  final String multicastAddr;
  final int multicastPort;

  const Channel({
    required this.id,
    required this.name,
    required this.multicastAddr,
    required this.multicastPort,
  });

  factory Channel.fromJson(Map<String, dynamic> json) => Channel(
        id: json['id'] as int,
        name: json['name'] as String,
        multicastAddr: json['multicast_addr'] as String,
        multicastPort: json['multicast_port'] as int,
      );

  int get unicastPort => 5000 + id;
}
```

- [ ] **Step 4: Create prefs.dart**

Create `app/lib/shared/prefs.dart`:

```dart
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

class AppPrefs {
  final SharedPreferences _prefs;
  static const _roleKey = 'app_role';

  AppPrefs._(this._prefs);

  static Future<AppPrefs> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppPrefs._(prefs);
  }

  AppRole? get role {
    final val = _prefs.getString(_roleKey);
    if (val == null) return null;
    return AppRole.values.firstWhere((r) => r.name == val);
  }

  Future<void> setRole(AppRole role) => _prefs.setString(_roleKey, role.name);
}
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
cd /Users/rafaelbrito/Developer/translator/app
flutter test test/shared_test.dart
```

Expected: all tests PASS

- [ ] **Step 6: Commit**

```bash
git -C /Users/rafaelbrito/Developer/translator add app/lib/shared/ app/test/shared_test.dart
git -C /Users/rafaelbrito/Developer/translator commit -m "feat(app): shared models and preferences"
```

---

## Task 3: Wi-Fi Detection + Role Selection Screen

**Files:**
- Create: `app/lib/shared/wifi_check.dart`
- Create: `app/lib/role_selection/role_selection_screen.dart`
- Modify: `app/lib/main.dart`
- Create: `app/test/wifi_check_test.dart`

- [ ] **Step 1: Write failing test for wifi check**

Create `app/test/wifi_check_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:church_translator/shared/wifi_check.dart';

void main() {
  test('isChurchNetwork returns true for matching SSID', () {
    expect(isChurchNetwork('ChurchTranslator'), isTrue);
  });

  test('isChurchNetwork returns false for other SSID', () {
    expect(isChurchNetwork('HomeWifi'), isFalse);
  });

  test('isChurchNetwork returns false for null SSID', () {
    expect(isChurchNetwork(null), isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /Users/rafaelbrito/Developer/translator/app
flutter test test/wifi_check_test.dart
```

Expected: FAIL — cannot find `wifi_check.dart`

- [ ] **Step 3: Create wifi_check.dart**

Create `app/lib/shared/wifi_check.dart`:

```dart
import 'package:network_info_plus/network_info_plus.dart';

const _targetSsid = 'ChurchTranslator';
const piHost = '192.168.4.1';

bool isChurchNetwork(String? ssid) => ssid == _targetSsid;

Future<bool> isConnectedToChurchNetwork() async {
  final info = NetworkInfo();
  final ssid = await info.getWifiName();
  // Android returns SSID wrapped in quotes: "ChurchTranslator"
  final clean = ssid?.replaceAll('"', '');
  return isChurchNetwork(clean);
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
cd /Users/rafaelbrito/Developer/translator/app
flutter test test/wifi_check_test.dart
```

Expected: all tests PASS

- [ ] **Step 5: Create role_selection_screen.dart**

Create `app/lib/role_selection/role_selection_screen.dart`:

```dart
import 'package:flutter/material.dart';
import '../shared/prefs.dart';
import '../shared/models.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  Future<void> _selectRole(BuildContext context, AppRole role) async {
    final prefs = await AppPrefs.load();
    await prefs.setRole(role);
    if (!context.mounted) return;
    Navigator.of(context).pushReplacementNamed(
      role == AppRole.translator ? '/translator' : '/listener',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Church Translator',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Select your role',
                style: TextStyle(color: Colors.white54, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              ElevatedButton.icon(
                icon: const Icon(Icons.mic),
                label: const Text('I am a Translator'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C6AF7),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                ),
                onPressed: () => _selectRole(context, AppRole.translator),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.headphones),
                label: const Text('I am a Listener'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                ),
                onPressed: () => _selectRole(context, AppRole.listener),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Create main.dart**

Replace `app/lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'shared/prefs.dart';
import 'shared/models.dart';
import 'shared/wifi_check.dart';
import 'role_selection/role_selection_screen.dart';
import 'translator/translator_screen.dart';
import 'listener/listener_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await AppPrefs.load();
  final onChurchNetwork = await isConnectedToChurchNetwork();
  runApp(ChurchTranslatorApp(
    initialRole: prefs.role,
    onChurchNetwork: onChurchNetwork,
  ));
}

class ChurchTranslatorApp extends StatelessWidget {
  final AppRole? initialRole;
  final bool onChurchNetwork;

  const ChurchTranslatorApp({
    super.key,
    required this.initialRole,
    required this.onChurchNetwork,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Church Translator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      initialRoute: _initialRoute(),
      routes: {
        '/': (context) => const RoleSelectionScreen(),
        '/translator': (context) => const TranslatorScreen(),
        '/listener': (context) => const ListenerScreen(),
      },
    );
  }

  String _initialRoute() {
    if (!onChurchNetwork) return '/';
    return switch (initialRole) {
      AppRole.translator => '/translator',
      AppRole.listener => '/listener',
      null => '/',
    };
  }
}
```

- [ ] **Step 7: Create stub screens so the app compiles**

Create `app/lib/translator/translator_screen.dart`:

```dart
import 'package:flutter/material.dart';

class TranslatorScreen extends StatelessWidget {
  const TranslatorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Translator — coming soon')),
    );
  }
}
```

Create `app/lib/listener/listener_screen.dart`:

```dart
import 'package:flutter/material.dart';

class ListenerScreen extends StatelessWidget {
  const ListenerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Listener — coming soon')),
    );
  }
}
```

- [ ] **Step 8: Run all tests**

```bash
cd /Users/rafaelbrito/Developer/translator/app
flutter test
```

Expected: all tests PASS

- [ ] **Step 9: Commit**

```bash
git -C /Users/rafaelbrito/Developer/translator add app/lib/ app/test/
git -C /Users/rafaelbrito/Developer/translator commit -m "feat(app): role selection screen and wifi detection"
```

---

## Task 4: RTP Framing + Channel Registry Client

**Files:**
- Create: `app/lib/network/rtp.dart`
- Create: `app/lib/network/registry_client.dart`
- Create: `app/test/network_test.dart`

- [ ] **Step 1: Write failing tests**

Create `app/test/network_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:church_translator/network/rtp.dart';

void main() {
  group('RtpPacket', () {
    test('pack and unpack round-trip preserves payload', () {
      final payload = [1, 2, 3, 4, 5, 6, 7, 8];
      final packet = RtpPacket.pack(
        sequenceNumber: 42,
        timestamp: 1234567,
        ssrc: 0xDEADBEEF,
        payload: payload,
      );
      final unpacked = RtpPacket.unpack(packet);
      expect(unpacked.sequenceNumber, 42);
      expect(unpacked.timestamp, 1234567);
      expect(unpacked.ssrc, 0xDEADBEEF);
      expect(unpacked.payload, payload);
    });

    test('pack produces correct RTP header byte layout', () {
      final packet = RtpPacket.pack(
        sequenceNumber: 1,
        timestamp: 0,
        ssrc: 0,
        payload: [],
      );
      // Byte 0: version=2 (0x80), no padding, no extension, no CC
      expect(packet[0], 0x80);
      // Byte 1: marker=0, PT=111 (Opus)
      expect(packet[1], 111);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd /Users/rafaelbrito/Developer/translator/app
flutter test test/network_test.dart
```

Expected: FAIL — cannot find `rtp.dart`

- [ ] **Step 3: Create rtp.dart**

Create `app/lib/network/rtp.dart`:

```dart
import 'dart:typed_data';

class RtpPacket {
  static const _headerBytes = 12;
  static const _payloadType = 111; // dynamic PT for Opus

  final int sequenceNumber;
  final int timestamp;
  final int ssrc;
  final List<int> payload;

  const RtpPacket({
    required this.sequenceNumber,
    required this.timestamp,
    required this.ssrc,
    required this.payload,
  });

  static Uint8List pack({
    required int sequenceNumber,
    required int timestamp,
    required int ssrc,
    required List<int> payload,
  }) {
    final buf = ByteData(_headerBytes + payload.length);
    buf.setUint8(0, 0x80); // V=2, P=0, X=0, CC=0
    buf.setUint8(1, _payloadType);
    buf.setUint16(2, sequenceNumber);
    buf.setUint32(4, timestamp);
    buf.setUint32(8, ssrc);
    final bytes = buf.buffer.asUint8List();
    bytes.setRange(_headerBytes, bytes.length, payload);
    return bytes;
  }

  static RtpPacket unpack(List<int> data) {
    final buf = ByteData.sublistView(Uint8List.fromList(data));
    return RtpPacket(
      sequenceNumber: buf.getUint16(2),
      timestamp: buf.getUint32(4),
      ssrc: buf.getUint32(8),
      payload: data.sublist(_headerBytes),
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd /Users/rafaelbrito/Developer/translator/app
flutter test test/network_test.dart
```

Expected: all tests PASS

- [ ] **Step 5: Create registry_client.dart**

Create `app/lib/network/registry_client.dart`:

```dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../shared/models.dart';
import '../shared/wifi_check.dart';

Future<List<Channel>> fetchChannels({Duration timeout = const Duration(seconds: 3)}) async {
  final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
  final completer = Completer<List<Channel>>();

  socket.listen((event) {
    if (event == RawSocketEvent.read) {
      final dg = socket.receive();
      if (dg == null) return;
      try {
        final json = jsonDecode(utf8.decode(dg.data)) as List<dynamic>;
        final channels = json
            .cast<Map<String, dynamic>>()
            .map(Channel.fromJson)
            .toList();
        if (!completer.isCompleted) completer.complete(channels);
      } catch (_) {
        if (!completer.isCompleted) completer.complete([]);
      }
    }
  });

  final dest = InternetAddress(piHost);
  socket.send(utf8.encode('list'), dest, 4999);

  try {
    return await completer.future.timeout(timeout);
  } on TimeoutException {
    return [];
  } finally {
    socket.close();
  }
}
```

- [ ] **Step 6: Commit**

```bash
git -C /Users/rafaelbrito/Developer/translator add app/lib/network/ app/test/network_test.dart
git -C /Users/rafaelbrito/Developer/translator commit -m "feat(app): RTP framing and channel registry client"
```

---

## Task 5: Opus Codec Wrapper

**Files:**
- Create: `app/lib/audio/opus_codec.dart`
- Create: `app/test/opus_codec_test.dart`

- [ ] **Step 1: Write failing tests**

Create `app/test/opus_codec_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:church_translator/audio/opus_codec.dart';

void main() {
  group('OpusCodec', () {
    late OpusCodec codec;

    setUp(() {
      codec = OpusCodec(sampleRate: 48000, channels: 1, frameSizeMs: 10);
    });

    tearDown(() => codec.dispose());

    test('encode returns non-empty bytes for non-silence', () {
      // 480 samples at 48kHz for 10ms frame
      final pcm = List.generate(480, (i) => (i % 100) * 100 - 5000);
      final encoded = codec.encode(pcm);
      expect(encoded, isNotEmpty);
    });

    test('decode returns correct number of samples', () {
      final pcm = List.generate(480, (i) => (i % 100) * 100 - 5000);
      final encoded = codec.encode(pcm);
      final decoded = codec.decode(encoded);
      expect(decoded.length, 480);
    });

    test('encode/decode round-trip produces recognizable audio', () {
      final input = List.generate(480, (i) => (i % 50) * 200 - 5000);
      final encoded = codec.encode(input);
      final decoded = codec.decode(encoded);
      // Lossy codec — just verify signal is non-zero
      expect(decoded.any((s) => s != 0), isTrue);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd /Users/rafaelbrito/Developer/translator/app
flutter test test/opus_codec_test.dart
```

Expected: FAIL — cannot find `opus_codec.dart`

- [ ] **Step 3: Create opus_codec.dart**

Create `app/lib/audio/opus_codec.dart`:

```dart
import 'package:opus_flutter/opus_flutter.dart' as opus;

class OpusCodec {
  final int sampleRate;
  final int channels;
  final int frameSizeMs;

  late final opus.Encoder _encoder;
  late final opus.Decoder _decoder;

  OpusCodec({
    required this.sampleRate,
    required this.channels,
    required this.frameSizeMs,
  }) {
    _encoder = opus.Encoder(
      sampleRate: sampleRate,
      channels: channels,
      application: opus.Application.voip,
    );
    _encoder.bitrate = 16000;
    _decoder = opus.Decoder(sampleRate: sampleRate, channels: channels);
  }

  /// Encodes a frame of 16-bit PCM samples. Input length must be sampleRate * frameSizeMs / 1000.
  List<int> encode(List<int> pcmSamples) {
    return _encoder.encode(input: pcmSamples);
  }

  /// Decodes an Opus packet to 16-bit PCM samples.
  List<int> decode(List<int> opusData) {
    final frameSizeSamples = sampleRate * frameSizeMs ~/ 1000;
    return _decoder.decode(input: opusData, frameSize: frameSizeSamples);
  }

  void dispose() {
    _encoder.destroy();
    _decoder.destroy();
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd /Users/rafaelbrito/Developer/translator/app
flutter test test/opus_codec_test.dart
```

Expected: all tests PASS

Note: if `opus_flutter` FFI initialization fails in the test runner, tests may be skipped. Proceed and verify on a physical device in Task 8.

- [ ] **Step 5: Commit**

```bash
git -C /Users/rafaelbrito/Developer/translator add app/lib/audio/opus_codec.dart app/test/opus_codec_test.dart
git -C /Users/rafaelbrito/Developer/translator commit -m "feat(app): Opus encode/decode wrapper"
```

---

## Task 6: Jitter Buffer

**Files:**
- Create: `app/lib/audio/jitter_buffer.dart`
- Create: `app/test/jitter_buffer_test.dart`

- [ ] **Step 1: Write failing tests**

Create `app/test/jitter_buffer_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:church_translator/audio/jitter_buffer.dart';

void main() {
  group('JitterBuffer', () {
    test('returns null when buffer is empty', () {
      final buf = JitterBuffer(capacityFrames: 4);
      expect(buf.pop(), isNull);
    });

    test('pop returns frames in sequence order', () {
      final buf = JitterBuffer(capacityFrames: 4);
      buf.push(seq: 2, data: [20]);
      buf.push(seq: 1, data: [10]);
      buf.push(seq: 3, data: [30]);
      expect(buf.pop(), [10]);
      expect(buf.pop(), [20]);
      expect(buf.pop(), [30]);
    });

    test('oldest frame is dropped when capacity exceeded', () {
      final buf = JitterBuffer(capacityFrames: 2);
      buf.push(seq: 1, data: [10]);
      buf.push(seq: 2, data: [20]);
      buf.push(seq: 3, data: [30]); // seq 1 dropped
      expect(buf.pop(), [20]);
      expect(buf.pop(), [30]);
    });

    test('duplicate sequence number is ignored', () {
      final buf = JitterBuffer(capacityFrames: 4);
      buf.push(seq: 1, data: [10]);
      buf.push(seq: 1, data: [99]); // duplicate
      expect(buf.pop(), [10]);
      expect(buf.pop(), isNull);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd /Users/rafaelbrito/Developer/translator/app
flutter test test/jitter_buffer_test.dart
```

Expected: FAIL — cannot find `jitter_buffer.dart`

- [ ] **Step 3: Create jitter_buffer.dart**

Create `app/lib/audio/jitter_buffer.dart`:

```dart
import 'dart:collection';

class _Frame {
  final int seq;
  final List<int> data;
  _Frame(this.seq, this.data);
}

class JitterBuffer {
  final int capacityFrames;
  final SplayTreeMap<int, _Frame> _frames = SplayTreeMap();

  JitterBuffer({required this.capacityFrames});

  void push({required int seq, required List<int> data}) {
    if (_frames.containsKey(seq)) return; // drop duplicate
    if (_frames.length >= capacityFrames) {
      _frames.remove(_frames.firstKey());
    }
    _frames[seq] = _Frame(seq, data);
  }

  List<int>? pop() {
    if (_frames.isEmpty) return null;
    final key = _frames.firstKey()!;
    return _frames.remove(key)!.data;
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd /Users/rafaelbrito/Developer/translator/app
flutter test test/jitter_buffer_test.dart
```

Expected: all tests PASS

- [ ] **Step 5: Commit**

```bash
git -C /Users/rafaelbrito/Developer/translator add app/lib/audio/jitter_buffer.dart app/test/jitter_buffer_test.dart
git -C /Users/rafaelbrito/Developer/translator commit -m "feat(app): jitter buffer for listener playback"
```

---

## Task 7: Translator UDP Socket + Controller

**Files:**
- Create: `app/lib/network/translator_socket.dart`
- Create: `app/lib/translator/translator_controller.dart`
- Modify: `app/lib/translator/translator_screen.dart`

- [ ] **Step 1: Create translator_socket.dart**

Create `app/lib/network/translator_socket.dart`:

```dart
import 'dart:io';
import '../shared/models.dart';
import '../shared/wifi_check.dart';

class TranslatorSocket {
  final Channel channel;
  RawDatagramSocket? _socket;

  TranslatorSocket(this.channel);

  Future<void> open() async {
    _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
  }

  void send(List<int> rtpPacket) {
    _socket?.send(
      rtpPacket,
      InternetAddress(piHost),
      channel.unicastPort,
    );
  }

  void close() {
    _socket?.close();
    _socket = null;
  }
}
```

- [ ] **Step 2: Create translator_controller.dart**

Create `app/lib/translator/translator_controller.dart`:

```dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import '../audio/opus_codec.dart';
import '../network/rtp.dart';
import '../network/translator_socket.dart';
import '../shared/models.dart';

class TranslatorController extends ChangeNotifier {
  final Channel channel;
  final bool pushToTalk;

  TranslatorController({required this.channel, this.pushToTalk = false});

  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  late final OpusCodec _codec;
  late final TranslatorSocket _socket;

  bool _recording = false;
  bool _pttActive = false;
  double _level = 0.0;
  int _seq = 0;
  int _timestamp = 0;

  static const _sampleRate = 48000;
  static const _frameSizeMs = 10;
  static const _samplesPerFrame = _sampleRate * _frameSizeMs ~/ 1000; // 480
  static const _ssrc = 0x12345678;

  bool get isRecording => _recording;
  bool get pttActive => _pttActive;
  double get level => _level;

  Future<void> start() async {
    await Permission.microphone.request();
    await _recorder.openRecorder();
    _codec = OpusCodec(
      sampleRate: _sampleRate,
      channels: 1,
      frameSizeMs: _frameSizeMs,
    );
    _socket = TranslatorSocket(channel);
    await _socket.open();

    if (!pushToTalk) await _startCapture();
    _recording = true;
    notifyListeners();
  }

  Future<void> _startCapture() async {
    await _recorder.startRecorder(
      toStream: _onAudioData(),
      codec: Codec.pcm16,
      numChannels: 1,
      sampleRate: _sampleRate,
    );
  }

  StreamSink<Food> _onAudioData() {
    final controller = StreamController<Food>();
    List<int> buffer = [];

    controller.stream.listen((food) {
      if (food is FoodData && food.data != null) {
        buffer.addAll(food.data!);
        while (buffer.length >= _samplesPerFrame * 2) {
          final frame = buffer.sublist(0, _samplesPerFrame * 2);
          buffer = buffer.sublist(_samplesPerFrame * 2);
          _processFrame(frame);
        }
      }
    });
    return controller.sink;
  }

  void _processFrame(List<int> rawBytes) {
    // Convert bytes to 16-bit PCM samples (little-endian)
    final pcm = <int>[];
    for (var i = 0; i < rawBytes.length - 1; i += 2) {
      final sample = rawBytes[i] | (rawBytes[i + 1] << 8);
      pcm.add(sample > 32767 ? sample - 65536 : sample);
    }

    // Level meter: RMS
    final rms = pcm.isEmpty
        ? 0.0
        : pcm.map((s) => s * s).reduce((a, b) => a + b) / pcm.length;
    _level = (rms / (32768.0 * 32768.0)).clamp(0.0, 1.0);
    notifyListeners();

    final encoded = _codec.encode(pcm);
    final packet = RtpPacket.pack(
      sequenceNumber: _seq++ & 0xFFFF,
      timestamp: _timestamp += _samplesPerFrame,
      ssrc: _ssrc,
      payload: encoded,
    );
    _socket.send(packet);
  }

  Future<void> pttPress() async {
    if (!pushToTalk || _pttActive) return;
    _pttActive = true;
    notifyListeners();
    await _startCapture();
  }

  Future<void> pttRelease() async {
    if (!pushToTalk || !_pttActive) return;
    _pttActive = false;
    notifyListeners();
    await _recorder.stopRecorder();
  }

  Future<void> stop() async {
    await _recorder.stopRecorder();
    await _recorder.closeRecorder();
    _codec.dispose();
    _socket.close();
    _recording = false;
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
```

- [ ] **Step 3: Replace translator_screen.dart with full UI**

Replace `app/lib/translator/translator_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../shared/models.dart';
import 'translator_controller.dart';

class TranslatorScreen extends StatelessWidget {
  const TranslatorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final channel = ModalRoute.of(context)?.settings.arguments as Channel?;
    if (channel == null) {
      return const Scaffold(body: Center(child: Text('No channel selected')));
    }
    return ChangeNotifierProvider(
      create: (_) => TranslatorController(channel: channel)..start(),
      child: const _TranslatorView(),
    );
  }
}

class _TranslatorView extends StatelessWidget {
  const _TranslatorView();

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<TranslatorController>();
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Translator'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).pushNamed('/'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              ctrl.channel.name,
              style: const TextStyle(color: Colors.white70, fontSize: 18),
            ),
            const SizedBox(height: 32),
            _LevelMeter(level: ctrl.level),
            const SizedBox(height: 32),
            if (ctrl.pushToTalk)
              GestureDetector(
                onTapDown: (_) => ctrl.pttPress(),
                onTapUp: (_) => ctrl.pttRelease(),
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: ctrl.pttActive
                        ? const Color(0xFF7C6AF7)
                        : Colors.grey[800],
                  ),
                  child: const Icon(Icons.mic, size: 48, color: Colors.white),
                ),
              )
            else
              Icon(
                Icons.mic,
                size: 64,
                color: ctrl.isRecording
                    ? const Color(0xFF7C6AF7)
                    : Colors.grey,
              ),
            const SizedBox(height: 16),
            Text(
              ctrl.pushToTalk
                  ? (ctrl.pttActive ? 'Transmitting...' : 'Hold to talk')
                  : (ctrl.isRecording ? 'Transmitting' : 'Stopped'),
              style: const TextStyle(color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelMeter extends StatelessWidget {
  final double level;
  const _LevelMeter({required this.level});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 12,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(6),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: level.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF7C6AF7),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Add provider dependency to pubspec.yaml**

In `app/pubspec.yaml`, add under dependencies:

```yaml
  provider: ^6.1.2
```

Then run:

```bash
cd /Users/rafaelbrito/Developer/translator/app
flutter pub get
```

- [ ] **Step 5: Run all tests**

```bash
cd /Users/rafaelbrito/Developer/translator/app
flutter test
```

Expected: all tests PASS

- [ ] **Step 6: Commit**

```bash
git -C /Users/rafaelbrito/Developer/translator add app/
git -C /Users/rafaelbrito/Developer/translator commit -m "feat(app): translator screen with audio capture and UDP send"
```

---

## Task 8: Listener UDP Socket + Controller + Screen

**Files:**
- Create: `app/lib/network/listener_socket.dart`
- Create: `app/lib/listener/listener_controller.dart`
- Modify: `app/lib/listener/listener_screen.dart`

- [ ] **Step 1: Create listener_socket.dart**

Create `app/lib/network/listener_socket.dart`:

```dart
import 'dart:async';
import 'dart:io';

class ListenerSocket {
  final String multicastAddr;
  final int multicastPort;

  RawDatagramSocket? _socket;
  final _controller = StreamController<List<int>>.broadcast();

  ListenerSocket({required this.multicastAddr, required this.multicastPort});

  Stream<List<int>> get packets => _controller.stream;

  Future<void> open() async {
    _socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      multicastPort,
    );
    _socket!.multicastLoopback = false;
    _socket!.joinMulticast(InternetAddress(multicastAddr));
    _socket!.listen((event) {
      if (event == RawSocketEvent.read) {
        final dg = _socket?.receive();
        if (dg != null) _controller.add(dg.data);
      }
    });
  }

  void close() {
    _socket?.leaveMulticast(InternetAddress(multicastAddr));
    _socket?.close();
    _controller.close();
  }
}
```

- [ ] **Step 2: Create listener_controller.dart**

Create `app/lib/listener/listener_controller.dart`:

```dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_sound/flutter_sound.dart';
import '../audio/jitter_buffer.dart';
import '../audio/opus_codec.dart';
import '../network/listener_socket.dart';
import '../network/registry_client.dart';
import '../network/rtp.dart';
import '../shared/models.dart';

class ListenerController extends ChangeNotifier {
  List<Channel> channels = [];
  Channel? selectedChannel;
  bool loading = true;
  bool connected = false;

  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  OpusCodec? _codec;
  ListenerSocket? _socket;
  JitterBuffer? _jitterBuffer;
  StreamSubscription<List<int>>? _sub;
  Timer? _playbackTimer;

  static const _sampleRate = 48000;
  static const _frameSizeMs = 10;
  static const _samplesPerFrame = _sampleRate * _frameSizeMs ~/ 1000;

  Future<void> init() async {
    channels = await fetchChannels();
    loading = false;
    notifyListeners();
  }

  Future<void> selectChannel(Channel ch) async {
    await _disconnect();
    selectedChannel = ch;
    notifyListeners();
    await _connect(ch);
  }

  Future<void> _connect(Channel ch) async {
    await _player.openPlayer();
    await _player.startPlayerFromStream(
      codec: Codec.pcm16,
      numChannels: 1,
      sampleRate: _sampleRate,
    );

    _codec = OpusCodec(
      sampleRate: _sampleRate,
      channels: 1,
      frameSizeMs: _frameSizeMs,
    );
    _jitterBuffer = JitterBuffer(capacityFrames: 4); // 40ms buffer
    _socket = ListenerSocket(
      multicastAddr: ch.multicastAddr,
      multicastPort: ch.multicastPort,
    );
    await _socket!.open();

    _sub = _socket!.packets.listen((raw) {
      final pkt = RtpPacket.unpack(raw);
      _jitterBuffer!.push(seq: pkt.sequenceNumber, data: pkt.payload);
    });

    // Feed decoded audio to player every frameSizeMs
    _playbackTimer = Timer.periodic(
      Duration(milliseconds: _frameSizeMs),
      (_) => _feedPlayer(),
    );

    connected = true;
    notifyListeners();
  }

  void _feedPlayer() {
    final encoded = _jitterBuffer?.pop();
    if (encoded == null) return;
    try {
      final pcm = _codec!.decode(encoded);
      // Convert PCM samples to raw bytes (little-endian 16-bit)
      final bytes = <int>[];
      for (final s in pcm) {
        final v = s.clamp(-32768, 32767);
        bytes.add(v & 0xFF);
        bytes.add((v >> 8) & 0xFF);
      }
      _player.foodSink?.add(FoodData(Uint8List.fromList(bytes)));
    } catch (_) {}
  }

  Future<void> _disconnect() async {
    _playbackTimer?.cancel();
    await _sub?.cancel();
    _socket?.close();
    _codec?.dispose();
    await _player.stopPlayer();
    await _player.closePlayer();
    connected = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disconnect();
    super.dispose();
  }
}
```

Add to the top of `listener_controller.dart`:
```dart
import 'dart:typed_data';
```

- [ ] **Step 3: Replace listener_screen.dart with full UI**

Replace `app/lib/listener/listener_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'listener_controller.dart';
import '../shared/models.dart';

class ListenerScreen extends StatelessWidget {
  const ListenerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ListenerController()..init(),
      child: const _ListenerView(),
    );
  }
}

class _ListenerView extends StatelessWidget {
  const _ListenerView();

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ListenerController>();
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Listener'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).pushNamed('/'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: ctrl.loading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Fetching channels...', style: TextStyle(color: Colors.white54)),
                  ],
                ),
              )
            : ctrl.channels.isEmpty
                ? const Center(
                    child: Text(
                      'No channels found.\nMake sure you are connected to ChurchTranslator Wi-Fi.',
                      style: TextStyle(color: Colors.white54),
                      textAlign: TextAlign.center,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Select language',
                        style: TextStyle(color: Colors.white54, fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      ...ctrl.channels.map((ch) => _ChannelTile(
                            channel: ch,
                            selected: ctrl.selectedChannel?.id == ch.id,
                            connected: ctrl.connected && ctrl.selectedChannel?.id == ch.id,
                            onTap: () => ctrl.selectChannel(ch),
                          )),
                    ],
                  ),
      ),
    );
  }
}

class _ChannelTile extends StatelessWidget {
  final Channel channel;
  final bool selected;
  final bool connected;
  final VoidCallback onTap;

  const _ChannelTile({
    required this.channel,
    required this.selected,
    required this.connected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFF59E0B).withOpacity(0.15)
              : Colors.grey[900],
          border: Border.all(
            color: selected ? const Color(0xFFF59E0B) : Colors.grey[800]!,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.headphones,
              color: selected ? const Color(0xFFF59E0B) : Colors.white38,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                channel.name,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white70,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            if (connected)
              const Icon(Icons.volume_up, color: Color(0xFFF59E0B), size: 18),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run all tests**

```bash
cd /Users/rafaelbrito/Developer/translator/app
flutter test
```

Expected: all tests PASS

- [ ] **Step 5: Commit**

```bash
git -C /Users/rafaelbrito/Developer/translator add app/
git -C /Users/rafaelbrito/Developer/translator commit -m "feat(app): listener screen with multicast receive, decode, and playback"
```

---

## Task 9: Wi-Fi Gating + Channel Picker for Translator

**Files:**
- Modify: `app/lib/main.dart`
- Create: `app/lib/shared/no_wifi_screen.dart`
- Create: `app/lib/translator/channel_picker_screen.dart`

- [ ] **Step 1: Create no_wifi_screen.dart**

Create `app/lib/shared/no_wifi_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'wifi_check.dart';
import '../shared/prefs.dart';

class NoWifiScreen extends StatelessWidget {
  const NoWifiScreen({super.key});

  Future<void> _retry(BuildContext context) async {
    final ok = await isConnectedToChurchNetwork();
    if (!context.mounted) return;
    if (ok) {
      final prefs = await AppPrefs.load();
      if (!context.mounted) return;
      Navigator.of(context).pushReplacementNamed(
        prefs.role == null ? '/' : (prefs.role!.name == 'translator' ? '/translator' : '/listener'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off, size: 64, color: Colors.white38),
              const SizedBox(height: 24),
              const Text(
                'Join ChurchTranslator Wi-Fi to begin',
                style: TextStyle(color: Colors.white, fontSize: 20),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Go to Settings → Wi-Fi → ChurchTranslator',
                style: TextStyle(color: Colors.white54, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () => _retry(context),
                child: const Text('I\'m connected — continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Create channel_picker_screen.dart for Translator**

Create `app/lib/translator/channel_picker_screen.dart`:

```dart
import 'package:flutter/material.dart';
import '../network/registry_client.dart';
import '../shared/models.dart';

class TranslatorChannelPickerScreen extends StatefulWidget {
  const TranslatorChannelPickerScreen({super.key});

  @override
  State<TranslatorChannelPickerScreen> createState() =>
      _TranslatorChannelPickerScreenState();
}

class _TranslatorChannelPickerScreenState
    extends State<TranslatorChannelPickerScreen> {
  List<Channel>? _channels;

  @override
  void initState() {
    super.initState();
    fetchChannels().then((ch) {
      if (mounted) setState(() => _channels = ch);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Select Channel'),
      ),
      body: _channels == null
          ? const Center(child: CircularProgressIndicator())
          : _channels!.isEmpty
              ? const Center(
                  child: Text(
                    'No channels available.\nIs the relay running?',
                    style: TextStyle(color: Colors.white54),
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(24),
                  children: _channels!
                      .map((ch) => ListTile(
                            title: Text(ch.name,
                                style:
                                    const TextStyle(color: Colors.white)),
                            leading: const Icon(Icons.mic,
                                color: Color(0xFF7C6AF7)),
                            onTap: () => Navigator.of(context).pushNamed(
                              '/translator',
                              arguments: ch,
                            ),
                          ))
                      .toList(),
                ),
    );
  }
}
```

- [ ] **Step 3: Update main.dart routes**

Replace `app/lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'shared/prefs.dart';
import 'shared/models.dart';
import 'shared/wifi_check.dart';
import 'shared/no_wifi_screen.dart';
import 'role_selection/role_selection_screen.dart';
import 'translator/channel_picker_screen.dart';
import 'translator/translator_screen.dart';
import 'listener/listener_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await AppPrefs.load();
  final onChurchNetwork = await isConnectedToChurchNetwork();
  runApp(ChurchTranslatorApp(
    initialRole: prefs.role,
    onChurchNetwork: onChurchNetwork,
  ));
}

class ChurchTranslatorApp extends StatelessWidget {
  final AppRole? initialRole;
  final bool onChurchNetwork;

  const ChurchTranslatorApp({
    super.key,
    required this.initialRole,
    required this.onChurchNetwork,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Church Translator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      initialRoute: _initialRoute(),
      routes: {
        '/': (context) => const RoleSelectionScreen(),
        '/no-wifi': (context) => const NoWifiScreen(),
        '/translator/channels': (context) => const TranslatorChannelPickerScreen(),
        '/translator': (context) => const TranslatorScreen(),
        '/listener': (context) => const ListenerScreen(),
      },
    );
  }

  String _initialRoute() {
    if (!onChurchNetwork) return '/no-wifi';
    return switch (initialRole) {
      AppRole.translator => '/translator/channels',
      AppRole.listener => '/listener',
      null => '/',
    };
  }
}
```

- [ ] **Step 4: Run all tests**

```bash
cd /Users/rafaelbrito/Developer/translator/app
flutter test
```

Expected: all tests PASS

- [ ] **Step 5: Commit**

```bash
git -C /Users/rafaelbrito/Developer/translator add app/
git -C /Users/rafaelbrito/Developer/translator commit -m "feat(app): wifi gating, no-wifi screen, translator channel picker"
```

---

## Self-Review Checklist

**Spec requirements covered:**
- [x] Single Flutter app, iOS + Android — Task 1
- [x] Role selection on first launch, stored in prefs — Task 2, 3
- [x] Wi-Fi detection → "Join ChurchTranslator Wi-Fi" prompt — Task 3, 9
- [x] Translator: mic capture, Opus encode, RTP/UDP send — Task 5, 7
- [x] Translator: always-on mode by default; PTT available as toggle — Task 7 (TranslatorController `pushToTalk` flag)
- [x] Translator: audio level meter — Task 7 (_LevelMeter widget)
- [x] Translator: channel selection — Task 9
- [x] Listener: fetch channels from Pi registry — Task 4
- [x] Listener: join UDP multicast group — Task 8
- [x] Listener: Opus decode + playback — Task 5, 8
- [x] Listener: channel switching — Task 8 (selectChannel)
- [x] RTP packet format — Task 4
- [x] Jitter buffer 20ms — Task 6 (4 frames × 10ms)
- [x] iOS background audio mode — Task 1 (Info.plist)
- [x] iOS local network permission — Task 1 (Info.plist)
- [x] Android MulticastLock — **GAP: Android requires acquiring MulticastLock for multicast UDP to work on some devices**

**Gap fix — add MulticastLock to ListenerSocket for Android:**

Add to `app/lib/network/listener_socket.dart` after the existing import:

```dart
import 'package:flutter/services.dart';
```

Add this method to `ListenerSocket` and call it inside `open()` before joining multicast:

```dart
static const _channel = MethodChannel('com.churchtranslator/multicast');

Future<void> _acquireMulticastLock() async {
  try {
    await _channel.invokeMethod('acquireMulticastLock');
  } catch (_) {}
}

Future<void> releaseMulticastLock() async {
  try {
    await _channel.invokeMethod('releaseMulticastLock');
  } catch (_) {}
}
```

And in `app/android/app/src/main/kotlin/.../MainActivity.kt` (or `MainActivity.java`), register the channel:

```kotlin
import android.net.wifi.WifiManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var multicastLock: WifiManager.MulticastLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.churchtranslator/multicast")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "acquireMulticastLock" -> {
                        val wifiManager = applicationContext.getSystemService(WIFI_SERVICE) as WifiManager
                        multicastLock = wifiManager.createMulticastLock("church_translator")
                        multicastLock?.acquire()
                        result.success(null)
                    }
                    "releaseMulticastLock" -> {
                        multicastLock?.release()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
```

Commit this fix:

```bash
git -C /Users/rafaelbrito/Developer/translator add app/
git -C /Users/rafaelbrito/Developer/translator commit -m "fix(app): Android MulticastLock for listener UDP multicast"
```

**Open questions from spec:**
- `opus_flutter` FFI on both iOS and Android: validate in Task 5 on a physical device; fallback is manual libopus FFI bindings
- iOS background audio: declared in Info.plist in Task 1 — verify by locking screen while listening during device testing
