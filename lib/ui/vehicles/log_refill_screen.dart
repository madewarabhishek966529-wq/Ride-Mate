import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../domain/models/fuel_refill.dart';
import '../../domain/models/vehicle.dart';
import '../../providers/providers.dart';

class LogRefillScreen extends ConsumerStatefulWidget {
  final String? initialVehicleId;

  const LogRefillScreen({super.key, this.initialVehicleId});

  @override
  ConsumerState<LogRefillScreen> createState() => _LogRefillScreenState();
}

class _LogRefillScreenState extends ConsumerState<LogRefillScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedVehicleId;
  final _litersController = TextEditingController();
  final _priceController = TextEditingController();
  final _odometerController = TextEditingController();
  final _notesController = TextEditingController();
  final DateTime _refillDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _selectedVehicleId = widget.initialVehicleId;
  }

  @override
  void dispose() {
    _litersController.dispose();
    _priceController.dispose();
    _odometerController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onVehicleChanged(String? vehicleId, List<Vehicle> vehicles) {
    setState(() {
      _selectedVehicleId = vehicleId;
      if (vehicleId != null) {
        final v = vehicles.firstWhere((x) => x.id == vehicleId, orElse: () => vehicles.first);
        if (_priceController.text.isEmpty) {
          _priceController.text = v.defaultFuelPrice.toString();
        }
      }
    });
  }

  Future<void> _saveRefill(List<Vehicle> vehicles) async {
    if (!_formKey.currentState!.validate()) return;

    final vehicleId = _selectedVehicleId ??
        vehicles.firstWhere((v) => v.isDefault, orElse: () => vehicles.first).id;

    final liters = double.parse(_litersController.text.trim());
    final price = _priceController.text.trim().isNotEmpty
        ? double.tryParse(_priceController.text.trim())
        : null;
    final odometer = _odometerController.text.trim().isNotEmpty
        ? double.tryParse(_odometerController.text.trim())
        : null;
    final notes = _notesController.text.trim().isNotEmpty
        ? _notesController.text.trim()
        : null;

    final refill = FuelRefill(
      id: const Uuid().v4(),
      vehicleId: vehicleId,
      date: _refillDate,
      litersAdded: liters,
      pricePerLiter: price,
      odometerReading: odometer,
      notes: notes,
    );

    await ref.read(fuelRefillListProvider.notifier).addRefill(refill);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fuel refill logged successfully!')),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicles = ref.watch(vehicleListProvider);
    if (_selectedVehicleId == null && vehicles.isNotEmpty) {
      final defaultVeh = vehicles.firstWhere((v) => v.isDefault, orElse: () => vehicles.first);
      _selectedVehicleId = defaultVeh.id;
      if (_priceController.text.isEmpty) {
        _priceController.text = defaultVeh.defaultFuelPrice.toString();
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Log Fuel Refill'),
      ),
      body: vehicles.isEmpty
          ? const Center(
              child: Text('Please add a vehicle first before logging fuel refills.'),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Vehicle Selector
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
                          child: Text('${v.name} ${v.isDefault ? "(Default)" : ""}'),
                        );
                      }).toList(),
                      onChanged: (val) => _onVehicleChanged(val, vehicles),
                      validator: (val) => val == null ? 'Please select a vehicle' : null,
                    ),
                    const SizedBox(height: 16),

                    // Liters Added
                    TextFormField(
                      controller: _litersController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Liters Added *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.local_gas_station),
                        suffixText: 'L',
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Enter liters added';
                        final numVal = double.tryParse(val.trim());
                        if (numVal == null || numVal <= 0) return 'Enter a valid positive number';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Price per liter
                    TextFormField(
                      controller: _priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Price / Liter (₹) (Optional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.currency_rupee),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Odometer reading
                    TextFormField(
                      controller: _odometerController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Odometer Reading (km) (Optional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.speed),
                        suffixText: 'km',
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Notes
                    TextFormField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        labelText: 'Notes (Optional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.note),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Save Button
                    ElevatedButton.icon(
                      onPressed: () => _saveRefill(vehicles),
                      icon: const Icon(Icons.save),
                      label: const Text(
                        'Save Refill',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
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
