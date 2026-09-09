import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/gtfs_service.dart';
import '../main.dart' show gtfsService;
import '../theme.dart';
import 'trip_summary_screen.dart';

/// Combines a MultiLegJourney's stops into one flat, live timeline
/// (with a "Transfer" marker between legs, if any), shows the real
/// route line on a map, and highlights the current stage by comparing
/// the phone's real clock against a schedule anchored to when the
/// trip actually started — built from real travel durations in the
/// GTFS data, not a live vehicle feed (Malaysia has no public one).
///
/// Visual style now matches TripProgressDriveScreen: a unified stat
/// row, a progress bar, and a consistent step-list card.
class TripProgressTransitScreen extends StatefulWidget {
  final MultiLegJourney journey;
  final double fare;
  final double savedVsAlternative;
  const TripProgressTransitScreen({super.key, required this.journey, required this.fare, required this.savedVsAlternative});

  @override
  State<TripProgressTransitScreen> createState() => _TripProgressTransitScreenState();
}

class _TripProgressTransitScreenState extends State<TripProgressTransitScreen> {
  static const _walkToFirstStationMinutes = 5;
  static const _transferBufferMinutes = 3;

  int _activeFlatIndex = 0;
  late List<_FlatStep> _flatSteps;
  Timer? _liveTimer;

  @override
  void initState() {
    super.initState();
    _flatSteps = _flattenJourney(DateTime.now().add(const Duration(minutes: _walkToFirstStationMinutes)));
    _computeActiveStop();
    _liveTimer = Timer.periodic(const Duration(seconds: 30), (_) => _computeActiveStop());
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    super.dispose();
  }

  List<_FlatStep> _flattenJourney(DateTime anchor) {
    final steps = <_FlatStep>[];
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

  void _computeActiveStop() {
    if (!mounted) return;
    final now = DateTime.now();
    int active = 0;
    for (int i = 0; i < _flatSteps.length; i++) {
      final step = _flatSteps[i];
      if (step.isTransferMarker || step.time == null) continue;
      if (now.isAfter(step.time!) || now.isAtSameMomentAs(step.time!)) active = i;
    }
    setState(() => _activeFlatIndex = active);
  }

  double get _progressFraction {
    if (_flatSteps.length <= 1) return 0;
    return (_activeFlatIndex / (_flatSteps.length - 1)).clamp(0, 1).toDouble();
  }

  DateTime? get _finalArrivalTime {
    for (int i = _flatSteps.length - 1; i >= 0; i--) {
      if (!_flatSteps[i].isTransferMarker && _flatSteps[i].time != null) return _flatSteps[i].time;
    }
    return null;
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
    // Real, schedule-based "you should be around here now" marker —
    // NOT live GPS (no such data exists for Malaysian rail), but a
    // genuine visualization of the real active station, updating as
    // the schedule progresses over time.
    if (_activeFlatIndex < _flatSteps.length) {
      final activePos = _flatSteps[_activeFlatIndex].position;
      if (activePos != null) {
        markers.add(Marker(
          point: activePos,
          width: 36, height: 36,
          child: Container(
            decoration: BoxDecoration(color: AppColors.mint, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
            child: const Icon(Icons.schedule, color: Colors.white, size: 16),
          ),
        ));
      }
    }
    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final originStation = widget.journey.legs.first.boardStation;
    final finalArrival = _finalArrivalTime;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('On the Way')),
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
                // ── Unified stat row — same visual style as Drive ──
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
                          Text('${widget.journey.totalDurationMinutes} min', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.teal)),
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
                // ── Progress bar — same visual style as Drive ──
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
                      final isFirst = i == 0;
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
                                    step.time != null ? GtfsService.formatDateTime(step.time!) : '',
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
                const SizedBox(height: 8),
                Text(
                  'The mint marker on the map shows where the schedule says you should be right now — it\'s based on real timing, not live GPS or vehicle tracking (no such public feed exists for Malaysian rail).',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                  textAlign: TextAlign.center,
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
  final LatLng? position;
  _FlatStep({required this.stationName, this.time, this.position}) : isTransferMarker = false;
  _FlatStep.transferMarker(this.stationName) : time = null, isTransferMarker = true, position = null;
}