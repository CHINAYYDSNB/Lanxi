import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// 保存文件到本地 (Native)
String saveFileSync(String name, List<int> bytes) {
  throw UnsupportedError('Use async saveFile');
}

Future<String> saveFile(String name, List<int> bytes) async {
  final dir = await getApplicationDocumentsDirectory();
  final path = '${dir.path}/$name';
  final file = File(path);
  await file.writeAsBytes(bytes);
  return path;
}

Future<String> saveTextFile(String name, String text) async {
  final dir = await getApplicationDocumentsDirectory();
  final path = '${dir.path}/$name';
  final file = File(path);
  await file.writeAsString(text);
  return path;
}
