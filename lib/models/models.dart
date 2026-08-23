// ─────────────────────────────────────────────────────────────
// Core data models used across the app.
// ─────────────────────────────────────────────────────────────

/// A single transit station, read from the real GTFS stops.txt
/// (verified from your downloaded gtfs_rapid_rail_kl.zip)
class Station {
  final String id;
  final String name;
  final double lat;
  final double lon;

  Station({required this.id, required this.name, required this.lat, required this.lon});

  factory Station.fromCsvRow(Map<String, dynamic> row) {
    return Station(
      id: row['stop_id'].toString(),
      name: row['stop_name'].toString(),
      lat: double.parse(row['stop_lat'].toString()),
      lon: double.parse(row['stop_lon'].toString()),
    );
  }
}

/// A scheduled stop-time entry, read from the real GTFS stop_times.txt
class StopTime {
  final String tripId;
  final String stopId;
  final String arrivalTime;
  final String departureTime;
  final int stopSequence;

  StopTime({
    required this.tripId,
    required this.stopId,
    required this.arrivalTime,
    required this.departureTime,
    required this.stopSequence,
  });

  factory StopTime.fromCsvRow(Map<String, dynamic> row) {
    return StopTime(
      tripId: row['trip_id'].toString(),
      stopId: row['stop_id'].toString(),
      arrivalTime: row['arrival_time'].toString(),
      departureTime: row['departure_time'].toString(),
      stopSequence: int.parse(row['stop_sequence'].toString()),
    );
  }
}

/// A saved location (Home, Work, etc.) — stored in SQLite. Full CRUD.
class SavedLocationModel {
  final int? id;          // null until saved — SQLite auto-assigns it
  final String label;
  final String address;
  final double lat;
  final double lon;

  SavedLocationModel({
    this.id,
    required this.label,
    required this.address,
    required this.lat,
    required this.lon,
  });

  factory SavedLocationModel.fromJson(Map<String, dynamic> data) => SavedLocationModel(
        id: data['id'],
        label: data['label'],
        address: data['address'],
        lat: data['lat'],
        lon: data['lon'],
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'label': label,
        'address': address,
        'lat': lat,
        'lon': lon,
      };
}

/// A savings goal set by the user — stored in SQLite. Full CRUD.
class SavingsGoalModel {
  final int? id;
  final String name;
  final double targetAmount;
  final double savedAmount;

  SavingsGoalModel({
    this.id,
    required this.name,
    required this.targetAmount,
    this.savedAmount = 0,
  });

  double get progressPercent =>
      targetAmount == 0 ? 0 : (savedAmount / targetAmount).clamp(0, 1) * 100;

  factory SavingsGoalModel.fromJson(Map<String, dynamic> data) => SavingsGoalModel(
        id: data['id'],
        name: data['name'],
        targetAmount: (data['targetAmount'] as num).toDouble(),
        savedAmount: (data['savedAmount'] as num).toDouble(),
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'targetAmount': targetAmount,
        'savedAmount': savedAmount,
      };
}

/// A logged trip in the user's history — stored in SQLite. Full CRUD.
class TripLogModel {
  final int? id;
  final String route;
  final String mode; // "drive" or "transit"
  final double cost;
  final double savedVsAlternative;
  final String createdOn; // stored as ISO date string

  TripLogModel({
    this.id,
    required this.route,
    required this.mode,
    required this.cost,
    required this.savedVsAlternative,
    required this.createdOn,
  });

  factory TripLogModel.fromJson(Map<String, dynamic> data) => TripLogModel(
        id: data['id'],
        route: data['route'],
        mode: data['mode'],
        cost: (data['cost'] as num).toDouble(),
        savedVsAlternative: (data['savedVsAlternative'] as num).toDouble(),
        createdOn: data['createdOn'],
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'route': route,
        'mode': mode,
        'cost': cost,
        'savedVsAlternative': savedVsAlternative,
        'createdOn': createdOn,
      };
}
