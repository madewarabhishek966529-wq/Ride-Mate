import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ridemate/data/database/app_database.dart';
import 'package:ridemate/data/repositories/ride_repository.dart';
import 'package:ridemate/domain/models/ride.dart';
import 'package:ridemate/providers/providers.dart';
import 'package:ridemate/ui/rides/ride_history_screen.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('RideHistoryScreen displays travel stats and deletes ride', (WidgetTester tester) async {
    final db = await AppDatabase.initInMemory();

    // Insert sample ride
    final repo = RideRepository(db);
    final ride1 = Ride(
      id: 'test-ride-1',
      name: 'Weekend Trip',
      date: DateTime.now(),
      vehicleId: 'default-vehicle-1',
      vehicleName: 'Default Bike',
      mileage: 45.0,
      fuelPrice: 100.0,
      distanceKm: 50.0,
      fuelUsedLiters: 1.11,
      totalFuelCost: 111.0,
      trackingMode: 'Manual',
      paidBy: 'ME',
      participantIds: ['ME'],
      participantShares: {'ME': 111.0},
      routePoints: [
        {'lat': 28.6139, 'lng': 77.2090},
        {'lat': 28.7041, 'lng': 77.1025},
      ],
    );
    await repo.insertRide(ride1);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
        child: const MaterialApp(
          home: RideHistoryScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Summary Banner
    expect(find.text('Total Travel History'), findsOneWidget);
    expect(find.text('50.0 km'), findsOneWidget);
    expect(find.text('Weekend Trip'), findsOneWidget);
    expect(find.text('View Route Map'), findsOneWidget);

    // Verify Delete Dialog flow
    final deleteIcon = find.byIcon(Icons.delete_outline);
    expect(deleteIcon, findsOneWidget);
    await tester.tap(deleteIcon);
    await tester.pumpAndSettle();

    // Confirm dialog title
    expect(find.text('Delete Ride'), findsOneWidget);
    final confirmDeleteButton = find.widgetWithText(ElevatedButton, 'Delete');
    await tester.tap(confirmDeleteButton);
    await tester.pumpAndSettle();

    // Verify Ride is removed
    expect(find.text('Weekend Trip'), findsNothing);
    expect(find.text('No Rides Tracked Yet'), findsOneWidget);
  });
}
