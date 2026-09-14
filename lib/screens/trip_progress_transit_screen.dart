import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart' as loc;
import '../services/gtfs_service.dart';
import '../services/location_tracking_service.dart';
import '../services/database_service.dart';
import '../main.dart' show gtfsService;
import 'report_issue_dialog.dart';
import '../theme.dart';
import 'trip_summary_screen.dart';
import 'nfc_pay_screen.dart';
import 'top_up_screen.dart';

class TripProgressTransitScreen extends StatefulWidget {
  final MultiLegJourney journey;
  final double fare;
  final double savedVsAlternative;
  final int walkToFirstStationMin;
  final int walkFromLastStationMin;
  const TripProgressTransitScreen({
    super.key,
    required this.journey,
    required this.fare,
    required this.savedVsAlternative,
    required this.walkToFirstStationMin,
    required this.walkFromLastStationMin,
  });

  @override
  State<TripProgressTransitScreen> createState() => _TripProgressTransitScreenState();
}

class _TripProgressTransitScreenState extends State<TripProgressTransitScreen> {
  static const _transferBufferMinutes = 3;

  int _activeFlatIndex = 0;
  late List<_FlatStep> _flatSteps;
  final _locationService = LocationTrackingService();
  final _db = DatabaseService();
  LatLng? _currentPosition;

  late DateTime _anchor;
  Timer? _clockTimer;

  int? _lastCorrectedIndex;
  Duration _liveDelay = Duration.zero;

  @override
  void initState() {
    super.initState();

    _anchor = DateTime.now().add(Duration(minutes: widget.walkToFirstStationMin));
    _flatSteps = _flattenJourney(_anchor);
    _startTracking();

    _clockTimer = Timer.periodic(const Duration(seconds: 20), (_) => _updateLiveDelay());
  }

  Future<void> _startTracking() async {
    final granted = await _locationService.isPermissionGranted();
    if (!granted) await _locationService.requestLocationPermission();
    final gpsOn = await _locationService.requestEnableGps();
    if (!gpsOn) return;

    _locationService.startTracking((loc.LocationData data) {
      if (data.latitude == null || data.longitude == null) return;
      final pos = LatLng(data.latitude!, data.longitude!);
      if (mounted) {
        setState(() => _currentPosition = pos);
        _computeActiveStopFromPosition(pos);
      }
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  List<_FlatStep> _flattenJourney(DateTime anchor) {
    final steps = <_FlatStep>[];

    if (widget.journey.legs.isNotEmpty) {
      steps.add(_FlatStep.walkStep(
        stationName: widget.journey.legs.first.boardStation.name,
        time: anchor,
      ));
    }

    DateTime cursor = anchor;
    for (int legIdx = 0; legIdx < widget.journey.legs.length; legIdx++) {
      final leg = widget.journey.legs[legIdx];
      if (legIdx > 0) {
        steps.add(_FlatStep.transferMarker(leg.boardStation.name));
        cursor = cursor.add(const Duration(minutes: _transferBufferMinutes));
      }
      final legStartTime = leg.intermediateStops.first.arrivalTime;
      for (final st in leg.intermediateStops) {
        final station = gtfsService.getStationById(st.stopId);
        final offsetMinutes = GtfsService.minutesBetweenTimes(legStartTime, st.arrivalTime);
        final displayTime = cursor.add(Duration(minutes: offsetMinutes));
        steps.add(_FlatStep(
          stationName: station?.name ?? st.stopId,
          time: displayTime,
          position: station != null ? LatLng(station.lat, station.lon) : null,
        ));
      }
      final lastOffset = GtfsService.minutesBetweenTimes(legStartTime, leg.intermediateStops.last.arrivalTime);
      cursor = cursor.add(Duration(minutes: lastOffset));
    }
    return steps;
  }

  void _computeActiveStopFromPosition(LatLng pos) {
    if (!mounted) return;
    int closestIndex = 0;
    double closestDistanceMeters = double.infinity;

    for (int i = 0; i < _flatSteps.length; i++) {
      final step = _flatSteps[i];
      if (step.position == null) continue;
      final distance = Distance()(pos, step.position!);
      if (distance < closestDistanceMeters) {
        closestDistanceMeters = distance;
        closestIndex = i;
      }
    }

    if (closestIndex == _lastCorrectedIndex) return;
    _lastCorrectedIndex = closestIndex;

    final matchedStep = _flatSteps[closestIndex];
    if (matchedStep.time != null) {

      final correction = DateTime.now().difference(matchedStep.time!);
      final newAnchor = _anchor.add(correction);
      setState(() {
        _anchor = newAnchor;
        _flatSteps = _flattenJourney(newAnchor);
        _activeFlatIndex = closestIndex;
        _liveDelay = Duration.zero;
      });
    } else {
      setState(() {
        _activeFlatIndex = closestIndex;
        _liveDelay = Duration.zero;
      });
    }
  }

  void _updateLiveDelay() {
    if (!mounted) return;
    final activeStep = _flatSteps[_activeFlatIndex];
    if (activeStep.time == null) return;
    final overdue = DateTime.now().difference(activeStep.time!);
    final newDelay = overdue.isNegative ? Duration.zero : overdue;
    if (newDelay != _liveDelay) setState(() => _liveDelay = newDelay);
  }

  double get _progressFraction {
    if (_flatSteps.length <= 1) return 0;
    return (_activeFlatIndex / (_flatSteps.length - 1)).clamp(0, 1).toDouble();
  }

  DateTime? get _finalArrivalTime {
    for (int i = _flatSteps.length - 1; i >= 0; i--) {
      if (!_flatSteps[i].isTransferMarker && _flatSteps[i].time != null) {
        return _flatSteps[i].time!.add(_liveDelay);
      }
    }
    return null;
  }

  Future<void> _onPayFare() async {
    final balance = await _db.getWalletBalance();
    if (balance < widget.fare) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Insufficient balance for this RM ${widget.fare.toStringAsFixed(2)} fare.'),
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
        builder: (_) => NfcPayScreen(amount: widget.fare, label: 'LRT/MRT Fare'),
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
      builder: (_) => TripSummaryScreen(
        route: '${widget.journey.originStation.name} -> ${widget.journey.destStation.name}',
        mode: 'transit',
        cost: widget.fare,
        savedVsAlternative: widget.savedVsAlternative,
        distanceKm: widget.journey.totalDistanceKm,
      ),
    ));
  }

  List<Polyline> get _mapPolylines {
    return widget.journey.legs.map((leg) => Polyline(points: leg.shapePoints, color: AppColors.mint, strokeWidth: 4)).toList();
  }

  List<Marker> get _mapMarkers {
    final markers = <Marker>[];
    for (final leg in widget.journey.legs) {
      markers.add(Marker(
        point: LatLng(leg.boardStation.lat, leg.boardStation.lon),
        width: 26, height: 26,
        child: const Icon(Icons.trip_origin, color: AppColors.teal, size: 22),
      ));
      markers.add(Marker(
        point: LatLng(leg.alightStation.lat, leg.alightStation.lon),
        width: 26, height: 26,
        child: const Icon(Icons.location_on, color: AppColors.amber, size: 26),
      ));
    }

    if (_currentPosition != null) {
      markers.add(Marker(
        point: _currentPosition!,
        width: 34, height: 34,
        child: Container(
          decoration: BoxDecoration(color: AppColors.mint, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
          child: const Icon(Icons.navigation, color: Colors.white, size: 16),
        ),
      ));
    }
    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final originStation = widget.journey.legs.first.boardStation;
    final finalArrival = _finalArrivalTime;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('On the Way'),
        actions: [
          IconButton(
            tooltip: 'Pay fare with wallet',
            icon: const Icon(Icons.contactless_outlined),
            onPressed: _onPayFare,
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 200,
            child: FlutterMap(
              options: MapOptions(initialCenter: LatLng(originStation.lat, originStation.lon), initialZoom: 12),
              children: [
                TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.example.driveorride'),
                PolylineLayer(polylines: _mapPolylines),
                MarkerLayer(markers: _mapMarkers),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [

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
                          Text('${widget.journey.totalDurationMinutes + widget.walkToFirstStationMin + widget.walkFromLastStationMin} min', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.teal)),
                          const Text('Total time', style: TextStyle(fontSize: 10, color: Colors.grey)),
                        ]),
                      ),
                      Container(width: 1, height: 32, color: Colors.grey.shade200),
                      Expanded(
                        child: Column(children: [
                          Text(finalArrival != null ? GtfsService.formatDateTime(finalArrival) : '--', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.teal)),
                          const Text('ETA', style: TextStyle(fontSize: 10, color: Colors.grey)),
                        ]),
                      ),
                      Container(width: 1, height: 32, color: Colors.grey.shade200),
                      Expanded(
                        child: Column(children: [
                          const Icon(Icons.schedule, color: AppColors.mint, size: 18),
                          const Text('On Schedule', style: TextStyle(fontSize: 10, color: Colors.grey)),
                        ]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

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
                if (widget.journey.needsTransfer)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppColors.amberLight, borderRadius: BorderRadius.circular(10)),
                    child: Row(children: [
                      const Icon(Icons.sync_alt, color: AppColors.amber, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Transfer required at ${widget.journey.transferStation!.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    ]),
                  ),
                const Text('Schedule', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.teal)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    children: List.generate(_flatSteps.length, (i) {
                      final step = _flatSteps[i];
                      if (step.isWalkStep) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(children: [
                            const SizedBox(width: 4),
                            Icon(Icons.directions_walk, size: 16, color: Colors.grey.shade500),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Walk to ${step.stationName}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
                                  Text(
                                    '~${widget.walkToFirstStationMin} min · arrive ${step.time != null ? GtfsService.formatDateTime(_activeFlatIndex == 0 ? step.time!.add(_liveDelay) : step.time!) : ''}',
                                    style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                                  ),
                                ],
                              ),
                            ),
                          ]),
                        );
                      }
                      if (step.isTransferMarker) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(children: [
                            const SizedBox(width: 4),
                            const Icon(Icons.sync_alt, size: 14, color: AppColors.amber),
                            const SizedBox(width: 8),
                            Text('Change at ${step.stationName}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.amber)),
                          ]),
                        );
                      }
                      final isActive = i == _activeFlatIndex;
                      final isPast = i < _activeFlatIndex;
                      final isFirst = i == 1;
                      final isLast = i == _flatSteps.length - 1;
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        padding: isActive ? const EdgeInsets.symmetric(vertical: 6, horizontal: 8) : const EdgeInsets.symmetric(vertical: 6),
                        decoration: isActive ? BoxDecoration(color: AppColors.mintLight, borderRadius: BorderRadius.circular(12)) : null,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Icon(
                                isFirst ? Icons.trip_origin : (isLast ? Icons.flag : Icons.fiber_manual_record),
                                size: isFirst || isLast ? 18 : 10,
                                color: isActive ? AppColors.mint : (isPast ? Colors.grey.shade300 : AppColors.mint),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(step.stationName, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: isPast ? Colors.grey : AppColors.teal)),
                                  Text(
                                    step.time != null
                                        ? GtfsService.formatDateTime(isPast ? step.time! : step.time!.add(_liveDelay))
                                        : '',
                                    style: TextStyle(fontSize: 11, color: isPast ? Colors.grey.shade400 : Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            if (isActive)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(color: AppColors.mint, borderRadius: BorderRadius.circular(20)),
                                child: const Text('NOW', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                              ),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _onArrived, child: const Text("I've Arrived"))),
              const SizedBox(height: 8),
              SizedBox(width: double.infinity, child: OutlinedButton(onPressed: _onStop, child: const Text('Stop Trip'))),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => showReportIssueDialog(
                    context,
                    category: 'rail',
                    stationName: _flatSteps[_activeFlatIndex].stationName,
                  ),
                  icon: const Icon(Icons.report_problem_outlined, size: 16, color: Colors.orange),
                  label: const Text('Report an Issue', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13)),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.orange)),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _FlatStep {
  final String stationName;
  final DateTime? time;
  final bool isTransferMarker;
  final bool isWalkStep;
  final LatLng? position;
  _FlatStep({required this.stationName, this.time, this.position}) : isTransferMarker = false, isWalkStep = false;
  _FlatStep.transferMarker(this.stationName) : time = null, isTransferMarker = true, isWalkStep = false, position = null;
  _FlatStep.walkStep({required this.stationName, required DateTime this.time}) : isTransferMarker = false, isWalkStep = true, position = null;
}