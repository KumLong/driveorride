import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class RoutingService {

  Future<LatLng?> geocode(String placeName) async {
    final direct = await _tryGeocode(placeName);
    if (direct != null) return direct;

    if (!placeName.toLowerCase().contains('malaysia')) {
      final retry = await _tryGeocode('$placeName, Malaysia');
      if (retry != null) return retry;
    }
    return null;
  }

  Future<LatLng?> _tryGeocode(String query) async {
    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/search'
          '?q=${Uri.encodeComponent(query)}&format=json&limit=1&countrycodes=my',
    );
    try {
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
    } catch (e) {

      print('Geocode error for "$query": $e');
    }
    return null;
  }

  Future<DrivingRoute?> getDrivingRoute(LatLng origin, LatLng destination) async {
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
          '${origin.longitude},${origin.latitude};'
          '${destination.longitude},${destination.latitude}'
          '?overview=full&geometries=geojson&steps=true',
    );
    try {
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
            steps: _parseSteps(route),
          );
        }
      }
    } catch (e) {

      print('OSRM routing failed, falling back to straight-line estimate: $e');
    }

    final straightLineKm = Distance()(origin, destination) / 1000.0;
    final estimatedRoadKm = straightLineKm * 1.3;
    const avgSpeedKmh = 40.0;
    return DrivingRoute(
      distanceKm: estimatedRoadKm,
      durationMinutes: (estimatedRoadKm / avgSpeedKmh) * 60,
      routePoints: [origin, destination],
      steps: [],
    );
  }

  List<String> _parseSteps(Map<String, dynamic> route) {
    final steps = <String>[];
    try {
      for (final leg in route['legs']) {
        for (final step in leg['steps']) {
          final maneuver = step['maneuver'];
          final type = maneuver['type'] as String;
          final modifier = maneuver['modifier'] as String?;
          final name = (step['name'] as String?)?.trim() ?? '';
          final ref = (step['ref'] as String?)?.trim() ?? '';
          final roadLabel = [name, if (ref.isNotEmpty) '($ref)'].where((s) => s.isNotEmpty).join(' ');

          String text;
          switch (type) {
            case 'depart':
              text = roadLabel.isNotEmpty ? 'Head out via $roadLabel' : 'Start your journey';
              break;
            case 'arrive':
              text = 'Arrive at your destination';
              break;
            case 'merge':
            case 'on ramp':
              text = roadLabel.isNotEmpty ? 'Merge onto $roadLabel' : 'Merge onto the main road';
              break;
            case 'off ramp':
              text = roadLabel.isNotEmpty ? 'Take the exit toward $roadLabel' : 'Take the exit';
              break;
            case 'fork':
              text = modifier != null ? 'Keep $modifier at the fork${roadLabel.isNotEmpty ? ' onto $roadLabel' : ''}' : 'Continue at the fork';
              break;
            case 'turn':
              text = modifier != null ? 'Turn $modifier${roadLabel.isNotEmpty ? ' onto $roadLabel' : ''}' : 'Turn${roadLabel.isNotEmpty ? ' onto $roadLabel' : ''}';
              break;
            case 'roundabout':
            case 'rotary':
              text = 'Go through the roundabout${roadLabel.isNotEmpty ? ' onto $roadLabel' : ''}';
              break;
            case 'new name':
              text = roadLabel.isNotEmpty ? 'Continue onto $roadLabel' : 'Continue straight';
              break;
            default:
              text = roadLabel.isNotEmpty ? 'Continue on $roadLabel' : 'Continue';
          }
          if (text.trim().isNotEmpty) steps.add(text);
        }
      }
    } catch (e) {

      print('Could not parse OSRM steps (route still works without them): $e');
    }
    return steps;
  }
}

class DrivingRoute {
  final double distanceKm;
  final double durationMinutes;
  final List<LatLng> routePoints;
  final List<String> steps;

  DrivingRoute({required this.distanceKm, required this.durationMinutes, required this.routePoints, this.steps = const []});
}