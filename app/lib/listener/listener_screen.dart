import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'listener_controller.dart';
import '../shared/models.dart';

class ListenerScreen extends StatelessWidget {
  const ListenerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ListenerController()..init(),
      child: const _ListenerView(),
    );
  }
}

class _ListenerView extends StatelessWidget {
  const _ListenerView();

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ListenerController>();
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Listener'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).pushNamed('/'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: ctrl.loading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Fetching channels...',
                        style: TextStyle(color: Colors.white54)),
                  ],
                ),
              )
            : ctrl.channels.isEmpty
                ? const Center(
                    child: Text(
                      'No channels found.\nMake sure you are connected to ChurchTranslator Wi-Fi.',
                      style: TextStyle(color: Colors.white54),
                      textAlign: TextAlign.center,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Select language',
                        style:
                            TextStyle(color: Colors.white54, fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      ...ctrl.channels.map((ch) => _ChannelTile(
                            channel: ch,
                            selected: ctrl.selectedChannel?.id == ch.id,
                            connected: ctrl.connected &&
                                ctrl.selectedChannel?.id == ch.id,
                            onTap: () => ctrl.selectChannel(ch),
                          )),
                    ],
                  ),
      ),
    );
  }
}

class _ChannelTile extends StatelessWidget {
  final Channel channel;
  final bool selected;
  final bool connected;
  final VoidCallback onTap;

  const _ChannelTile({
    required this.channel,
    required this.selected,
    required this.connected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFF59E0B).withOpacity(0.15)
              : Colors.grey[900],
          border: Border.all(
            color:
                selected ? const Color(0xFFF59E0B) : Colors.grey[800]!,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.headphones,
              color:
                  selected ? const Color(0xFFF59E0B) : Colors.white38,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                channel.name,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white70,
                  fontWeight: selected
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            ),
            if (connected)
              const Icon(Icons.volume_up,
                  color: Color(0xFFF59E0B), size: 18),
          ],
        ),
      ),
    );
  }
}
