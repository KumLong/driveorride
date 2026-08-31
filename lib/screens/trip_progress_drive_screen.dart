import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart' as loc;
import '../services/location_tracking_service.dart';
import '../theme.dart';
import 'trip_summary_screen.dart';
import 'stop_trip_screen.dart';

/// Live GPS tracking during a drive — matches Practical 13's location
/// package pattern. Shows a moving "you are here" dot on the map.
class TripProgressDriveScreen extends StatefulWidget {
  final LatLng destination;
  final String routeName;
  final List<LatLng> routePoints;
  final double distanceKm;
  final double cost;
  final double savedVsAlternative;
  const TripProgressDriveScreen({
    super.key,
    required this.destination,
    required this.routeName,
    required this.routePoints,
    required this.distanceKm,
    required this.cost,
    required this.savedVsAlternative,
  });

  @override
  State<TripProgressDriveScreen> createState() => _TripProgressDriveScreenState();
}

class _TripProgressDriveScreenState extends State<TripProgressDriveScreen> {
  final _locationService = LocationTrackingService();
  LatLng? _currentPosition;
  double _distanceRemainingKm = 0;

  @override
  void initState() {
    super.initState();
    _distanceRemainingKm = widget.distanceKm;
    _startTracking();
  }

  Future<void> _startTracking() async {
    final granted = await _locationService.isPermissionGranted();
    if (!granted) await _locationService.requestLocationPermission();
    final gpsOn = await _locationService.requestEnableGps();
    if (!gpsOn) return;

    _locationService.startTracking((loc.LocationData data) {
      if (data.latitude == null || data.longitude == null) return;
      final pos = LatLng(data.latitude!, data.longitude!);
      final dist = Distance()(pos, widget.destination) / 1000.0;
      setState(() {
        _currentPosition = pos;
        _distanceRemainingKm = dist;
      });
    });
  }

  @override
  void dispose() {
    _locationService.stopTracking();
    super.dispose();
  }

  void _onStop() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const StopTripScreen()));
  }

  void _onArrived() {
    Navigator.pushReplacement(context, MaterialPageRoute(
      builder: (_) => TripSummaryScreen(route: widget.routeName, mode: 'drive', cost: widget.cost, savedVsAlternative: widget.savedVsAlternative, distanceKm: widget.distanceKm),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final center = _currentPosition ?? (widget.routePoints.isNotEmpty ? widget.routePoints.first : widget.destination);
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('On the Way')),
      body: Column(
        children: [
          SizedBox(
            height: 260,
            child: FlutterMap(
              options: MapOptions(initialCenter: center, initialZoom: 13),
              children: [
                TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.example.driveorride'),
                if (widget.routePoints.isNotEmpty)
                  PolylineLayer(polylines: [Polyline(points: widget.routePoints, color: AppColors.amber, strokeWidth: 4)]),
                MarkerLayer(markers: [
                  Marker(point: widget.destination, width: 30, height: 30, child: const Icon(Icons.location_on, color: AppColors.amber)),
                  if (_currentPosition != null)
                    Marker(
                      point: _currentPosition!,
                      width: 34, height: 34,
                      child: Container(
                        decoration: BoxDecoration(color: AppColors.mint, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
                        child: const Icon(Icons.navigation, color: Colors.white, size: 16),
                      ),
                    ),
                ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: AppColors.mintLight, borderRadius: BorderRadius.circular(14)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Distance remaining', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      Text('${_distanceRemainingKm.toStringAsFixed(1)} km', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.teal)),
                    ]),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: AppColors.amberLight, borderRadius: BorderRadius.circular(14)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Status', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      Text(_currentPosition == null ? 'Waiting for GPS...' : 'Tracking live', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.teal)),
                    ]),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _onArrived, child: const Text("I've Arrived"))),
                const SizedBox(height: 8),
                SizedBox(width: double.infinity, child: OutlinedButton(onPressed: _onStop, child: const Text('Stop Trip'))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
