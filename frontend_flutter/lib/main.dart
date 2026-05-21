import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'data/repositories/auth_repository_impl.dart';
import 'data/repositories/form_repository_impl.dart';
import 'security/auth_service.dart';
import 'sync/sync_engine.dart';
import 'services/update_service.dart';
import 'presentation/screens/login_screen.dart';
import 'presentation/widgets/update_dialog.dart';

String _getPlatformName() {
  if (kIsWeb) return 'Web';
  if (Platform.isWindows) return 'Windows';
  if (Platform.isMacOS) return 'macOS';
  if (Platform.isLinux) return 'Linux';
  if (Platform.isAndroid) return 'Android';
  if (Platform.isIOS) return 'iOS';
  return 'Unknown';
}

String _getDeviceName() {
  final platform = _getPlatformName();
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    return 'BioLab Desktop - $platform';
  }
  return 'BioLab Mobile - $platform';
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  var deviceId = prefs.getString('device_id');
  if (deviceId == null) {
    deviceId = const Uuid().v4();
    await prefs.setString('device_id', deviceId);
  }

  final platformName = _getPlatformName();
  final deviceName = _getDeviceName();

  try {
    await http.post(
      Uri.parse('http://localhost:8000/api/auth/register-device'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'device_id': deviceId,
        'device_name': deviceName,
        'os': platformName,
      }),
    ).timeout(const Duration(seconds: 3));
  } catch (_) {}

  final authRepo = AuthRepositoryImpl();
  final authService = AuthService(authRepo);
  final syncEngine = SyncEngine();
  final formRepo = FormRepositoryImpl();
  final updateService = UpdateService();

  await syncEngine.checkOnline();
  await syncEngine.getPendingCount();
  syncEngine.startPeriodicSync(interval: const Duration(minutes: 5));

  updateService.startPeriodicCheck(interval: const Duration(hours: 1));
  updateService.checkForUpdates();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>.value(value: authService),
        ChangeNotifierProvider<SyncEngine>.value(value: syncEngine),
        ChangeNotifierProvider<UpdateService>.value(value: updateService),
        Provider<FormRepositoryImpl>.value(value: formRepo),
      ],
      child: const BioLabApp(),
    ),
  );
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdates();
    });
  }

  void _checkForUpdates() {
    final updateService = context.read<UpdateService>();
    updateService.checkForUpdates().then((_) {
      if (mounted && updateService.hasUpdate) {
        showDialog(
          context: context,
          barrierDismissible: !updateService.isMandatory,
          builder: (ctx) => const UpdateDialog(),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BioLab - LABSYNC Enterprise',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: const Color(0xFF004A99),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}
