import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import 'auth_service.dart';

/// REMOTE storage using Supabase (Practical 11 pattern).
///
/// ⚠️ SETUP REQUIRED: create a Supabase project, a "trip_logs" table
/// (see README), and paste your URL/key into main.dart. You also need
/// to run this once in Supabase's SQL Editor, to match the same
/// per-user scoping now used locally:
///   ALTER TABLE trip_logs ADD COLUMN ownerId TEXT DEFAULT 'guest';
///
/// Until the URL/key is set up, calls here will throw a caught,
/// friendly error (see try/catch in trip_history_screen.dart /
/// trip_summary_screen.dart) instead of crashing the app — because
/// the Supabase client is only accessed lazily, when actually used,
/// not the moment this class exists.
class SupabaseService {
  SupabaseClient get _client => Supabase.instance.client;
  final _authService = AuthService();

  /// Same "owner" concept as DatabaseService (SQLite) — the logged-in
  /// user's real Supabase Auth ID, or 'guest' if nobody is logged in.
  /// This keeps local and remote data scoped identically, so a trip
  /// saved by one account never shows up for another.
  String get _ownerId => _authService.currentUser?.id ?? 'guest';

  Future<void> uploadTrip(TripLogModel trip) async {
    await _client.from('trip_logs').insert({
      'route': trip.route,
      'mode': trip.mode,
      'cost': trip.cost,
      'savedVsAlternative': trip.savedVsAlternative,
      'distanceKm': trip.distanceKm,
      'createdOn': trip.createdOn,
      'ownerId': _ownerId,
    });
  }

  /// Fetches trips belonging ONLY to the current user/guest — not
  /// everyone's trips, which was the original bug.
  Future<List<TripLogModel>> fetchTrips() async {
    final data = await _client.from('trip_logs').select().eq('ownerId', _ownerId);
    return (data as List)
        .map((row) => TripLogModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// Deletes ONE remote trip, matched by route + exact timestamp AND
  /// the current owner — so one account can never accidentally delete
  /// another account's trip, even if the route/time happened to match.
  Future<void> deleteTripByMatch(String route, String createdOn) async {
    await _client.from('trip_logs').delete().eq('route', route).eq('createdOn', createdOn).eq('ownerId', _ownerId);
  }

  /// Deletes every trip belonging to the CURRENT user/guest only —
  /// not the whole table, which would have wiped every other
  /// account's data too.
  Future<void> deleteAllTrips() async {
    await _client.from('trip_logs').delete().eq('ownerId', _ownerId);
  }
}