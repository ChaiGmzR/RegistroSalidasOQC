import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

/// Niveles de log
enum LogLevel {
  debug,
  info,
  warning,
  error,
}

extension LogLevelExtension on LogLevel {
  String get label {
    switch (this) {
      case LogLevel.debug:
        return 'DEBUG';
      case LogLevel.info:
        return 'INFO';
      case LogLevel.warning:
        return 'WARN';
      case LogLevel.error:
        return 'ERROR';
    }
  }

  String get emoji {
    switch (this) {
      case LogLevel.debug:
        return '🔍';
      case LogLevel.info:
        return 'ℹ️';
      case LogLevel.warning:
        return '⚠️';
      case LogLevel.error:
        return '❌';
    }
  }
}

/// Entrada de log individual
class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String source;
  final String message;
  final String? details;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.source,
    required this.message,
    this.details,
  });

  String get formattedTime =>
      DateFormat('HH:mm:ss.SSS').format(timestamp);

  String get formattedDate =>
      DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(timestamp);

  @override
  String toString() {
    final detailStr = details != null ? ' | $details' : '';
    return '[$formattedDate] [${level.label}] [$source] $message$detailStr';
  }

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'level': level.label,
        'source': source,
        'message': message,
        'details': details,
      };
}

/// Servicio centralizado de logging para debug
class LoggerService extends ChangeNotifier {
  // Singleton
  static final LoggerService _instance = LoggerService._internal();
  factory LoggerService() => _instance;
  LoggerService._internal();

  /// Si el modo debug está habilitado
  bool _debugMode = false;
  bool get debugMode => _debugMode;

  /// Logs en memoria (máximo 2000 entradas)
  final int _maxLogs = 2000;
  final Queue<LogEntry> _logs = Queue<LogEntry>();
  List<LogEntry> get logs => _logs.toList();

  /// Cantidad de errores desde el último cleareo
  int _errorCount = 0;
  int get errorCount => _errorCount;

  /// Listeners para nuevos logs
  final List<void Function(LogEntry)> _logListeners = [];

  /// Activar/desactivar modo debug
  void setDebugMode(bool enabled) {
    _debugMode = enabled;
    if (enabled) {
      info('Logger', 'Modo debug activado');
    }
    notifyListeners();
  }

  /// Toggle modo debug
  void toggleDebugMode() {
    setDebugMode(!_debugMode);
  }

  /// Agregar un listener de log
  void addLogListener(void Function(LogEntry) listener) {
    _logListeners.add(listener);
  }

  /// Remover un listener de log
  void removeLogListener(void Function(LogEntry) listener) {
    _logListeners.remove(listener);
  }

  /// Log de nivel DEBUG
  void debug(String source, String message, [String? details]) {
    _addLog(LogLevel.debug, source, message, details);
  }

  /// Log de nivel INFO
  void info(String source, String message, [String? details]) {
    _addLog(LogLevel.info, source, message, details);
  }

  /// Log de nivel WARNING
  void warning(String source, String message, [String? details]) {
    _addLog(LogLevel.warning, source, message, details);
  }

  /// Log de nivel ERROR
  void error(String source, String message, [String? details]) {
    _addLog(LogLevel.error, source, message, details);
    _errorCount++;
  }

  /// Agregar una entrada de log
  void _addLog(LogLevel level, String source, String message, String? details) {
    // Siempre registrar en modo debug, y siempre registrar errors/warnings
    if (!_debugMode && level == LogLevel.debug) return;

    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      source: source,
      message: message,
      details: details,
    );

    _logs.addLast(entry);

    // Limitar el tamaño del buffer
    while (_logs.length > _maxLogs) {
      _logs.removeFirst();
    }

    // Imprimir también en la consola de debug
    if (kDebugMode || _debugMode) {
      debugPrint('${entry.level.emoji} ${entry.toString()}');
    }

    // Notificar listeners
    for (final listener in _logListeners) {
      listener(entry);
    }

    notifyListeners();
  }

  /// Limpiar todos los logs
  void clearLogs() {
    _logs.clear();
    _errorCount = 0;
    notifyListeners();
  }

  /// Filtrar logs por nivel
  List<LogEntry> getLogsByLevel(LogLevel level) {
    return _logs.where((log) => log.level == level).toList();
  }

  /// Filtrar logs por fuente
  List<LogEntry> getLogsBySource(String source) {
    return _logs.where((log) => log.source == source).toList();
  }

  /// Filtrar logs por búsqueda de texto
  List<LogEntry> searchLogs(String query) {
    final q = query.toLowerCase();
    return _logs.where((log) {
      return log.message.toLowerCase().contains(q) ||
          log.source.toLowerCase().contains(q) ||
          (log.details?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  /// Obtener todas las fuentes únicas
  Set<String> get sources => _logs.map((l) => l.source).toSet();

  /// Exportar logs como texto
  String exportAsText() {
    final buffer = StringBuffer();
    buffer.writeln('=== OQC Registro de Salidas - Debug Logs ===');
    buffer.writeln('Exportado: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}');
    buffer.writeln('Total de entradas: ${_logs.length}');
    buffer.writeln('==========================================\n');

    for (final log in _logs) {
      buffer.writeln(log.toString());
    }

    return buffer.toString();
  }

  /// Exportar logs como JSON
  String exportAsJson() {
    final data = {
      'exportDate': DateTime.now().toIso8601String(),
      'totalEntries': _logs.length,
      'logs': _logs.map((l) => l.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// Guardar logs a archivo
  Future<String?> saveLogsToFile() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final logDir = Directory('${dir.path}/OQC_Logs');
      if (!logDir.existsSync()) {
        logDir.createSync(recursive: true);
      }

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File('${logDir.path}/oqc_debug_$timestamp.log');
      await file.writeAsString(exportAsText());

      info('Logger', 'Logs guardados en: ${file.path}');
      return file.path;
    } catch (e) {
      error('Logger', 'Error al guardar logs', e.toString());
      return null;
    }
  }
}
