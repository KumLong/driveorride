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
      'createdOn': trip.createdOn,
    });
  }

  Future<List<TripLogModel>> fetchTrips() async {
    final data = await _client.from('trip_logs').select();
    return (data as List)
        .map((row) => TripLogModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> deleteTrip(int remoteId) async {
    await _client.from('trip_logs').delete().eq('id', remoteId);
  }
}
