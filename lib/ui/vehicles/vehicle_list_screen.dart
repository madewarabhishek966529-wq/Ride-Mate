import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../domain/models/vehicle.dart';
import '../../providers/providers.dart';
import 'log_refill_screen.dart';
import 'vehicle_detail_screen.dart';

class VehicleListScreen extends ConsumerWidget {
  const VehicleListScreen({super.key});

  void _showAddVehicleDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final mileageController = TextEditingController();
    final priceController = TextEditingController();
    bool isDefault = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add Vehicle'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Vehicle Name (e.g. Royal Enfield)'),
                    ),
                    TextField(
                      controller: mileageController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Estimated Mileage (km/L)'),
                    ),
                    TextField(
                      controller: priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Default Fuel Price (₹/L)'),
                    ),
                    CheckboxListTile(
                      title: const Text('Set as Default Vehicle'),
                      value: isDefault,
                      onChanged: (val) => setState(() => isDefault = val ?? false),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.trim().isEmpty) return;
                    final mileage = double.tryParse(mileageController.text.trim()) ?? 40.0;
                    final price = double.tryParse(priceController.text.trim()) ?? 100.0;

                    final newVehicle = Vehicle(
                      id: const Uuid().v4(),
                      name: nameController.text.trim(),
                      mileage: mileage,
                      defaultFuelPrice: price,
                      isDefault: isDefault,
                    );

                    await ref.read(vehicleListProvider.notifier).addVehicle(newVehicle);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicles = ref.watch(vehicleListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Vehicles'),
        actions: [
          IconButton(
            icon: const Icon(Icons.local_gas_station),
            tooltip: 'Log Refill',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const LogRefillScreen()),
              );
            },
          ),
        ],
      ),
      body: vehicles.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.directions_car_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No vehicles added yet.'),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showAddVehicleDialog(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Vehicle'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: vehicles.length,
              itemBuilder: (context, index) {
                final v = vehicles[index];
                final actualMileage = ref.watch(actualMileageProvider(v.id));

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: v.isDefault ? Colors.blue : Colors.grey.shade400,
                      child: const Icon(Icons.two_wheeler, color: Colors.white),
                    ),
                    title: Text(
                      '${v.name} ${v.isDefault ? "(Default)" : ""}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Est: ${v.mileage.toStringAsFixed(1)} km/L • Actual: ${actualMileage != null ? "${actualMileage.toStringAsFixed(1)} km/L" : "--"}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => VehicleDetailScreen(vehicleId: v.id),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddVehicleDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }
}
