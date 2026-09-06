import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/models.dart';
import '../services/routing_service.dart';
import '../services/gtfs_service.dart';
import '../services/fuel_price_service.dart';
import '../main.dart' show gtfsService;
import '../theme.dart';
import 'confirm_choice_screen.dart';

class RouteDetailsScreen extends StatefulWidget {
  final LatLng origin;
  final LatLng destination;
  final String originName;
  final String destinationName;
  const RouteDetailsScreen({super.key, required this.origin, required this.destination, required this.originName, required this.destinationName});

  @override
  State<RouteDetailsScreen> createState() => _RouteDetailsScreenState();
}

class _RouteDetailsScreenState extends State<RouteDetailsScreen> {
  final _routingService = RoutingService();
  final _fuelService = FuelPriceService();
  String _mode = 'transit';
  bool _loading = true;

  List<LatLng> _driveRoutePoints = [];
  double _driveDistanceKm = 0;
  double _driveDurationMin = 0;
  double _driveCost = 0; // REAL: (fuel price × distance) + toll estimate
  double _fuelCost = 0;
  double _tollCost = 0;

  Station? _originStation;
  Station? _destStation;
  MultiLegJourney? _journey;
  double _transitFareEstimate = 0; // ESTIMATED: distance-based formula, no fare API exists

  static const _litresPerKm = 0.07; // assumed average sedan fuel consumption

  /// Toll estimate: rate × distance, matching PLUS's own stated method
  /// ("Toll Fare calculation is based on the current toll rate (cent/km)
  /// and distance travelled" — confirmed from their official FAQ).
  /// RM 0.12/km is a reasonable approximate average across common
  /// Klang Valley expressways for a Class 1 (car) — not every route
  /// actually uses a toll road, so this is a general estimate, not a
  /// route-specific lookup of which exact highway is used.
  static const _tollRatePerKm = 0.12;

  /// Distance-based fare estimate, modelled on Prasarana's published
  /// fare bands (roughly RM1.20 for the shortest trips, scaling up to
  /// a capped maximum around RM6.40 for the longest single trips).
  /// This is an ESTIMATE, not a real fare lookup — no public fare API
  /// exists, as established earlier.
  double _estimateFare(double distanceKm) {
    const baseFare = 1.20;
    const ratePerKm = 0.18;
    const maxFare = 6.40;
    return (baseFare + ratePerKm * distanceKm).clamp(baseFare, maxFare);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final route = await _routingService.getDrivingRoute(widget.origin, widget.destination);
    final fuelPrice = await _fuelService.getLatestRon95Price();
    _originStation = gtfsService.findNearestStation(widget.origin);
    _destStation = gtfsService.findNearestStation(widget.destination);

    if (_originStation != null && _destStation != null) {
      _journey = gtfsService.findJourney(_originStation!, _destStation!);
    }

    setState(() {
      _driveRoutePoints = route?.routePoints ?? [];
      _driveDistanceKm = route?.distanceKm ?? 0;
      _driveDurationMin = route?.durationMinutes ?? 0;
      _fuelCost = _driveDistanceKm * _litresPerKm * fuelPrice;
      _tollCost = _driveDistanceKm * _tollRatePerKm;
      _driveCost = _fuelCost + _tollCost; // REAL combined calculation
      _transitFareEstimate = _journey != null ? _estimateFare(_journey!.totalDistanceKm) : 0;
      _loading = false;
    });
  }

  List<LatLng> get _transitPolyline {
    if (_journey == null) return [];
    return _journey!.legs.expand((leg) => leg.shapePoints).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Route Details')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          SizedBox(
            height: 220,
            child: FlutterMap(
              options: MapOptions(initialCenter: widget.origin, initialZoom: 12),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.driveorride',
                ),
                if (_mode == 'drive' && _driveRoutePoints.isNotEmpty)
                  PolylineLayer(polylines: [Polyline(points: _driveRoutePoints, color: AppColors.amber, strokeWidth: 4)]),
                if (_mode == 'transit' && _transitPolyline.isNotEmpty)
                  PolylineLayer(polylines: [Polyline(points: _transitPolyline, color: AppColors.mint, strokeWidth: 4)]),
                MarkerLayer(markers: [
                  Marker(point: widget.origin, width: 30, height: 30, child: const Icon(Icons.trip_origin, color: AppColors.teal)),
                  Marker(point: widget.destination, width: 30, height: 30, child: const Icon(Icons.location_on, color: AppColors.amber)),
                ]),
              ],
            ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(child: _modeButton('drive', Icons.directions_car, 'Drive')),
                const SizedBox(width: 8),
                Expanded(child: _modeButton('transit', Icons.directions_bus, 'Public Transport')),
              ],
            ),
          ),
          Expanded(child: _mode == 'transit' ? _buildTransitContent() : _buildDriveContent()),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(onPressed: _canConfirm() ? _onConfirm : null, child: const Text('Confirm My Choice →')),
            ),
          ),
        ],
      ),
    );
  }

  bool _canConfirm() {
    return _driveRoutePoints.isNotEmpty || _journey != null;
  }

  void _onConfirm() {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ConfirmChoiceScreen(
        destination: widget.destination,
        originName: widget.originName,
        destinationName: widget.destinationName,
        driveRoutePoints: _driveRoutePoints,
        driveDistanceKm: _driveDistanceKm,
        driveDurationMin: _driveDurationMin,
        driveCost: _driveCost,
        journey: _journey,
        transitFare: _transitFareEstimate,
      ),
    ));
  }

  Widget _modeButton(String value, IconData icon, String label) {
    final selected = _mode == value;
    return GestureDetector(
      onTap: () => setState(() => _mode = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: selected ? AppColors.teal : Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          Icon(icon, color: selected ? Colors.white : Colors.grey, size: 18),
          Text(label, style: TextStyle(color: selected ? Colors.white : Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }

  Widget _buildTransitContent() {
    if (_originStation == null || _destStation == null) {
      return const Center(child: Padding(padding: EdgeInsets.all(16), child: Text('No nearby real transit station found for one of these points.', textAlign: TextAlign.center)));
    }
    if (_journey == null) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.info_outline, color: Colors.grey, size: 32),
            const SizedBox(height: 12),
            Text('No route found between ${_originStation!.name} and ${_destStation!.name} within one transfer.', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'This version automatically finds direct and single-transfer journeys. Trips needing 2+ transfers aren\'t supported yet.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    final j = _journey!;

    // Build a live, always-consistent timeline: instead of showing each
    // leg's raw absolute schedule time (which may not line up with the
    // other leg if the sample data is sparse), we use the REAL travel
    // durations between stops (a genuine fact from the schedule data)
    // and anchor the whole journey starting from right now — the same
    // way you'd actually plan a trip: "if I leave now, I'll reach each
    // stop at approximately this time."
    const walkToFirstStationMinutes = 5;
    const transferBufferMinutes = 3;
    final displayTimes = <DateTime>[];
    DateTime cursor = DateTime.now().add(const Duration(minutes: walkToFirstStationMinutes));
    for (int legIdx = 0; legIdx < j.legs.length; legIdx++) {
      final stops = j.legs[legIdx].intermediateStops;
      if (legIdx > 0) cursor = cursor.add(const Duration(minutes: transferBufferMinutes));
      final legStartTime = stops.first.arrivalTime;
      for (final st in stops) {
        final offsetMinutes = GtfsService.minutesBetweenTimes(legStartTime, st.arrivalTime);
        displayTimes.add(cursor.add(Duration(minutes: offsetMinutes)));
      }
      cursor = displayTimes.last; // next leg (if any) continues from here
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.mintLight, borderRadius: BorderRadius.circular(14)),
          child: Row(
            children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Total time', style: TextStyle(fontSize: 10, color: Colors.grey)),
                Text('${j.totalDurationMinutes} min', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.teal)),
              ])),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Est. fare', style: TextStyle(fontSize: 10, color: Colors.grey)),
                Text('RM ${_transitFareEstimate.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.teal)),
              ])),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Transfers', style: TextStyle(fontSize: 10, color: Colors.grey)),
                Text(j.needsTransfer ? '1' : 'None', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.teal)),
              ])),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            Icon(Icons.info_outline, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 8),
            Expanded(child: Text(
              'Times shown assume you leave now — calculated from real scheduled travel durations for this line, not a live feed.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
            )),
          ]),
        ),
        for (int legIdx = 0, flatIdx = 0; legIdx < j.legs.length; legIdx++) ...[
          if (legIdx > 0)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.amberLight, borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                const Icon(Icons.sync_alt, color: AppColors.amber, size: 18),
                const SizedBox(width: 8),
                Text('Transfer at ${j.legs[legIdx - 1].alightStation.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ]),
            ),
          ...j.legs[legIdx].intermediateStops.asMap().entries.map((entry) {
            final i = entry.key;
            final st = entry.value;
            final station = gtfsService.getStationById(st.stopId);
            final isFirst = i == 0;
            final isLast = i == j.legs[legIdx].intermediateStops.length - 1;
            final displayTime = displayTimes[flatIdx];
            flatIdx++;
            return ListTile(
              leading: Icon(isFirst ? Icons.trip_origin : (isLast ? Icons.flag : Icons.fiber_manual_record), size: isFirst || isLast ? 22 : 12, color: AppColors.mint),
              title: Text(station?.name ?? st.stopId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: Text(GtfsService.formatDateTime(displayTime)),
              dense: true,
            );
          }),
        ],
        const SizedBox(height: 8),
        const Text('Fare is an estimate based on Prasarana\'s published distance-based fare bands — no public fare API exists, so this is not pulled from a live source.', style: TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _buildDriveContent() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(children: [
            Expanded(child: _statBox(Icons.route, 'Distance', '${_driveDistanceKm.toStringAsFixed(1)} km')),
            const SizedBox(width: 10),
            Expanded(child: _statBox(Icons.access_time, 'Time', '${_driveDurationMin.toStringAsFixed(0)} min')),
            const SizedBox(width: 10),
            Expanded(child: _statBox(Icons.payments, 'Total cost', 'RM ${_driveCost.toStringAsFixed(2)}', highlight: true)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _statBox(Icons.local_gas_station, 'Fuel', 'RM ${_fuelCost.toStringAsFixed(2)}')),
            const SizedBox(width: 10),
            Expanded(child: _statBox(Icons.toll, 'Toll (est.)', 'RM ${_tollCost.toStringAsFixed(2)}')),
          ]),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: const Text(
              'Fuel is calculated live (fuel price × distance). Toll is estimated using rate × distance, per PLUS\'s own published calculation method — not every route actually uses a toll road, so this is a general estimate, not a route-specific lookup.',
              style: TextStyle(fontSize: 11, color: Colors.grey, height: 1.4),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statBox(IconData icon, String label, String value, {bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: highlight ? AppColors.teal : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: highlight ? AppColors.mint : AppColors.amber),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 9, color: highlight ? Colors.white70 : Colors.grey)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: highlight ? Colors.white : AppColors.teal), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}