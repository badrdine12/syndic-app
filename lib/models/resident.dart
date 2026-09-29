class Resident {
  final int? id;
  final String apartmentNumber;
  final String fullName;
  final String phone;

  Resident({
    this.id,
    required this.apartmentNumber,
    required this.fullName,
    required this.phone,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'apartment_number': apartmentNumber,
      'full_name': fullName,
      'phone': phone,
    };
  }

  factory Resident.fromMap(Map<String, dynamic> map) {
    return Resident(
      id: map['id'] as int?,
      apartmentNumber: map['apartment_number']?.toString() ?? '',
      fullName: map['full_name']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
    );
  }

  Resident copyWith({
    int? id,
    String? apartmentNumber,
    String? fullName,
    String? phone,
  }) {
    return Resident(
      id: id ?? this.id,
      apartmentNumber: apartmentNumber ?? this.apartmentNumber,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
    );
  }
}