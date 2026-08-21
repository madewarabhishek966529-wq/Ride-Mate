class Vehicle {
  final String id;
  final String name;
  final double mileage; // estimated km/L
  final double defaultFuelPrice;
  final bool isDefault;

  Vehicle({
    required this.id,
    required this.name,
    required this.mileage,
    required this.defaultFuelPrice,
    this.isDefault = false,
  });

  Vehicle copyWith({
    String? id,
    String? name,
    double? mileage,
    double? defaultFuelPrice,
    bool? isDefault,
  }) {
    return Vehicle(
      id: id ?? this.id,
      name: name ?? this.name,
      mileage: mileage ?? this.mileage,
      defaultFuelPrice: defaultFuelPrice ?? this.defaultFuelPrice,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'mileage': mileage,
      'defaultFuelPrice': defaultFuelPrice,
      'isDefault': isDefault ? 1 : 0,
    };
  }

  factory Vehicle.fromMap(Map<String, dynamic> map) {
    return Vehicle(
      id: map['id'] as String,
      name: map['name'] as String,
      mileage: (map['mileage'] as num).toDouble(),
      defaultFuelPrice: (map['defaultFuelPrice'] as num).toDouble(),
      isDefault: (map['isDefault'] as int) == 1,
    );
  }
}
