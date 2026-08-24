import 'dart:convert';

class Ride {
  final String id;
  final String name;
  final DateTime date;
  final String vehicleId;
  final String vehicleName;
  final double mileage; // saved snapshot at ride time
  final double fuelPrice; // saved snapshot at ride time
  final double distanceKm;
  final double fuelUsedLiters;
  final double totalFuelCost;
  final String trackingMode; // 'GPS' or 'Manual'
  final bool isRoundTrip;
  final int stopCount;
  final String paidBy; // 'ME' or friendId
  final List<String> participantIds;
  final Map<String, double> participantShares; // participantId -> amount
  final List<Map<String, double>> routePoints; // [{'lat': 28.6, 'lng': 77.2}, ...]

  Ride({
    required this.id,
    required this.name,
    required this.date,
    required this.vehicleId,
    required this.vehicleName,
    required this.mileage,
    required this.fuelPrice,
    required this.distanceKm,
    required this.fuelUsedLiters,
    required this.totalFuelCost,
    required this.trackingMode,
    this.isRoundTrip = false,
    this.stopCount = 1,
    required this.paidBy,
    required this.participantIds,
    required this.participantShares,
    this.routePoints = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'date': date.toIso8601String(),
      'vehicleId': vehicleId,
      'vehicleName': vehicleName,
      'mileage': mileage,
      'fuelPrice': fuelPrice,
      'distanceKm': distanceKm,
      'fuelUsedLiters': fuelUsedLiters,
      'totalFuelCost': totalFuelCost,
      'trackingMode': trackingMode,
      'isRoundTrip': isRoundTrip ? 1 : 0,
      'stopCount': stopCount,
      'paidBy': paidBy,
      'participantIds': jsonEncode(participantIds),
      'participantShares': jsonEncode(participantShares),
      'routePoints': jsonEncode(routePoints),
    };
  }

  factory Ride.fromMap(Map<String, dynamic> map) {
    final rawShares = jsonDecode(map['participantShares'] as String) as Map<String, dynamic>;
    final shares = rawShares.map((k, v) => MapEntry(k, (v as num).toDouble()));

    List<Map<String, double>> parsedRoutePoints = [];
    if (map['routePoints'] != null && map['routePoints'] is String && (map['routePoints'] as String).isNotEmpty) {
      try {
        final rawList = jsonDecode(map['routePoints'] as String) as List;
        parsedRoutePoints = rawList.map((item) {
          final m = item as Map<String, dynamic>;
          return {
            'lat': (m['lat'] as num).toDouble(),
            'lng': (m['lng'] as num).toDouble(),
          };
        }).toList();
      } catch (_) {}
    }

    return Ride(
      id: map['id'] as String,
      name: map['name'] as String,
      date: DateTime.parse(map['date'] as String),
      vehicleId: map['vehicleId'] as String,
      vehicleName: map['vehicleName'] as String,
      mileage: (map['mileage'] as num).toDouble(),
      fuelPrice: (map['fuelPrice'] as num).toDouble(),
      distanceKm: (map['distanceKm'] as num).toDouble(),
      fuelUsedLiters: (map['fuelUsedLiters'] as num).toDouble(),
      totalFuelCost: (map['totalFuelCost'] as num).toDouble(),
      trackingMode: map['trackingMode'] as String,
      isRoundTrip: (map['isRoundTrip'] as int?) == 1,
      stopCount: (map['stopCount'] as int?) ?? 1,
      paidBy: map['paidBy'] as String,
      participantIds: List<String>.from(jsonDecode(map['participantIds'] as String) as List),
      participantShares: shares,
      routePoints: parsedRoutePoints,
    );
  }
}
