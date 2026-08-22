import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../domain/models/vehicle.dart';
import '../../providers/providers.dart';
import 'export_report_screen.dart';

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  void _showManageBikesModal(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return const ManageBikesModal();
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Appearance',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.brightness_6),
            title: const Text('Theme Mode'),
            subtitle: Text(themeMode.name.toUpperCase()),
            trailing: DropdownButton<ThemeMode>(
              value: themeMode,
              onChanged: (val) {
                if (val != null) {
                  ref.read(themeModeProvider.notifier).state = val;
                }
              },
              items: const [
                DropdownMenuItem(
                  value: ThemeMode.system,
                  child: Text('System'),
                ),
                DropdownMenuItem(
                  value: ThemeMode.light,
                  child: Text('Light'),
                ),
                DropdownMenuItem(
                  value: ThemeMode.dark,
                  child: Text('Dark'),
                ),
              ],
            ),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Bikes & Fuel Rates',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.two_wheeler),
            title: const Text('Manage Bike Profiles'),
            subtitle: const Text('Add bikes, set average mileage & default petrol rates'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showManageBikesModal(context, ref),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Data & Export',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.output),
            title: const Text('Export Expense Report'),
            subtitle: const Text('Export CSV or PDF monthly ride reports'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const ExportReportScreen()),
              );
            },
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'About',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
          ),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('RideMate'),
            subtitle: Text('Mileage Intelligence, Group Ledger & Export v1.0.0'),
          ),
        ],
      ),
    );
  }
}

class ManageBikesModal extends ConsumerWidget {
  const ManageBikesModal({super.key});

  void _showAddEditBikeDialog(BuildContext context, WidgetRef ref, [Vehicle? existing]) {
    final bikeNameController = TextEditingController(text: existing?.name ?? '');
    final bikeMileageController = TextEditingController(text: (existing?.mileage ?? 45.0).toString());
    final bikePriceController =
        TextEditingController(text: (existing?.defaultFuelPrice ?? 100.0).toString());
    bool isDefaultBike = existing?.isDefault ?? false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(existing == null ? 'Add Bike Profile' : 'Edit Bike Profile'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: bikeNameController,
                      decoration: const InputDecoration(
                        labelText: 'Bike Name (e.g. Pulsar 150)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.two_wheeler),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: bikeMileageController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Average Mileage (km/L)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.speed),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: bikePriceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: "Default Petrol Rate (₹/L)",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.local_gas_station),
                      ),
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      title: const Text('Set as Default Bike'),
                      value: isDefaultBike,
                      onChanged: (val) {
                        setDialogState(() {
                          isDefaultBike = val ?? false;
                        });
                      },
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
                    final name = bikeNameController.text.trim();
                    final mileage = double.tryParse(bikeMileageController.text.trim()) ?? 45.0;
                    final price = double.tryParse(bikePriceController.text.trim()) ?? 100.0;

                    if (name.isEmpty) return;

                    if (existing == null) {
                      final newBike = Vehicle(
                        id: const Uuid().v4(),
                        name: name,
                        mileage: mileage,
                        defaultFuelPrice: price,
                        isDefault: isDefaultBike,
                      );
                      await ref.read(vehicleListProvider.notifier).addVehicle(newBike);
                    } else {
                      final updatedBike = Vehicle(
                        id: existing.id,
                        name: name,
                        mileage: mileage,
                        defaultFuelPrice: price,
                        isDefault: isDefaultBike,
                      );
                      await ref.read(vehicleListProvider.notifier).updateVehicle(updatedBike);
                    }

                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
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

    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Bike Profiles',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle),
                color: Colors.blue,
                onPressed: () => _showAddEditBikeDialog(context, ref),
              ),
            ],
          ),
          const Divider(),
          Expanded(
            child: vehicles.isEmpty
                ? const Center(child: Text('No bike profiles added yet.'))
                : ListView.builder(
                    itemCount: vehicles.length,
                    itemBuilder: (context, index) {
                      final bike = vehicles[index];
                      return ListTile(
                        leading: const Icon(Icons.two_wheeler, color: Colors.blue),
                        title: Row(
                          children: [
                            Text(bike.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            if (bike.isDefault) ...[
                              const SizedBox(width: 8),
                              const Chip(
                                label: Text('DEFAULT', style: TextStyle(fontSize: 10, color: Colors.white)),
                                backgroundColor: Colors.green,
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text(
                          'Avg: ${bike.mileage.toStringAsFixed(0)} km/L • Petrol: ₹${bike.defaultFuelPrice.toStringAsFixed(2)}/L',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20),
                              onPressed: () => _showAddEditBikeDialog(context, ref, bike),
                            ),
                            if (vehicles.length > 1)
                              IconButton(
                                icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                                onPressed: () {
                                  ref.read(vehicleListProvider.notifier).deleteVehicle(bike.id);
                                },
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
