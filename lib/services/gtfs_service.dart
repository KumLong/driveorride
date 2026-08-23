import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';
import 'package:latlong2/latlong.dart';
import '../models/models.dart';

/// Reads the REAL GTFS files you already downloaded and verified.
/// SETUP: copy stops.txt, stop_times.txt, trips.txt, routes.txt,
/// shapes.txt from your gtfs_rapid_rail_kl.zip into assets/gtfs/
class GtfsService {
  List<Station> _stations = [];
  List<StopTime> _stopTimes = [];
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    final stopsRaw = await rootBundle.loadString('assets/gtfs/stops.txt');
    final stopTimesRaw = await rootBundle.loadString('assets/gtfs/stop_times.txt');
    _stations = _parseCsv(stopsRaw).map((row) => Station.fromCsvRow(row)).toList();
    _stopTimes = _parseCsv(stopTimesRaw).map((row) => StopTime.fromCsvRow(row)).toList();
    _loaded = true;
  }

  /// Converts a raw CSV string into a list of row-maps keyed by header name.
  /// Uses the csv package's CURRENT API (v8+): the top-level `csv` instance
  /// with `.decode()`. The older `CsvToListConverter` class was removed in
  /// that version — this is why the old code showed a red error.
  List<Map<String, dynamic>> _parseCsv(String raw) {
    final rows = csv.decode(raw);
    if (rows.isEmpty) return [];
    final headers = rows.first.map((h) => h.toString()).toList();
    return rows.skip(1).map((row) {
      return {for (var i = 0; i < headers.length; i++) headers[i]: row[i]};
    }).toList();
  }

  /// Finds the real station nearest to any coordinate — this is what
  /// makes the app work for ANY typed address, not a fixed list.
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

  List<StopTime> getStopTimesForStation(String stationId) {
    return _stopTimes.where((st) => st.stopId == stationId).toList()
      ..sort((a, b) => a.departureTime.compareTo(b.departureTime));
  }

  List<Station> get allStations => _stations;
}
