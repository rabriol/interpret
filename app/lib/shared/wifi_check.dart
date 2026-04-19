import 'package:network_info_plus/network_info_plus.dart';

const _targetSsid = 'ChurchTranslator';
const piHost = '192.168.4.1';

bool isChurchNetwork(String? ssid) => ssid == _targetSsid;

Future<bool> isConnectedToChurchNetwork() async {
  final info = NetworkInfo();
  final ssid = await info.getWifiName();
  // Android returns SSID wrapped in quotes: "ChurchTranslator"
  final clean = ssid?.replaceAll('"', '');
  return isChurchNetwork(clean);
}
