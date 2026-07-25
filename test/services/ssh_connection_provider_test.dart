import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lanxi/services/ssh_command_service.dart';
import 'package:lanxi/services/storage_service.dart';
import 'package:lanxi/providers/ssh_connection_provider.dart';
import 'package:lanxi/models/ssh_config.dart';

class MockSshCommandService extends Mock implements SshCommandService {}

class MockStorageService extends Mock implements StorageService {}

final dummyConfig = SshConfig(
  host: '1.2.3.4',
  port: 22,
  username: 'root',
  password: 'pw',
);

void main() {
  // Task 2 依赖 WidgetsBinding（lifecycle observer），需先初始化 binding。
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // mocktail 对自定义类型 any() 需要 fallback value
    registerFallbackValue(dummyConfig);
    registerFallbackValue(<Map<String, dynamic>>[]);
  });

  /// 构造一个断网/可重连的 notifier，并等待其内部 _autoConnect 跑完。
  Future<SshConnectionNotifier> _spawn({
    required MockSshCommandService ssh,
    required MockStorageService storage,
    List<Duration> reconnectDelays = const [Duration.zero],
  }) async {
    final notifier = SshConnectionNotifier(
      serviceFactory: () => ssh,
      storage: storage,
      reconnectDelays: reconnectDelays,
      enableKeepalive: false,
    );
    // _autoConnect 是 fire-and-forget，等其完成
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return notifier;
  }

  group('Task 2 — SSH 自动重连', () {
    test('App 回到前台时检查连接并尝试重连', () async {
      final ssh = MockSshCommandService();
      final storage = MockStorageService();

      when(() => ssh.isConnected).thenReturn(false);
      when(() => ssh.connect(any())).thenAnswer((_) async {});
      when(() => ssh.disconnect()).thenReturn(null);
      when(() => ssh.ping()).thenAnswer((_) async => true);
      when(() => storage.getSshConnections())
          .thenAnswer((_) async => [dummyConfig.toJson()]);
      when(() => storage.saveSshConnections(any())).thenAnswer((_) async {});

      final notifier = await _spawn(ssh: ssh, storage: storage);
      // 初始 _autoConnect 已 connect 1 次

      // 模拟 App 回到前台
      notifier.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // resumed 应强制 disconnect 并再次重连 -> connect 至少被调用 2 次
      verify(() => ssh.connect(any())).called(greaterThanOrEqualTo(2));
      notifier.dispose();
    });

    test('重连失败 5 次后停止', () async {
      final ssh = MockSshCommandService();
      final storage = MockStorageService();

      when(() => ssh.isConnected).thenReturn(false);
      when(() => ssh.connect(any())).thenThrow(Exception('boom'));
      when(() => ssh.disconnect()).thenReturn(null);
      when(() => ssh.ping()).thenAnswer((_) async => false);
      when(() => storage.getSshConnections())
          .thenAnswer((_) async => [dummyConfig.toJson()]);
      when(() => storage.saveSshConnections(any())).thenAnswer((_) async {});

      final notifier = await _spawn(
        ssh: ssh,
        storage: storage,
        reconnectDelays: List.filled(5, Duration.zero), // 1/2/4/8/16s 对应 5 次
      );

      // 指数退避重连最多 5 次后停止
      verify(() => ssh.connect(any())).called(5);
      notifier.dispose();
    });

    test('连接信息持久化后可自动恢复', () async {
      final ssh = MockSshCommandService();
      final storage = MockStorageService();

      when(() => ssh.isConnected).thenReturn(true);
      when(() => ssh.connect(any())).thenAnswer((_) async {});
      when(() => ssh.disconnect()).thenReturn(null);
      when(() => ssh.ping()).thenAnswer((_) async => true);
      when(() => storage.getSshConnections())
          .thenAnswer((_) async => [dummyConfig.toJson()]);
      when(() => storage.saveSshConnections(any())).thenAnswer((_) async {});

      final notifier = await _spawn(ssh: ssh, storage: storage);

      // 从持久化存储读取连接信息并自动 connect
      verify(() => storage.getSshConnections()).called(greaterThanOrEqualTo(1));
      verify(() => ssh.connect(any())).called(greaterThanOrEqualTo(1));
      notifier.dispose();
    });
  });
}
