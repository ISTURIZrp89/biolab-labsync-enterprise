import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme.dart';
import 'core/constants.dart';
import 'core/logger.dart';
import 'presentation/screens/login_screen.dart';
import 'presentation/screens/dashboard_screen.dart';
import 'services/auth_service.dart';
import 'sync/sync_engine.dart';
import 'sync/lan_discovery_service.dart';

final _log = getLogger('BioLabApp');

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
    } catch (e, st) {
      _log.error('Init services error', e, st);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    if (_checkingAuth) {
      return MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final initialRoute = authState.isAuthenticated ? '/dashboard' : '/login';

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
