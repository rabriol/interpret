import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../shared/models.dart';
import 'translator_controller.dart';

class TranslatorScreen extends StatelessWidget {
  const TranslatorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final channel = ModalRoute.of(context)?.settings.arguments as Channel?;
    if (channel == null) {
      return const Scaffold(body: Center(child: Text('No channel selected')));
    }
    return ChangeNotifierProvider(
      create: (_) => TranslatorController(channel: channel)..start(),
      child: const _TranslatorView(),
    );
  }
}

class _TranslatorView extends StatelessWidget {
  const _TranslatorView();

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<TranslatorController>();
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Translator'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).pushNamed('/'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              ctrl.channel.name,
              style: const TextStyle(color: Colors.white70, fontSize: 18),
            ),
            const SizedBox(height: 32),
            _LevelMeter(level: ctrl.level),
            const SizedBox(height: 32),
            if (ctrl.pushToTalk)
              GestureDetector(
                onTapDown: (_) => ctrl.pttPress(),
                onTapUp: (_) => ctrl.pttRelease(),
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: ctrl.pttActive
                        ? const Color(0xFF7C6AF7)
                        : Colors.grey[800],
                  ),
                  child: const Icon(Icons.mic, size: 48, color: Colors.white),
                ),
              )
            else
              Icon(
                Icons.mic,
                size: 64,
                color: ctrl.isRecording ? const Color(0xFF7C6AF7) : Colors.grey,
              ),
            const SizedBox(height: 16),
            Text(
              ctrl.pushToTalk
                  ? (ctrl.pttActive ? 'Transmitting...' : 'Hold to talk')
                  : (ctrl.isRecording ? 'Transmitting' : 'Stopped'),
              style: const TextStyle(color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelMeter extends StatelessWidget {
  final double level;
  const _LevelMeter({required this.level});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 12,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(6),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: level.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF7C6AF7),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
    );
  }
}
