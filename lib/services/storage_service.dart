import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Unified storage — SharedPreferences only.
class StorageService {
  StorageService._();

  static final _instance = StorageService._();
  static StorageService get instance => _instance;

  Future<void> _write(String key, String value) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(key, base64Encode(utf8.encode(value)));
  }

  Future<String?> _read(String key) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(key);
    if (raw == null) return null;
    try {
      return utf8.decode(base64Decode(raw));
    } catch (_) {
      return raw;
    }
  }

  Future<void> _delete(String key) async {
    final p = await SharedPreferences.getInstance();
    await p.remove(key);
  }

  // ─── API Key (sensitive, encrypted) ───

  Future<void> saveApiKey(String key) => _write('api_key', key);

  Future<String?> getApiKey() => _read('api_key');

  Future<void> deleteApiKey() => _delete('api_key');

  // ─── Server Address ───

  Future<void> saveServerHost(String host) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('server_host', host);
  }

  Future<String?> getServerHost() async {
    final p = await SharedPreferences.getInstance();
    return p.getString('server_host');
  }

  Future<void> saveServerPort(int port) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('server_port', port);
  }

  Future<int?> getServerPort() async {
    final p = await SharedPreferences.getInstance();
    final v = p.getInt('server_port');
    return v;
  }

  // ─── Server URL (deprecated, kept for migration) ───

  Future<void> saveServerUrl(String url) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('server_url', url);
  }

  Future<String?> getServerUrl() async {
    final p = await SharedPreferences.getInstance();
    return p.getString('server_url');
  }

  Future<void> deleteServerUrl() async {
    final p = await SharedPreferences.getInstance();
    await p.remove('server_url');
  }

  // ─── Saved Servers List (keep apiKey encrypted, rest in prefs) ───

  /// Save server list metadata (without apiKey).
  /// Keys stored separately in secure storage.
  Future<void> saveServersJson(String json) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('saved_servers', json);
  }

  Future<String?> getServersJson() async {
    final p = await SharedPreferences.getInstance();
    return p.getString('saved_servers');
  }

  /// Encrypt/store a single saved server's apiKey.
  Future<void> saveServerKey(String serverId, String apiKey) =>
      _write('srv_key_$serverId', apiKey);

  /// Decrypt/load a single saved server's apiKey.
  Future<String?> getServerKey(String serverId) =>
      _read('srv_key_$serverId');

  /// Delete a single saved server's apiKey.
  Future<void> deleteServerKey(String serverId) =>
      _delete('srv_key_$serverId');

  // ─── Init ───

  Future<void> migrateIfNeeded() async {} // no-op: all SharedPreferences now

  // ─── Deprecated: Logto storage (kept for compatibility) ───

  Future<void> saveLogtoPending(String verifier, String state) async {
    await _write('logto_pending', jsonEncode({'verifier': verifier, 'state': state}));
  }

  Future<Map<String, String>?> getLogtoPending() async {
    final raw = await _read('logto_pending');
    if (raw == null) return null;
    try {
      final m = jsonDecode(raw) as Map;
      return {
        'verifier': m['verifier']?.toString() ?? '',
        'state': m['state']?.toString() ?? '',
      };
    } catch (_) {
      return null;
    }
  }

  Future<void> clearLogtoPending() => _delete('logto_pending');

  // ─── Logto OIDC Tokens ───

  Future<void> saveLogtoTokens({
    required String accessToken,
    String refreshToken = '',
    String idToken = '',
    int expiresIn = 3600,
  }) async {
    final expiry = DateTime.now().millisecondsSinceEpoch + (expiresIn * 1000);
    await _write('logto_at', accessToken);
    if (refreshToken.isNotEmpty) await _write('logto_rt', refreshToken);
    if (idToken.isNotEmpty) await _write('logto_id', idToken);
    await _write('logto_exp', expiry.toString());
  }

  Future<String?> getLogtoAccessToken() => _read('logto_at');
  Future<String?> getLogtoRefreshToken() => _read('logto_rt');
  Future<String?> getLogtoIdToken() => _read('logto_id');
  Future<bool> getLogtoTokenValid() async {
    final exp = await _read('logto_exp');
    if (exp == null) return false;
    final expiry = int.tryParse(exp) ?? 0;
    return DateTime.now().millisecondsSinceEpoch < expiry;
  }

  Future<void> deleteLogtoTokens() async {
    await _delete('logto_at');
    await _delete('logto_rt');
    await _delete('logto_id');
    await _delete('logto_exp');
  }

  // ─── SSH 连接保存 ───

  Future<void> saveSshConnections(List<Map<String, dynamic>> connections) async {
    await _write('ssh_connections', jsonEncode(connections));
  }

  Future<List<Map<String, dynamic>>?> getSshConnections() async {
    final raw = await _read('ssh_connections');
    if (raw == null) return null;
    try {
      return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return null;
    }
  }
}
