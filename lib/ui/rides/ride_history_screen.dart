import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../../domain/models/ride.dart';
import '../../providers/providers.dart';
import '../widgets/gradient_button.dart';
import '../widgets/real_route_map_widget.dart';
import 'ride_tracking_screen.dart';

class RideHistoryScreen extends ConsumerWidget {
  const RideHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rides = ref.watch(rideListProvider);
    final friends = ref.watch(friendListProvider);
    final friendMap = {for (var f in friends) f.id: f.name};

    final totalDistance = rides.fold<double>(0.0, (sum, r) => sum + r.distanceKm);
    final totalCost = rides.fold<double>(0.0, (sum, r) => sum + r.totalFuelCost);
    final totalRides = rides.length;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.two_wheeler, color: Color(0xFF6366F1)),
            SizedBox(width: 8),
            Text('Ride History', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: rides.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.directions_bike, size: 72, color: Color(0xFF6366F1)),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'No Rides Tracked Yet',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tap below to track real GPS movement or calculate road distance!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(height: 24),
                    GradientButton(
                      text: 'Start New Ride',
                      icon: Icons.add_circle,
                      gradientColors: const [Color(0xFF6366F1), Color(0xFF3B82F6), Color(0xFF06B6D4)],
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => const RideTrackingScreen()),
                        );
                      },
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: rides.length + 1, // 1 for summary header card
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _buildSummaryCard(totalDistance, totalRides, totalCost);
                }

                final ride = rides[index - 1];
                final payerName = ride.paidBy == 'ME' ? 'Me' : (friendMap[ride.paidBy] ?? ride.paidBy);

                return TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: 1.0),
                  duration: Duration(milliseconds: 250 + (index * 60)),
                  builder: (context, value, child) {
                    return Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: Opacity(
                        opacity: value,
                        child: child,
                      ),
                    );
                  },
                  child: Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
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
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                    tooltip: 'Delete Ride',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () => _confirmDeleteRide(context, ref, ride),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${DateFormat('MMM d, yyyy • HH:mm').format(ride.date)} • ${ride.vehicleName}',
                                style: const TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                              Wrap(
                                spacing: 4,
                                children: [
                                  if (ride.isRoundTrip)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.purple.shade700,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.sync, size: 10, color: Colors.white),
                                          SizedBox(width: 2),
                                          Text('Return', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  if (ride.stopCount > 1)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade800,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '${ride.stopCount} Stops',
                                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      gradient: ride.trackingMode == 'GPS'
                                          ? const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)])
                                          : const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF3B82F6)]),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          ride.trackingMode == 'GPS' ? Icons.gps_fixed : Icons.map,
                                          size: 10,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          ride.trackingMode,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Divider(height: 1),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _statColumn('Distance', '${ride.distanceKm.toStringAsFixed(2)} km', Colors.blue.shade700),
                              _statColumn('Fuel Cost', '₹${ride.totalFuelCost.toStringAsFixed(2)}', Colors.green.shade700),
                              _statColumn('Paid By', payerName, Colors.purple.shade700),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                side: BorderSide(color: Colors.blue.shade400),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () => _showRideMapDialog(context, ride, friendMap),
                              icon: const Icon(Icons.map_outlined, size: 16, color: Color(0xFF6366F1)),
                              label: const Text(
                                'View Route Map & Details',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF6366F1)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6366F1), Color(0xFF3B82F6), Color(0xFF06B6D4)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366F1).withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          heroTag: 'start_ride_fab',
          elevation: 0,
          backgroundColor: Colors.transparent,
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const RideTrackingScreen()),
            );
          },
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('Track Ride', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(double totalDistance, int totalRides, double totalCost) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              const Color(0xFF6366F1).withValues(alpha: 0.12),
              const Color(0xFF3B82F6).withValues(alpha: 0.08),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.query_stats, color: Color(0xFF6366F1), size: 20),
                SizedBox(width: 8),
                Text(
                  'Total Travel History',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _summaryItem(
                  icon: Icons.map,
                  iconColor: Colors.blue.shade700,
                  label: 'Total Traveled',
                  value: '${totalDistance.toStringAsFixed(1)} km',
                ),
                Container(width: 1, height: 35, color: Colors.grey.withValues(alpha: 0.3)),
                _summaryItem(
                  icon: Icons.directions_bike,
                  iconColor: Colors.purple.shade700,
                  label: 'Total Rides',
                  value: '$totalRides',
                ),
                Container(width: 1, height: 35, color: Colors.grey.withValues(alpha: 0.3)),
                _summaryItem(
                  icon: Icons.local_gas_station,
                  iconColor: Colors.green.shade700,
                  label: 'Fuel Spent',
                  value: '₹${totalCost.toStringAsFixed(0)}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryItem({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.grey, fontSize: 11),
        ),
      ],
    );
  }

  Widget _statColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color),
        ),
      ],
    );
  }

  void _showRideMapDialog(BuildContext context, Ride ride, Map<String, String> friendMap) {
    final List<LatLng> points = ride.routePoints
        .map((p) => LatLng(p['lat']!, p['lng']!))
        .toList();
    final payerName = ride.paidBy == 'ME' ? 'Me' : (friendMap[ride.paidBy] ?? ride.paidBy);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.88,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header title and close button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ride.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        Text(
                          '${DateFormat('EEEE, MMM d, yyyy • HH:mm').format(ride.date)} • ${ride.vehicleName}',
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Badges row
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: ride.trackingMode == 'GPS'
                          ? const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)])
                          : const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF3B82F6)]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          ride.trackingMode == 'GPS' ? Icons.gps_fixed : Icons.map,
                          size: 12,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${ride.trackingMode} Mode',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  if (ride.isRoundTrip)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade700,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.sync, size: 12, color: Colors.white),
                          SizedBox(width: 3),
                          Text('Return Trip', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  if (ride.stopCount > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade800,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${ride.stopCount} Stops',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade700,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      points.isNotEmpty ? '${points.length} Map GPS Points' : 'Manual Distance Entry',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Interactive Map View
              SizedBox(
                height: 280,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: RealRouteMapWidget(
                    routePoints: points,
                    currentDistanceKm: ride.distanceKm,
                    isLiveTracking: false,
                    isManualMapMode: points.isEmpty,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Detailed Ride Info Card
              Expanded(
                child: SingleChildScrollView(
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Ride Travel Details',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _statColumn('Distance', '${ride.distanceKm.toStringAsFixed(2)} km', Colors.blue.shade700),
                              _statColumn('Fuel Consumed', '${ride.fuelUsedLiters.toStringAsFixed(2)} L', Colors.orange.shade700),
                              _statColumn('Total Fuel Cost', '₹${ride.totalFuelCost.toStringAsFixed(2)}', Colors.green.shade700),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Vehicle Mileage: ${ride.mileage.toStringAsFixed(1)} km/L',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              Text(
                                'Fuel Rate: ₹${ride.fuelPrice.toStringAsFixed(1)}/L',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(Icons.account_balance_wallet_outlined, size: 16, color: Colors.purple),
                              const SizedBox(width: 6),
                              Text(
                                'Paid By: $payerName',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.purple.shade700),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Split Shares:',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: ride.participantShares.entries.map((entry) {
                              final pName = entry.key == 'ME' ? 'Me' : (friendMap[entry.key] ?? entry.key);
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  '$pName: ₹${entry.value.toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDeleteRide(BuildContext context, WidgetRef ref, Ride ride) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.delete_forever, color: Colors.redAccent),
              SizedBox(width: 8),
              Text('Delete Ride'),
            ],
          ),
          content: Text('Are you sure you want to delete "${ride.name}"? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                Navigator.of(context).pop();
                await ref.read(rideListProvider.notifier).deleteRide(ride.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Deleted "${ride.name}"'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}
