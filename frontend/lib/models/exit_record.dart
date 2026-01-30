class ExitRecord {
  final int? id;
  final String? folio;
  final int partNumberId;
  final int esdBoxId;
  final int operatorId;
  final int quantity;
  final DateTime inspectionDate;
  final DateTime? exitDate;
  final String destination;
  final String status;
  final String? observations;
  final bool qcPassed;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Campos relacionados
  final String? partNumber;
  final String? partDescription;
  final String? model;
  final String? boxCode;
  final int? boxCapacity;
  final String? employeeId;
  final String? operatorName;

  ExitRecord({
    this.id,
    this.folio,
    required this.partNumberId,
    required this.esdBoxId,
    required this.operatorId,
    required this.quantity,
    required this.inspectionDate,
    this.exitDate,
    this.destination = 'Almacen',
    this.status = 'pending',
    this.observations,
    this.qcPassed = true,
    this.createdAt,
    this.updatedAt,
    this.partNumber,
    this.partDescription,
    this.model,
    this.boxCode,
    this.boxCapacity,
    this.employeeId,
    this.operatorName,
  });

  factory ExitRecord.fromJson(Map<String, dynamic> json) {
    return ExitRecord(
      id: json['id'],
      folio: json['folio'],
      partNumberId: json['part_number_id'] ?? 0,
      esdBoxId: json['esd_box_id'] ?? 0,
      operatorId: json['operator_id'] ?? 0,
      quantity: json['quantity'] ?? 0,
      inspectionDate: json['inspection_date'] != null
          ? DateTime.parse(json['inspection_date'])
          : DateTime.now(),
      exitDate:
          json['exit_date'] != null ? DateTime.parse(json['exit_date']) : null,
      destination: json['destination'] ?? 'Almacen',
      status: json['status'] ?? 'pending',
      observations: json['observations'],
      qcPassed: json['qc_passed'] == 1 || json['qc_passed'] == true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      partNumber: json['part_number'],
      partDescription: json['part_description'],
      model: json['model'],
      // scanned_box_code es el código de caja escaneado, esd_box_type es el tipo de caja ESD
      boxCode: json['scanned_box_code'] ?? json['box_code'],
      boxCapacity: json['capacity'],
      employeeId: json['employee_id'],
      operatorName: json['operator_name'],
    );
  }

  Map<String, dynamic> toJson() {
    // Usar la hora local del dispositivo para exit_date
    final now = DateTime.now();
    final exitDateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

    return {
      'id': id,
      'folio': folio,
      'part_number_id': partNumberId,
      'esd_box_id': esdBoxId,
      'operator_id': operatorId,
      'quantity': quantity,
      'inspection_date': inspectionDate.toIso8601String().split('T')[0],
      'exit_date': exitDateStr,
      'destination': destination,
      'status': status,
      'observations': observations,
      'qc_passed': qcPassed,
    };
  }

  String get statusText {
    switch (status) {
      case 'pending':
        return 'Pendiente';
      case 'released':
        return 'Liberado';
      case 'shipped':
        return 'Enviado';
      case 'cancelled':
        return 'Cancelado';
      default:
        return status;
    }
  }

  ExitRecord copyWith({
    int? id,
    String? folio,
    int? partNumberId,
    int? esdBoxId,
    int? operatorId,
    int? quantity,
    DateTime? inspectionDate,
    String? destination,
    String? status,
    String? observations,
    bool? qcPassed,
  }) {
    return ExitRecord(
      id: id ?? this.id,
      folio: folio ?? this.folio,
      partNumberId: partNumberId ?? this.partNumberId,
      esdBoxId: esdBoxId ?? this.esdBoxId,
      operatorId: operatorId ?? this.operatorId,
      quantity: quantity ?? this.quantity,
      inspectionDate: inspectionDate ?? this.inspectionDate,
      destination: destination ?? this.destination,
      status: status ?? this.status,
      observations: observations ?? this.observations,
      qcPassed: qcPassed ?? this.qcPassed,
    );
  }
}

class ExitRecordStats {
  final int totalRecords;
  final int totalQuantity;
  final int uniqueParts;
  final int released;
  final int pending;
  final int shipped;

  ExitRecordStats({
    this.totalRecords = 0,
    this.totalQuantity = 0,
    this.uniqueParts = 0,
    this.released = 0,
    this.pending = 0,
    this.shipped = 0,
  });

  factory ExitRecordStats.fromJson(Map<String, dynamic> json) {
    return ExitRecordStats(
      totalRecords: json['total_records'] ?? 0,
      totalQuantity: json['total_quantity'] ?? 0,
      uniqueParts: json['unique_parts'] ?? 0,
      released: json['released'] ?? 0,
      pending: json['pending'] ?? 0,
      shipped: json['shipped'] ?? 0,
    );
  }
}
