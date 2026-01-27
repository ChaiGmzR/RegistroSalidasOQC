class Operator {
  final int? id;
  final String employeeId;
  final String name;
  final String pin;
  final bool isSupervisor;
  final String department;
  final bool active;
  final DateTime? createdAt;

  Operator({
    this.id,
    required this.employeeId,
    required this.name,
    this.pin = '0000',
    this.isSupervisor = false,
    this.department = 'OQC',
    this.active = true,
    this.createdAt,
  });

  factory Operator.fromJson(Map<String, dynamic> json) {
    return Operator(
      id: json['id'],
      employeeId: json['employee_id'] ?? '',
      name: json['name'] ?? '',
      pin: json['pin'] ?? '0000',
      isSupervisor: json['is_supervisor'] == 1 || json['is_supervisor'] == true,
      department: json['department'] ?? 'OQC',
      active: json['active'] == 1 || json['active'] == true,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employee_id': employeeId,
      'name': name,
      'pin': pin,
      'is_supervisor': isSupervisor,
      'department': department,
      'active': active,
    };
  }

  @override
  String toString() => '$name ($employeeId)';
}
