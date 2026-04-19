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
