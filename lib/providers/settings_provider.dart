import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/storage_service.dart';

class SettingsState {
  final bool isConnected;
  final String? serverHost;
  final int? serverPort;
  final String? error;
  final bool loading;

  SettingsState({
    this.isConnected = false,
    this.serverHost,
    this.serverPort,
    this.error,
    this.loading = false,
  });

  SettingsState copyWith({
    bool? isConnected,
    String? serverHost,
    int? serverPort,
    String? error,
    bool? loading,
  }) {
    return SettingsState(
      isConnected: isConnected ?? this.isConnected,
      serverHost: serverHost ?? this.serverHost,
      serverPort: serverPort ?? this.serverPort,
      error: error,
      loading: loading ?? this.loading,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(SettingsState());

  Future<void> init() async {
    final host = await StorageService.instance.getServerHost();
    if (host != null && host.isNotEmpty) {
      final port = await StorageService.instance.getServerPort();
      state = SettingsState(
        isConnected: false, // need explicit connect via SSH
        serverHost: host,
        serverPort: port,
      );
    }
  }

  Future<bool> connect(String host, int port) async {
    state = state.copyWith(loading: true, error: null);
    try {
      await StorageService.instance.saveServerHost(host);
      await StorageService.instance.saveServerPort(port);
      state = SettingsState(isConnected: true, serverHost: host, serverPort: port);
      return true;
    } catch (e) {
      state = SettingsState(error: e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  void disconnect() {
    state = SettingsState();
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier();
});
