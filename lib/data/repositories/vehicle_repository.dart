import '../../domain/models/vehicle.dart';
import '../database/app_database.dart';

class VehicleRepository {
  final AppDatabaseInterface _db;

  VehicleRepository(this._db);

  Future<List<Vehicle>> getAllVehicles() async {
    final maps = await _db.query('vehicles');
    return maps.map((m) => Vehicle.fromMap(m)).toList();
  }

  Future<void> insertVehicle(Vehicle vehicle) async {
    if (vehicle.isDefault) {
      await _clearDefaults();
    }
    await _db.insert('vehicles', vehicle.toMap());
  }

  Future<void> updateVehicle(Vehicle vehicle) async {
    if (vehicle.isDefault) {
      await _clearDefaults();
    }
    await _db.update(
      'vehicles',
      vehicle.toMap(),
      where: 'id = ?',
      whereArgs: [vehicle.id],
    );
  }

  Future<void> deleteVehicle(String id) async {
    await _db.delete(
      'vehicles',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> _clearDefaults() async {
    final vehicles = await getAllVehicles();
    for (var v in vehicles) {
      if (v.isDefault) {
        final updated = Vehicle(
          id: v.id,
          name: v.name,
          mileage: v.mileage,
          defaultFuelPrice: v.defaultFuelPrice,
          isDefault: false,
        );
        await _db.update('vehicles', updated.toMap(), where: 'id = ?', whereArgs: [v.id]);
      }
    }
  }
}
