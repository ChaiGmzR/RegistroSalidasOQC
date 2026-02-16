class OqcRejection {
  final int? id;
  final String? rejectionFolio;
  final int? exitRecordId;
  final int partNumberId;
  final int operatorId;
  final String? employeeId;
  final int expectedQuantity;
  final int actualQuantity;
  final int quantityDifference;
  final String rejectionReason;
  final String? boxCodes;
  final DateTime? rejectionDate;
  final String status;
  final int? correctedBy;
  final DateTime? correctedAt;
  final String? correctionNotes;
  final String? returnFolio;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Campos relacionados (JOINs)
  final String? partNumber;
  final String? model;
  final String? partDescription;
  final String? operatorName;
  final String? correctedByName;
  final String? exitFolio;

  OqcRejection({
    this.id,
    this.rejectionFolio,
    this.exitRecordId,
    required this.partNumberId,
    required this.operatorId,
    this.employeeId,
    required this.expectedQuantity,
    required this.actualQuantity,
    this.quantityDifference = 0,
    required this.rejectionReason,
    this.boxCodes,
    this.rejectionDate,
    this.status = 'pending',
    this.correctedBy,
    this.correctedAt,
    this.correctionNotes,
    this.returnFolio,
    this.createdAt,
    this.updatedAt,
    this.partNumber,
    this.model,
    this.partDescription,
    this.operatorName,
    this.correctedByName,
    this.exitFolio,
  });

  factory OqcRejection.fromJson(Map<String, dynamic> json) {
    return OqcRejection(
      id: json['id'],
      rejectionFolio: json['rejection_folio'],
      exitRecordId: json['exit_record_id'],
      partNumberId: json['part_number_id'] ?? 0,
      operatorId: json['operator_id'] ?? 0,
      employeeId: json['employee_id'],
      expectedQuantity: json['expected_quantity'] ?? 0,
      actualQuantity: json['actual_quantity'] ?? 0,
      quantityDifference: json['quantity_difference'] ?? 0,
      rejectionReason: json['rejection_reason'] ?? '',
      boxCodes: json['box_codes'],
      rejectionDate: json['rejection_date'] != null
          ? DateTime.parse(json['rejection_date'])
          : null,
      status: json['status'] ?? 'pending',
      correctedBy: json['corrected_by'],
      correctedAt: json['corrected_at'] != null
          ? DateTime.parse(json['corrected_at'])
          : null,
      correctionNotes: json['correction_notes'],
      returnFolio: json['return_folio'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      partNumber: json['part_number'],
      model: json['model'],
      partDescription: json['part_description'],
      operatorName: json['operator_name'],
      correctedByName: json['corrected_by_name'],
      exitFolio: json['exit_folio'],
    );
  }

  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'Pendiente';
      case 'in_review':
        return 'En Revisión';
      case 'corrected':
        return 'Corregido';
      case 'returned':
        return 'Devuelto';
      default:
        return status;
    }
  }
}
