import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme.dart';
import 'core/constants.dart';
import 'presentation/screens/login_screen.dart';
import 'presentation/screens/dashboard_screen.dart';
import 'services/auth_service.dart';
import 'sync/sync_engine.dart';
import 'sync/lan_discovery_service.dart';

class BioLabApp extends ConsumerStatefulWidget {
  const BioLabApp({super.key});

  @override
  ConsumerState<BioLabApp> createState() => _BioLabAppState();
}

class _BioLabAppState extends ConsumerState<BioLabApp> {
  bool _checkingAuth = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(authProvider.notifier).tryAutoLogin();
      if (mounted) {
        setState(() => _checkingAuth = false);
        _initServices();
      }
    });
  }

  Future<void> _initServices() async {
    try {
      ref.read(syncEngineProvider.notifier).startPeriodicSync();
      ref.read(lanDiscoveryServiceProvider.notifier).startDiscovery();
    } catch (e) {
      debugPrint('Init services error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final initialRoute = _checkingAuth
        ? null
        : authState.isAuthenticated
            ? '/dashboard'
            : '/login';

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
      initialRoute: initialRoute,
      routes: {
        '/login': (_) => const LoginScreen(),
        '/dashboard': (_) => const DashboardScreen(),
      },
    );
  }
}
