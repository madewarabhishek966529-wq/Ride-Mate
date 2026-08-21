import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';
import '../../domain/models/vehicle.dart';

class VehicleRepository {
  final AppDatabaseInterface _db;

  VehicleRepository(this._db);

  Future<List<Vehicle>> getAllVehicles() async {
    final maps = await _db.query('vehicles');
    return maps.map((m) => Vehicle.fromMap(m)).toList();
  }

  Future<Vehicle?> getVehicleById(String id) async {
    final maps = await _db.query('vehicles', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Vehicle.fromMap(maps.first);
  }

  Future<Vehicle?> getDefaultVehicle() async {
    final maps = await _db.query('vehicles', where: 'isDefault = 1');
    if (maps.isNotEmpty) return Vehicle.fromMap(maps.first);
    final all = await getAllVehicles();
    return all.isNotEmpty ? all.first : null;
  }

  Future<void> insertVehicle(Vehicle vehicle) async {
    if (vehicle.isDefault) {
      await _db.update('vehicles', {'isDefault': 0});
    }
    await _db.insert(
      'vehicles',
      vehicle.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateVehicle(Vehicle vehicle) async {
    if (vehicle.isDefault) {
      await _db.update('vehicles', {'isDefault': 0});
    }
    await _db.update(
      'vehicles',
      vehicle.toMap(),
      where: 'id = ?',
      whereArgs: [vehicle.id],
    );
  }

  Future<void> deleteVehicle(String id) async {
    await _db.delete('vehicles', where: 'id = ?', whereArgs: [id]);
  }
}
