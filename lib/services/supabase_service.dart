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

  // ───────────── SAVINGS GOALS ─────────────
  //
  // Unlike trips (immutable events, matched by route+timestamp),
  // goals are matched by (ownerId, name) — a goal's savedAmount and
  // celebrated flag change repeatedly over its lifetime, so this uses
  // UPSERT: insert if new, update in place if a goal with that name
  // already exists for this owner. The 'name' UNIQUE constraint on
  // the real table is what makes this upsert actually work correctly.

  Future<void> uploadGoal(SavingsGoalModel goal) async {
    await _client.from('savings_goals').upsert({
      'name': goal.name,
      'targetAmount': goal.targetAmount,
      'savedAmount': goal.savedAmount,
      'celebrated': goal.celebrated ? 1 : 0,
      'ownerId': _ownerId,
    }, onConflict: 'ownerId,name');
  }

  /// Fetches goals belonging ONLY to the current user/guest.
  Future<List<SavingsGoalModel>> fetchGoals() async {
    final data = await _client.from('savings_goals').select().eq('ownerId', _ownerId);
    return (data as List)
        .map((row) => SavingsGoalModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// Deletes ONE remote goal, matched by name + the current owner —
  /// so one account can never affect another's goal, even if the
  /// name happened to match.
  Future<void> deleteGoalByName(String name) async {
    await _client.from('savings_goals').delete().eq('name', name).eq('ownerId', _ownerId);
  }

  /// Deletes every goal belonging to the CURRENT user/guest only.
  Future<void> deleteAllGoals() async {
    await _client.from('savings_goals').delete().eq('ownerId', _ownerId);
  }

  // ───────────── WALLET — scoped per user, same ownerId pattern ─────────────
  // ⚠️ SETUP: create `wallet_transactions` table (see README) with an
  // ownerId TEXT column, matching trip_logs/savings_goals above.

  Future<void> uploadWalletTransaction(WalletTransactionModel tx) async {
    await _client.from('wallet_transactions').insert({
      'label': tx.label,
      'amount': tx.amount,
      'createdOn': tx.createdOn,
      'ownerId': _ownerId,
    });
  }

  /// Fetches wallet transactions belonging ONLY to the current user/guest.
  Future<List<WalletTransactionModel>> fetchWalletTransactions() async {
    final data = await _client.from('wallet_transactions').select().eq('ownerId', _ownerId);
    return (data as List)
        .map((row) => WalletTransactionModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// Deletes every wallet transaction belonging to the CURRENT
  /// user/guest only — used by account deletion.
  Future<void> deleteAllWalletTransactions() async {
    await _client.from('wallet_transactions').delete().eq('ownerId', _ownerId);
  }
}