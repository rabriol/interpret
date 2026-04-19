import 'package:flutter/material.dart';
import 'wifi_check.dart';
import 'prefs.dart';

class NoWifiScreen extends StatelessWidget {
  const NoWifiScreen({super.key});

  Future<void> _retry(BuildContext context) async {
    final ok = await isConnectedToChurchNetwork();
    if (!context.mounted) return;
    if (ok) {
      final prefs = await AppPrefs.load();
      if (!context.mounted) return;
      Navigator.of(context).pushReplacementNamed(
        prefs.role == null
            ? '/'
            : (prefs.role!.name == 'translator' ? '/translator/channels' : '/listener'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off, size: 64, color: Colors.white38),
              const SizedBox(height: 24),
              const Text(
                'Join ChurchTranslator Wi-Fi to begin',
                style: TextStyle(color: Colors.white, fontSize: 20),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Go to Settings → Wi-Fi → ChurchTranslator',
                style: TextStyle(color: Colors.white54, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () => _retry(context),
                child: const Text("I'm connected — continue"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
