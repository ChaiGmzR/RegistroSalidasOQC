class PartNumber {
  final int? id;
  final String partNumber;
  final String? description;
  final int standardPack;
  final String? model;
  final String customer;
  final bool active;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  PartNumber({
    this.id,
    required this.partNumber,
    this.description,
    required this.standardPack,
    this.model,
    this.customer = 'LG',
    this.active = true,
    this.createdAt,
    this.updatedAt,
  });

  factory PartNumber.fromJson(Map<String, dynamic> json) {
    return PartNumber(
      id: json['id'],
      partNumber: json['part_number'] ?? '',
      description: json['description'],
      standardPack: json['standard_pack'] ?? 10,
      model: json['model'],
      customer: json['customer'] ?? 'LG',
      active: json['active'] == 1 || json['active'] == true,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : null,
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'part_number': partNumber,
      'description': description,
      'standard_pack': standardPack,
      'model': model,
      'customer': customer,
      'active': active,
    };
  }

  PartNumber copyWith({
    int? id,
    String? partNumber,
    String? description,
    int? standardPack,
    String? model,
    String? customer,
    bool? active,
  }) {
    return PartNumber(
      id: id ?? this.id,
      partNumber: partNumber ?? this.partNumber,
      description: description ?? this.description,
      standardPack: standardPack ?? this.standardPack,
      model: model ?? this.model,
      customer: customer ?? this.customer,
      active: active ?? this.active,
    );
  }
}
