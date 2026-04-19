import 'package:flutter/material.dart';
import '../network/registry_client.dart';
import '../shared/models.dart';

class TranslatorChannelPickerScreen extends StatefulWidget {
  const TranslatorChannelPickerScreen({super.key});

  @override
  State<TranslatorChannelPickerScreen> createState() =>
      _TranslatorChannelPickerScreenState();
}

class _TranslatorChannelPickerScreenState
    extends State<TranslatorChannelPickerScreen> {
  List<Channel>? _channels;

  @override
  void initState() {
    super.initState();
    fetchChannels().then((ch) {
      if (mounted) setState(() => _channels = ch);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Select Channel'),
      ),
      body: _channels == null
          ? const Center(child: CircularProgressIndicator())
          : _channels!.isEmpty
              ? const Center(
                  child: Text(
                    'No channels available.\nIs the relay running?',
                    style: TextStyle(color: Colors.white54),
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(24),
                  children: _channels!
                      .map((ch) => ListTile(
                            title: Text(ch.name,
                                style: const TextStyle(color: Colors.white)),
                            leading: const Icon(Icons.mic,
                                color: Color(0xFF7C6AF7)),
                            onTap: () => Navigator.of(context).pushNamed(
                              '/translator',
                              arguments: ch,
                            ),
                          ))
                      .toList(),
                ),
    );
  }
}
