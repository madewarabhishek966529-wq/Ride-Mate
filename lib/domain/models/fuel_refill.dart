class FuelRefill {
  final String id;
  final String vehicleId;
  final DateTime date;
  final double litersAdded;
  final double? pricePerLiter;
  final double? odometerReading;
  final double? cumulativeGpsKmSinceLastRefill;
  final String? notes;

  FuelRefill({
    required this.id,
    required this.vehicleId,
    required this.date,
    required this.litersAdded,
    this.pricePerLiter,
    this.odometerReading,
    this.cumulativeGpsKmSinceLastRefill,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vehicleId': vehicleId,
      'date': date.toIso8601String(),
      'litersAdded': litersAdded,
      'pricePerLiter': pricePerLiter,
      'odometerReading': odometerReading,
      'cumulativeGpsKmSinceLastRefill': cumulativeGpsKmSinceLastRefill,
      'notes': notes,
    };
  }

  factory FuelRefill.fromMap(Map<String, dynamic> map) {
    return FuelRefill(
      id: map['id'] as String,
      vehicleId: map['vehicleId'] as String,
      date: DateTime.parse(map['date'] as String),
      litersAdded: (map['litersAdded'] as num).toDouble(),
      pricePerLiter: map['pricePerLiter'] != null
          ? (map['pricePerLiter'] as num).toDouble()
          : null,
      odometerReading: map['odometerReading'] != null
          ? (map['odometerReading'] as num).toDouble()
          : null,
      cumulativeGpsKmSinceLastRefill:
          map['cumulativeGpsKmSinceLastRefill'] != null
              ? (map['cumulativeGpsKmSinceLastRefill'] as num).toDouble()
              : null,
      notes: map['notes'] as String?,
    );
  }
}
