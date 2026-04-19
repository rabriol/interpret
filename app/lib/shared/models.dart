enum AppRole { translator, listener }

class Channel {
  final int id;
  final String name;
  final String multicastAddr;
  final int multicastPort;

  const Channel({
    required this.id,
    required this.name,
    required this.multicastAddr,
    required this.multicastPort,
  });

  factory Channel.fromJson(Map<String, dynamic> json) => Channel(
        id: json['id'] as int,
        name: json['name'] as String,
        multicastAddr: json['multicast_addr'] as String,
        multicastPort: json['multicast_port'] as int,
      );

  int get unicastPort => 5000 + id;
}
