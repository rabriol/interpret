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
      expect(packet[0], 0x80);
      expect(packet[1], 111);
    });
  });
}
