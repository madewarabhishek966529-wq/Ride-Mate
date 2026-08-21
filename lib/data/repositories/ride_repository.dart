import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';
import '../../domain/models/ride.dart';

class RideRepository {
  final AppDatabaseInterface _db;

  RideRepository(this._db);

  Future<List<Ride>> getAllRides() async {
    final maps = await _db.query('rides', orderBy: 'date DESC');
    return maps.map((m) => Ride.fromMap(m)).toList();
  }

  Future<List<Ride>> getRidesByVehicle(String vehicleId) async {
    final maps = await _db.query(
      'rides',
      where: 'vehicleId = ?',
      whereArgs: [vehicleId],
      orderBy: 'date ASC',
    );
    return maps.map((m) => Ride.fromMap(m)).toList();
  }

  Future<List<Ride>> getRidesByDateRange(DateTime start, DateTime end, {String? vehicleId}) async {
    final startIso = start.toIso8601String();
    final endIso = end.toIso8601String();

    if (vehicleId != null && vehicleId.isNotEmpty) {
      final maps = await _db.query(
        'rides',
        where: 'date >= ? AND date <= ? AND vehicleId = ?',
        whereArgs: [startIso, endIso, vehicleId],
        orderBy: 'date DESC',
      );
      return maps.map((m) => Ride.fromMap(m)).toList();
    } else {
      final maps = await _db.query(
        'rides',
        where: 'date >= ? AND date <= ?',
        whereArgs: [startIso, endIso],
        orderBy: 'date DESC',
      );
      return maps.map((m) => Ride.fromMap(m)).toList();
    }
  }

  Future<void> insertRide(Ride ride) async {
    await _db.insert(
      'rides',
      ride.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteRide(String id) async {
    await _db.delete('rides', where: 'id = ?', whereArgs: [id]);
  }
}
