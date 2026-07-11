import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/script_store_item.dart';
import 'client.dart';

/// 脚本商店 API
class ScriptStoreApi {
  static const _proxyBase = 'http://localhost:25568';
  static const _rawBase = 'https://raw.githubusercontent.com/CHINAYYDSNB/Tianxuan/main/scripts';

  /// 取索引 (优先代理, 回退直连)
  static Future<ScriptIndex> fetchIndex() async {
    try {
      final r = await http
          .get(Uri.parse('$_proxyBase/api/script/index'))
          .timeout(const Duration(seconds: 5));
      if (r.statusCode == 200) return ScriptIndex.fromJson(jsonDecode(r.body));
    } catch (_) {}
    final r = await http
        .get(Uri.parse('$_rawBase/index.json'))
        .timeout(const Duration(seconds: 10));
    if (r.statusCode != 200) throw Exception('获取商店索引失败 (${r.statusCode})');
    return ScriptIndex.fromJson(jsonDecode(r.body));
  }

  /// 取脚本详情 (优先代理, 回退直连)
  static Future<ScriptDetail> fetchDetail(String id) async {
    try {
      final r = await http
          .get(Uri.parse('$_proxyBase/api/script/detail/$id'))
          .timeout(const Duration(seconds: 5));
      if (r.statusCode == 200) return ScriptDetail.fromJson(jsonDecode(r.body));
    } catch (_) {}
    final r = await http
        .get(Uri.parse('$_rawBase/details/$id.json'))
        .timeout(const Duration(seconds: 10));
    if (r.statusCode != 200) throw Exception('获取脚本详情失败 (${r.statusCode})');
    return ScriptDetail.fromJson(jsonDecode(r.body));
  }

  /// 下载脚本内容 (优先代理, 回退直连)
  static Future<String> downloadScript(String url) async {
    try {
      final r = await http
          .get(Uri.parse('$_proxyBase/api/script-download?url=${Uri.encodeComponent(url)}'))
          .timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) return r.body;
    } catch (_) {}
    final r = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
    if (r.statusCode != 200) throw Exception('下载失败 (${r.statusCode})');
    return r.body;
  }

  /// 上传脚本到 1Panel
  static Future<void> uploadToServer(String path, String content) async {
    await ApiClient.instance.post('/files/save', data: {'path': path, 'content': content});
  }

  /// 通过 server.mjs 执行脚本
  static Future<String> executeViaProxy(String scriptPath) async {
    final url = ApiClient.instance.serverUrl.replaceAll(RegExp(r':\d+$'), ':25568');
    final r = await http.post(
      Uri.parse('$url/api/script/exec'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'path': scriptPath}),
    );
    if (r.statusCode != 200) throw Exception('执行失败 (${r.statusCode})');
    return r.body;
  }
}
