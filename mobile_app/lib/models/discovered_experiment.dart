
class DiscoveredExperiment {
  final String name;
  final String host;
  final int port;

  const DiscoveredExperiment({
    required this.name,
    required this.host,
    required this.port,
  });

  factory DiscoveredExperiment.fromMap(
    Map<dynamic, dynamic> map,
  ) {
    return DiscoveredExperiment(
      name: map['name'] as String,
      host: map['host'] as String,
      port: (map['port'] as num).toInt(),
    );
  }
}
