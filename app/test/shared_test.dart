import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:church_translator/shared/models.dart';
import 'package:church_translator/shared/prefs.dart';

void main() {
  group('AppPrefs', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('role defaults to null on first launch', () async {
      final prefs = await AppPrefs.load();
      expect(prefs.role, isNull);
    });

    test('saves and reads Translator role', () async {
      final prefs = await AppPrefs.load();
      await prefs.setRole(AppRole.translator);
      final prefs2 = await AppPrefs.load();
      expect(prefs2.role, AppRole.translator);
    });

    test('saves and reads Listener role', () async {
      final prefs = await AppPrefs.load();
      await prefs.setRole(AppRole.listener);
      final prefs2 = await AppPrefs.load();
      expect(prefs2.role, AppRole.listener);
    });
  });

  group('Channel', () {
    test('fromJson parses correctly', () {
      final ch = Channel.fromJson({
        'id': 2,
        'name': 'English → Portuguese',
        'multicast_addr': '239.0.0.2',
        'multicast_port': 6002,
      });
      expect(ch.id, 2);
      expect(ch.name, 'English → Portuguese');
      expect(ch.multicastAddr, '239.0.0.2');
      expect(ch.multicastPort, 6002);
    });
  });
}
