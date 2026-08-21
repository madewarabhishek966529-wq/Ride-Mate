import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/providers.dart';
import '../settings/export_report_screen.dart';

class MonthlyAnalyticsScreen extends ConsumerWidget {
  const MonthlyAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rides = ref.watch(rideListProvider);
    final now = DateTime.now();

    // Current month rides
    final currentMonthRides = rides.where((r) {
      return r.date.year == now.year && r.date.month == now.month;
    }).toList();

    final totalDist = currentMonthRides.fold<double>(0, (sum, r) => sum + r.distanceKm);
    final totalCost = currentMonthRides.fold<double>(0, (sum, r) => sum + r.totalFuelCost);
    final totalFuel = currentMonthRides.fold<double>(0, (sum, r) => sum + r.fuelUsedLiters);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.output),
            tooltip: 'Export Report',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const ExportReportScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Month Header
            Text(
              DateFormat('MMMM yyyy').format(now),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Summary Grid
            Row(
              children: [
                Expanded(
                  child: _analyticsCard(
                    context,
                    'Total Distance',
                    '${totalDist.toStringAsFixed(1)} km',
                    Icons.directions_bike,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _analyticsCard(
                    context,
                    'Total Fuel Cost',
                    '₹${totalCost.toStringAsFixed(2)}',
                    Icons.currency_rupee,
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _analyticsCard(
                    context,
                    'Fuel Consumed',
                    '${totalFuel.toStringAsFixed(1)} L',
                    Icons.local_gas_station,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _analyticsCard(
                    context,
                    'Rides Completed',
                    '${currentMonthRides.length}',
                    Icons.route,
                    Colors.purple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Export Banner Card
            Card(
              elevation: 2,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.blue.shade900.withValues(alpha: 0.4)
                  : Colors.blue.shade50,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Icon(Icons.file_download, size: 40, color: Colors.blue),
                    const SizedBox(height: 8),
                    const Text(
                      'Export Expense Report',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Generate detailed CSV or PDF monthly expense statements and share offline.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const ExportReportScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.output),
                      label: const Text('Go to Export'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _analyticsCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
