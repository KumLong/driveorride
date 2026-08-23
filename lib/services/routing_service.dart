import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Turns typed addresses into coordinates (Nominatim) and calculates
/// real driving routes between them (OSRM). Both free, no API key.
class RoutingService {
  Future<LatLng?> geocode(String placeName) async {
    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/search'
      '?q=${Uri.encodeComponent(placeName)}&format=json&limit=1&countrycodes=my',
    );
    final response = await http.get(
      url,
      headers: {'User-Agent': 'DriveOrRideApp/1.0 (student project)'},
    );
    if (response.statusCode == 200) {
      final List results = json.decode(response.body);
      if (results.isNotEmpty) {
        return LatLng(double.parse(results[0]['lat']), double.parse(results[0]['lon']));
      }
    }
    return null;
  }

  Future<DrivingRoute?> getDrivingRoute(LatLng origin, LatLng destination) async {
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '${origin.longitude},${origin.latitude};'
      '${destination.longitude},${destination.latitude}'
      '?overview=full&geometries=geojson',
    );
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['code'] == 'Ok' && data['routes'].isNotEmpty) {
        final route = data['routes'][0];
        final coords = (route['geometry']['coordinates'] as List)
            .map((c) => LatLng(c[1], c[0]))
            .toList();
        return DrivingRoute(
          distanceKm: route['distance'] / 1000.0,
          durationMinutes: route['duration'] / 60.0,
          routePoints: coords,
        );
      }
    }
    return null;
  }
}

class DrivingRoute {
  final double distanceKm;
  final double durationMinutes;
  final List<LatLng> routePoints;

  DrivingRoute({required this.distanceKm, required this.durationMinutes, required this.routePoints});
}
