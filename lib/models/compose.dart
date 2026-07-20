import 'dart:convert';

class ComposeInfo {
  final String name;
  final String status;
  final String configFiles;

  ComposeInfo({required this.name, required this.status, required this.configFiles});

  factory ComposeInfo.fromJson(Map<String, dynamic> json) => ComposeInfo(
    name: json['Name']?.toString() ?? '',
    status: json['Status']?.toString() ?? '',
    configFiles: json['ConfigFiles']?.toString() ?? '',
  );

  static List<ComposeInfo> fromJsonl(String jsonl) {
    return jsonl.split('\n').where((l) => l.trim().isNotEmpty).map((l) {
      try { return ComposeInfo.fromJson(jsonDecode(l)); } catch (_) { return null; }
    }).whereType<ComposeInfo>().toList();
  }
}
