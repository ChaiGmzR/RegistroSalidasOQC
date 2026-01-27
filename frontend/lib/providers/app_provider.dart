import 'package:flutter/foundation.dart';
import '../models/part_number.dart';
import '../models/esd_box.dart';
import '../models/operator.dart';
import '../models/exit_record.dart';
import '../services/api_service.dart';

class AppProvider with ChangeNotifier {
  // Estado de conexión
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  // Estado de carga
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // Mensaje de error
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // Datos
  List<PartNumber> _partNumbers = [];
  List<PartNumber> get partNumbers => _partNumbers;

  List<EsdBox> _esdBoxes = [];
  List<EsdBox> get esdBoxes => _esdBoxes;

  List<Operator> _operators = [];
  List<Operator> get operators => _operators;

  List<ExitRecord> _exitRecords = [];
  List<ExitRecord> get exitRecords => _exitRecords;

  ExitRecordStats _stats = ExitRecordStats();
  ExitRecordStats get stats => _stats;

  // Operador actual
  Operator? _currentOperator;
  Operator? get currentOperator => _currentOperator;

  void setCurrentOperator(Operator? operator) {
    _currentOperator = operator;
    notifyListeners();
  }

  // Inicializar
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      _isConnected = await ApiService.checkHealth();
      if (_isConnected) {
        await Future.wait([
          loadPartNumbers(),
          loadEsdBoxes(),
          loadOperators(),
          loadExitRecords(),
          loadStats(),
        ]);
      }
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
      _isConnected = false;
    }

    _isLoading = false;
    notifyListeners();
  }

  // Cargar números de parte
  Future<void> loadPartNumbers() async {
    try {
      _partNumbers = await ApiService.getPartNumbers();
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
    }
  }

  // Crear número de parte
  Future<bool> createPartNumber(PartNumber partNumber) async {
    try {
      final created = await ApiService.createPartNumber(partNumber);
      _partNumbers.add(created);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    }
  }

  // Actualizar número de parte
  Future<bool> updatePartNumber(PartNumber partNumber) async {
    try {
      final updated = await ApiService.updatePartNumber(partNumber);
      final index = _partNumbers.indexWhere((p) => p.id == updated.id);
      if (index != -1) {
        _partNumbers[index] = updated;
      }
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    }
  }

  // Eliminar número de parte
  Future<bool> deletePartNumber(int id) async {
    try {
      await ApiService.deletePartNumber(id);
      _partNumbers.removeWhere((p) => p.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    }
  }

  // Cargar cajas ESD
  Future<void> loadEsdBoxes() async {
    try {
      _esdBoxes = await ApiService.getEsdBoxes();
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
    }
  }

  // Cargar operadores
  Future<void> loadOperators() async {
    try {
      _operators = await ApiService.getOperators();
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
    }
  }

  // Crear operador
  Future<bool> createOperator(Operator operator) async {
    try {
      final created = await ApiService.createOperator(operator);
      _operators.add(created);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    }
  }

  // Actualizar operador
  Future<bool> updateOperator(Operator operator) async {
    try {
      final updated = await ApiService.updateOperator(operator);
      final index = _operators.indexWhere((o) => o.id == updated.id);
      if (index != -1) {
        _operators[index] = updated;
      }
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    }
  }

  // Eliminar operador
  Future<bool> deleteOperator(int id) async {
    try {
      await ApiService.deleteOperator(id);
      _operators.removeWhere((o) => o.id == id);
      if (_currentOperator?.id == id) {
        _currentOperator = null;
      }
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    }
  }

  // Cargar registros de salida
  Future<void> loadExitRecords({
    String? status,
    String? startDate,
    String? endDate,
    String? partNumber,
    bool? qcPassed,
    int? limit,
  }) async {
    try {
      _exitRecords = await ApiService.getExitRecords(
        status: status,
        startDate: startDate,
        endDate: endDate,
        partNumber: partNumber,
        qcPassed: qcPassed,
        limit: limit,
      );
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
    }
  }

  // Crear registro de salida
  Future<ExitRecord?> createExitRecord(ExitRecord record) async {
    try {
      final created = await ApiService.createExitRecord(record);
      _exitRecords.insert(0, created);
      await loadStats();
      notifyListeners();
      return created;
    } catch (e) {
      _errorMessage = e.toString();
      return null;
    }
  }

  // Actualizar estado del registro
  Future<bool> updateExitRecordStatus(int id, String status) async {
    try {
      await ApiService.updateExitRecordStatus(id, status);
      final index = _exitRecords.indexWhere((r) => r.id == id);
      if (index != -1) {
        await loadExitRecords();
      }
      await loadStats();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    }
  }

  // Cancelar registro
  Future<bool> cancelExitRecord(int id) async {
    try {
      await ApiService.deleteExitRecord(id);
      _exitRecords.removeWhere((r) => r.id == id);
      await loadStats();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    }
  }

  // Cargar estadísticas
  Future<void> loadStats({String? startDate, String? endDate}) async {
    try {
      final now = DateTime.now();
      final start = startDate ?? DateTime(now.year, now.month, 1).toIso8601String().split('T')[0];
      final end = endDate ?? now.toIso8601String().split('T')[0];
      _stats = await ApiService.getStats(startDate: start, endDate: end);
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
    }
  }

  // Limpiar error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
