import 'package:flutter_test/flutter_test.dart';
import 'package:ridemate/domain/models/fuel_refill.dart';
import 'package:ridemate/domain/models/ride.dart';
import 'package:ridemate/services/mileage_analysis_service.dart';

void main() {
  group('MileageAnalysisService Tests', () {
    late MileageAnalysisService service;

    setUp(() {
      service = MileageAnalysisService();
    });

    test('Returns null when fewer than 2 refills exist', () {
      final refills = [
        FuelRefill(
          id: 'refill-1',
          vehicleId: 'v1',
          date: DateTime(2026, 8, 1),
          litersAdded: 10.0,
        ),
      ];
      final rides = <Ride>[];

      final actualMileage = service.calculateActualMileage(refills, rides);
      expect(actualMileage, isNull);
    });

    test('Actual mileage calculation with 2 refills and 2 GPS rides in between (summed GPS fallback)', () {
      final r1 = FuelRefill(
        id: 'r1',
        vehicleId: 'v1',
        date: DateTime(2026, 8, 1, 10, 0),
        litersAdded: 10.0,
        odometerReading: null, // missing odometer
      );

      final r2 = FuelRefill(
        id: 'r2',
        vehicleId: 'v1',
        date: DateTime(2026, 8, 10, 10, 0),
        litersAdded: 10.0, // 10 liters added at second refill
        odometerReading: null,
      );

      final ride1 = Ride(
        id: 'ride1',
        name: 'Ride 1',
        date: DateTime(2026, 8, 3),
        vehicleId: 'v1',
        vehicleName: 'Bike',
        mileage: 50.0,
        fuelPrice: 100.0,
        distanceKm: 250.0,
        fuelUsedLiters: 5.0,
        totalFuelCost: 500.0,
        trackingMode: 'GPS',
        paidBy: 'ME',
        participantIds: ['ME'],
        participantShares: {'ME': 500.0},
      );

      final ride2 = Ride(
        id: 'ride2',
        name: 'Ride 2',
        date: DateTime(2026, 8, 7),
        vehicleId: 'v1',
        vehicleName: 'Bike',
        mileage: 50.0,
        fuelPrice: 100.0,
        distanceKm: 268.0,
        fuelUsedLiters: 5.36,
        totalFuelCost: 536.0,
        trackingMode: 'GPS',
        paidBy: 'ME',
        participantIds: ['ME'],
        participantShares: {'ME': 536.0},
      );

      // Total distance = 250 + 268 = 518 km
      // Liters added at 2nd refill = 10 L
      // Actual mileage = 518 / 10 = 51.8 km/L
      final actualMileage = service.calculateActualMileage([r1, r2], [ride1, ride2]);
      expect(actualMileage, equals(51.8));
    });

    test('Actual mileage prefers odometer delta over GPS rides when odometer readings present', () {
      final r1 = FuelRefill(
        id: 'r1',
        vehicleId: 'v1',
        date: DateTime(2026, 8, 1, 10, 0),
        litersAdded: 10.0,
        odometerReading: 1000.0,
      );

      final r2 = FuelRefill(
        id: 'r2',
        vehicleId: 'v1',
        date: DateTime(2026, 8, 10, 10, 0),
        litersAdded: 10.0,
        odometerReading: 1550.0, // Odometer delta = 550 km
      );

      // Odometer delta = 550 km, liters added = 10 L -> 55.0 km/L
      final actualMileage = service.calculateActualMileage([r1, r2], []);
      expect(actualMileage, equals(55.0));
    });
  });
}
