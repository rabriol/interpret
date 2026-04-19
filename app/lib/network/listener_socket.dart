import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';

class ListenerSocket {
  final String multicastAddr;
  final int multicastPort;

  static const _channel = MethodChannel('com.churchtranslator/multicast');

  RawDatagramSocket? _socket;
  final _controller = StreamController<List<int>>.broadcast();

  ListenerSocket({required this.multicastAddr, required this.multicastPort});

  Stream<List<int>> get packets => _controller.stream;

  Future<void> open() async {
    await _acquireMulticastLock();
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

  void close() {
    _socket?.leaveMulticast(InternetAddress(multicastAddr));
    _socket?.close();
    releaseMulticastLock();
    _controller.close();
  }
}
