import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'data/db.dart';
import 'data/db_native.dart';
import 'data/repositories/auth_repository_impl.dart';
import 'data/repositories/form_repository_impl.dart';
import 'security/auth_service.dart';
import 'security/permission_service.dart';
import 'security/edit_lock_service.dart';
import 'ai/ai_service.dart';
import 'ai/chat_service.dart';
import 'ai/distributed/model_manager.dart';
import 'ai/distributed/node_manager.dart';
import 'ai/distributed/shared_memory.dart';
import 'sync/sync_engine.dart';
import 'sync/lan_discovery_service.dart';
import 'sync/lan_sync_server.dart';
import 'services/update_service.dart';
import 'services/notification_service.dart';
import 'services/dashboard_service.dart';
import 'services/user_service.dart';
import 'services/closure_service.dart';
import 'services/license_service.dart';
import 'services/audit_service.dart';
import 'services/vps_service.dart';
import 'presentation/screens/login_screen.dart';
import 'presentation/screens/activation_screen.dart';
import 'theme/omni_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('Flutter error: ${details.exception}');
  };

  try {
    ensureSqfliteInit();

    final prefs = await SharedPreferences.getInstance();
    var deviceId = prefs.getString('device_id');
    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await prefs.setString('device_id', deviceId);
    }

    final db = await LocalDatabase.instance.database;
    debugPrint('Database initialized at: ${db.path}');

    final authRepo = AuthRepositoryImpl();
    final authService = AuthService(authRepo);
    final syncEngine = SyncEngine();
    final formRepo = FormRepositoryImpl();
    final updateService = UpdateService();
    final notificationService = NotificationService();
    final dashboardService = DashboardService();
    final closureService = ClosureService();
    final userService = UserService();
    userService.loadFromAuth(authService);
    final permissionService = PermissionService();
    final editLockService = EditLockService();
    final aiService = AiService(LocalDatabase.instance);
    final modelManager = ModelManager();
    final chatService = ChatService(modelManager);
    final nodeManager = NodeManager();
    final sharedMemory = SharedMemory();
    await sharedMemory.load();
    final lanDiscovery = LanDiscoveryService();
    final lanSyncServer = LanSyncServer();
    final licenseService = LicenseService();
    await licenseService.init();
    final auditService = AuditService();
    await auditService.init();
    final vpsService = VpsService();
    await vpsService.init();

    final lanDiscoveryPort = int.tryParse(prefs.getString('lan_port') ?? '8765') ?? 8765;
    lanDiscovery.start(port: lanDiscoveryPort);

    final lanSyncServerEnabled = prefs.getBool('lan_sync_server_enabled') ?? false;
    if (lanSyncServerEnabled) {
      final serverPort = prefs.getInt('lan_server_port') ?? 8766;
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
          ChangeNotifierProvider<ClosureService>.value(value: closureService),
          ChangeNotifierProvider<UserService>.value(value: userService),
          ChangeNotifierProvider<PermissionService>.value(value: permissionService),
          ChangeNotifierProvider<EditLockService>.value(value: editLockService),
          ChangeNotifierProvider<AiService>.value(value: aiService),
          ChangeNotifierProvider<ModelManager>.value(value: modelManager),
          ChangeNotifierProvider<ChatService>.value(value: chatService),
          ChangeNotifierProvider<NodeManager>.value(value: nodeManager),
          ChangeNotifierProvider<SharedMemory>.value(value: sharedMemory),
          ChangeNotifierProvider<LanDiscoveryService>.value(value: lanDiscovery),
          ChangeNotifierProvider<LanSyncServer>.value(value: lanSyncServer),
          ChangeNotifierProvider<LicenseService>.value(value: licenseService),
          ChangeNotifierProvider<AuditService>.value(value: auditService),
          ChangeNotifierProvider<VpsService>.value(value: vpsService),
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

        Timer.periodic(const Duration(seconds: 30), (_) async {
          try {
            final discovery = context.read<LanDiscoveryService>();
            if (discovery.isRunning && discovery.peers.isNotEmpty) {
              await sync.syncWithLanPeers(peers: discovery.peers);
            }
          } catch (_) {}
        });

        final discovery = context.read<LanDiscoveryService>();
        Timer? pendingSync;
        discovery.addListener(() {
          pendingSync?.cancel();
          pendingSync = Timer(const Duration(seconds: 3), () async {
            try {
              if (discovery.isRunning && discovery.peers.isNotEmpty) {
                await sync.syncWithLanPeers(peers: discovery.peers);
              }
            } catch (_) {}
          });
        });

        final updateService = context.read<UpdateService>();
        updateService.startPeriodicCheck(interval: const Duration(hours: 1));

        sync.addListener(() {
          if (sync.isOnline && sync.syncCount > 0) {
            context.read<NotificationService>().success(
              'Sincronizacion completada',
              message: '${sync.syncCount} sincronizaciones exitosas',
            );
          } else if (!sync.isOnline && sync.failedCount > 0) {
            context.read<NotificationService>().warning(
              'Error de sincronizacion',
              message: '${sync.failedCount} fallos',
            );
          }
        });

        Timer.periodic(const Duration(minutes: 30), (_) async {
          try {
            final prefs = await SharedPreferences.getInstance();
            final autoBackup = prefs.getBool('auto_backup') ?? false;
            final backupPath = prefs.getString('backup_path') ?? '';
            if (autoBackup && backupPath.isNotEmpty) {
              await LocalDatabase.instance.exportToDirectory(backupPath, label: 'auto');
            }
          } catch (_) {}
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
      home: Consumer<LicenseService>(
        builder: (ctx, license, _) {
          if (license.checking) {
            return Scaffold(
              backgroundColor: OmniTheme.bg950,
              body: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [OmniTheme.accentBlue, OmniTheme.accentIndigo]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                  ),
                  const SizedBox(height: 16),
                  const Text('Verificando licencia...', style: TextStyle(color: OmniTheme.textMuted, fontSize: 13)),
                ]),
              ),
            );
          }
          if (!license.activated) {
            return const ActivationScreen();
          }
          return const LoginScreen();
        },
      ),
    );
  }
}
