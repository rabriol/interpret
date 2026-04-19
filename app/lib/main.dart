import 'package:flutter/material.dart';
import 'shared/prefs.dart';
import 'shared/models.dart';
import 'shared/wifi_check.dart';
import 'shared/no_wifi_screen.dart';
import 'role_selection/role_selection_screen.dart';
import 'translator/channel_picker_screen.dart';
import 'translator/translator_screen.dart';
import 'listener/listener_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await AppPrefs.load();
  final onChurchNetwork = await isConnectedToChurchNetwork();
  runApp(ChurchTranslatorApp(
    initialRole: prefs.role,
    onChurchNetwork: onChurchNetwork,
  ));
}

class ChurchTranslatorApp extends StatelessWidget {
  final AppRole? initialRole;
  final bool onChurchNetwork;

  const ChurchTranslatorApp({
    super.key,
    required this.initialRole,
    required this.onChurchNetwork,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Interpret',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      initialRoute: _initialRoute(),
      routes: {
        '/': (context) => const RoleSelectionScreen(),
        '/no-wifi': (context) => const NoWifiScreen(),
        '/translator/channels': (context) =>
            const TranslatorChannelPickerScreen(),
        '/translator': (context) => const TranslatorScreen(),
        '/listener': (context) => const ListenerScreen(),
      },
    );
  }

  String _initialRoute() {
    if (!onChurchNetwork) return '/no-wifi';
    return switch (initialRole) {
      AppRole.translator => '/translator/channels',
      AppRole.listener => '/listener',
      null => '/',
    };
  }
}
