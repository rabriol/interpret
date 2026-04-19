import 'package:flutter_test/flutter_test.dart';
import 'package:church_translator/shared/wifi_check.dart';

void main() {
  test('isChurchNetwork returns true for matching SSID', () {
    expect(isChurchNetwork('ChurchTranslator'), isTrue);
  });

  test('isChurchNetwork returns false for other SSID', () {
    expect(isChurchNetwork('HomeWifi'), isFalse);
  });

  test('isChurchNetwork returns false for null SSID', () {
    expect(isChurchNetwork(null), isFalse);
  });
}
