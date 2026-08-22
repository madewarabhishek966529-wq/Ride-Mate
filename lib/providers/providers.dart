import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/database/app_database.dart';
import '../data/repositories/friend_repository.dart';
import '../data/repositories/ride_repository.dart';
import '../data/repositories/settlement_repository.dart';
import '../data/repositories/vehicle_repository.dart';
import '../domain/models/friend.dart';
import '../domain/models/ride.dart';
import '../domain/models/settlement_record.dart';
import '../domain/models/vehicle.dart';
import '../services/distance_calculation_service.dart';
import '../services/export_service.dart';
import '../services/fuel_calculation_service.dart';
import '../services/ledger_service.dart';
import '../services/split_calculation_service.dart';

// Database Provider
final databaseProvider = Provider<AppDatabaseInterface>((ref) {
  throw UnimplementedError('Database provider must be overridden in main with initialized db');
});

// Repositories
final vehicleRepositoryProvider = Provider<VehicleRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return VehicleRepository(db);
});

final friendRepositoryProvider = Provider<FriendRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return FriendRepository(db);
});

final rideRepositoryProvider = Provider<RideRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return RideRepository(db);
});

final settlementRepositoryProvider = Provider<SettlementRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return SettlementRepository(db);
});

// Services
final distanceCalculationServiceProvider = Provider<DistanceCalculationService>((ref) {
  return DistanceCalculationService();
});

final fuelCalculationServiceProvider = Provider<FuelCalculationService>((ref) {
  return FuelCalculationService();
});

final splitCalculationServiceProvider = Provider<SplitCalculationService>((ref) {
  return SplitCalculationService();
});

final ledgerServiceProvider = Provider<LedgerService>((ref) {
  return LedgerService();
});

final exportServiceProvider = Provider<ExportService>((ref) {
  return ExportService();
});

// Vehicles / Bikes Notifier
class VehicleListNotifier extends StateNotifier<List<Vehicle>> {
  final VehicleRepository _repo;

  VehicleListNotifier(this._repo) : super([]) {
    loadVehicles();
  }

  Future<void> loadVehicles() async {
    final vehicles = await _repo.getAllVehicles();
    state = vehicles;
  }

  Future<void> addVehicle(Vehicle vehicle) async {
    await _repo.insertVehicle(vehicle);
    await loadVehicles();
  }

  Future<void> updateVehicle(Vehicle vehicle) async {
    await _repo.updateVehicle(vehicle);
    await loadVehicles();
  }

  Future<void> deleteVehicle(String id) async {
    await _repo.deleteVehicle(id);
    await loadVehicles();
  }
}

final vehicleListProvider = StateNotifierProvider<VehicleListNotifier, List<Vehicle>>((ref) {
  final repo = ref.watch(vehicleRepositoryProvider);
  return VehicleListNotifier(repo);
});

// Friends Notifier
class FriendListNotifier extends StateNotifier<List<Friend>> {
  final FriendRepository _repo;

  FriendListNotifier(this._repo) : super([]) {
    loadFriends();
  }

  Future<void> loadFriends() async {
    final friends = await _repo.getAllFriends();
    state = friends;
  }

  Future<void> addFriend(Friend friend) async {
    await _repo.insertFriend(friend);
    await loadFriends();
  }

  Future<void> deleteFriend(String id) async {
    await _repo.deleteFriend(id);
    await loadFriends();
  }
}

final friendListProvider = StateNotifierProvider<FriendListNotifier, List<Friend>>((ref) {
  final repo = ref.watch(friendRepositoryProvider);
  return FriendListNotifier(repo);
});

// Rides Notifier
class RideListNotifier extends StateNotifier<List<Ride>> {
  final RideRepository _repo;

  RideListNotifier(this._repo) : super([]) {
    loadRides();
  }

  Future<void> loadRides() async {
    final rides = await _repo.getAllRides();
    state = rides;
  }

  Future<void> addRide(Ride ride) async {
    await _repo.insertRide(ride);
    await loadRides();
  }
}

final rideListProvider = StateNotifierProvider<RideListNotifier, List<Ride>>((ref) {
  final repo = ref.watch(rideRepositoryProvider);
  return RideListNotifier(repo);
});

// Settlements Notifier
class SettlementListNotifier extends StateNotifier<List<SettlementRecord>> {
  final SettlementRepository _repo;

  SettlementListNotifier(this._repo) : super([]) {
    loadSettlements();
  }

  Future<void> loadSettlements() async {
    final list = await _repo.getAllSettlements();
    state = list;
  }

  Future<void> addSettlement(SettlementRecord record) async {
    await _repo.insertSettlement(record);
    await loadSettlements();
  }
}

final settlementListProvider =
    StateNotifierProvider<SettlementListNotifier, List<SettlementRecord>>((ref) {
  final repo = ref.watch(settlementRepositoryProvider);
  return SettlementListNotifier(repo);
});

// Computed Friend Ledger Provider for a Friend ID
final friendLedgerProvider = Provider.family<FriendLedgerSummary, String>((ref, friendId) {
  final rides = ref.watch(rideListProvider);
  final settlements = ref.watch(settlementListProvider);
  final service = ref.watch(ledgerServiceProvider);
  return service.calculateFriendBalance(
    friendId: friendId,
    rides: rides,
    settlements: settlements,
  );
});
