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
        steps.add(_FlatStep(stationName: station?.name ?? st.stopId, time: displayTime));
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

  // Real route line(s) — combines every leg's shape, same as Route Details.
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
    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final originStation = widget.journey.legs.first.boardStation;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('On the Way')),
      body: Column(
        children: [
          // Real map showing the route line + station markers — this
          // was accidentally dropped in an earlier edit; restored here.
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
          if (widget.journey.needsTransfer)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              color: AppColors.amberLight,
              child: Text('Transfer required at ${widget.journey.transferStation!.name}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _flatSteps.length,
              itemBuilder: (ctx, i) {
                final step = _flatSteps[i];
                if (step.isTransferMarker) {
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppColors.amberLight, borderRadius: BorderRadius.circular(10)),
                    child: Row(children: [
                      const Icon(Icons.sync_alt, color: AppColors.amber, size: 16),
                      const SizedBox(width: 8),
                      Text('Change here: ${step.stationName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ]),
                  );
                }
                final isActive = i == _activeFlatIndex;
                final isPast = i < _activeFlatIndex;
                return Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: isActive ? const EdgeInsets.symmetric(vertical: 6, horizontal: 10) : EdgeInsets.zero,
                  decoration: isActive ? BoxDecoration(color: AppColors.mintLight, borderRadius: BorderRadius.circular(12)) : null,
                  child: ListTile(
                    dense: true,
                    leading: Container(
                      width: isActive ? 18 : 12, height: isActive ? 18 : 12,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: isActive ? AppColors.mint : (isPast ? Colors.grey.shade300 : Colors.grey.shade400)),
                    ),
                    title: Text(step.stationName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isPast ? Colors.grey : AppColors.teal)),
                    subtitle: Text(
                      step.time != null ? GtfsService.formatDateTime(step.time!) : '',
                      style: TextStyle(color: isPast ? Colors.grey.shade400 : Colors.grey, fontWeight: FontWeight.w600),
                    ),
                    trailing: isActive
                        ? Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: AppColors.mint, borderRadius: BorderRadius.circular(20)), child: const Text('NOW', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)))
                        : null,
                  ),
                );
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text('Times assume you left when you confirmed this trip — calculated from real scheduled durations, not live vehicle tracking.', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.grey)),
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
  _FlatStep({required this.stationName, this.time}) : isTransferMarker = false;
  _FlatStep.transferMarker(this.stationName) : time = null, isTransferMarker = true;
}