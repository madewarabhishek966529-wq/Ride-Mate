import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class LocationSearchResult {
  final String displayName;
  final LatLng location;

  LocationSearchResult({
    required this.displayName,
    required this.location,
  });
}

class LocationSearchService {
  /// Searches places worldwide by text query using OpenStreetMap Nominatim API.
  Future<List<LocationSearchResult>> searchPlaces(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query.trim())}&format=json&addressdetails=1&limit=5',
      );

      final response = await http.get(
        url,
        headers: {'User-Agent': 'RideMateApp/1.0 (com.ridemate.app)'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
        return data.map((item) {
          final map = item as Map<String, dynamic>;
          final lat = double.parse(map['lat'] as String);
          final lon = double.parse(map['lon'] as String);
          final displayName = map['display_name'] as String;

          return LocationSearchResult(
            displayName: displayName,
            location: LatLng(lat, lon),
          );
        }).toList();
      }
    } catch (_) {
      // Return empty list gracefully if offline or timeout
    }

    return [];
  }
}
