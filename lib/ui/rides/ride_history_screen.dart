import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/providers.dart';
import 'ride_tracking_screen.dart';

class RideHistoryScreen extends ConsumerWidget {
  const RideHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rides = ref.watch(rideListProvider);
    final friends = ref.watch(friendListProvider);
    final friendMap = {for (var f in friends) f.id: f.name};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ride History'),
      ),
      body: rides.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.directions_bike, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No rides recorded yet.'),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const RideTrackingScreen()),
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Start New Ride'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: rides.length,
              itemBuilder: (context, index) {
                final ride = rides[index];
                final payerName = ride.paidBy == 'ME' ? 'Me' : (friendMap[ride.paidBy] ?? ride.paidBy);

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                ride.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            Chip(
                              label: Text(ride.trackingMode),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${DateFormat('MMM d, yyyy HH:mm').format(ride.date)} • ${ride.mileage.toStringAsFixed(0)} km/L',
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _statColumn('Distance', '${ride.distanceKm.toStringAsFixed(1)} km'),
                            _statColumn('Fuel Cost', '₹${ride.totalFuelCost.toStringAsFixed(2)}'),
                            _statColumn('Paid By', payerName),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const RideTrackingScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _statColumn(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }
}
