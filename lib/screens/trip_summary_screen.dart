import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/database_service.dart';
import '../services/supabase_service.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import 'trip_added_screen.dart';

class TripSummaryScreen extends StatefulWidget {
  final String route;
  final String mode;
  final double cost;
  final double savedVsAlternative;
  final double distanceKm;
  const TripSummaryScreen({
    super.key,
    required this.route,
    required this.mode,
    required this.cost,
    required this.savedVsAlternative,
    required this.distanceKm,
  });

  @override
  State<TripSummaryScreen> createState() => _TripSummaryScreenState();
}

class _TripSummaryScreenState extends State<TripSummaryScreen> with SingleTickerProviderStateMixin {
  final _db = DatabaseService();
  final _supabase = SupabaseService();
  final _authService = AuthService();
  bool _saving = false;

  late final AnimationController _controller;
  late final Animation<double> _checkScale;
  late final Animation<double> _confettiFade;
  late final Animation<double> _contentFade;
  late final Animation<Offset> _contentSlide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

    // Checkmark "pops" in with a bouncy overshoot.
    _checkScale = CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.6, curve: Curves.elasticOut));

    // Text/cards fade and slide up shortly after, so the eye lands on
    // the checkmark first.
    _contentFade = CurvedAnimation(parent: _controller, curve: const Interval(0.35, 1.0, curve: Curves.easeOut));
    _contentSlide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: const Interval(0.35, 1.0, curve: Curves.easeOut)));

    // Separate, non-elastic fade for confetti — _checkScale uses
    // elasticOut which can briefly exceed 1.0 (a valid scale value, but
    // NOT a valid opacity value), so it can't be reused directly here.
    _confettiFade = CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.4, curve: Curves.easeOut));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _logTripAndFinish() async {
    setState(() => _saving = true);

    final trip = TripLogModel(
      route: widget.route,
      mode: widget.mode,
      cost: widget.cost,
      savedVsAlternative: widget.savedVsAlternative,
      distanceKm: widget.distanceKm,
      createdOn: DateTime.now().toIso8601String(),
    );

    await _db.insertTrip(trip);

    // Only sync to Supabase for a REAL logged-in account — a guest
    // has no account to ever log back into and retrieve synced data
    // from, so syncing guest data to one shared cloud table would
    // just mix every guest's trips together across every device.
    if (_authService.isLoggedIn) {
      try {
        await _supabase.uploadTrip(trip);
      } catch (e) {
        // ignore: avoid_print
        print('Supabase sync failed: $e');
      }
    }

    // NEW: apply this trip's real savings toward the user's active
    // savings goal, so the progress bar on Savings Goals actually
    // moves — this connection didn't exist before, which is why goals
    // never increased regardless of how much was saved on real trips.
    if (widget.savedVsAlternative > 0) {
      try {
        final goals = await _db.getGoals();
        if (goals.isNotEmpty) {
          final activeGoal = goals.first; // matches Home screen's "active goal" logic
          final updatedGoal = SavingsGoalModel(
            id: activeGoal.id,
            name: activeGoal.name,
            targetAmount: activeGoal.targetAmount,
            savedAmount: activeGoal.savedAmount + widget.savedVsAlternative,
          );
          await _db.updateGoal(updatedGoal);
        }
      } catch (e) {
        // ignore: avoid_print
        print('Updating savings goal failed (trip was still logged fine): $e');
      }
    }

    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(
        builder: (_) => TripAddedScreen(route: widget.route, savedVsAlternative: widget.savedVsAlternative),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasSavings = widget.savedVsAlternative > 0;
    // A light, playful "what your savings could buy" comparison — purely
    // illustrative, not a real product price lookup.
    final teCups = (widget.savedVsAlternative / 2.5).floor(); // approx RM2.50 per teh tarik

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Trip Summary'), automaticallyImplyLeading: false),
      body: Stack(
        children: [
          // Decorative confetti dots around the checkmark — fade in
          // together with the checkmark pop animation.
          FadeTransition(
            opacity: _confettiFade,
            child: const Stack(
              children: [
                _Confetti(top: 60, left: 40, color: AppColors.mint, size: 8),
                _Confetti(top: 90, left: 300, color: AppColors.amber, size: 6),
                _Confetti(top: 140, left: 20, color: AppColors.teal, size: 5),
                _Confetti(top: 150, left: 320, color: AppColors.mint, size: 7),
                _Confetti(top: 210, left: 60, color: AppColors.amber, size: 6),
                _Confetti(top: 220, left: 290, color: Color(0xFF7C3AED), size: 5),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ScaleTransition(
                    scale: _checkScale,
                    child: Container(
                      width: 96, height: 96,
                      decoration: BoxDecoration(color: AppColors.mintLight, shape: BoxShape.circle, boxShadow: [BoxShadow(color: AppColors.mint.withOpacity(0.25), blurRadius: 20, spreadRadius: 4)]),
                      child: const Icon(Icons.check_circle, color: AppColors.mint, size: 56),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FadeTransition(
                    opacity: _contentFade,
                    child: SlideTransition(
                      position: _contentSlide,
                      child: Column(
                        children: [
                          const Text('Great choice!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.teal)),
                          const SizedBox(height: 8),
                          Text(
                            hasSavings
                                ? 'You took ${widget.mode == 'transit' ? 'public transport' : 'this route'} and saved RM ${widget.savedVsAlternative.toStringAsFixed(2)} today!'
                                : 'Trip logged — cost this time: RM ${widget.cost.toStringAsFixed(2)}.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4))],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Column(children: [
                                  Icon(Icons.receipt_long, size: 18, color: Colors.grey.shade400),
                                  const SizedBox(height: 4),
                                  const Text('Trip cost', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                  Text('RM ${widget.cost.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.teal)),
                                ]),
                                Container(width: 1, height: 40, color: Colors.grey.shade100),
                                Column(children: [
                                  const Icon(Icons.savings, size: 18, color: AppColors.mint),
                                  const SizedBox(height: 4),
                                  const Text('Saved vs alternative', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                  Text('RM ${widget.savedVsAlternative.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.mint)),
                                ]),
                              ],
                            ),
                          ),
                          if (hasSavings && teCups > 0) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(color: AppColors.amberLight, borderRadius: BorderRadius.circular(14)),
                              child: Row(
                                children: [
                                  const Text('☕', style: TextStyle(fontSize: 22)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'That\'s enough for $teCups cup${teCups > 1 ? 's' : ''} of teh tarik!',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.teal),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 28),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _saving ? null : _logTripAndFinish,
                              child: _saving ? const CircularProgressIndicator(color: Colors.white) : const Text('Done'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Confetti extends StatelessWidget {
  final double top;
  final double left;
  final Color color;
  final double size;
  const _Confetti({required this.top, required this.left, required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top, left: left,
      child: Container(width: size, height: size, decoration: BoxDecoration(color: color.withOpacity(0.7), shape: BoxShape.circle)),
    );
  }
}