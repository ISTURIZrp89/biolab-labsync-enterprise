import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'data/repositories/auth_repository_impl.dart';
import 'data/repositories/form_repository_impl.dart';
import 'security/auth_service.dart';
import 'sync/sync_engine.dart';
import 'sync/lan_discovery_service.dart';
import 'sync/lan_sync_server.dart';
import 'services/update_service.dart';
import 'services/notification_service.dart';
import 'services/dashboard_service.dart';
import 'presentation/screens/login_screen.dart';
import 'theme/omni_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('Flutter error: ${details.exception}');
  };

  try {
    final prefs = await SharedPreferences.getInstance();
    var deviceId = prefs.getString('device_id');
    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await prefs.setString('device_id', deviceId);
    }

    final authRepo = AuthRepositoryImpl();
    final authService = AuthService(authRepo);
    final syncEngine = SyncEngine();
    final formRepo = FormRepositoryImpl();
    final updateService = UpdateService();
    final notificationService = NotificationService();
    final dashboardService = DashboardService();
    final lanDiscovery = LanDiscoveryService();
    final lanSyncServer = LanSyncServer();

    final lanEnabled = prefs.getBool('lan_sync_enabled') ?? false;
    if (lanEnabled) {
      final lanPort = prefs.getString('lan_port') ?? '8765';
      final serverPort = prefs.getInt('lan_server_port') ?? 8766;
      lanDiscovery.start(port: int.tryParse(lanPort) ?? 8765);
      lanSyncServer.start(port: serverPort);
    }

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthService>.value(value: authService),
          ChangeNotifierProvider<SyncEngine>.value(value: syncEngine),
          ChangeNotifierProvider<UpdateService>.value(value: updateService),
          ChangeNotifierProvider<NotificationService>.value(value: notificationService),
          ChangeNotifierProvider<DashboardService>.value(value: dashboardService),
          ChangeNotifierProvider<LanDiscoveryService>.value(value: lanDiscovery),
          ChangeNotifierProvider<LanSyncServer>.value(value: lanSyncServer),
          Provider<FormRepositoryImpl>.value(value: formRepo),
        ],
        child: const BioLabApp(),
      ),
    );
  } catch (e, stack) {
    debugPrint('Fatal init error: $e');
    debugPrint('Stack: $stack');
    runApp(const _ErrorApp());
  }
}

class _ErrorApp extends StatelessWidget {
  const _ErrorApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: OmniTheme.theme,
      home: Scaffold(
        backgroundColor: OmniTheme.bg950,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [OmniTheme.accentBlue, OmniTheme.accentIndigo],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.error, color: Colors.white, size: 32),
              ),
              const SizedBox(height: 16),
              const Text(
                'Error al iniciar',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: OmniTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Revisa la consola para mas detalles',
                style: TextStyle(color: OmniTheme.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BioLabApp extends StatefulWidget {
  const BioLabApp({super.key});

  @override
  State<BioLabApp> createState() => _BioLabAppState();
}

class _BioLabAppState extends State<BioLabApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final sync = context.read<SyncEngine>();
        sync.startPeriodicSync(interval: const Duration(minutes: 5));

        Timer.periodic(const Duration(minutes: 3), (_) async {
          try {
            final discovery = context.read<LanDiscoveryService>();
            if (discovery.isRunning && discovery.peers.isNotEmpty) {
              await sync.syncWithLanPeers(peers: discovery.peers);
            }
          } catch (_) {}
        });

        final updateService = context.read<UpdateService>();
        updateService.startPeriodicCheck(interval: const Duration(hours: 1));

        sync.addListener(() {
          if (sync.isOnline && sync.syncCount > 0) {
            context.read<NotificationService>().success(
              'Sincronizacion completada',
              message: '${sync.syncCount} sincronizaciones exitosas',
            );
          } else           if (!sync.isOnline && sync.failedCount > 0) {
            context.read<NotificationService>().warning(
              'Error de sincronizacion',
              message: '${sync.failedCount} fallos',
            );
          }
        });

        final discovery = context.read<LanDiscoveryService>();
        discovery.addListener(() {
          if (discovery.peers.isNotEmpty) {
            context.read<NotificationService>().info(
              'PCs detectadas en red',
              message: discovery.peers.map((p) => p.hostname).join(', '),
            );
          }
        });
      } catch (e) {
        debugPrint('Init error: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BioLab',
      debugShowCheckedModeBanner: false,
      theme: OmniTheme.theme,
      home: const LoginScreen(),
    );
  }
}
