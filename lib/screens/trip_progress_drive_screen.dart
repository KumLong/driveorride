import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart' as loc;
import '../services/location_tracking_service.dart';
import '../services/database_service.dart';
import 'report_issue_dialog.dart';
import '../theme.dart';
import 'trip_summary_screen.dart';
import 'nfc_pay_screen.dart';
import 'top_up_screen.dart';

/// Live GPS tracking during a drive — matches Practical 13's location
/// package pattern. Shows a moving "you are here" dot on the map, a
/// real progress bar, a real ETA, and the actual turn-by-turn
/// directions from OSRM for this specific route.
class TripProgressDriveScreen extends StatefulWidget {
  final LatLng destination;
  final String routeName;
  final List<LatLng> routePoints;
  final double distanceKm;
  final double durationMin; // the ORIGINAL planned duration, for ETA calc
  final List<String> steps;
  final double cost;
  final double savedVsAlternative;
  const TripProgressDriveScreen({
    super.key,
    required this.destination,
    required this.routeName,
    required this.routePoints,
    required this.distanceKm,
    required this.durationMin,
    required this.steps,
    required this.cost,
    required this.savedVsAlternative,
  });

  @override
  State<TripProgressDriveScreen> createState() => _TripProgressDriveScreenState();
}

class _TripProgressDriveScreenState extends State<TripProgressDriveScreen> {
  final _locationService = LocationTrackingService();
  final _db = DatabaseService();
  LatLng? _currentPosition;
  double _distanceRemainingKm = 0;
  late final double _totalDistanceKm; // fixed at trip start, for the progress bar

  // Same rate your leader already uses in compare_screen.dart /
  // route_details_screen.dart (RM0.12/km) — recomputed independently
  // here, from the distanceKm this screen already receives, so the
  // wallet can charge the real toll-only amount without needing any
  // change to those files or an extra parameter threaded through them.
  static const _tollRatePerKm = 0.12;
  double get _tollCost => widget.distanceKm * _tollRatePerKm;

  // Cumulative distance (km) along the REAL route shape, from the
  // start up to each point — e.g. _cumulativeKm[5] is how far along
  // the actual road you'd have travelled by the time you reach
  // routePoints[5]. This is what makes progress correctly follow the
  // road's real curves and turns, instead of a straight line — a
  // straight line from start to your current position is almost
  // always SHORTER than the real road distance (roads curve, a
  // straight line doesn't), which is exactly why progress used to get
  // stuck around 70% even standing right at the destination.
  late final List<double> _cumulativeKm;

  @override
  void initState() {
    super.initState();
    _distanceRemainingKm = widget.distanceKm;
    _totalDistanceKm = widget.distanceKm > 0 ? widget.distanceKm : 1; // avoid divide-by-zero
    _cumulativeKm = _buildCumulativeDistances(widget.routePoints);
    _startTracking();
  }

  /// Builds the running total distance (km) along the route, one
  /// entry per point — entry 0 is always 0 (the start), and the last
  /// entry is the real total road distance.
  List<double> _buildCumulativeDistances(List<LatLng> points) {
    final result = <double>[0.0];
    if (points.isEmpty) return result;
    final distance = Distance();
    double running = 0.0;
    for (int i = 1; i < points.length; i++) {
      running += distance(points[i - 1], points[i]) / 1000.0;
      result.add(running);
    }
    return result;
  }

  Future<void> _startTracking() async {
    final granted = await _locationService.isPermissionGranted();
    if (!granted) await _locationService.requestLocationPermission();
    final gpsOn = await _locationService.requestEnableGps();
    if (!gpsOn) return;

    _locationService.startTracking((loc.LocationData data) {
      if (data.latitude == null || data.longitude == null) return;
      final pos = LatLng(data.latitude!, data.longitude!);

      // Finds whichever point on the REAL route is currently
      // closest to you, then reads off how far along the road that
      // point actually is — correctly reaching the full total
      // distance right at the destination, and correctly starting
      // at 0 right at the origin, since both ends of the route are
      // real points in this same list.
      final traveledKm = _distanceTravelledAlongRoute(pos);
      final dist = (_totalDistanceKm - traveledKm).clamp(0.0, _totalDistanceKm);

      if (mounted) {
        setState(() {
          _currentPosition = pos;
          _distanceRemainingKm = dist;
        });
      }
    });
  }

  /// Finds the point on the real route closest to [pos], and returns
  /// how far along the actual road that point is — this is the real
  /// fix: measuring against the road's real shape, not a straight
  /// line, so it correctly reaches the full distance right at the
  /// destination and starts at 0 right at the origin.
  double _distanceTravelledAlongRoute(LatLng pos) {
    if (widget.routePoints.isEmpty) return 0.0;
    final distance = Distance();
    int closestIndex = 0;
    double closestDistanceMeters = double.infinity;
    for (int i = 0; i < widget.routePoints.length; i++) {
      final d = distance(pos, widget.routePoints[i]);
      if (d < closestDistanceMeters) {
        closestDistanceMeters = d;
        closestIndex = i;
      }
    }
    return _cumulativeKm[closestIndex];
  }

  @override
  void dispose() {
    _locationService.stopTracking();
    super.dispose();
  }

  /// Real-ish ETA: scales the original planned duration by how much
  /// distance is actually left, then adds that to the current real
  /// clock time — e.g. if half the distance remains, assumes roughly
  /// half the time remains too.
  DateTime get _estimatedArrival {
    final progressRatio = (_distanceRemainingKm / _totalDistanceKm).clamp(0, 1);
    final minutesRemaining = widget.durationMin * progressRatio;
    return DateTime.now().add(Duration(minutes: minutesRemaining.round()));
  }

  String _formatTime(DateTime dt) {
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    int hour12 = dt.hour % 12;
    if (hour12 == 0) hour12 = 12;
    return '$hour12:${dt.minute.toString().padLeft(2, '0')} $period';
  }

  double get _progressFraction {
    final travelled = _totalDistanceKm - _distanceRemainingKm;
    return (travelled / _totalDistanceKm).clamp(0, 1).toDouble();
  }

  /// Taps the virtual wallet to pay THIS trip's real TOLL only —
  /// _tollCost, recomputed from the real distance using your leader's
  /// existing RM0.12/km rate — not the combined fuel+toll `widget.cost`.
  /// Checks balance first and offers a Top Up shortcut if it's
  /// insufficient, same pattern as the transit screen's fare payment.
  Future<void> _onPayToll() async {
    final balance = await _db.getWalletBalance();
    if (balance < _tollCost) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Insufficient balance for this RM ${_tollCost.toStringAsFixed(2)} toll.'),
          action: SnackBarAction(
            label: 'Top Up',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TopUpScreen())),
          ),
        ),
      );
      return;
    }

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NfcPayScreen(amount: _tollCost, label: 'Toll Payment'),
      ),
    );
  }

  void _onStop() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: GestureDetector(
                  onTap: () => Navigator.pop(dialogContext),
                  child: const Icon(Icons.close, color: Colors.grey, size: 20),
                ),
              ),
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(color: AppColors.amberLight, shape: BoxShape.circle),
                child: const Icon(Icons.warning_amber_rounded, color: AppColors.amber, size: 32),
              ),
              const SizedBox(height: 16),
              const Text('Stop this trip?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.teal)),
              const SizedBox(height: 8),
              const Text(
                'This trip won\'t be counted in your savings if you stop now.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.mintLight, borderRadius: BorderRadius.circular(14)),
                child: Row(
                  children: [
                    const Icon(Icons.savings, color: AppColors.mint),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('This trip\'s savings', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        Text('RM ${widget.savedVsAlternative.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.teal)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        Navigator.popUntil(context, (route) => route.isFirst);
                      },
                      child: const Text('Stop Trip'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
      appBar: AppBar(
        title: const Text('On the Way'),
        actions: [
          if (_tollCost > 0)
            IconButton(
              tooltip: 'Pay toll with wallet',
              icon: const Icon(Icons.contactless_outlined),
              onPressed: _onPayToll,
            ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 220,
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
                ]),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Real stat row: distance remaining, ETA, status ──
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(children: [
                          Text('${_distanceRemainingKm.toStringAsFixed(1)} km', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.teal)),
                          const Text('Remaining', style: TextStyle(fontSize: 10, color: Colors.grey)),
                        ]),
                      ),
                      Container(width: 1, height: 32, color: Colors.grey.shade200),
                      Expanded(
                        child: Column(children: [
                          Text(_formatTime(_estimatedArrival), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.teal)),
                          const Text('ETA', style: TextStyle(fontSize: 10, color: Colors.grey)),
                        ]),
                      ),
                      Container(width: 1, height: 32, color: Colors.grey.shade200),
                      Expanded(
                        child: Column(children: [
                          Icon(_currentPosition == null ? Icons.gps_not_fixed : Icons.gps_fixed, color: _currentPosition == null ? Colors.grey : AppColors.mint, size: 18),
                          Text(_currentPosition == null ? 'Waiting...' : 'Live', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        ]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // ── Real progress bar: how much of the route is done ──
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Start', style: TextStyle(fontSize: 10, color: Colors.grey)),
                          Text('${(_progressFraction * 100).toStringAsFixed(0)}% complete', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.mint)),
                          const Text('Arrive', style: TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(value: _progressFraction, backgroundColor: Colors.grey.shade200, color: AppColors.mint, minHeight: 8),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (widget.steps.isNotEmpty) ...[
                  const Text('Directions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.teal)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      children: List.generate(widget.steps.length, (i) {
                        final isFirst = i == 0;
                        final isLast = i == widget.steps.length - 1;
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
                              Expanded(child: Text(widget.steps[i], style: const TextStyle(fontSize: 13, color: AppColors.teal, fontWeight: FontWeight.w600))),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Directions are real, from OSRM\'s routing data — not step-by-step live navigation, since matching your live position to the exact current step isn\'t built in this version.',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _onArrived, child: const Text("I've Arrived"))),
                const SizedBox(height: 8),
                SizedBox(width: double.infinity, child: OutlinedButton(onPressed: _onStop, child: const Text('Stop Trip'))),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _currentPosition == null ? null : () => showReportIssueDialog(
                      context,
                      category: 'road',
                      latitude: _currentPosition!.latitude,
                      longitude: _currentPosition!.longitude,
                    ),
                    icon: const Icon(Icons.report_problem_outlined, size: 16, color: Colors.orange),
                    label: const Text('Report an Issue', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13)),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.orange)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}