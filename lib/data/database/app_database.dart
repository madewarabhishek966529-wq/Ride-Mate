import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static Database? _db;

  static Future<Database> get instance async {
    if (_db != null) return _db!;
    _db = await _initDb('ridemate.db');
    return _db!;
  }

  static Future<Database> initInMemory() async {
    final db = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: _onCreate,
    );
    _db = db;
    return db;
  }

  static Future<Database> _initDb(String filePath) async {
    if (kIsWeb) {
      return await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: _onCreate,
      );
    }
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE vehicles (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        mileage REAL NOT NULL,
        defaultFuelPrice REAL NOT NULL,
        isDefault INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE friends (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE fuel_refills (
        id TEXT PRIMARY KEY,
        vehicleId TEXT NOT NULL,
        date TEXT NOT NULL,
        litersAdded REAL NOT NULL,
        pricePerLiter REAL,
        odometerReading REAL,
        cumulativeGpsKmSinceLastRefill REAL,
        notes TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE rides (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        date TEXT NOT NULL,
        vehicleId TEXT NOT NULL,
        vehicleName TEXT NOT NULL,
        mileage REAL NOT NULL,
        fuelPrice REAL NOT NULL,
        distanceKm REAL NOT NULL,
        fuelUsedLiters REAL NOT NULL,
        totalFuelCost REAL NOT NULL,
        trackingMode TEXT NOT NULL,
        paidBy TEXT NOT NULL,
        participantIds TEXT NOT NULL,
        participantShares TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE settlements (
        id TEXT PRIMARY KEY,
        friendId TEXT NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL
      )
    ''');

    await db.insert('vehicles', {
      'id': 'default-vehicle-1',
      'name': 'Default Bike',
      'mileage': 45.0,
      'defaultFuelPrice': 100.0,
      'isDefault': 1,
    });
  }

  static Future<void> resetForTesting() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }
}
