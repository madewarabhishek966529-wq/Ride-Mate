import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

abstract class AppDatabaseInterface {
  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
  });

  Future<int> insert(
    String table,
    Map<String, dynamic> values, {
    ConflictAlgorithm? conflictAlgorithm,
  });

  Future<int> update(
    String table,
    Map<String, dynamic> values, {
    String? where,
    List<Object?>? whereArgs,
  });

  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  });
}

class SqfliteDatabaseAdapter implements AppDatabaseInterface {
  final Database _db;
  SqfliteDatabaseAdapter(this._db);

  @override
  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
  }) {
    return _db.query(table, where: where, whereArgs: whereArgs, orderBy: orderBy);
  }

  @override
  Future<int> insert(
    String table,
    Map<String, dynamic> values, {
    ConflictAlgorithm? conflictAlgorithm,
  }) {
    return _db.insert(table, values, conflictAlgorithm: conflictAlgorithm);
  }

  @override
  Future<int> update(
    String table,
    Map<String, dynamic> values, {
    String? where,
    List<Object?>? whereArgs,
  }) {
    return _db.update(table, values, where: where, whereArgs: whereArgs);
  }

  @override
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) {
    return _db.delete(table, where: where, whereArgs: whereArgs);
  }
}

class InMemoryDatabaseAdapter implements AppDatabaseInterface {
  final Map<String, List<Map<String, dynamic>>> _tables = {};

  InMemoryDatabaseAdapter() {
    _seedDefaultData();
  }

  void _seedDefaultData() {
    _tables['vehicles'] = [
      {
        'id': 'default-vehicle-1',
        'name': 'Default Bike',
        'mileage': 45.0,
        'defaultFuelPrice': 100.0,
        'isDefault': 1,
      }
    ];
    _tables['friends'] = [];
    _tables['fuel_refills'] = [];
    _tables['rides'] = [];
    _tables['settlements'] = [];
  }

  @override
  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
  }) async {
    final list = _tables[table] ?? [];
    List<Map<String, dynamic>> results = list.map((m) => Map<String, dynamic>.from(m)).toList();

    if (where != null && whereArgs != null) {
      if (where.contains('id = ?')) {
        final targetId = whereArgs[0] as String;
        results = results.where((m) => m['id'] == targetId).toList();
      } else if (where.contains('vehicleId = ?')) {
        final targetId = whereArgs[0] as String;
        results = results.where((m) => m['vehicleId'] == targetId).toList();
      } else if (where.contains('friendId = ?')) {
        final targetId = whereArgs[0] as String;
        results = results.where((m) => m['friendId'] == targetId).toList();
      } else if (where.contains('isDefault = 1')) {
        results = results.where((m) => m['isDefault'] == 1).toList();
      } else if (where.contains('date >= ? AND date <= ?')) {
        final start = whereArgs[0] as String;
        final end = whereArgs[1] as String;
        results = results.where((m) {
          final d = m['date'] as String;
          return d.compareTo(start) >= 0 && d.compareTo(end) <= 0;
        }).toList();
        if (where.contains('vehicleId = ?') && whereArgs.length > 2) {
          final vId = whereArgs[2] as String;
          results = results.where((m) => m['vehicleId'] == vId).toList();
        }
      }
    }

    if (orderBy != null) {
      if (orderBy.contains('date ASC')) {
        results.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
      } else if (orderBy.contains('date DESC')) {
        results.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));
      } else if (orderBy.contains('name ASC')) {
        results.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
      }
    }

    return results;
  }

  @override
  Future<int> insert(
    String table,
    Map<String, dynamic> values, {
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    _tables.putIfAbsent(table, () => []);
    final list = _tables[table]!;

    final id = values['id'];
    if (id != null) {
      list.removeWhere((item) => item['id'] == id);
    }

    if (values['isDefault'] == 1) {
      for (var item in list) {
        item['isDefault'] = 0;
      }
    }

    list.add(Map<String, dynamic>.from(values));
    return 1;
  }

  @override
  Future<int> update(
    String table,
    Map<String, dynamic> values, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final list = _tables[table] ?? [];
    int updatedCount = 0;

    if (values['isDefault'] == 1) {
      for (var item in list) {
        item['isDefault'] = 0;
      }
    }

    final targetId = whereArgs != null && whereArgs.isNotEmpty ? whereArgs[0] as String : null;

    for (var i = 0; i < list.length; i++) {
      if (targetId == null || list[i]['id'] == targetId) {
        list[i] = {...list[i], ...values};
        updatedCount++;
      }
    }

    return updatedCount;
  }

  @override
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final list = _tables[table] ?? [];
    final targetId = whereArgs != null && whereArgs.isNotEmpty ? whereArgs[0] as String : null;
    int initialLength = list.length;

    if (targetId != null) {
      list.removeWhere((m) => m['id'] == targetId);
    } else {
      list.clear();
    }

    return initialLength - list.length;
  }
}

class AppDatabase {
  static AppDatabaseInterface? _adapter;

  static Future<AppDatabaseInterface> get instance async {
    if (_adapter != null) return _adapter!;

    if (kIsWeb) {
      _adapter = InMemoryDatabaseAdapter();
      return _adapter!;
    }

    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'ridemate.db');
      final db = await openDatabase(
        path,
        version: 2,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        onOpen: _onOpen,
      );
      _adapter = SqfliteDatabaseAdapter(db);
    } catch (e) {
      _adapter = InMemoryDatabaseAdapter();
    }
    return _adapter!;
  }

  static Future<AppDatabaseInterface> initInMemory() async {
    _adapter = InMemoryDatabaseAdapter();
    return _adapter!;
  }

  static Future<void> _onOpen(Database db) async {
    try {
      await db.execute('ALTER TABLE rides ADD COLUMN isRoundTrip INTEGER DEFAULT 0;');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE rides ADD COLUMN stopCount INTEGER DEFAULT 1;');
    } catch (_) {}
  }

  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute('ALTER TABLE rides ADD COLUMN isRoundTrip INTEGER DEFAULT 0;');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE rides ADD COLUMN stopCount INTEGER DEFAULT 1;');
      } catch (_) {}
    }
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
        isRoundTrip INTEGER DEFAULT 0,
        stopCount INTEGER DEFAULT 1,
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
    _adapter = null;
  }
}
