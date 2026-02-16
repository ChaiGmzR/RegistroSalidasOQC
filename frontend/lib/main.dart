import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'dart:io';
import 'providers/app_provider.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';
import 'services/print_service.dart';
import 'services/backend_service.dart';
import 'services/logger_service.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final log = LoggerService();
  log.info('App', 'Iniciando OQC Registro de Salidas...');

  // Inicializar datos de localización para fechas
  await initializeDateFormatting('es', null);
  log.debug('App', 'Localización inicializada');

  // Cargar configuración de impresión
  await PrintService.loadConfig();
  log.debug('App', 'Configuración de impresión cargada');

  // Iniciar backend local (solo en desktop, no en web)
  if (!kIsWeb && Platform.isWindows) {
    log.info('App', 'Iniciando backend local...');
    final backendStarted = await BackendService.start();
    if (!backendStarted) {
      log.warning('App', 'No se pudo iniciar el backend local');
    }
  }

  // Configurar ventana solo para escritorio (no web)
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS)) {
    await windowManager.ensureInitialized();

    WindowOptions windowOptions = const WindowOptions(
      size: Size(1400, 900),
      minimumSize: Size(1200, 700),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
      title: 'OQC - Registro de Salidas | Ilsan Electronics',
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
      await windowManager.maximize();
    });
  }

  runApp(const OQCApp());
}

class OQCApp extends StatefulWidget {
  const OQCApp({super.key});

  @override
  State<OQCApp> createState() => _OQCAppState();
}

class _OQCAppState extends State<OQCApp> {
  bool _showSplash = true;

  void _onSplashComplete() {
    setState(() {
      _showSplash = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()),
      ],
      child: MaterialApp(
        title: 'OQC - Registro de Salidas',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        home: _showSplash
            ? SplashScreen(onComplete: _onSplashComplete)
            : const HomeScreen(),
      ),
    );
  }
}
