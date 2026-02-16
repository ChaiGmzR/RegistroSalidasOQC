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
      while (newParts.length < 3) {
        newParts.add(0);
      }
      while (currentParts.length < 3) {
        currentParts.add(0);
      }

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

  /// Ejecuta el updater.bat para instalar el ZIP descargado
  static Future<void> installUpdate(String zipPath) async {
    try {
      // Verificar que existe el ZIP descargado
      if (!await File(zipPath).exists()) {
        throw Exception('No se encontró el archivo descargado');
      }

      // Obtener el directorio de la aplicación actual
      final exePath = Platform.resolvedExecutable;
      final appDir = File(exePath).parent.path;

      // Buscar updater.bat en el directorio de la app
      final updaterPath = '$appDir\\updater.bat';
      if (!await File(updaterPath).exists()) {
        throw Exception('No se encontró updater.bat en: $updaterPath');
      }

      // Ejecutar updater.bat con la ruta del ZIP y el directorio de la app
      await Process.start(
        'cmd',
        ['/c', updaterPath, zipPath, appDir],
        mode: ProcessStartMode.detached,
      );

      // Cerrar la aplicación actual para que el instalador pueda completarse
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
