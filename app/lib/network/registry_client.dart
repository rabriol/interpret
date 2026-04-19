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
