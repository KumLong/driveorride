import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/models.dart';
import '../services/routing_service.dart';
import '../services/gtfs_service.dart';
import '../services/fuel_price_service.dart';
import '../services/fuel_preference_service.dart';
import '../services/report_service.dart';
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
  final _fuelPreference = FuelPreferenceService();
  final _reportService = ReportService();
  String _mode = 'transit';
  bool _loading = true;
  List<RouteReport> _roadReports = [];
  List<RouteReport> _railReports = [];

  List<LatLng> _driveRoutePoints = [];
  double _driveDistanceKm = 0;
  double _driveDurationMin = 0;
  double _driveCost = 0;
  double _fuelCost = 0;
  double _tollCost = 0;
  List<String> _driveSteps = [];

  Station? _originStation;
  Station? _destStation;
  MultiLegJourney? _journey;
  double _transitFareEstimate = 0;

  static const _litresPerKm = 0.07;
  static const _tollRatePerKm = 0.12;

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
    final fuelType = await _fuelPreference.getFuelType();
    final fuelPrice = await _fuelService.getLatestPrice(fuelType);
    _originStation = gtfsService.findNearestStation(widget.origin);
    _destStation = gtfsService.findNearestStation(widget.destination);

    if (_originStation != null && _destStation != null) {
      _journey = gtfsService.findJourney(_originStation!, _destStation!);
    }

    setState(() {
      _driveRoutePoints = route?.routePoints ?? [];
      _driveDistanceKm = route?.distanceKm ?? 0;
      _driveDurationMin = route?.durationMinutes ?? 0;
      _driveSteps = route?.steps ?? [];
      _fuelCost = _driveDistanceKm * _litresPerKm * fuelPrice;
      _tollCost = _driveDistanceKm * _tollRatePerKm;
      _driveCost = _fuelCost + _tollCost;
      _transitFareEstimate = _journey != null ? _estimateFare(_journey!.totalDistanceKm) : 0;
      _loading = false;
    });

    try {
      if (_driveRoutePoints.isNotEmpty) {
        final roadReports = await _reportService.getApprovedRoadReports(_driveRoutePoints);
        if (mounted) setState(() => _roadReports = roadReports);
      }
      if (_journey != null) {

        final stationNames = _journey!.legs
            .expand((leg) => leg.intermediateStops)
            .map((st) => gtfsService.getStationById(st.stopId)?.name)
            .whereType<String>()
            .toSet()
            .toList();
        final railReports = await _reportService.getApprovedRailReports(stationNames);
        if (mounted) setState(() => _railReports = railReports);
      }
    } catch (e) {

      print('Could not check for active reports: $e');
    }
  }

  List<LatLng> get _transitPolyline {
    if (_journey == null) return [];
    return _journey!.legs.expand((leg) => leg.shapePoints).toList();
  }

  int _estimateWalkMinutes(LatLng a, LatLng b) {
    final meters = Distance()(a, b);
    final km = meters / 1000.0;
    final minutes = (km / 0.08).ceil();
    return minutes < 1 ? 1 : minutes;
  }

  bool _canConfirm() {
    return _driveRoutePoints.isNotEmpty || _journey != null;
  }

  void _onConfirm() {

    final walkToFirstStationMin = _originStation != null ? _estimateWalkMinutes(widget.origin, LatLng(_originStation!.lat, _originStation!.lon)) : 5;
    final walkFromLastStationMin = _destStation != null ? _estimateWalkMinutes(LatLng(_destStation!.lat, _destStation!.lon), widget.destination) : 5;

    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ConfirmChoiceScreen(
        destination: widget.destination,
        originName: widget.originName,
        destinationName: widget.destinationName,
        driveRoutePoints: _driveRoutePoints,
        driveDistanceKm: _driveDistanceKm,
        driveDurationMin: _driveDurationMin,
        driveCost: _driveCost,
        driveSteps: _driveSteps,
        journey: _journey,
        transitFare: _transitFareEstimate,
        walkToFirstStationMin: walkToFirstStationMin,
        walkFromLastStationMin: walkFromLastStationMin,
      ),
    ));
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

          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                const Icon(Icons.circle, size: 10, color: AppColors.teal),
                const SizedBox(width: 8),
                Expanded(child: Text(widget.originName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis)),
                Icon(Icons.arrow_forward, size: 14, color: Colors.grey.shade400),
                const SizedBox(width: 8),
                const Icon(Icons.location_on, size: 14, color: AppColors.amber),
                const SizedBox(width: 4),
                Expanded(child: Text(widget.destinationName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),

          SizedBox(
            height: 200,
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
                  PolylineLayer(polylines: [
                    Polyline(points: _transitPolyline, color: AppColors.mint, strokeWidth: 4),
                    if (_originStation != null)
                      Polyline(points: [widget.origin, LatLng(_originStation!.lat, _originStation!.lon)], color: Colors.grey.shade600, strokeWidth: 3, pattern: StrokePattern.dashed(segments: const [6, 6])),
                    if (_destStation != null)
                      Polyline(points: [LatLng(_destStation!.lat, _destStation!.lon), widget.destination], color: Colors.grey.shade600, strokeWidth: 3, pattern: StrokePattern.dashed(segments: const [6, 6])),
                  ]),
                MarkerLayer(markers: [
                  Marker(point: widget.origin, width: 30, height: 30, child: const Icon(Icons.trip_origin, color: AppColors.teal)),
                  Marker(point: widget.destination, width: 30, height: 30, child: const Icon(Icons.location_on, color: AppColors.amber)),
                ]),
              ],
            ),
          ),

          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
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

  Widget _reportWarningBanner(List<RouteReport> reports) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.report_problem, color: Colors.orange, size: 18),
            const SizedBox(width: 8),
            Text('${reports.length} report${reports.length > 1 ? 's' : ''} on this route', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.orange.shade900)),
          ]),
          const SizedBox(height: 8),
          ...reports.take(3).map((r) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('• ${r.issueType[0].toUpperCase()}${r.issueType.substring(1)}: ${r.description}', style: TextStyle(fontSize: 12, color: Colors.orange.shade800)),
          )),
        ],
      ),
    );
  }

  Widget _statsRow(List<(String, String)> items) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: List.generate(items.length * 2 - 1, (i) {
          if (i.isOdd) {
            return Container(width: 1, height: 32, color: Colors.grey.shade200, margin: const EdgeInsets.symmetric(horizontal: 4));
          }
          final (label, value) = items[i ~/ 2];
          return Expanded(
            child: Column(
              children: [
                Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.teal)),
                const SizedBox(height: 2),
                Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _stepTile({required bool isFirst, required bool isLast, required String title, String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              isFirst ? Icons.trip_origin : (isLast ? Icons.flag : Icons.fiber_manual_record),
              size: isFirst || isLast ? 18 : 10,
              color: AppColors.mint,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.teal)),
                if (subtitle != null) Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriveContent() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_roadReports.isNotEmpty) ...[
          _reportWarningBanner(_roadReports),
          const SizedBox(height: 12),
        ],
        _statsRow([
          ('Travel time', '${_driveDurationMin.toStringAsFixed(0)} min'),
          ('Distance', '${_driveDistanceKm.toStringAsFixed(1)} km'),
          ('Est. cost', 'RM ${_driveCost.toStringAsFixed(2)}'),
        ]),
        const SizedBox(height: 20),
        const Text('Route details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.teal)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: _driveSteps.isEmpty
              ? Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: _stepTile(isFirst: true, isLast: true, title: '${widget.originName} → ${widget.destinationName}', subtitle: 'Turn-by-turn steps unavailable for this route'),
          )
              : Column(
            children: List.generate(_driveSteps.length, (i) => _stepTile(
              isFirst: i == 0,
              isLast: i == _driveSteps.length - 1,
              title: _driveSteps[i],
            )),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
          child: Row(
            children: [
              Expanded(child: Row(children: [const Icon(Icons.local_gas_station, size: 16, color: AppColors.amber), const SizedBox(width: 6), Text('Fuel: RM ${_fuelCost.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))])),
              Expanded(child: Row(children: [const Icon(Icons.toll, size: 16, color: AppColors.amber), const SizedBox(width: 6), Text('Toll: RM ${_tollCost.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))])),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Turn-by-turn directions are real, from OSRM\'s routing data. Fuel is calculated live; toll is a general rate-based estimate, not route-specific.',
          style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
          textAlign: TextAlign.center,
        ),
      ],
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

    const transferBufferMinutes = 3;
    final walkToFirstStationMinutes = _estimateWalkMinutes(widget.origin, LatLng(_originStation!.lat, _originStation!.lon));
    final displayTimes = <DateTime>[];
    DateTime cursor = DateTime.now().add(Duration(minutes: walkToFirstStationMinutes));
    for (int legIdx = 0; legIdx < j.legs.length; legIdx++) {
      final stops = j.legs[legIdx].intermediateStops;
      if (legIdx > 0) cursor = cursor.add(const Duration(minutes: transferBufferMinutes));
      final legStartTime = stops.first.arrivalTime;
      for (final st in stops) {
        final offsetMinutes = GtfsService.minutesBetweenTimes(legStartTime, st.arrivalTime);
        displayTimes.add(cursor.add(Duration(minutes: offsetMinutes)));
      }
      cursor = displayTimes.last;
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_railReports.isNotEmpty) ...[
          _reportWarningBanner(_railReports),
          const SizedBox(height: 12),
        ],
        _statsRow([
          ('Travel time', '${j.totalDurationMinutes + walkToFirstStationMinutes + _estimateWalkMinutes(LatLng(_destStation!.lat, _destStation!.lon), widget.destination)} min'),
          ('Est. fare', 'RM ${_transitFareEstimate.toStringAsFixed(2)}'),
          ('Transfers', j.needsTransfer ? '1' : '0'),
        ]),
        const SizedBox(height: 12),
        if (j.needsTransfer)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.amberLight, borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              const Icon(Icons.sync_alt, color: AppColors.amber, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text('Transfer at ${j.transferStation!.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            ]),
          ),
        const SizedBox(height: 4),
        const Text('Route details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.teal)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              for (int legIdx = 0, flatIdx = 0; legIdx < j.legs.length; legIdx++) ...[
                if (legIdx == 0)
                  _stepTile(isFirst: true, isLast: false, title: 'Walk to ${_originStation!.name}', subtitle: '~$walkToFirstStationMinutes min walk'),
                if (legIdx > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      const SizedBox(width: 4),
                      const Icon(Icons.sync_alt, size: 14, color: AppColors.amber),
                      const SizedBox(width: 8),
                      Text('Change at ${j.legs[legIdx - 1].alightStation.name}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.amber)),
                    ]),
                  ),
                ...j.legs[legIdx].intermediateStops.asMap().entries.map((entry) {
                  final i = entry.key;
                  final st = entry.value;
                  final station = gtfsService.getStationById(st.stopId);
                  final displayTime = displayTimes[flatIdx];
                  flatIdx++;
                  return _stepTile(
                    isFirst: false,
                    isLast: false,
                    title: station?.name ?? st.stopId,
                    subtitle: GtfsService.formatDateTime(displayTime),
                  );
                }),
                if (legIdx == j.legs.length - 1)
                  _stepTile(isFirst: false, isLast: true, title: 'Walk to ${widget.destinationName}', subtitle: '~${_estimateWalkMinutes(LatLng(_destStation!.lat, _destStation!.lon), widget.destination)} min walk'),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Times assume you leave now, using real scheduled durations. Fare is an estimate — no public fare API exists.',
          style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}