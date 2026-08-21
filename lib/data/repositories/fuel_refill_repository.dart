import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';
import '../../domain/models/fuel_refill.dart';

class FuelRefillRepository {
  final AppDatabaseInterface _db;

  FuelRefillRepository(this._db);

  Future<List<FuelRefill>> getRefillsForVehicle(String vehicleId) async {
    final maps = await _db.query(
      'fuel_refills',
      where: 'vehicleId = ?',
      whereArgs: [vehicleId],
      orderBy: 'date ASC',
    );
    return maps.map((m) => FuelRefill.fromMap(m)).toList();
  }

  Future<List<FuelRefill>> getAllRefills() async {
    final maps = await _db.query('fuel_refills', orderBy: 'date DESC');
    return maps.map((m) => FuelRefill.fromMap(m)).toList();
  }

  Future<void> insertRefill(FuelRefill refill) async {
    await _db.insert(
      'fuel_refills',
      refill.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteRefill(String id) async {
    await _db.delete('fuel_refills', where: 'id = ?', whereArgs: [id]);
  }
}
