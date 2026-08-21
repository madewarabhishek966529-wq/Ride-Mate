import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../domain/models/friend.dart';
import '../../domain/models/ride.dart';
import '../../domain/models/vehicle.dart';
import '../../providers/providers.dart';

class RideTrackingScreen extends ConsumerStatefulWidget {
  const RideTrackingScreen({super.key});

  @override
  ConsumerState<RideTrackingScreen> createState() => _RideTrackingScreenState();
}

class _RideTrackingScreenState extends ConsumerState<RideTrackingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController(text: 'Afternoon Ride');
  final _manualDistanceController = TextEditingController();

  String? _selectedVehicleId;
  String _trackingMode = 'GPS'; // 'GPS' or 'Manual'
  String _paidBy = 'ME'; // 'ME' or friendId
  final Set<String> _selectedParticipantIds = {'ME'}; // 'ME' + friend IDs

  // Simulation of GPS tracking
  bool _isTracking = false;
  double _gpsDistanceKm = 0.0;

  @override
  void dispose() {
    _nameController.dispose();
    _manualDistanceController.dispose();
    super.dispose();
  }

  void _startGpsTracking() {
    setState(() {
      _isTracking = true;
      _gpsDistanceKm = 0.0;
    });
  }

  void _stopGpsTracking() {
    setState(() {
      _isTracking = false;
      // Simulate recorded distance if 0
      if (_gpsDistanceKm == 0.0) {
        _gpsDistanceKm = 14.5;
      }
    });
  }

  Future<void> _saveRide(List<Vehicle> vehicles, List<Friend> friends) async {
    if (!_formKey.currentState!.validate()) return;

    final vehicle = vehicles.firstWhere(
      (v) => v.id == _selectedVehicleId,
      orElse: () => vehicles.first,
    );

    final distanceKm = _trackingMode == 'GPS'
        ? _gpsDistanceKm
        : (double.tryParse(_manualDistanceController.text.trim()) ?? 0.0);

    if (distanceKm <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Distance must be greater than 0 km')),
      );
      return;
    }

    final fuelCalc = ref.read(fuelCalculationServiceProvider);
    final splitCalc = ref.read(splitCalculationServiceProvider);

    final fuelUsed = fuelCalc.calculateFuelUsed(distanceKm, vehicle.mileage);
    final fuelCost = fuelCalc.calculateFuelCost(fuelUsed, vehicle.defaultFuelPrice);

    final participantList = _selectedParticipantIds.toList();
    final shares = splitCalc.calculateEvenShares(fuelCost, participantList);

    final newRide = Ride(
      id: const Uuid().v4(),
      name: _nameController.text.trim(),
      date: DateTime.now(),
      vehicleId: vehicle.id,
      vehicleName: vehicle.name,
      mileage: vehicle.mileage, // Snapshot
      fuelPrice: vehicle.defaultFuelPrice, // Snapshot
      distanceKm: distanceKm,
      fuelUsedLiters: fuelUsed,
      totalFuelCost: fuelCost,
      trackingMode: _trackingMode,
      paidBy: _paidBy,
      participantIds: participantList,
      participantShares: shares,
    );

    await ref.read(rideListProvider.notifier).addRide(newRide);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ride saved successfully!')),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicles = ref.watch(vehicleListProvider);
    final friends = ref.watch(friendListProvider);

    if (_selectedVehicleId == null && vehicles.isNotEmpty) {
      final def = vehicles.firstWhere((v) => v.isDefault, orElse: () => vehicles.first);
      _selectedVehicleId = def.id;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Track & Split Ride'),
      ),
      body: vehicles.isEmpty
          ? const Center(
              child: Text('Please add a vehicle first before tracking rides.'),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Ride Title
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Ride Name / Destination',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_on),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Enter ride name' : null,
                    ),
                    const SizedBox(height: 16),

                    // Vehicle Selection
                    DropdownButtonFormField<String>(
                      initialValue: _selectedVehicleId,
                      decoration: const InputDecoration(
                        labelText: 'Vehicle',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.directions_car),
                      ),
                      items: vehicles.map((v) {
                        return DropdownMenuItem(
                          value: v.id,
                          child: Text('${v.name} (${v.mileage} km/L)'),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedVehicleId = val),
                    ),
                    const SizedBox(height: 16),

                    // Tracking Mode Selector
                    const Text(
                      'Tracking Mode',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'GPS', label: Text('GPS Track'), icon: Icon(Icons.gps_fixed)),
                        ButtonSegment(value: 'Manual', label: Text('Manual Entry'), icon: Icon(Icons.edit)),
                      ],
                      selected: {_trackingMode},
                      onSelectionChanged: (set) => setState(() => _trackingMode = set.first),
                    ),
                    const SizedBox(height: 16),

                    // GPS Mode UI
                    if (_trackingMode == 'GPS') ...[
                      Card(
                        color: _isTracking ? Colors.green.shade50 : Colors.blue.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Text(
                                '${_gpsDistanceKm.toStringAsFixed(2)} km',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: _isTracking ? Colors.green.shade800 : Colors.blue.shade800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _isTracking ? 'Tracking GPS distance...' : 'GPS Stopped',
                                style: const TextStyle(fontSize: 14),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: _isTracking ? _stopGpsTracking : _startGpsTracking,
                                icon: Icon(_isTracking ? Icons.stop : Icons.play_arrow),
                                label: Text(_isTracking ? 'Stop Ride' : 'Start GPS Ride'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isTracking ? Colors.red : Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      TextFormField(
                        controller: _manualDistanceController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Distance (km)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.straighten),
                          suffixText: 'km',
                        ),
                        validator: (val) {
                          if (_trackingMode == 'Manual') {
                            if (val == null || val.trim().isEmpty) return 'Enter distance';
                            final numVal = double.tryParse(val.trim());
                            if (numVal == null || numVal <= 0) return 'Enter valid distance';
                          }
                          return null;
                        },
                      ),
                    ],
                    const SizedBox(height: 24),

                    // Participants & Split
                    const Text(
                      'Split with Friends',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      title: const Text('Include Me'),
                      value: _selectedParticipantIds.contains('ME'),
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedParticipantIds.add('ME');
                          } else {
                            if (_selectedParticipantIds.length > 1) {
                              _selectedParticipantIds.remove('ME');
                            }
                          }
                        });
                      },
                    ),
                    ...friends.map((f) {
                      return CheckboxListTile(
                        title: Text(f.name),
                        value: _selectedParticipantIds.contains(f.id),
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedParticipantIds.add(f.id);
                            } else {
                              if (_selectedParticipantIds.length > 1) {
                                _selectedParticipantIds.remove(f.id);
                              }
                            }
                          });
                        },
                      );
                    }),
                    const SizedBox(height: 16),

                    // Paid By Selector
                    const Text(
                      'Paid By',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _paidBy,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.payment),
                      ),
                      items: [
                        const DropdownMenuItem(value: 'ME', child: Text('Me (User)')),
                        ...friends
                            .where((f) => _selectedParticipantIds.contains(f.id))
                            .map((f) => DropdownMenuItem(value: f.id, child: Text(f.name))),
                      ],
                      onChanged: (val) => setState(() => _paidBy = val ?? 'ME'),
                    ),
                    const SizedBox(height: 24),

                    // Save Button
                    ElevatedButton.icon(
                      onPressed: () => _saveRide(vehicles, friends),
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Save & Calculate Ride'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
