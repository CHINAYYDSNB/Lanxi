import 'dart:convert';

class ImageInfo {
  final String id;
  final String repository;
  final String tag;
  final String size;
  final String created;

  ImageInfo({
    required this.id,
    required this.repository,
    required this.tag,
    required this.size,
    required this.created,
  });

  factory ImageInfo.fromJson(Map<String, dynamic> json) => ImageInfo(
    id: json['ID']?.toString().substring(0, 12) ?? '',
    repository: json['Repository']?.toString() ?? '',
    tag: json['Tag']?.toString() ?? 'latest',
    size: json['Size']?.toString() ?? '',
    created: json['CreatedAt']?.toString() ?? '',
  );

  static List<ImageInfo> fromJsonl(String jsonl) {
    return jsonl.split('\n').where((l) => l.trim().isNotEmpty).map((l) {
      try { return ImageInfo.fromJson(jsonDecode(l)); } catch (_) { return null; }
    }).whereType<ImageInfo>().toList();
  }
}
