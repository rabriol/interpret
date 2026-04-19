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
