import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../domain/models/vehicle.dart';
import '../../providers/providers.dart';
import 'log_refill_screen.dart';

class VehicleDetailScreen extends ConsumerStatefulWidget {
  final String vehicleId;

  const VehicleDetailScreen({super.key, required this.vehicleId});

  @override
  ConsumerState<VehicleDetailScreen> createState() => _VehicleDetailScreenState();
}

class _VehicleDetailScreenState extends ConsumerState<VehicleDetailScreen> {
  bool _dismissedSuggestion = false;

  @override
  Widget build(BuildContext context) {
    final vehicles = ref.watch(vehicleListProvider);
    final vehicle = vehicles.firstWhere(
      (v) => v.id == widget.vehicleId,
      orElse: () => Vehicle(
        id: widget.vehicleId,
        name: 'Unknown Vehicle',
        mileage: 0,
        defaultFuelPrice: 0,
      ),
    );

    final actualMileage = ref.watch(actualMileageProvider(widget.vehicleId));
    final refills = ref
        .watch(fuelRefillListProvider)
        .where((r) => r.vehicleId == widget.vehicleId)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    // Variance check (> 10%)
    bool showSuggestion = false;
    if (actualMileage != null && vehicle.mileage > 0 && !_dismissedSuggestion) {
      final diff = (vehicle.mileage - actualMileage).abs();
      if ((diff / vehicle.mileage) > 0.10) {
        showSuggestion = true;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(vehicle.name),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Mileage Side-by-Side Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          const Text(
                            'Estimated Mileage\n(set by you)',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${vehicle.mileage.toStringAsFixed(1)} km/L',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(height: 40, width: 1, color: Colors.grey.shade300),
                    Expanded(
                      child: Column(
                        children: [
                          const Text(
                            'Actual Mileage\n(from refills)',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            actualMileage != null
                                ? '${actualMileage.toStringAsFixed(1)} km/L'
                                : '--',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: actualMileage != null ? Colors.green : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Dismissible Suggestion Banner
            if (showSuggestion && actualMileage != null)
              Card(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.amber.shade900.withValues(alpha: 0.4)
                    : Colors.amber.shade50,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: Colors.amber.shade700, width: 1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.lightbulb, color: Colors.amber.shade800),
                          const SizedBox(width: 8),
                          const Text(
                            'Mileage Update Suggestion',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your actual mileage (${actualMileage.toStringAsFixed(1)} km/L) looks different from your saved estimate (${vehicle.mileage.toStringAsFixed(1)} km/L). Update vehicle mileage to ${actualMileage.toStringAsFixed(1)} km/L?',
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _dismissedSuggestion = true;
                              });
                            },
                            child: const Text('Dismiss'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () async {
                              final updated = vehicle.copyWith(mileage: actualMileage);
                              final messenger = ScaffoldMessenger.of(context);
                              await ref
                                  .read(vehicleListProvider.notifier)
                                  .updateVehicle(updated);
                              if (!mounted) return;
                              setState(() {
                                _dismissedSuggestion = true;
                              });
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Updated vehicle mileage to ${actualMileage.toStringAsFixed(1)} km/L',
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber.shade800,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Update'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            if (showSuggestion && actualMileage != null) const SizedBox(height: 16),

            // Vehicle Specs & Default Price
            Card(
              child: ListTile(
                leading: const Icon(Icons.local_gas_station),
                title: const Text('Default Fuel Price'),
                subtitle: Text('₹${vehicle.defaultFuelPrice.toStringAsFixed(2)} / L'),
              ),
            ),
            const SizedBox(height: 16),

            // Log Refill Button
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => LogRefillScreen(initialVehicleId: vehicle.id),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Log Fuel Refill'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 24),

            // Refills History
            const Text(
              'Fuel Refill Logs',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (refills.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(
                  child: Text(
                    'No refills logged for this vehicle yet.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: refills.length,
                itemBuilder: (context, index) {
                  final r = refills[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.local_gas_station, size: 20),
                      ),
                      title: Text('${r.litersAdded.toStringAsFixed(2)} Liters'),
                      subtitle: Text(
                        'Date: ${DateFormat('yyyy-MM-dd HH:mm').format(r.date)}'
                        '${r.odometerReading != null ? " • Odo: ${r.odometerReading} km" : ""}',
                      ),
                      trailing: r.pricePerLiter != null
                          ? Text('₹${r.pricePerLiter!.toStringAsFixed(2)}/L')
                          : null,
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
