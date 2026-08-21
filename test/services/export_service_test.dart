import 'package:flutter_test/flutter_test.dart';
import 'package:ridemate/domain/models/ride.dart';
import 'package:ridemate/services/export_service.dart';

void main() {
  group('ExportService Tests', () {
    late ExportService service;

    setUp(() {
      service = ExportService();
    });

    final testRides = [
      Ride(
        id: 'r1',
        name: 'Ride 1',
        date: DateTime(2026, 8, 5),
        vehicleId: 'v1',
        vehicleName: 'Bike 1',
        mileage: 50.0,
        fuelPrice: 100.0,
        distanceKm: 50.0,
        fuelUsedLiters: 1.0,
        totalFuelCost: 100.0,
        trackingMode: 'GPS',
        paidBy: 'ME',
        participantIds: ['ME'],
        participantShares: {'ME': 100.0},
      ),
      Ride(
        id: 'r2',
        name: 'Ride 2',
        date: DateTime(2026, 8, 10),
        vehicleId: 'v2',
        vehicleName: 'Car 1',
        mileage: 15.0,
        fuelPrice: 100.0,
        distanceKm: 30.0,
        fuelUsedLiters: 2.0,
        totalFuelCost: 200.0,
        trackingMode: 'Manual',
        paidBy: 'ME',
        participantIds: ['ME'],
        participantShares: {'ME': 200.0},
      ),
    ];

    test('CSV export row count matches ride count plus header', () {
      final csvContent = service.generateCsvContent(testRides, {});
      final lines = csvContent.trim().split('\n');

      // 1 header row + 2 ride rows = 3 lines total
      expect(lines.length, equals(3));
    });

    test('PDF generation short-circuits on zero-ride range without crashing', () async {
      final pdfBytes = await service.generatePdfContent(
        rides: [],
        startDate: DateTime(2026, 8, 1),
        endDate: DateTime(2026, 8, 31),
        friendNames: {},
      );

      expect(pdfBytes, isEmpty);
    });

    test('Export respects vehicle filter when filtering ride list', () {
      final v1Rides = testRides.where((r) => r.vehicleId == 'v1').toList();
      expect(v1Rides.length, equals(1));

      final csvContent = service.generateCsvContent(v1Rides, {});
      final lines = csvContent.trim().split('\n');
      expect(lines.length, equals(2)); // Header + 1 row
      expect(lines[1], contains('Bike 1'));
    });
  });
}
