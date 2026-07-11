import '../models/app_store_item.dart';
import 'client.dart';

class AppStoreApi {
  /// Search apps in store
  static Future<Map<String, dynamic>> search({
    int page = 1,
    int pageSize = 20,
    String? type,
    String? name,
  }) async {
    final params = <String, dynamic>{'page': page, 'pageSize': pageSize};
    if (type != null && type.isNotEmpty) params['type'] = type;
    if (name != null && name.isNotEmpty) params['name'] = name;
    final res = await ApiClient.instance.post('/apps/search', data: params);
    final data = res.data['data'] as Map? ?? {};
    final items = (data['items'] as List?)?.map(
          (e) => AppStoreItem.fromJson(e as Map<String, dynamic>),
        ) ??
        <AppStoreItem>[];
    return {'total': data['total'] ?? 0, 'items': items};
  }

  /// Get app detail by key
  static Future<AppDetail> getDetail(String key) async {
    final res = await ApiClient.instance.get('/apps/$key');
    final raw = res.data['data'];
    final data = (raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{});
    return AppDetail.fromJson(data);
  }

  /// Sync remote apps
  static Future<void> syncRemote() async {
    await ApiClient.instance.post('/apps/sync/remote');
  }

  /// Get default compose / params for an app
  static Future<String?> fetchCompose(String key, String version) async {
    try {
      final res = await ApiClient.instance.post('/apps/install/conf', data: {
        'key': key,
        'version': version,
      });
      final data = res.data['data'];
      if (data is Map) {
        if (data['dockerCompose'] != null) return data['dockerCompose'].toString();
        if (data['compose'] != null) return data['compose'].toString();
      }
      if (data is String) return data;
      return null;
    } catch (_) {
      return null;
    }
  }
}
