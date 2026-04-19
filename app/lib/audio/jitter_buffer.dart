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
