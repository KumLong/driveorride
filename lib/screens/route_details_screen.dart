import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/models.dart';
import '../services/routing_service.dart';
import '../main.dart' show gtfsService;
import '../theme.dart';
import 'trip_summary_screen.dart';

/// Shows the real map (OpenStreetMap via flutter_map) with the driving
/// route drawn on it (from OSRM), plus the nearest real transit stations
/// found from your verified GTFS stops.txt data.
class RouteDetailsScreen extends StatefulWidget {
  final LatLng origin;
  final LatLng destination;
  const RouteDetailsScreen({super.key, required this.origin, required this.destination});

  @override
  State<RouteDetailsScreen> createState() => _RouteDetailsScreenState();
}

class _RouteDetailsScreenState extends State<RouteDetailsScreen> {
  final _routingService = RoutingService();
  String _mode = 'transit'; // 'drive' or 'transit'
  List<LatLng> _routePoints = [];
  Station? _originStation;
  Station? _destStation;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final route = await _routingService.getDrivingRoute(widget.origin, widget.destination);
    _originStation = gtfsService.findNearestStation(widget.origin);
    _destStation = gtfsService.findNearestStation(widget.destination);
    setState(() {
      _routePoints = route?.routePoints ?? [];
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Route Details')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                SizedBox(
                  height: 220,
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: widget.origin,
                      initialZoom: 12,
                    ),
                    children: [
                      // Real OpenStreetMap tiles (Practical 12 pattern)
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.driveorride',
                      ),
                      if (_routePoints.isNotEmpty)
                        PolylineLayer(polylines: [
                          Polyline(points: _routePoints, color: AppColors.mint, strokeWidth: 4),
                        ]),
                      MarkerLayer(markers: [
                        Marker(point: widget.origin, child: const Icon(Icons.trip_origin, color: AppColors.teal)),
                        Marker(point: widget.destination, child: const Icon(Icons.location_on, color: AppColors.amber)),
                      ]),
                    ],
                  ),
                ),
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      Expanded(
                        child: _modeButton('drive', Icons.directions_car, 'Drive'),
                      ),
                      Expanded(
                        child: _modeButton('transit', Icons.directions_bus, 'Public Transport'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _mode == 'transit' ? _buildTransitSchedule() : _buildDriveSummary(),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.mint, foregroundColor: Colors.white, padding: const EdgeInsets.all(16)),
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => TripSummaryScreen(
                          route: '${_originStation?.name ?? "Origin"} -> ${_destStation?.name ?? "Destination"}',
                          mode: _mode,
                        )));
                      },
                      child: const Text('Confirm My Choice →'),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _modeButton(String value, IconData icon, String label) {
    final selected = _mode == value;
    return GestureDetector(
      onTap: () => setState(() => _mode = value),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.teal : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? Colors.white : Colors.grey, size: 18),
            Text(label, style: TextStyle(color: selected ? Colors.white : Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildTransitSchedule() {
    if (_originStation == null || _destStation == null) {
      return const Center(child: Text('No nearby station found for one of these points.'));
    }
    // NOTE: this shows the two nearest real stations found from your
    // verified GTFS data. Full multi-leg/transfer routing (e.g. Surian ->
    // Taman Melati requiring an interchange) needs the small interchange
    // lookup table discussed earlier — not yet built in this version.
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _scheduleStep(Icons.directions_walk, 'Walk to ${_originStation!.name} station', 'Nearest real station to your origin'),
        _scheduleStep(Icons.directions_railway, 'Board at ${_originStation!.name}', 'Real GTFS station'),
        _scheduleStep(Icons.flag, 'Alight at ${_destStation!.name}', 'Nearest real station to your destination'),
        _scheduleStep(Icons.directions_walk, 'Walk to destination', ''),
        const SizedBox(height: 12),
        const Text(
          'Fare: check Prasarana\'s official fare calculator for this station pair (no public fare API exists).',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildDriveSummary() {
    return const Center(child: Padding(
      padding: EdgeInsets.all(16),
      child: Text('Driving route shown on map above. Toll cost should be added using rate × distance, per the operator\'s published rate (see project notes).', textAlign: TextAlign.center),
    ));
  }

  Widget _scheduleStep(IconData icon, String title, String sub) {
    return ListTile(
      leading: Icon(icon, color: AppColors.mint),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: sub.isNotEmpty ? Text(sub) : null,
    );
  }
}
