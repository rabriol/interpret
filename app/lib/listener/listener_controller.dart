import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';
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
      bufferSize: 4096,
    );

    _codec = OpusCodec(
      sampleRate: _sampleRate,
      channels: 1,
      frameSizeMs: _frameSizeMs,
    );
    _jitterBuffer = JitterBuffer(capacityFrames: 4);
    _socket = ListenerSocket(
      multicastAddr: ch.multicastAddr,
      multicastPort: ch.multicastPort,
    );
    await _socket!.open();

    _sub = _socket!.packets.listen((raw) {
      final pkt = RtpPacket.unpack(raw);
      _jitterBuffer!.push(seq: pkt.sequenceNumber, data: pkt.payload);
    });

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
      final bytes = <int>[];
      for (final s in pcm) {
        final v = s.clamp(-32768, 32767);
        bytes.add(v & 0xFF);
        bytes.add((v >> 8) & 0xFF);
      }
      _player.uint8ListSink?.add(Uint8List.fromList(bytes));
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
