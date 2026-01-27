class EsdBox {
  final int? id;
  final String boxCode;
  final int capacity;
  final String? description;
  final bool active;
  final DateTime? createdAt;

  EsdBox({
    this.id,
    required this.boxCode,
    required this.capacity,
    this.description,
    this.active = true,
    this.createdAt,
  });

  factory EsdBox.fromJson(Map<String, dynamic> json) {
    return EsdBox(
      id: json['id'],
      boxCode: json['box_code'] ?? '',
      capacity: json['capacity'] ?? 0,
      description: json['description'],
      active: json['active'] == 1 || json['active'] == true,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'box_code': boxCode,
      'capacity': capacity,
      'description': description,
      'active': active,
    };
  }

  @override
  String toString() => '$boxCode (Cap: $capacity)';
}
