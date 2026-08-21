import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../data/repositories/friend_repository.dart';
import '../data/repositories/fuel_refill_repository.dart';
import '../data/repositories/ride_repository.dart';
import '../data/repositories/settlement_repository.dart';
import '../data/repositories/vehicle_repository.dart';
import '../domain/models/friend.dart';
import '../domain/models/fuel_refill.dart';
import '../domain/models/ride.dart';
import '../domain/models/settlement_record.dart';
import '../domain/models/vehicle.dart';
import '../services/distance_calculation_service.dart';
import '../services/export_service.dart';
import '../services/fuel_calculation_service.dart';
import '../services/ledger_service.dart';
import '../services/mileage_analysis_service.dart';
import '../services/split_calculation_service.dart';

// Database Provider
final databaseProvider = Provider<Database>((ref) {
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

final fuelRefillRepositoryProvider = Provider<FuelRefillRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return FuelRefillRepository(db);
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

final mileageAnalysisServiceProvider = Provider<MileageAnalysisService>((ref) {
  return MileageAnalysisService();
});

final ledgerServiceProvider = Provider<LedgerService>((ref) {
  return LedgerService();
});

final exportServiceProvider = Provider<ExportService>((ref) {
  return ExportService();
});

// Vehicles Notifier
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

// Refills Notifier
class FuelRefillListNotifier extends StateNotifier<List<FuelRefill>> {
  final FuelRefillRepository _repo;

  FuelRefillListNotifier(this._repo) : super([]) {
    loadRefills();
  }

  Future<void> loadRefills() async {
    final refills = await _repo.getAllRefills();
    state = refills;
  }

  Future<void> addRefill(FuelRefill refill) async {
    await _repo.insertRefill(refill);
    await loadRefills();
  }
}

final fuelRefillListProvider = StateNotifierProvider<FuelRefillListNotifier, List<FuelRefill>>((ref) {
  final repo = ref.watch(fuelRefillRepositoryProvider);
  return FuelRefillListNotifier(repo);
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

// Computed Actual Mileage Provider for a Vehicle ID
final actualMileageProvider = Provider.family<double?, String>((ref, vehicleId) {
  final refills = ref.watch(fuelRefillListProvider).where((r) => r.vehicleId == vehicleId).toList();
  final rides = ref.watch(rideListProvider).where((r) => r.vehicleId == vehicleId).toList();
  final service = ref.watch(mileageAnalysisServiceProvider);
  return service.calculateActualMileage(refills, rides);
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
