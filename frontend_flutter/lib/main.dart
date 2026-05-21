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
import 'services/update_service.dart';
import 'presentation/screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final sync = context.read<SyncEngine>();
        sync.startPeriodicSync(interval: const Duration(minutes: 5));

        final updateService = context.read<UpdateService>();
        updateService.startPeriodicCheck(interval: const Duration(hours: 1));
      } catch (e) {
        debugPrint('Init error: $e');
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
