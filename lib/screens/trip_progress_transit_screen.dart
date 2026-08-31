import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/gtfs_service.dart';
import '../main.dart' show gtfsService;
import '../theme.dart';
import 'trip_summary_screen.dart';
import 'stop_trip_screen.dart';

/// Combines a MultiLegJourney's stops into one flat timeline (with a
/// "Transfer" marker between legs, if any), shows the real route line
/// on a map, and highlights the current stage based on the phone's
/// clock vs. the real scheduled times.
class TripProgressTransitScreen extends StatefulWidget {
  final MultiLegJourney journey;
  final double fare;
  final double savedVsAlternative;
  const TripProgressTransitScreen({super.key, required this.journey, required this.fare, required this.savedVsAlternative});

  @override
  State<TripProgressTransitScreen> createState() => _TripProgressTransitScreenState();
}

class _TripProgressTransitScreenState extends State<TripProgressTransitScreen> {
  int _activeFlatIndex = 0;
  late List<_FlatStep> _flatSteps;

  @override
  void initState() {
    super.initState();
    _flatSteps = _flattenJourney();
    _computeActiveStop();
  }

  List<_FlatStep> _flattenJourney() {
    final steps = <_FlatStep>[];
    for (int legIdx = 0; legIdx < widget.journey.legs.length; legIdx++) {
      final leg = widget.journey.legs[legIdx];
      if (legIdx > 0) {
        steps.add(_FlatStep.transferMarker(leg.boardStation.name));
      }
      for (final st in leg.intermediateStops) {
        final station = gtfsService.getStationById(st.stopId);
        steps.add(_FlatStep(stationName: station?.name ?? st.stopId, time: st.arrivalTime));
      }
    }
    return steps;
  }

  void _computeActiveStop() {
    final now = TimeOfDay.now();
    final nowMinutes = now.hour * 60 + now.minute;
    int active = 0;
    for (int i = 0; i < _flatSteps.length; i++) {
      final step = _flatSteps[i];
      if (step.isTransferMarker) continue;
      final parts = step.time!.split(':').map(int.parse).toList();
      final stopMinutes = parts[0] * 60 + parts[1];
      if (nowMinutes >= stopMinutes) active = i;
    }
    setState(() => _activeFlatIndex = active);
  }

  void _onStop() => Navigator.push(context, MaterialPageRoute(builder: (_) => const StopTripScreen()));

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

  /// All legs' route lines combined, so the map shows the whole
  /// journey (including both segments if there's a transfer).
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
          // Map showing the real route line(s) and stations — this was
          // missing before; now shown just like the Route Details screen.
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
                    // Times now formatted as "7:05 AM" instead of raw "07:05:00".
                    subtitle: Text(step.time != null ? GtfsService.formatTime(step.time!) : '', style: TextStyle(color: isPast ? Colors.grey.shade400 : Colors.grey, fontWeight: FontWeight.w600)),
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
            child: Text('Progress shown is based on schedule, not live vehicle tracking.', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.grey)),
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
  final String? time;
  final bool isTransferMarker;
  _FlatStep({required this.stationName, this.time}) : isTransferMarker = false;
  _FlatStep.transferMarker(this.stationName) : time = null, isTransferMarker = true;
}
