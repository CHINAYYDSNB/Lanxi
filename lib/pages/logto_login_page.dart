import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/logto_service.dart';
import '../services/storage_service.dart';
import '../services/logto_bridge.dart';

class LogtoLoginPage extends ConsumerStatefulWidget {
  final Widget child;
  const LogtoLoginPage({super.key, required this.child});

  @override
  ConsumerState<LogtoLoginPage> createState() => _LogtoLoginPageState();
}

class _LogtoLoginPageState extends ConsumerState<LogtoLoginPage>
    with WidgetsBindingObserver {
  bool _checking = true;
  bool _loggedIn = false;
  StreamSubscription<Uri>? _linkSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _linkSub?.cancel();
    super.dispose();
  }

  /// 从后台切回前台时，检查是否有回调参数 (native deep link)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !kIsWeb && !_loggedIn) {
      _checkCallbackOnResume();
    }
  }

  Future<void> _checkCallbackOnResume() async {
    final initial = await LogtoBridge.getInitialLink();
    if (initial != null && mounted) {
      final handled = await _processCallback(
        initial.queryParameters['code'],
        initial.queryParameters['state'],
      );
      if (!handled && mounted) await _checkAlreadyLoggedIn();
    }
  }

  Future<void> _init() async {
    // Web: 当前 URL 已有回调参数
    if (kIsWeb) {
      final handled = await _processCallback(
        LogtoBridge.extractCallbackParams()['code'],
        LogtoBridge.extractCallbackParams()['state'],
      );
      if (handled) return;
    }

    // Native: app 通过深度链接启动时，取初始链接
    if (!kIsWeb) {
      try {
        final initial = await LogtoBridge.getInitialLink();
        if (initial != null) {
          final handled = await _processCallback(
            initial.queryParameters['code'],
            initial.queryParameters['state'],
          );
          if (handled) return;
        }
      } catch (_) {}
    }

    // 监听后续深度链接 (native EventChannel stream)
    if (!kIsWeb) {
      _linkSub = LogtoBridge.onCallback.listen((uri) async {
        final query = uri.queryParameters;
        await _processCallback(query['code'], query['state']);
      });
    }

    // 检查已有登录态
    final loggedIn = await LogtoService.isLoggedIn;
    if (mounted) setState(() { _loggedIn = loggedIn; _checking = false; });
  }

  Future<bool> _processCallback(String? code, String? state) async {
    if (code == null || state == null) return false;

    final saved = await StorageService.instance.getLogtoPending();
    if (saved == null || state != saved['state']) {
      // Fallback: another listener (SettingsPage) may have already
      // processed this callback and cleared the pending state
      return await _checkAlreadyLoggedIn();
    }

    final ok = await LogtoService.exchangeCode(
      code: code,
      verifier: saved['verifier'] ?? '',
      redirectUri: LogtoBridge.callbackUri,
      state: state,
      expectedState: saved['state'],
    );

    if (ok) {
      if (kIsWeb) LogtoBridge.clearCallbackParams();
      await StorageService.instance.clearLogtoPending();
      if (mounted) setState(() { _loggedIn = true; _checking = false; });
      return true;
    }
    // exchangeCode failed — code may have been consumed by another listener
    return await _checkAlreadyLoggedIn();
  }

  Future<bool> _checkAlreadyLoggedIn() async {
    final loggedIn = await LogtoService.isLoggedIn;
    if (loggedIn && mounted) {
      setState(() { _loggedIn = true; _checking = false; });
      return true;
    }
    return false;
  }

  Future<void> _startLogtoLogin() async {
    try {
      final pkce = LogtoService.buildPkce();
      await StorageService.instance.saveLogtoPending(pkce.verifier, pkce.state);
      final url = LogtoService.buildAuthUrl(
        verifier: pkce.verifier,
        challenge: pkce.challenge,
        state: pkce.state,
        redirectUri: LogtoBridge.callbackUri,
      );
      await LogtoBridge.redirect(url);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('打开浏览器失败: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_loggedIn) return widget.child;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                'assets/Tianxuan.svg',
                width: 100,
                height: 100,
              ),
              const SizedBox(height: 24),
              Text('天璇 Tianxuan',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('1Panel 第三方管理器',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: _startLogtoLogin,
                  icon: const Icon(Icons.login),
                  label: const Text('使用 Logto 登录', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => setState(() => _loggedIn = true),
                child: const Text('跳过登录（开发模式）'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
