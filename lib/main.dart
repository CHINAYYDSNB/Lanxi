import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/settings_provider.dart';
import 'services/storage_service.dart';
import 'pages/home_page.dart';
import 'pages/login_page.dart';
import 'pages/logto_login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.instance.migrateIfNeeded();
  runApp(const ProviderScope(child: OnePanelApp()));
}

class OnePanelApp extends StatelessWidget {
  const OnePanelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Tianxuan',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        // LogtoLoginPage wraps the initial route so it gates app access
        // inside MaterialApp where Theme/MediaQuery are available
        home: const LogtoLoginPage(child: InitPage()),
        routes: {
          '/login': (context) => const LoginPage(),
          '/home': (context) => const HomePage(),
        },
    );
  }
}

class InitPage extends ConsumerStatefulWidget {
  const InitPage({super.key});

  @override
  ConsumerState<InitPage> createState() => _InitPageState();
}

class _InitPageState extends ConsumerState<InitPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => _checkConfig());
    // Safety timeout: if config check doesn't complete, go to login
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    });
  }

  Future<void> _checkConfig() async {
    try {
      final settings = ref.read(settingsProvider.notifier);
      await settings.init();
      if (!mounted) return;
      if (ref.read(settingsProvider).isConnected) {
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      debugPrint('InitPage._checkConfig error: $e');
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
