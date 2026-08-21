import 'dart:math';

class DistanceCalculationService {
  /// Calculates total distance in kilometers from GPS coordinates [lat, lon].
  double calculateGpsDistance(List<List<double>> coordinates) {
    if (coordinates.length < 2) return 0.0;
    double total = 0.0;
    for (int i = 0; i < coordinates.length - 1; i++) {
      total += haversineDistance(
        coordinates[i][0],
        coordinates[i][1],
        coordinates[i + 1][0],
        coordinates[i + 1][1],
      );
    }
    return double.parse(total.toStringAsFixed(2));
  }

  double haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0; // Radius of earth in km
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _toRadians(double degree) => degree * pi / 180.0;
}
