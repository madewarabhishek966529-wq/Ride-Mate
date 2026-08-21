import '../domain/models/fuel_refill.dart';
import '../domain/models/ride.dart';

class MileageAnalysisService {
  /// Calculates actual mileage (km/L) for a vehicle from a list of refills and rides.
  /// Returns null if fewer than 2 refills exist for the vehicle.
  double? calculateActualMileage(
    List<FuelRefill> refills,
    List<Ride> rides,
  ) {
    if (refills.length < 2) return null;

    // Sort refills chronologically
    final sortedRefills = List<FuelRefill>.from(refills)
      ..sort((a, b) => a.date.compareTo(b.date));

    double totalDistance = 0.0;
    double totalLiters = 0.0;

    for (int i = 0; i < sortedRefills.length - 1; i++) {
      final r1 = sortedRefills[i];
      final r2 = sortedRefills[i + 1];

      double intervalDistance = 0.0;
      if (r1.odometerReading != null && r2.odometerReading != null) {
        intervalDistance = r2.odometerReading! - r1.odometerReading!;
      } else {
        // Fall back to summed GPS-tracked ride distance between r1.date and r2.date
        final intervalRides = rides.where((ride) {
          final isGps = ride.trackingMode.toUpperCase() == 'GPS';
          final inRange = (ride.date.isAfter(r1.date) || ride.date.isAtSameMomentAs(r1.date)) &&
              (ride.date.isBefore(r2.date) || ride.date.isAtSameMomentAs(r2.date));
          return isGps && inRange;
        });

        for (final ride in intervalRides) {
          intervalDistance += ride.distanceKm;
        }
      }

      totalDistance += intervalDistance;
      totalLiters += r2.litersAdded;
    }

    if (totalLiters <= 0) return null;
    final actualMileage = totalDistance / totalLiters;
    return double.parse(actualMileage.toStringAsFixed(1));
  }
}
