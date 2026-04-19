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
      buf.push(seq: 3, data: [30]);
      expect(buf.pop(), [20]);
      expect(buf.pop(), [30]);
    });

    test('duplicate sequence number is ignored', () {
      final buf = JitterBuffer(capacityFrames: 4);
      buf.push(seq: 1, data: [10]);
      buf.push(seq: 1, data: [99]);
      expect(buf.pop(), [10]);
      expect(buf.pop(), isNull);
    });
  });
}
