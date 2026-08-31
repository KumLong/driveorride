import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

/// REMOTE storage using Supabase (Practical 11 pattern).
///
/// ⚠️ SETUP REQUIRED: create a Supabase project, a "trip_logs" table
/// (see README), and paste your URL/key into main.dart.
///
/// Until that's done, calls here will throw a caught, friendly error
/// (see try/catch in trip_history_screen.dart / trip_summary_screen.dart)
/// instead of crashing the app — because the Supabase client is only
/// accessed lazily, when actually used, not the moment this class exists.
class SupabaseService {
  SupabaseClient get _client => Supabase.instance.client;

  Future<void> uploadTrip(TripLogModel trip) async {
    await _client.from('trip_logs').insert({
      'route': trip.route,
      'mode': trip.mode,
      'cost': trip.cost,
      'savedVsAlternative': trip.savedVsAlternative,
      'distanceKm': trip.distanceKm, // was missing before — same bug as SQLite's insert
      'createdOn': trip.createdOn,
    });
  }

  Future<List<TripLogModel>> fetchTrips() async {
    final data = await _client.from('trip_logs').select();
    return (data as List)
        .map((row) => TripLogModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// Deletes ONE remote trip, matched by route + exact timestamp
  /// (createdOn) rather than by ID — the local SQLite row's ID and the
  /// remote Supabase row's ID are two independent, unrelated sequences
  /// (each database assigns its own), so matching on the data itself
  /// is the reliable way to find the corresponding remote record.
  Future<void> deleteTripByMatch(String route, String createdOn) async {
    await _client.from('trip_logs').delete().eq('route', route).eq('createdOn', createdOn);
  }

  /// Deletes every trip in the remote table — used to keep "Clear All"
  /// consistent between local (SQLite) and remote (Supabase), instead
  /// of only clearing the local copy.
  ///
  /// Filters on createdOn (guaranteed to exist and never empty) rather
  /// than "id" — this avoids depending on whether your Supabase table
  /// happens to have an id/primary key column set up, since that's not
  /// something this app otherwise requires.
  Future<void> deleteAllTrips() async {
    await _client.from('trip_logs').delete().neq('createdOn', '');
  }
}
