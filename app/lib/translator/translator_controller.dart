import 'dart:async';
import 'dart:typed_data';
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
  static const _samplesPerFrame = _sampleRate * _frameSizeMs ~/ 1000;
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
    final streamSink = _onAudioData();
    await _recorder.startRecorder(
      toStream: streamSink,
      codec: Codec.pcm16,
      numChannels: 1,
      sampleRate: _sampleRate,
    );
  }

  StreamSink<Uint8List> _onAudioData() {
    final controller = StreamController<Uint8List>();
    List<int> buffer = [];

    controller.stream.listen((data) {
      buffer.addAll(data);
      while (buffer.length >= _samplesPerFrame * 2) {
        final frame = buffer.sublist(0, _samplesPerFrame * 2);
        buffer = buffer.sublist(_samplesPerFrame * 2);
        _processFrame(frame);
      }
    });
    return controller.sink;
  }

  void _processFrame(List<int> rawBytes) {
    final pcm = <int>[];
    for (var i = 0; i < rawBytes.length - 1; i += 2) {
      final sample = rawBytes[i] | (rawBytes[i + 1] << 8);
      pcm.add(sample > 32767 ? sample - 65536 : sample);
    }

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
