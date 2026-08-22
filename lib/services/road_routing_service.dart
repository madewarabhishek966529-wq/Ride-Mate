import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class RoadRouteResult {
  final double distanceKm;
  final List<LatLng> polylinePoints;
  final bool isRoadRouting;

  RoadRouteResult({
    required this.distanceKm,
    required this.polylinePoints,
    required this.isRoadRouting,
  });
}

class RoadRoutingService {
  /// Fetches real road driving distance and turn-by-turn road polyline geometry using OpenStreetMap OSRM routing engine.
  Future<RoadRouteResult> getRoadRoute(LatLng start, LatLng end) async {
    return getMultiStopRoadRoute([start, end]);
  }

  /// Fetches real road driving distance across multiple stops / waypoints using OpenStreetMap OSRM routing engine.
  Future<RoadRouteResult> getMultiStopRoadRoute(List<LatLng> waypoints) async {
    if (waypoints.length < 2) {
      return RoadRouteResult(
        distanceKm: 0.0,
        polylinePoints: waypoints,
        isRoadRouting: false,
      );
    }

    try {
      final coordsString = waypoints.map((p) => '${p.longitude},${p.latitude}').join(';');
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/$coordsString?overview=full&geometries=geojson',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final routes = data['routes'] as List<dynamic>?;

        if (routes != null && routes.isNotEmpty) {
          final firstRoute = routes[0] as Map<String, dynamic>;
          final distanceMeters = (firstRoute['distance'] as num).toDouble();
          final distanceKm = distanceMeters / 1000.0;

          final geometry = firstRoute['geometry'] as Map<String, dynamic>?;
          final rawCoords = geometry?['coordinates'] as List<dynamic>?;

          final List<LatLng> polylinePoints = [];
          if (rawCoords != null) {
            for (var item in rawCoords) {
              final coord = item as List<dynamic>;
              final lon = (coord[0] as num).toDouble();
              final lat = (coord[1] as num).toDouble();
              polylinePoints.add(LatLng(lat, lon));
            }
          }

          if (polylinePoints.isNotEmpty) {
            return RoadRouteResult(
              distanceKm: distanceKm,
              polylinePoints: polylinePoints,
              isRoadRouting: true,
            );
          }
        }
      }
    } catch (_) {
      // Fallback
    }

    // Geodesic fallback across all waypoints
    double totalMeters = 0.0;
    for (int i = 0; i < waypoints.length - 1; i++) {
      totalMeters += Geolocator.distanceBetween(
        waypoints[i].latitude,
        waypoints[i].longitude,
        waypoints[i + 1].latitude,
        waypoints[i + 1].longitude,
      );
    }

    return RoadRouteResult(
      distanceKm: totalMeters / 1000.0,
      polylinePoints: waypoints,
      isRoadRouting: false,
    );
  }
}
