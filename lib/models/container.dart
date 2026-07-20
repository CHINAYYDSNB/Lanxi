import 'dart:convert';

class ContainerInfo {
  final String id;
  final String name;
  final String image;
  final String status;
  final String state; // running, exited, etc.
  final String created;
  final List<String> ports;
  final Map<String, String> labels;

  ContainerInfo({
    required this.id,
    required this.name,
    required this.image,
    required this.status,
    required this.state,
    required this.created,
    required this.ports,
    required this.labels,
  });

  factory ContainerInfo.fromJson(Map<String, dynamic> json) {
    final names = (json['Names'] as String?)?.split(',') ?? [];
    final rawId = json['Id'] as String?;
    final name = names.isNotEmpty ? names.first.replaceAll('/', '') : rawId?.substring(0, 12) ?? '';
    return ContainerInfo(
      id: rawId?.substring(0, 12) ?? '',
      name: name,
      image: json['Image']?.toString() ?? '',
      status: json['Status']?.toString() ?? '',
      state: json['State']?.toString() ?? '',
      created: json['CreatedAt']?.toString() ?? '',
      ports: (json['Ports'] as String?)?.split(',').where((p) => p.isNotEmpty).toList() ?? [],
      labels: _parseLabels(json['Labels'] as String?),
    );
  }

  static Map<String, String> _parseLabels(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    final m = <String, String>{};
    for (final p in raw.split(',')) {
      final kv = p.split('=');
      if (kv.length == 2) m[kv[0]] = kv[1];
    }
    return m;
  }

  bool get isRunning => state == 'running';

  static List<ContainerInfo> fromJsonl(String jsonl) {
    return jsonl.split('\n').where((l) => l.trim().isNotEmpty).map((l) {
      try { return ContainerInfo.fromJson(jsonDecode(l)); } catch (_) { return null; }
    }).whereType<ContainerInfo>().toList();
  }
}
