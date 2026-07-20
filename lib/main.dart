import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/settings_provider.dart';
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.instance.migrateIfNeeded();
  runApp(const ProviderScope(child: LanxiApp()));
}

class LanxiApp extends StatelessWidget {
  const LanxiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lanxi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.light(
          surface: const Color(0xFFEBEDF5),
          onSurface: const Color(0xFF0C1014),
          onSurfaceVariant: const Color(0xFF686F78),
          outline: const Color(0xFFAAB4BF),
          primary: const Color(0xFF0062F5),
        ),
        scaffoldBackgroundColor: const Color(0xFFEBEDF5),
        appBarTheme: const AppBarTheme(
          titleTextStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Color(0xFF0C1014)),
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFFFFFFFF),
          elevation: 0,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(17))),
        ),
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        splashColor: Colors.transparent,
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
      ),
      home: const InitPage(),
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
    Future.microtask(() => _init());
  }

  Future<void> _init() async {
    try {
      await ref.read(settingsProvider.notifier).init();
    } catch (e) {
      debugPrint('InitPage error: $e');
    }
    if (mounted) Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
