import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/supabase_service.dart';
import '../theme.dart';
import 'top_up_screen.dart';

/// A SIMULATED virtual transit/toll card — balance, top-ups, and
/// transaction history, all real (stored locally + synced to
/// Supabase, scoped per account the same way trips/goals are). This
/// screen is a dashboard only: paying a fare or toll always happens
/// contextually from the "On the Way" screen during an active trip
/// (TripProgressTransitScreen / TripProgressDriveScreen), using that
/// trip's real amount — never a generic, made-up number here.
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final _db = DatabaseService();
  final _supabase = SupabaseService();
  final _auth = AuthService();

  double _balance = 0;
  List<WalletTransactionModel> _transactions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final balance = await _db.getWalletBalance();
    final txs = await _db.getWalletTransactions();
    if (mounted) {
      setState(() {
        _balance = balance;
        _transactions = txs;
        _loading = false;
      });
    }
  }

  Future<void> _onTopUp() async {
    final success = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const TopUpScreen()),
    );
    if (success == true) _refresh();
  }

  /// Purely cosmetic — a stable 4-digit "card number" derived from the
  /// signed-in user, so it looks like a real masked card number without
  /// storing or exposing any real payment data.
  String get _maskedCardNumber {
    final id = _auth.currentUser?.id ?? _auth.currentUser?.email ?? 'guest';
    final digits = (id.hashCode.abs() % 9000 + 1000).toString();
    return '•••• $digits';
  }

  String get _cardHolderName => _auth.currentUser?.email ?? 'Guest User';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('My Wallet')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Virtual card ──
            Container(
              padding: const EdgeInsets.all(20),
              height: 190,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.teal, Color(0xFF025D6A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 16, offset: const Offset(0, 8))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('DriveOrRide',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const Icon(Icons.wifi, color: Colors.white70, size: 22),
                    ],
                  ),
                  const Text('Virtual Transit Card', style: TextStyle(color: AppColors.mint, fontSize: 11)),
                  const Spacer(),
                  Text(_maskedCardNumber,
                      style: const TextStyle(color: Colors.white, fontSize: 20, letterSpacing: 2, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(_cardHolderName,
                            style: const TextStyle(color: Colors.white70, fontSize: 12), overflow: TextOverflow.ellipsis),
                      ),
                      const Icon(Icons.contactless, color: Colors.white, size: 24),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Balance', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text('RM ${_balance.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.teal)),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _onTopUp,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Top Up'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: AppColors.mintLight, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 14, color: AppColors.mint),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Fares and tolls are paid directly from the "On the Way" screen during an active trip, using that trip\'s real amount.',
                      style: TextStyle(fontSize: 11, color: Colors.teal.shade800),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            const Text('Recent transactions',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.teal)),
            const SizedBox(height: 10),
            if (_transactions.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                child: const Text('No recent transactions', style: TextStyle(color: Colors.grey, fontSize: 12)),
              )
            else
              ..._transactions.map((tx) {
                final isTopUp = tx.amount > 0;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6)],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: isTopUp ? AppColors.mintLight : AppColors.amberLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isTopUp ? Icons.add : Icons.directions_transit,
                          size: 16,
                          color: isTopUp ? AppColors.mint : AppColors.amber,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tx.label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            Text(
                              tx.createdOn.length >= 16 ? tx.createdOn.substring(0, 16).replaceFirst('T', ' ') : tx.createdOn,
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${isTopUp ? '+' : '-'}RM ${tx.amount.abs().toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: isTopUp ? AppColors.mint : AppColors.teal,
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}