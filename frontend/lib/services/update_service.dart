import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/update_config.dart';
import '../models/update_info.dart';

/// Servicio para gestionar actualizaciones automáticas via GitHub Releases
class UpdateService {
  static const String _lastCheckKey = 'last_update_check';

  /// Verifica si hay una nueva versión disponible
  static Future<UpdateInfo?> checkForUpdate({bool forceCheck = false}) async {
    try {
      // Verificar si debemos comprobar (intervalo mínimo)
      if (!forceCheck && !await _shouldCheck()) {
        return null;
      }

      final response = await http.get(
        Uri.parse(UpdateConfig.latestReleaseUrl),
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'OQC-RegistroSalidas-App',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        await _saveLastCheckTime();

        final data = jsonDecode(response.body);
        final updateInfo = UpdateInfo.fromGitHubRelease(data);

        // Comparar versiones
        if (_isNewerVersion(updateInfo.version, UpdateConfig.currentVersion)) {
          return updateInfo;
        }
      } else if (response.statusCode == 404) {
        // No hay releases todavía
        return null;
      }

      return null;
    } catch (e) {
      print('Error al verificar actualizaciones: $e');
      return null;
    }
  }

  /// Compara dos versiones semánticas (ej: "1.2.3" vs "1.2.0")
  static bool _isNewerVersion(String newVersion, String currentVersion) {
    try {
      final newParts = newVersion.split('.').map(int.parse).toList();
      final currentParts = currentVersion.split('.').map(int.parse).toList();

      // Asegurar que ambas tengan 3 partes
      while (newParts.length < 3) newParts.add(0);
      while (currentParts.length < 3) currentParts.add(0);

      for (int i = 0; i < 3; i++) {
        if (newParts[i] > currentParts[i]) return true;
        if (newParts[i] < currentParts[i]) return false;
      }

      return false; // Son iguales
    } catch (e) {
      return false;
    }
  }

  /// Verifica si ha pasado suficiente tiempo desde la última comprobación
  static Future<bool> _shouldCheck() async {
    final prefs = await SharedPreferences.getInstance();
    final lastCheck = prefs.getInt(_lastCheckKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final hoursSinceLastCheck = (now - lastCheck) / (1000 * 60 * 60);

    return hoursSinceLastCheck >= UpdateConfig.checkIntervalHours;
  }

  /// Guarda el timestamp de la última comprobación
  static Future<void> _saveLastCheckTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastCheckKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// Descarga la actualización y retorna la ruta del archivo
  static Future<String?> downloadUpdate(
    UpdateInfo updateInfo,
    void Function(double progress)? onProgress,
  ) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final updateDir = Directory('${tempDir.path}\\oqc_updates');

      if (!await updateDir.exists()) {
        await updateDir.create(recursive: true);
      }

      final filePath = '${updateDir.path}\\${updateInfo.assetName}';
      final file = File(filePath);

      // Descargar con progreso
      final request = http.Request('GET', Uri.parse(updateInfo.downloadUrl));
      request.headers['User-Agent'] = 'OQC-RegistroSalidas-App';

      final response = await http.Client().send(request);

      if (response.statusCode != 200) {
        throw Exception('Error al descargar: ${response.statusCode}');
      }

      final contentLength = response.contentLength ?? updateInfo.assetSize;
      int received = 0;

      final sink = file.openWrite();

      await for (var chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received / contentLength);
      }

      await sink.close();

      return filePath;
    } catch (e) {
      print('Error al descargar actualización: $e');
      return null;
    }
  }

  /// Ejecuta el script de actualización y cierra la app
  static Future<void> installUpdate(String zipPath) async {
    try {
      // Obtener directorio de la app
      final appDir = File(Platform.resolvedExecutable).parent.path;
      final updaterPath = '$appDir\\updater.bat';

      // Verificar que existe el updater
      if (!await File(updaterPath).exists()) {
        throw Exception('No se encontró el script de actualización');
      }

      // Ejecutar updater con ruta del ZIP y directorio de la app
      await Process.start(
        'cmd.exe',
        ['/c', updaterPath, zipPath, appDir],
        mode: ProcessStartMode.detached,
        workingDirectory: appDir,
      );

      // Cerrar la aplicación actual
      exit(0);
    } catch (e) {
      print('Error al instalar actualización: $e');
      rethrow;
    }
  }

  /// Abre la página de releases en el navegador
  static Future<void> openReleasesPage() async {
    final url = UpdateConfig.releasesUrl;

    if (Platform.isWindows) {
      await Process.run('start', [url], runInShell: true);
    }
  }
}
