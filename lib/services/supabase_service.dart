import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import 'auth_service.dart';

class SupabaseService {
  SupabaseClient get _client => Supabase.instance.client;
  final _authService = AuthService();

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

  Future<List<TripLogModel>> fetchTrips() async {
    final data = await _client.from('trip_logs').select().eq('ownerId', _ownerId);
    return (data as List)
        .map((row) => TripLogModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> deleteTripByMatch(String route, String createdOn) async {
    await _client.from('trip_logs').delete().eq('route', route).eq('createdOn', createdOn).eq('ownerId', _ownerId);
  }

  Future<void> deleteAllTrips() async {
    await _client.from('trip_logs').delete().eq('ownerId', _ownerId);
  }

  Future<void> uploadGoal(SavingsGoalModel goal) async {
    await _client.from('savings_goals').upsert({
      'name': goal.name,
      'targetAmount': goal.targetAmount,
      'savedAmount': goal.savedAmount,
      'celebrated': goal.celebrated ? 1 : 0,
      'ownerId': _ownerId,
    }, onConflict: 'ownerId,name');
  }

  Future<List<SavingsGoalModel>> fetchGoals() async {
    final data = await _client.from('savings_goals').select().eq('ownerId', _ownerId);
    return (data as List)
        .map((row) => SavingsGoalModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> deleteGoalByName(String name) async {
    await _client.from('savings_goals').delete().eq('name', name).eq('ownerId', _ownerId);
  }

  Future<void> deleteAllGoals() async {
    await _client.from('savings_goals').delete().eq('ownerId', _ownerId);
  }

  Future<void> uploadWalletTransaction(WalletTransactionModel tx) async {
    await _client.from('wallet_transactions').insert({
      'label': tx.label,
      'amount': tx.amount,
      'createdOn': tx.createdOn,
      'ownerId': _ownerId,
    });
  }

  Future<List<WalletTransactionModel>> fetchWalletTransactions() async {
    final data = await _client.from('wallet_transactions').select().eq('ownerId', _ownerId);
    return (data as List)
        .map((row) => WalletTransactionModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> deleteAllWalletTransactions() async {
    await _client.from('wallet_transactions').delete().eq('ownerId', _ownerId);
  }
}