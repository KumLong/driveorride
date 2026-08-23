import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../services/routing_service.dart';
import '../services/fuel_price_service.dart';
import '../main.dart' show gtfsService;
import 'route_details_screen.dart';

class CompareScreen extends StatefulWidget {
  final LatLng origin;
  final LatLng destination;
  const CompareScreen({super.key, required this.origin, required this.destination});

  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
  final _routingService = RoutingService();
  final _fuelService = FuelPriceService();

  bool _loading = true;
  double? _driveDistanceKm;
  double? _driveDurationMin;
  double? _driveCost;
  String? _nearestOriginStation;
  String? _nearestDestStation;

  static const _litresPerKm = 0.07; // assumed average sedan consumption

  @override
  void initState() {
    super.initState();
    _calculate();
  }

  Future<void> _calculate() async {
    final route = await _routingService.getDrivingRoute(widget.origin, widget.destination);
    final fuelPrice = await _fuelService.getLatestRon95Price();
    final originStation = gtfsService.findNearestStation(widget.origin);
    final destStation = gtfsService.findNearestStation(widget.destination);

    if (route != null) {
      setState(() {
        _driveDistanceKm = route.distanceKm;
        _driveDurationMin = route.durationMinutes;
        _driveCost = route.distanceKm * _litresPerKm * fuelPrice;
        _nearestOriginStation = originStation?.name;
        _nearestDestStation = destStation?.name;
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Compare Route')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    color: const Color(0xFFFEF3C7),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(children: [Icon(Icons.directions_car), SizedBox(width: 8), Text('Drive', style: TextStyle(fontWeight: FontWeight.bold))]),
                          const SizedBox(height: 8),
                          Text('Time: ${_driveDurationMin?.toStringAsFixed(0) ?? "-"} min'),
                          Text('Distance: ${_driveDistanceKm?.toStringAsFixed(1) ?? "-"} km'),
                          Text('Est. fuel cost: RM ${_driveCost?.toStringAsFixed(2) ?? "-"}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    color: const Color(0xFFE6FAF5),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(children: [Icon(Icons.directions_bus), SizedBox(width: 8), Text('Public Transport', style: TextStyle(fontWeight: FontWeight.bold))]),
                          const SizedBox(height: 8),
                          Text('Nearest boarding station: ${_nearestOriginStation ?? "not found"}'),
                          Text('Nearest arrival station: ${_nearestDestStation ?? "not found"}'),
                          const SizedBox(height: 4),
                          const Text(
                            'Fare: use Prasarana\'s official fare calculator for this station pair (no public fare API).',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: _loading ? null : Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => RouteDetailsScreen(origin: widget.origin, destination: widget.destination),
            ));
          },
          child: const Text('View Route Details →'),
        ),
      ),
    );
  }
}
