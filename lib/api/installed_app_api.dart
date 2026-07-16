import 'package:flutter/foundation.dart';
import '../models/installed_app.dart';
import '../models/app_store_item.dart';
import 'client.dart';

class InstalledAppApi {
  /// List installed apps
  static Future<List<InstalledApp>> list() async {
    final res = await ApiClient.instance.get('/apps/installed/list');
    final data = res.data['data'];
    if (data is List) {
      return data
          .map((e) => InstalledApp.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// Get installed app detail
  static Future<InstalledAppDetail> getInfo(int id) async {
    final res = await ApiClient.instance.get('/apps/installed/info/$id');
    final raw = res.data['data'];
    final data = (raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{});
    return InstalledAppDetail.fromJson(data);
  }

  /// Operate installed app: start / stop / restart / upgrade / delete
  static Future<void> operate(int id, String operation) async {
    await ApiClient.instance.post('/apps/installed/op', data: {
      'appInstallID': id,
      'operate': operation,
    });
  }

  /// Uninstall (delete) an installed app
  static Future<void> uninstall(int id, {bool force = true}) async {
    await ApiClient.instance.post('/apps/installed/op', data: {
      'installId': id,
      'operate': 'delete',
      'isForce': force,
    });
  }

  /// Install a new app
  static Future<void> install({
    required String key,
    required String name,
    required String version,
    required int appDetailId,
    required Map<String, String> params,
  }) async {
    debugPrint('Installing app: key=$key name=$name version=$version appDetailID=$appDetailId');
    final res = await ApiClient.instance.post('/apps/install', data: {
      'key': key,
      'name': name,
      'version': version,
      'appDetailID': appDetailId,
      'params': params,
    });
    debugPrint('Install response: ${res.data}');
  }

  /// Check / get update versions
  /// Returns list of available version strings (e.g. ["8.8.0", "8.6.3"])
  static Future<List<String>> getUpdateVersions(int id) async {
    final res = await ApiClient.instance.post('/apps/installed/update/versions', data: {
      'appInstallID': id,
    });
    final data = res.data['data'];
    if (data is List) {
      return data.map((e) {
        if (e is Map) return e['version']?.toString() ?? '';
        return e.toString();
      }).where((v) => v.isNotEmpty).toList();
    }
    return [];
  }

  /// Update config file
  static Future<void> updateConfig(int id, String content) async {
    await ApiClient.instance.post('/apps/installed/config/update', data: {
      'appInstallID': id,
      'content': content,
    });
  }

  /// Update params (env vars)
  static Future<void> updateParams(int id, Map<String, String> params) async {
    await ApiClient.instance.post('/apps/installed/params/update', data: {
      'appInstallID': id,
      'params': params,
    });
  }

  /// Ignore version update
  static Future<void> ignoreUpdate(int id) async {
    await ApiClient.instance.post('/apps/installed/ignore', data: {
      'appInstallID': id,
    });
  }
}
