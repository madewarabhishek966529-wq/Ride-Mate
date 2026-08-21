import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ridemate/data/database/app_database.dart';
import 'package:ridemate/providers/providers.dart';
import 'package:ridemate/main.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('RideMate App Smoke Test', (WidgetTester tester) async {
    final db = await AppDatabase.initInMemory();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
        child: const RideMateApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Verify home screen bottom navigation elements
    expect(find.text('Rides'), findsWidgets);
    expect(find.text('Vehicles'), findsWidgets);
    expect(find.text('Friends'), findsWidgets);
  });
}
