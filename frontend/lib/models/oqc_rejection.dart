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
  final int itemCount;
  final int rejectedCount;
  final int approvedCount;
  final int releasedCount;

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
    this.itemCount = 0,
    this.rejectedCount = 0,
    this.approvedCount = 0,
    this.releasedCount = 0,
  });

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
  }

  factory OqcRejection.fromJson(Map<String, dynamic> json) {
    return OqcRejection(
      id: json['id'],
      rejectionFolio: json['rejection_folio'],
      exitRecordId: json['exit_record_id'],
      partNumberId: json['part_number_id'] ?? 0,
      operatorId: json['operator_id'] ?? 0,
      employeeId: json['employee_id'],
      expectedQuantity: _toInt(json['expected_quantity']),
      actualQuantity: _toInt(json['actual_quantity']),
      quantityDifference: _toInt(json['quantity_difference']),
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
      itemCount: _toInt(json['item_count']),
      rejectedCount: _toInt(json['rejected_count']),
      approvedCount: _toInt(json['approved_count']),
      releasedCount: _toInt(json['released_count']),
    );
  }

  String get statusLabel {
    switch (status) {
      case 'rejected':
      case 'pending':
      case 'in_review':
        return 'Rechazado';
      case 'approved':
      case 'corrected':
        return 'Aprobado';
      case 'partial_approved':
        return 'Aprobado Parcial';
      case 'released':
      case 'returned':
        return 'Liberado';
      default:
        return status;
    }
  }

  int get displayQuantity => itemCount > 0 ? itemCount : actualQuantity;

  bool get canApprove {
    return status == 'rejected' ||
        status == 'partial_approved' ||
        status == 'pending' ||
        status == 'in_review';
  }
}

class OqcRejectionItem {
  final int id;
  final int rejectionId;
  final String serial;
  final String originalBoxCode;
  final String? partNumber;
  final String status;
  final int? approvedBy;
  final DateTime? approvedAt;
  final DateTime? releasedAt;
  final String? releaseFolio;
  final String? approvedByName;

  OqcRejectionItem({
    required this.id,
    required this.rejectionId,
    required this.serial,
    required this.originalBoxCode,
    this.partNumber,
    required this.status,
    this.approvedBy,
    this.approvedAt,
    this.releasedAt,
    this.releaseFolio,
    this.approvedByName,
  });

  factory OqcRejectionItem.fromJson(Map<String, dynamic> json) {
    return OqcRejectionItem(
      id: OqcRejection._toInt(json['id']),
      rejectionId: OqcRejection._toInt(json['rejection_id']),
      serial: json['serial'] ?? '',
      originalBoxCode: json['original_box_code'] ?? '',
      partNumber: json['part_number'],
      status: json['status'] ?? 'rejected',
      approvedBy: json['approved_by'],
      approvedAt: json['approved_at'] != null
          ? DateTime.parse(json['approved_at'])
          : null,
      releasedAt: json['released_at'] != null
          ? DateTime.parse(json['released_at'])
          : null,
      releaseFolio: json['release_folio'],
      approvedByName: json['approved_by_name'],
    );
  }

  String get statusLabel {
    switch (status) {
      case 'approved':
        return 'Aprobada';
      case 'released':
        return 'Liberada';
      default:
        return 'Rechazada';
    }
  }

  bool get canApprove => status != 'released';
}

class OqcRejectionDetails {
  final OqcRejection rejection;
  final List<OqcRejectionItem> items;

  OqcRejectionDetails({
    required this.rejection,
    required this.items,
  });

  factory OqcRejectionDetails.fromJson(Map<String, dynamic> json) {
    return OqcRejectionDetails(
      rejection: OqcRejection.fromJson(json['rejection'] ?? {}),
      items: ((json['items'] ?? []) as List)
          .map((item) => OqcRejectionItem.fromJson(item))
          .toList(),
    );
  }

  Map<String, List<OqcRejectionItem>> get groupedByBox {
    final grouped = <String, List<OqcRejectionItem>>{};
    for (final item in items) {
      grouped.putIfAbsent(item.originalBoxCode, () => []).add(item);
    }
    return grouped;
  }

  int get rejectedCount =>
      items.where((item) => item.status == 'rejected').length;
  int get approvedCount =>
      items.where((item) => item.status == 'approved').length;
  int get releasedCount =>
      items.where((item) => item.status == 'released').length;
}
