import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme.dart';
import 'core/constants.dart';
import 'presentation/screens/login_screen.dart';
import 'presentation/screens/dashboard_screen.dart';
import 'sync/sync_engine.dart';
import 'sync/lan_discovery_service.dart';

class BioLabApp extends ConsumerStatefulWidget {
  const BioLabApp({super.key});

  @override
  ConsumerState<BioLabApp> createState() => _BioLabAppState();
}

class _BioLabAppState extends ConsumerState<BioLabApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initServices());
  }

  Future<void> _initServices() async {
    try {
      final syncEngine = ref.read(syncEngineProvider);
      syncEngine.startPeriodicSync();
      final discovery = ref.read(lanDiscoveryServiceProvider);
      discovery.startDiscovery();
    } catch (e) {
      debugPrint('Init services error: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.light,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('es', ''), Locale('en', '')],
      initialRoute: '/login',
      routes: {
        '/login': (_) => const LoginScreen(),
        '/dashboard': (_) => const DashboardScreen(),
      },
    );
  }
}
