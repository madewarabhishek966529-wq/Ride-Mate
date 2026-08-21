import 'package:flutter_test/flutter_test.dart';
import 'package:ridemate/domain/models/ride.dart';
import 'package:ridemate/domain/models/settlement_record.dart';
import 'package:ridemate/services/ledger_service.dart';

void main() {
  group('LedgerService Tests', () {
    late LedgerService service;

    setUp(() {
      service = LedgerService();
    });

    test('Friend with zero shared rides shows 0 balance and 0 rides', () {
      final summary = service.calculateFriendBalance(
        friendId: 'f1',
        rides: [],
        settlements: [],
      );

      expect(summary.netBalance, equals(0.0));
      expect(summary.rideCount, equals(0));
      expect(summary.contributingRides, isEmpty);
    });

    test('Balance nets correctly across 3+ rides with mixed Paid By values', () {
      // Ride 1: User paid (ME). Total cost 200, Rahul share = 100. (Rahul owes user +100)
      final ride1 = Ride(
        id: 'r1',
        name: 'Ride 1',
        date: DateTime(2026, 8, 1),
        vehicleId: 'v1',
        vehicleName: 'Bike',
        mileage: 50.0,
        fuelPrice: 100.0,
        distanceKm: 100.0,
        fuelUsedLiters: 2.0,
        totalFuelCost: 200.0,
        trackingMode: 'GPS',
        paidBy: 'ME',
        participantIds: ['ME', 'f1'],
        participantShares: {'ME': 100.0, 'f1': 100.0},
      );

      // Ride 2: User paid (ME). Total cost 300, Rahul share = 150. (Rahul owes user +150)
      final ride2 = Ride(
        id: 'r2',
        name: 'Ride 2',
        date: DateTime(2026, 8, 5),
        vehicleId: 'v1',
        vehicleName: 'Bike',
        mileage: 50.0,
        fuelPrice: 100.0,
        distanceKm: 150.0,
        fuelUsedLiters: 3.0,
        totalFuelCost: 300.0,
        trackingMode: 'Manual',
        paidBy: 'ME',
        participantIds: ['ME', 'f1'],
        participantShares: {'ME': 150.0, 'f1': 150.0},
      );

      // Ride 3: Friend (f1) paid. Total cost 160, User share (ME) = 80. (User owes Rahul -80)
      final ride3 = Ride(
        id: 'r3',
        name: 'Ride 3',
        date: DateTime(2026, 8, 10),
        vehicleId: 'v1',
        vehicleName: 'Bike',
        mileage: 50.0,
        fuelPrice: 100.0,
        distanceKm: 80.0,
        fuelUsedLiters: 1.6,
        totalFuelCost: 160.0,
        trackingMode: 'GPS',
        paidBy: 'f1',
        participantIds: ['ME', 'f1'],
        participantShares: {'ME': 80.0, 'f1': 80.0},
      );

      // Gross = +100 + 150 - 80 = +170
      final summary = service.calculateFriendBalance(
        friendId: 'f1',
        rides: [ride1, ride2, ride3],
        settlements: [],
      );

      expect(summary.rideCount, equals(3));
      expect(summary.netBalance, equals(170.0));
    });

    test('Balance updates correctly after a Mark as Settled entry', () {
      final ride1 = Ride(
        id: 'r1',
        name: 'Ride 1',
        date: DateTime(2026, 8, 1),
        vehicleId: 'v1',
        vehicleName: 'Bike',
        mileage: 50.0,
        fuelPrice: 100.0,
        distanceKm: 100.0,
        fuelUsedLiters: 2.0,
        totalFuelCost: 200.0,
        trackingMode: 'GPS',
        paidBy: 'ME',
        participantIds: ['ME', 'f1'],
        participantShares: {'ME': 100.0, 'f1': 100.0},
      );

      // Before settlement: Rahul owes 100
      final summaryBefore = service.calculateFriendBalance(
        friendId: 'f1',
        rides: [ride1],
        settlements: [],
      );
      expect(summaryBefore.netBalance, equals(100.0));

      // After Mark as Settled (SettlementRecord for 100)
      final settlement = SettlementRecord(
        id: 's1',
        friendId: 'f1',
        amount: 100.0,
        date: DateTime(2026, 8, 2),
      );

      final summaryAfter = service.calculateFriendBalance(
        friendId: 'f1',
        rides: [ride1],
        settlements: [settlement],
      );

      expect(summaryAfter.netBalance, equals(0.0));
    });
  });
}
