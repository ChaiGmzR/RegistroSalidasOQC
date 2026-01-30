import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/part_number.dart';
import '../models/esd_box.dart';
import '../models/operator.dart';
import '../models/exit_record.dart';

class ApiService {
  // === PART NUMBERS ===
  static Future<List<PartNumber>> getPartNumbers() async {
    try {
      final response = await http
          .get(
            Uri.parse(ApiConfig.partNumbers),
          )
          .timeout(ApiConfig.connectionTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          return (data['data'] as List)
              .map((item) => PartNumber.fromJson(item))
              .toList();
        }
      }
      throw Exception('Error al obtener números de parte');
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  static Future<PartNumber> createPartNumber(PartNumber partNumber) async {
    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.partNumbers),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(partNumber.toJson()),
          )
          .timeout(ApiConfig.connectionTimeout);

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        if (data['success']) {
          return PartNumber.fromJson(data['data']);
        }
      }
      final error = json.decode(response.body);
      throw Exception(error['error'] ?? 'Error al crear número de parte');
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  static Future<PartNumber> updatePartNumber(PartNumber partNumber) async {
    try {
      final response = await http
          .put(
            Uri.parse('${ApiConfig.partNumbers}/${partNumber.id}'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(partNumber.toJson()),
          )
          .timeout(ApiConfig.connectionTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          return PartNumber.fromJson(data['data']);
        }
      }
      throw Exception('Error al actualizar número de parte');
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  static Future<void> deletePartNumber(int id) async {
    try {
      final response = await http
          .delete(
            Uri.parse('${ApiConfig.partNumbers}/$id'),
          )
          .timeout(ApiConfig.connectionTimeout);

      if (response.statusCode != 200) {
        throw Exception('Error al eliminar número de parte');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // === ESD BOXES ===
  static Future<List<EsdBox>> getEsdBoxes() async {
    try {
      final response = await http
          .get(
            Uri.parse(ApiConfig.esdBoxes),
          )
          .timeout(ApiConfig.connectionTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          return (data['data'] as List)
              .map((item) => EsdBox.fromJson(item))
              .toList();
        }
      }
      throw Exception('Error al obtener cajas ESD');
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // === OPERATORS ===
  static Future<List<Operator>> getOperators() async {
    try {
      final response = await http
          .get(
            Uri.parse(ApiConfig.operators),
          )
          .timeout(ApiConfig.connectionTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          return (data['data'] as List)
              .map((item) => Operator.fromJson(item))
              .toList();
        }
      }
      throw Exception('Error al obtener operadores');
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  static Future<Operator?> validateOperatorPin(
      String employeeId, String pin) async {
    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.operators}/validate-pin'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'employee_id': employeeId, 'pin': pin}),
          )
          .timeout(ApiConfig.connectionTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          return Operator.fromJson(data['data']);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<Operator?> validateSupervisorPin(String pin) async {
    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.operators}/validate-supervisor'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'pin': pin}),
          )
          .timeout(ApiConfig.connectionTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          return Operator.fromJson(data['data']);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<Operator> createOperator(Operator operator) async {
    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.operators),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(operator.toJson()),
          )
          .timeout(ApiConfig.connectionTimeout);

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        if (data['success']) {
          return Operator.fromJson(data['data']);
        }
      }
      final error = json.decode(response.body);
      throw Exception(error['error'] ?? 'Error al crear operador');
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  static Future<Operator> updateOperator(Operator operator) async {
    try {
      final response = await http
          .put(
            Uri.parse('${ApiConfig.operators}/${operator.id}'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(operator.toJson()),
          )
          .timeout(ApiConfig.connectionTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          return Operator.fromJson(data['data']);
        }
      }
      throw Exception('Error al actualizar operador');
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  static Future<void> deleteOperator(int id) async {
    try {
      final response = await http
          .delete(
            Uri.parse('${ApiConfig.operators}/$id'),
          )
          .timeout(ApiConfig.connectionTimeout);

      if (response.statusCode != 200) {
        throw Exception('Error al eliminar operador');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // === EXIT RECORDS ===
  static Future<List<ExitRecord>> getExitRecords({
    String? status,
    String? startDate,
    String? endDate,
    String? partNumber,
    bool? qcPassed,
    int? limit,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (status != null) queryParams['status'] = status;
      if (startDate != null) queryParams['startDate'] = startDate;
      if (endDate != null) queryParams['endDate'] = endDate;
      if (partNumber != null) queryParams['partNumber'] = partNumber;
      if (qcPassed != null) queryParams['qcPassed'] = qcPassed.toString();
      if (limit != null) queryParams['limit'] = limit.toString();

      final uri = Uri.parse(ApiConfig.exitRecords)
          .replace(queryParameters: queryParams);
      final response = await http.get(uri).timeout(ApiConfig.connectionTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          return (data['data'] as List)
              .map((item) => ExitRecord.fromJson(item))
              .toList();
        }
      }
      throw Exception('Error al obtener registros');
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  /// Validar si un boxCode ya fue registrado previamente
  /// Retorna información sobre el estado del registro si existe
  static Future<Map<String, dynamic>> validateBoxCode(String boxCode) async {
    try {
      final response = await http
          .get(
            Uri.parse('${ApiConfig.exitRecords}/validate-box/$boxCode'),
          )
          .timeout(ApiConfig.connectionTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          return data['data'];
        }
      }
      return {'exists': false};
    } catch (e) {
      // Si hay error de conexión, permitir continuar
      return {'exists': false, 'error': e.toString()};
    }
  }

  /// Crear registro de salida con array de cajas
  /// Cada caja creará un registro separado en la BD con el mismo folio
  static Future<Map<String, dynamic>> createExitRecordWithBoxes({
    required int partNumberId,
    required int esdBoxId,
    required int operatorId,
    required DateTime inspectionDate,
    required String destination,
    String? observations,
    required bool qcPassed,
    required List<Map<String, dynamic>> boxes, // [{boxCode, quantity}]
  }) async {
    try {
      final now = DateTime.now();
      final exitDateStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

      final body = {
        'part_number_id': partNumberId,
        'esd_box_id': esdBoxId,
        'operator_id': operatorId,
        'inspection_date': inspectionDate.toIso8601String().split('T')[0],
        'exit_date': exitDateStr,
        'destination': destination,
        'observations': observations,
        'qc_passed': qcPassed,
        'boxes': boxes,
      };

      final response = await http
          .post(
            Uri.parse(ApiConfig.exitRecords),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(body),
          )
          .timeout(ApiConfig.connectionTimeout);

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        if (data['success']) {
          return {
            'success': true,
            'folio': data['data']['folio'],
            'recordsCreated': data['data']['recordsCreated'] ?? 1,
            'totalQuantity': data['data']['totalQuantity'] ?? 0,
          };
        }
      }
      final error = json.decode(response.body);
      throw Exception(error['error'] ?? 'Error al crear registro');
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  static Future<ExitRecord> createExitRecord(ExitRecord record) async {
    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.exitRecords),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(record.toJson()),
          )
          .timeout(ApiConfig.connectionTimeout);

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        if (data['success']) {
          return ExitRecord.fromJson(data['data']);
        }
      }
      final error = json.decode(response.body);
      throw Exception(error['error'] ?? 'Error al crear registro');
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  static Future<ExitRecord> updateExitRecord(ExitRecord record) async {
    try {
      final response = await http
          .put(
            Uri.parse('${ApiConfig.exitRecords}/${record.id}'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(record.toJson()),
          )
          .timeout(ApiConfig.connectionTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          return ExitRecord.fromJson(data['data']);
        }
      }
      throw Exception('Error al actualizar registro');
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  static Future<void> updateExitRecordStatus(int id, String status) async {
    try {
      final response = await http
          .patch(
            Uri.parse('${ApiConfig.exitRecords}/$id/status'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'status': status}),
          )
          .timeout(ApiConfig.connectionTimeout);

      if (response.statusCode != 200) {
        throw Exception('Error al actualizar estado');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  static Future<void> deleteExitRecord(int id) async {
    try {
      final response = await http
          .delete(
            Uri.parse('${ApiConfig.exitRecords}/$id'),
          )
          .timeout(ApiConfig.connectionTimeout);

      if (response.statusCode != 200) {
        throw Exception('Error al cancelar registro');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  static Future<ExitRecordStats> getStats(
      {String? startDate, String? endDate}) async {
    try {
      final queryParams = <String, String>{};
      if (startDate != null) queryParams['startDate'] = startDate;
      if (endDate != null) queryParams['endDate'] = endDate;

      final uri = Uri.parse('${ApiConfig.exitRecords}/stats')
          .replace(queryParameters: queryParams);
      final response = await http.get(uri).timeout(ApiConfig.connectionTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          return ExitRecordStats.fromJson(data['data']);
        }
      }
      throw Exception('Error al obtener estadísticas');
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // === HEALTH CHECK ===
  static Future<bool> checkHealth() async {
    try {
      final response = await http
          .get(
            Uri.parse(ApiConfig.health),
          )
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // === BOX SCANS ===
  static Future<Map<String, dynamic>> getBoxQuantity(String boxCode) async {
    try {
      final response = await http
          .get(
            Uri.parse('${ApiConfig.boxScans}/quantity/$boxCode'),
          )
          .timeout(ApiConfig.connectionTimeout);

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success']) {
        return {
          'success': true,
          'boxCode': data['data']['boxCode'],
          'quantity': data['data']['quantity'],
          'firstScan': data['data']['firstScan'],
          'lastScan': data['data']['lastScan'],
          'folderDate': data['data']['folderDate'],
          'partNumber': data['data']['partNumber'],
        };
      } else if (response.statusCode == 404) {
        return {
          'success': false,
          'error': 'Código de caja no encontrado en registros LQC',
          'boxCode': boxCode,
        };
      }
      throw Exception(data['error'] ?? 'Error al consultar caja');
    } catch (e) {
      if (e.toString().contains('no encontrado')) {
        return {
          'success': false,
          'error': 'Código de caja no encontrado en registros LQC',
          'boxCode': boxCode,
        };
      }
      throw Exception('Error de conexión: $e');
    }
  }

  // === OQC REJECTIONS ===
  static Future<Map<String, dynamic>> createOqcRejection({
    required int exitRecordId,
    required int partNumberId,
    required int operatorId,
    required int expectedQuantity,
    required int actualQuantity,
    required String rejectionReason,
    String? boxCodes,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.oqcRejections),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'exit_record_id': exitRecordId,
              'part_number_id': partNumberId,
              'operator_id': operatorId,
              'expected_quantity': expectedQuantity,
              'actual_quantity': actualQuantity,
              'rejection_reason': rejectionReason,
              'box_codes': boxCodes,
            }),
          )
          .timeout(ApiConfig.connectionTimeout);

      final data = json.decode(response.body);

      if (response.statusCode == 201 && data['success']) {
        return {
          'success': true,
          'data': data['data'],
        };
      }
      throw Exception(data['error'] ?? 'Error al crear rechazo');
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getOqcRejections({
    String? status,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (status != null) queryParams['status'] = status;
      if (startDate != null) queryParams['startDate'] = startDate;
      if (endDate != null) queryParams['endDate'] = endDate;

      final uri = Uri.parse(ApiConfig.oqcRejections)
          .replace(queryParameters: queryParams);
      final response = await http.get(uri).timeout(ApiConfig.connectionTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }
      throw Exception('Error al obtener rechazos');
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  static Future<int> getPendingRejectionsCount() async {
    try {
      final response = await http
          .get(
            Uri.parse('${ApiConfig.oqcRejections}/pending-count'),
          )
          .timeout(ApiConfig.connectionTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          return data['count'];
        }
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }
}
