import 'package:flutter/material.dart';
import '../shared/prefs.dart';
import '../shared/models.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  Future<void> _selectRole(BuildContext context, AppRole role) async {
    final prefs = await AppPrefs.load();
    await prefs.setRole(role);
    if (!context.mounted) return;
    Navigator.of(context).pushReplacementNamed(
      role == AppRole.translator ? '/translator/channels' : '/listener',
    );
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Interpret',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Select your role',
                style: TextStyle(color: Colors.white54, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              ElevatedButton.icon(
                icon: const Icon(Icons.mic),
                label: const Text('I am a Translator'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C6AF7),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                ),
                onPressed: () => _selectRole(context, AppRole.translator),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.headphones),
                label: const Text('I am a Listener'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                ),
                onPressed: () => _selectRole(context, AppRole.listener),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
