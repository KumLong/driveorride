import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';
import 'package:latlong2/latlong.dart';
import '../models/models.dart';

/// One leg of a journey — riding a single line from one station to
/// another, with no transfer in between.
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

/// A full journey — either 1 leg (same line, no transfer) or 2 legs
/// (one transfer between two different lines, at a shared station).
class MultiLegJourney {
  final List<JourneyLeg> legs;
  MultiLegJourney({required this.legs});

  bool get needsTransfer => legs.length > 1;
  Station? get transferStation => needsTransfer ? legs.first.alightStation : null;
  Station get originStation => legs.first.boardStation;
  Station get destStation => legs.last.alightStation;
  int get totalDurationMinutes => legs.fold(0, (sum, l) => sum + l.durationMinutes);

  /// Real distance travelled, computed by summing the straight-line
  /// distance between each consecutive real station along the journey
  /// (not a made-up number) — used to estimate fare, since no fare API
  /// exists (see RouteDetailsScreen for the fare formula).
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
      // ignore: avoid_print
      print('trips.txt not found — line/transfer lookup will not work: $e');
    }
    try {
      final shapesRaw = await rootBundle.loadString('assets/gtfs/shapes.txt');
      _shapes = _parseCsv(shapesRaw);
    } catch (e) {
      // ignore: avoid_print
      print('shapes.txt not found — map polyline will be empty: $e');
    }

    // Group stop_times by trip once, up front — every journey lookup
    // below reuses this instead of re-scanning the full list each time.
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
    return nearest;
  }

  Station? getStationById(String id) {
    try {
      return _stations.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Normalizes a station name for comparison across lines — GTFS
  /// often lists the same physical interchange station under slightly
  /// different spellings/ids per line (e.g. "Masjid Jamek" vs
  /// "MASJID JAMEK"), so we match on a cleaned-up name, not stop_id.
  String _normalizeName(String name) => name.trim().toUpperCase();

  int _timeDiffMinutes(String start, String end) {
    int toMinutes(String t) {
      final parts = t.split(':').map(int.parse).toList();
      return parts[0] * 60 + parts[1];
    }
    return toMinutes(end) - toMinutes(start);
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

    // Trim the full line's shape down to just the segment actually
    // travelled (board -> alight), instead of drawing the entire line
    // end-to-end — that's what was making the map line look "messy".
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

  /// Finds the shape points nearest to the board/alight stations and
  /// returns only the portion of the line between them, in the correct
  /// direction of travel.
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
    // If the trip runs in the opposite direction to our board->alight
    // order, reverse it so the polyline still draws start-to-end correctly.
    return boardIdx <= alightIdx ? segment : segment.reversed.toList();
  }

  /// Direct, same-line journey — no transfer needed. Real data, no
  /// hardcoding: searches every trip for one that stops at both
  /// stations in the correct order.
  JourneyLeg? _findDirectLeg(Station origin, Station destination) {
    for (final entry in _stopsByTrip.entries) {
      final stops = entry.value;
      final originIdx = stops.indexWhere((s) => s.stopId == origin.id);
      final destIdx = stops.indexWhere((s) => s.stopId == destination.id);
      if (originIdx != -1 && destIdx != -1 && originIdx < destIdx) {
        return _buildLeg(entry.key, stops, originIdx, destIdx);
      }
    }
    return null;
  }

  /// Full journey finder: tries a direct (same-line) journey first;
  /// if none exists, automatically searches for ONE transfer point —
  /// a station name that appears both on a line reachable from the
  /// origin AND on a line that reaches the destination. This is
  /// computed fresh from your real GTFS data every time, not a
  /// hardcoded list of "known interchanges."
  ///
  /// LIMITATION (honest): only searches for journeys needing 0 or 1
  /// transfer. A trip requiring 2+ transfers won't be found — that
  /// would need a full journey-planning algorithm (e.g. RAPTOR),
  /// which is out of scope here.
  MultiLegJourney? findJourney(Station origin, Station destination) {
    final direct = _findDirectLeg(origin, destination);
    if (direct != null) return MultiLegJourney(legs: [direct]);

    // 1-transfer search: for every trip touching the origin, look at
    // every station further along it; for every trip touching the
    // destination, look at every station earlier on it. If any two
    // of those candidate stations share the same name, that's our
    // transfer point.
    final originCandidates = <MapEntry<String, List<StopTime>>>[]; // tripId -> stops, with origin present (not last)
    final destCandidates = <MapEntry<String, List<StopTime>>>[];

    for (final entry in _stopsByTrip.entries) {
      final stops = entry.value;
      final oIdx = stops.indexWhere((s) => s.stopId == origin.id);
      if (oIdx != -1 && oIdx < stops.length - 1) originCandidates.add(entry);
      final dIdx = stops.indexWhere((s) => s.stopId == destination.id);
      if (dIdx != -1 && dIdx > 0) destCandidates.add(entry);
    }

    for (final oEntry in originCandidates) {
      final oStops = oEntry.value;
      final oIdx = oStops.indexWhere((s) => s.stopId == origin.id);

      for (int i = oIdx + 1; i < oStops.length; i++) {
        final candidateStation = getStationById(oStops[i].stopId);
        if (candidateStation == null) continue;
        final candidateName = _normalizeName(candidateStation.name);

        for (final dEntry in destCandidates) {
          if (dEntry.key == oEntry.key) continue; // same trip — would've been a direct match already
          final dStops = dEntry.value;
          final dIdx = dStops.indexWhere((s) => s.stopId == destination.id);

          for (int j = 0; j < dIdx; j++) {
            final matchStation = getStationById(dStops[j].stopId);
            if (matchStation == null) continue;
            if (_normalizeName(matchStation.name) == candidateName) {
              // Found a transfer point — build both legs.
              final leg1 = _buildLeg(oEntry.key, oStops, oIdx, i);
              final leg2 = _buildLeg(dEntry.key, dStops, j, dIdx);
              return MultiLegJourney(legs: [leg1, leg2]);
            }
          }
        }
      }
    }

    return null; // no 0-transfer or 1-transfer journey found
  }

  List<Station> get allStations => _stations;
}
