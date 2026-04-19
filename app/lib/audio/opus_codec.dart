import 'dart:typed_data';
import 'package:opus_dart/opus_dart.dart';

class OpusCodec {
  final int sampleRate;
  final int channels;
  final int frameSizeMs;

  late final SimpleOpusEncoder _encoder;
  late final SimpleOpusDecoder _decoder;

  OpusCodec({
    required this.sampleRate,
    required this.channels,
    required this.frameSizeMs,
  }) {
    _encoder = SimpleOpusEncoder(
      sampleRate: sampleRate,
      channels: channels,
      application: Application.voip,
    );
    _decoder = SimpleOpusDecoder(sampleRate: sampleRate, channels: channels);
  }

  /// Encodes a frame of 16-bit PCM samples. Input length must be sampleRate * frameSizeMs / 1000.
  Uint8List encode(List<int> pcmSamples) {
    return _encoder.encode(input: Int16List.fromList(pcmSamples));
  }

  /// Decodes an Opus packet to 16-bit PCM samples.
  Int16List decode(List<int> opusData) {
    return _decoder.decode(input: Uint8List.fromList(opusData));
  }

  void dispose() {
    _encoder.destroy();
    _decoder.destroy();
  }
}
