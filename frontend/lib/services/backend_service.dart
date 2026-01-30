import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

/// Servicio para gestionar el proceso del backend Node.js
class BackendService {
  static Process? _backendProcess;
  static bool _isRunning = false;
  static const int _defaultPort = 3000;

  /// Obtener la ruta del ejecutable del backend
  static String get _backendPath {
    if (kDebugMode) {
      // En desarrollo, usar la ruta del proyecto
      return path.join(
          Directory.current.path, '..', 'backend', 'dist', 'oqc-backend.exe');
    } else {
      // En producción, el backend está junto al ejecutable
      final exePath = Platform.resolvedExecutable;
      final exeDir = path.dirname(exePath);
      return path.join(exeDir, 'backend', 'oqc-backend.exe');
    }
  }

  /// Obtener la ruta del directorio de trabajo del backend
  static String get _workingDirectory {
    final backendExe = _backendPath;
    return path.dirname(backendExe);
  }

  /// Verificar si el backend está en ejecución
  static bool get isRunning => _isRunning;

  /// Iniciar el backend
  static Future<bool> start() async {
    if (_isRunning) {
      debugPrint('Backend ya está en ejecución');
      return true;
    }

    final backendExe = _backendPath;
    final workDir = _workingDirectory;

    debugPrint('Iniciando backend desde: $backendExe');
    debugPrint('Directorio de trabajo: $workDir');

    // Verificar que existe el ejecutable
    if (!File(backendExe).existsSync()) {
      debugPrint(
          'ERROR: No se encontró el ejecutable del backend en: $backendExe');
      return false;
    }

    // Verificar que existe el archivo .env
    final envFile = File(path.join(workDir, '.env'));
    if (!envFile.existsSync()) {
      debugPrint('WARNING: No se encontró archivo .env en: ${envFile.path}');
    }

    try {
      _backendProcess = await Process.start(
        backendExe,
        [],
        workingDirectory: workDir,
        mode: ProcessStartMode.detached,
      );

      // Esperar un momento para que el servidor inicie
      await Future.delayed(const Duration(seconds: 2));

      // Verificar que el servidor está respondiendo
      final isHealthy = await _checkHealth();
      if (isHealthy) {
        _isRunning = true;
        debugPrint('Backend iniciado correctamente en puerto $_defaultPort');
        return true;
      } else {
        debugPrint('Backend iniciado pero no responde al health check');
        return false;
      }
    } catch (e) {
      debugPrint('Error al iniciar el backend: $e');
      return false;
    }
  }

  /// Detener el backend
  static Future<void> stop() async {
    if (_backendProcess != null) {
      debugPrint('Deteniendo backend...');
      _backendProcess!.kill();
      _backendProcess = null;
      _isRunning = false;
    }

    // También intentar matar cualquier proceso en el puerto 3000
    try {
      if (Platform.isWindows) {
        await Process.run(
            'cmd', ['/c', 'taskkill', '/F', '/IM', 'oqc-backend.exe'],
            runInShell: true);
      }
    } catch (e) {
      debugPrint('Error al intentar cerrar procesos: $e');
    }
  }

  /// Verificar si el backend está respondiendo
  static Future<bool> _checkHealth() async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);

      final request = await client.getUrl(
        Uri.parse('http://localhost:$_defaultPort/api/health'),
      );
      final response = await request.close();
      client.close();

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Health check fallido: $e');
      return false;
    }
  }

  /// Esperar a que el backend esté listo (con reintentos)
  static Future<bool> waitForReady(
      {int maxRetries = 10,
      Duration delay = const Duration(seconds: 1)}) async {
    for (int i = 0; i < maxRetries; i++) {
      if (await _checkHealth()) {
        return true;
      }
      await Future.delayed(delay);
    }
    return false;
  }
}
