import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';
import 'package:latlong2/latlong.dart';
import '../models/models.dart';

class JourneyLeg {
  final Station boardStation;
  final Station alightStation;
  final String tripId;
  final String routeId;
  final String departureTime;
  final String arrivalTime;
  final int durationMinutes;
  final List<LatLng> shapePoints;
  final List<StopTime> intermediateStops;

  JourneyLeg({
    required this.boardStation,
    required this.alightStation,
    required this.tripId,
    required this.routeId,
    required this.departureTime,
    required this.arrivalTime,
    required this.durationMinutes,
    required this.shapePoints,
    required this.intermediateStops,
  });
}

class MultiLegJourney {
  final List<JourneyLeg> legs;

  final bool isTimingApproximate;
  MultiLegJourney({required this.legs, this.isTimingApproximate = false});

  bool get needsTransfer => legs.length > 1;
  Station? get transferStation => needsTransfer ? legs.first.alightStation : null;
  Station get originStation => legs.first.boardStation;
  Station get destStation => legs.last.alightStation;
  int get totalDurationMinutes => legs.fold(0, (sum, l) => sum + l.durationMinutes);

  double get totalDistanceKm {
    final distance = Distance();
    double total = 0;
    for (final leg in legs) {
      total += distance(LatLng(leg.boardStation.lat, leg.boardStation.lon), LatLng(leg.alightStation.lat, leg.alightStation.lon));
    }
    return total / 1000.0;
  }
}

class GtfsService {
  List<Station> _stations = [];
  List<StopTime> _stopTimes = [];
  List<Map<String, dynamic>> _trips = [];
  List<Map<String, dynamic>> _shapes = [];
  Map<String, List<StopTime>> _stopsByTrip = {};
  Map<String, String> _tripToRoute = {};
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;

    final stopsRaw = await rootBundle.loadString('assets/gtfs/stops.txt');
    final stopTimesRaw = await rootBundle.loadString('assets/gtfs/stop_times.txt');
    _stations = _parseCsv(stopsRaw).map((row) => Station.fromCsvRow(row)).toList();
    _stopTimes = _parseCsv(stopTimesRaw).map((row) => StopTime.fromCsvRow(row)).toList();

    try {
      final tripsRaw = await rootBundle.loadString('assets/gtfs/trips.txt');
      _trips = _parseCsv(tripsRaw);
      for (final t in _trips) {
        _tripToRoute[t['trip_id'].toString()] = t['route_id']?.toString() ?? '';
      }
    } catch (e) {

      print('trips.txt not found — line/transfer lookup will not work: $e');
    }
    try {
      final shapesRaw = await rootBundle.loadString('assets/gtfs/shapes.txt');
      _shapes = _parseCsv(shapesRaw);
    } catch (e) {

      print('shapes.txt not found — map polyline will be empty: $e');
    }

    for (final st in _stopTimes) {
      _stopsByTrip.putIfAbsent(st.tripId, () => []).add(st);
    }
    for (final list in _stopsByTrip.values) {
      list.sort((a, b) => a.stopSequence.compareTo(b.stopSequence));
    }

    _loaded = true;
  }

  List<Map<String, dynamic>> _parseCsv(String raw) {
    final rows = csv.decode(raw);
    if (rows.isEmpty) return [];
    final headers = rows.first.map((h) => h.toString()).toList();
    return rows.skip(1).where((r) => r.length == headers.length).map((row) {
      return {for (var i = 0; i < headers.length; i++) headers[i]: row[i]};
    }).toList();
  }

  static const _maxReasonableDistanceMeters = 20000;

  Station? findNearestStation(LatLng point) {
    if (_stations.isEmpty) return null;
    final distance = Distance();
    Station? nearest;
    double bestDist = double.infinity;
    for (final station in _stations) {
      final d = distance(point, LatLng(station.lat, station.lon));
      if (d < bestDist) {
        bestDist = d;
        nearest = station;
      }
    }
    if (bestDist > _maxReasonableDistanceMeters) return null;
    return nearest;
  }

  Station? getStationById(String id) {
    try {
      return _stations.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  String _normalizeName(String name) => name.trim().toUpperCase();

  int _timeDiffMinutes(String start, String end) {
    int toMinutes(String t) {
      final parts = t.split(':').map(int.parse).toList();
      return parts[0] * 60 + parts[1];
    }
    return toMinutes(end) - toMinutes(start);
  }

  static String formatTime(String rawTime) {
    final parts = rawTime.split(':').map(int.parse).toList();
    int hour24 = parts[0] % 24;
    final minute = parts[1];
    final period = hour24 >= 12 ? 'PM' : 'AM';
    int hour12 = hour24 % 12;
    if (hour12 == 0) hour12 = 12;
    final minuteStr = minute.toString().padLeft(2, '0');
    return '$hour12:$minuteStr $period';
  }

  static int minutesBetweenTimes(String t1, String t2) {
    int toMin(String t) {
      final p = t.split(':').map(int.parse).toList();
      return p[0] * 60 + p[1];
    }
    return toMin(t2) - toMin(t1);
  }

  static String formatDateTime(DateTime dt) {
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    int hour12 = dt.hour % 12;
    if (hour12 == 0) hour12 = 12;
    final minuteStr = dt.minute.toString().padLeft(2, '0');
    return '$hour12:$minuteStr $period';
  }

  List<LatLng> _getShapePoints(String shapeId) {
    final points = _shapes.where((s) => s['shape_id'].toString() == shapeId).toList()
      ..sort((a, b) => int.parse(a['shape_pt_sequence'].toString()).compareTo(int.parse(b['shape_pt_sequence'].toString())));
    return points.map((p) => LatLng(
      double.parse(p['shape_pt_lat'].toString()),
      double.parse(p['shape_pt_lon'].toString()),
    )).toList();
  }

  JourneyLeg _buildLeg(String tripId, List<StopTime> stops, int fromIdx, int toIdx) {
    final routeId = _tripToRoute[tripId] ?? '';
    final tripRow = _trips.firstWhere((t) => t['trip_id'].toString() == tripId, orElse: () => <String, dynamic>{});
    final shapeId = tripRow['shape_id']?.toString();
    final boardStation = getStationById(stops[fromIdx].stopId)!;
    final alightStation = getStationById(stops[toIdx].stopId)!;

    final fullShape = shapeId != null ? _getShapePoints(shapeId) : <LatLng>[];
    final trimmedShape = _trimShapeToSegment(fullShape, LatLng(boardStation.lat, boardStation.lon), LatLng(alightStation.lat, alightStation.lon));

    return JourneyLeg(
      boardStation: boardStation,
      alightStation: alightStation,
      tripId: tripId,
      routeId: routeId,
      departureTime: stops[fromIdx].departureTime,
      arrivalTime: stops[toIdx].arrivalTime,
      durationMinutes: _timeDiffMinutes(stops[fromIdx].departureTime, stops[toIdx].arrivalTime),
      shapePoints: trimmedShape,
      intermediateStops: stops.sublist(fromIdx, toIdx + 1),
    );
  }

  List<LatLng> _trimShapeToSegment(List<LatLng> fullShape, LatLng boardPoint, LatLng alightPoint) {
    if (fullShape.isEmpty) return [];
    final distance = Distance();

    int nearestIndex(LatLng target) {
      int bestIdx = 0;
      double bestDist = double.infinity;
      for (int i = 0; i < fullShape.length; i++) {
        final d = distance(fullShape[i], target);
        if (d < bestDist) {
          bestDist = d;
          bestIdx = i;
        }
      }
      return bestIdx;
    }

    final boardIdx = nearestIndex(boardPoint);
    final alightIdx = nearestIndex(alightPoint);
    final start = boardIdx < alightIdx ? boardIdx : alightIdx;
    final end = boardIdx < alightIdx ? alightIdx : boardIdx;
    final segment = fullShape.sublist(start, end + 1);

    return boardIdx <= alightIdx ? segment : segment.reversed.toList();
  }

  int _currentMinutes() {
    final now = DateTime.now();
    return now.hour * 60 + now.minute;
  }

  int _toMinutesOfDay(String hhmmss) {
    final parts = hhmmss.split(':').map(int.parse).toList();
    return parts[0] * 60 + parts[1];
  }

  int _minutesUntil(int depMinutes) {
    final nowMin = _currentMinutes();
    return depMinutes >= nowMin ? depMinutes - nowMin : (depMinutes + 1440 - nowMin);
  }

  JourneyLeg? _findDirectLeg(Station origin, Station destination) {
    MapEntry<String, List<StopTime>>? bestEntry;
    int bestOriginIdx = -1, bestDestIdx = -1, bestWait = 1 << 30;

    for (final entry in _stopsByTrip.entries) {
      final stops = entry.value;
      final originIdx = stops.indexWhere((s) => s.stopId == origin.id);
      final destIdx = stops.indexWhere((s) => s.stopId == destination.id);
      if (originIdx != -1 && destIdx != -1 && originIdx < destIdx) {
        final depMin = _toMinutesOfDay(stops[originIdx].departureTime);
        final wait = _minutesUntil(depMin);
        if (wait < bestWait) {
          bestWait = wait;
          bestEntry = entry;
          bestOriginIdx = originIdx;
          bestDestIdx = destIdx;
        }
      }
    }

    if (bestEntry == null) return null;
    return _buildLeg(bestEntry.key, bestEntry.value, bestOriginIdx, bestDestIdx);
  }

  MultiLegJourney? findJourney(Station origin, Station destination) {
    final direct = _findDirectLeg(origin, destination);
    if (direct != null) return MultiLegJourney(legs: [direct]);

    final originCandidates = <MapEntry<String, List<StopTime>>>[];
    final destCandidates = <MapEntry<String, List<StopTime>>>[];

    for (final entry in _stopsByTrip.entries) {
      final stops = entry.value;
      final oIdx = stops.indexWhere((s) => s.stopId == origin.id);
      if (oIdx != -1 && oIdx < stops.length - 1) originCandidates.add(entry);
      final dIdx = stops.indexWhere((s) => s.stopId == destination.id);
      if (dIdx != -1 && dIdx > 0) destCandidates.add(entry);
    }

    JourneyLeg? bestLeg1, bestLeg2;
    int bestWait = 1 << 30;

    JourneyLeg? fallbackLeg1, fallbackLeg2;
    int fallbackWait = 1 << 30;

    for (final oEntry in originCandidates) {
      final oStops = oEntry.value;
      final oIdx = oStops.indexWhere((s) => s.stopId == origin.id);

      for (int i = oIdx + 1; i < oStops.length; i++) {
        final candidateStation = getStationById(oStops[i].stopId);
        if (candidateStation == null) continue;
        final candidateName = _normalizeName(candidateStation.name);

        for (final dEntry in destCandidates) {
          if (dEntry.key == oEntry.key) continue;
          final dStops = dEntry.value;
          final dIdx = dStops.indexWhere((s) => s.stopId == destination.id);

          for (int j = 0; j < dIdx; j++) {
            final matchStation = getStationById(dStops[j].stopId);
            if (matchStation == null) continue;
            if (_normalizeName(matchStation.name) == candidateName) {
              final depMin = _toMinutesOfDay(oStops[oIdx].departureTime);
              final wait = _minutesUntil(depMin);

              if (wait < fallbackWait) {
                fallbackWait = wait;
                fallbackLeg1 = _buildLeg(oEntry.key, oStops, oIdx, i);
                fallbackLeg2 = _buildLeg(dEntry.key, dStops, j, dIdx);
              }

              const transferBufferMinutes = 2;
              final leg1ArrivalMin = _toMinutesOfDay(oStops[i].arrivalTime);
              final leg2DepartureMin = _toMinutesOfDay(dStops[j].departureTime);
              final isChronologicallyValid = leg2DepartureMin >= leg1ArrivalMin + transferBufferMinutes;
              if (isChronologicallyValid && wait < bestWait) {
                bestWait = wait;
                bestLeg1 = _buildLeg(oEntry.key, oStops, oIdx, i);
                bestLeg2 = _buildLeg(dEntry.key, dStops, j, dIdx);
              }
            }
          }
        }
      }
    }

    bool usedFallback = false;
    if (bestLeg1 == null || bestLeg2 == null) {
      bestLeg1 = fallbackLeg1;
      bestLeg2 = fallbackLeg2;
      usedFallback = true;
    }

    if (bestLeg1 == null || bestLeg2 == null) return null;
    return MultiLegJourney(legs: [bestLeg1, bestLeg2], isTimingApproximate: usedFallback);
  }

  List<Station> get allStations => _stations;
}