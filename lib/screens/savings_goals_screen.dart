import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../services/supabase_service.dart';
import '../services/auth_service.dart';
import '../theme.dart';

class SavingsGoalsScreen extends StatefulWidget {
  final bool showBackButton;
  const SavingsGoalsScreen({super.key, this.showBackButton = false});

  @override
  State<SavingsGoalsScreen> createState() => _SavingsGoalsScreenState();
}

class _SavingsGoalsScreenState extends State<SavingsGoalsScreen> {
  final _db = DatabaseService();
  final _notifications = NotificationService();
  final _supabase = SupabaseService();
  final _authService = AuthService();
  List<SavingsGoalModel> _goals = [];
  double _totalSaved = 0;

  // Static so they persist across widget rebuilds within the same app session
  // — prevents re-triggering every time user switches to this tab
  static final _celebratedIds = <int>{};
  static final _notifiedIds = <int>{};

  static final _suggestions = [
    {'name': 'Holiday Trip',   'amount': 2000.0,  'icon': Icons.flight_takeoff_rounded},
    {'name': 'New Phone',      'amount': 1500.0,  'icon': Icons.smartphone_rounded},
    {'name': 'Education Fund', 'amount': 3000.0,  'icon': Icons.school_rounded},
    {'name': 'New Laptop',     'amount': 2500.0,  'icon': Icons.laptop_rounded},
    {'name': 'Home Savings',   'amount': 10000.0, 'icon': Icons.home_rounded},
    {'name': 'Car Fund',       'amount': 5000.0,  'icon': Icons.directions_car_rounded},
    {'name': 'Emergency Fund', 'amount': 1000.0,  'icon': Icons.shield_rounded},
    {'name': 'Shopping',       'amount': 500.0,   'icon': Icons.shopping_bag_rounded},
  ];

  IconData _goalIcon(String name) {
    final n = name.toLowerCase();
    if (n.contains('holiday') || n.contains('travel') || n.contains('trip') || n.contains('vacation'))
      return Icons.flight_takeoff_rounded;
    if (n.contains('phone') || n.contains('gadget'))
      return Icons.smartphone_rounded;
    if (n.contains('laptop') || n.contains('computer') || n.contains('tech'))
      return Icons.laptop_rounded;
    if (n.contains('education') || n.contains('study') || n.contains('school') || n.contains('course'))
      return Icons.school_rounded;
    if (n.contains('car') || n.contains('vehicle'))
      return Icons.directions_car_rounded;
    if (n.contains('home') || n.contains('house'))
      return Icons.home_rounded;
    if (n.contains('emergency') || n.contains('safety'))
      return Icons.shield_rounded;
    if (n.contains('shop') || n.contains('cloth'))
      return Icons.shopping_bag_rounded;
    return Icons.star_rounded;
  }

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final goals = await _db.getGoals();
    final total = await _db.getTotalSaved();
    if (!mounted) return;

    // Check milestones before updating state
    for (final goal in goals) {
      final id = goal.id;
      if (id == null) continue;

      // 100% — show celebration popup. Checks the PERSISTED
      // goal.celebrated flag (not just the in-memory _celebratedIds
      // set) — this is what actually fixes the bug where every
      // already-completed goal re-showed its celebration on every
      // fresh app launch, since the in-memory set alone resets every
      // time the app restarts.
      if (goal.progressPercent >= 100 && !goal.celebrated && !_celebratedIds.contains(id)) {
        _celebratedIds.add(id);
        // Persist immediately — marks this goal as celebrated for
        // good, not just for the current session.
        final updatedGoal = SavingsGoalModel(
          id: goal.id,
          name: goal.name,
          targetAmount: goal.targetAmount,
          savedAmount: goal.savedAmount,
          celebrated: true,
        );
        await _db.updateGoal(updatedGoal);
        if (_authService.isLoggedIn) {
          try {
            await _supabase.uploadGoal(updatedGoal);
          } catch (e) {
            // ignore: avoid_print
            print('Supabase goal sync failed (local save still succeeded): $e');
          }
        }
        // Delay slightly so screen finishes building first
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) _showCelebration(goal);
        });
      }

      // 80% milestone — send push notification (only once per session per goal)
      if (goal.progressPercent >= 80 &&
          goal.progressPercent < 100 &&
          !_notifiedIds.contains(id)) {
        _notifiedIds.add(id);
        final remaining = goal.targetAmount - goal.savedAmount;
        // Request permission first — in case user never toggled notifications
        final granted = await _notifications.requestPermission();
        if (granted) {
          _notifications.showImmediate(
            id: 9000 + id,
            title: "Almost there! 🎯",
            body:
            "RM ${remaining.toStringAsFixed(2)} more to reach your '${goal.name}' goal. Keep choosing transit!",
          );
        }
      }
    }

    setState(() {
      _goals = goals;
      _totalSaved = total;
    });
  }

  void _showCelebration(SavingsGoalModel goal) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Trophy — using the app's established mint accent
              // instead of an inconsistent amber tone
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: AppColors.mintLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.emoji_events_rounded,
                    color: AppColors.mint, size: 38),
              ),
              const SizedBox(height: 18),

              const Text('Goal Achieved!',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold,
                      color: AppColors.teal)),
              const SizedBox(height: 8),

              Text("You've reached your '${goal.name}' goal",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 14),

              // Amount — in its own soft card, matching the app's
              // stat-card language used elsewhere (Home, Route Details)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Text(
                      'RM ${goal.targetAmount.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.teal),
                    ),
                    const SizedBox(height: 2),
                    const Text('saved through smart commuting',
                        style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showGoalForm();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.mint,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: const Text('Set a New Goal',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ),

              const SizedBox(height: 10),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    if (goal.id != null) await _deleteGoal(goal.id!);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Remove This Goal',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                ),
              ),

              const SizedBox(height: 10),

              SizedBox(
                width: double.infinity,
                height: 44,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Keep it for now',
                      style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600, fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGoalForm({SavingsGoalModel? existing, String? prefillName, double? prefillAmount}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? prefillName ?? '');
    final targetCtrl = TextEditingController(
      text: existing != null ? existing.targetAmount.toStringAsFixed(0)
          : (prefillAmount != null ? prefillAmount.toStringAsFixed(0) : ''),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Text(existing == null ? 'Set a New Goal' : 'Edit Goal',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.teal)),
              const SizedBox(height: 16),
              _field(ctrl: nameCtrl, label: 'Goal Name', hint: 'e.g. Holiday Trip, New Phone'),
              const SizedBox(height: 12),
              _field(ctrl: targetCtrl, label: 'Target Amount (RM)', hint: '0.00',
                  prefix: 'RM  ', keyboard: TextInputType.number),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      final name = nameCtrl.text.trim();
                      final target = double.tryParse(targetCtrl.text) ?? 0;
                      if (name.isEmpty || target <= 0) return;
                      final SavingsGoalModel savedGoal;
                      if (existing == null) {
                        savedGoal = SavingsGoalModel(name: name, targetAmount: target);
                        await _db.insertGoal(savedGoal);
                      } else {
                        savedGoal = SavingsGoalModel(
                            id: existing.id, name: name,
                            targetAmount: target, savedAmount: existing.savedAmount,
                            celebrated: existing.celebrated); // preserve — editing name/target must never silently reset it
                        await _db.updateGoal(savedGoal);
                      }
                      // Only sync to Supabase for a REAL logged-in account —
                      // a guest has no account to ever log back into and
                      // retrieve synced data from.
                      if (_authService.isLoggedIn) {
                        try {
                          await _supabase.uploadGoal(savedGoal);
                        } catch (e) {
                          // ignore: avoid_print
                          print('Supabase goal sync failed (local save still succeeded): $e');
                        }
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                      _refresh();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.mint,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: Text(existing == null ? 'Create Goal' : 'Save',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field({required TextEditingController ctrl, required String label,
    String? hint, String? prefix, TextInputType? keyboard}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.teal)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: keyboard,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            prefixText: prefix,
            prefixStyle: TextStyle(color: AppColors.teal, fontWeight: FontWeight.bold),
            hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
            filled: true,
            fillColor: const Color(0xFFF5F5F5),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.mint, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  Future<void> _deleteGoal(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Goal?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('This goal will be permanently removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      // Look up the name BEFORE deleting locally — needed to also
      // delete the matching remote row, since goals are matched by
      // name (not id) between local SQLite and Supabase.
      final goalName = _goals.firstWhere((g) => g.id == id, orElse: () => SavingsGoalModel(name: '', targetAmount: 0)).name;
      // Cancel any milestone notification for this goal
      await _notifications.cancelGoalNotification(id);
      // Remove from tracking sets so it can re-trigger if user creates a new goal
      _notifiedIds.remove(id);
      _celebratedIds.remove(id);
      await _db.deleteGoal(id);
      if (_authService.isLoggedIn && goalName.isNotEmpty) {
        try {
          await _supabase.deleteGoalByName(goalName);
        } catch (e) {
          // ignore: avoid_print
          print('Supabase goal delete failed (local delete still succeeded): $e');
        }
      }
      _refresh();
    }
  }

  Widget _goalCard(SavingsGoalModel goal) {
    final percent = (goal.progressPercent / 100).clamp(0.0, 1.0);
    return GestureDetector(
      onTap: () => _showGoalForm(existing: goal),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: AppColors.mintLight, shape: BoxShape.circle),
              child: Icon(_goalIcon(goal.name), color: AppColors.mint, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: Text(goal.name,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.teal))),
                    GestureDetector(
                      onTap: () => _deleteGoal(goal.id!),
                      child: Icon(Icons.delete_outline, size: 16, color: Colors.grey.shade400),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade400),
                  ]),
                  const SizedBox(height: 2),
                  Text('RM ${goal.targetAmount.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: percent,
                      backgroundColor: Colors.grey.shade100,
                      color: AppColors.mint,
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('RM ${goal.savedAmount.toStringAsFixed(2)} saved',
                          style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      Text('${goal.progressPercent.toStringAsFixed(0)}%',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.mint)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _completedCard(SavingsGoalModel goal) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.green.shade100),
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: Icon(_goalIcon(goal.name), color: Colors.green, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(goal.name,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.teal)),
                const SizedBox(height: 2),
                Text('RM ${goal.targetAmount.toStringAsFixed(2)} — Goal reached! 🎉',
                    style: TextStyle(fontSize: 11, color: Colors.green.shade600)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _deleteGoal(goal.id!),
            child: Icon(Icons.delete_outline, size: 18, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: widget.showBackButton
            ? IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.teal),
          onPressed: () => Navigator.pop(context),
        )
            : null,
        // Left aligned title — matches the rest of the app
        title: const Text('Saving Goals',
            style: TextStyle(color: AppColors.teal, fontWeight: FontWeight.bold, fontSize: 20)),
        centerTitle: false,
      ),

      // Fixed "Set a New Goal" button at the bottom — moved into body
      bottomNavigationBar: null,

      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: [

          // ── Hero Banner ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.mintLight,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Small steps today,\nbigger savings tomorrow.',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
                              color: AppColors.teal, height: 1.3)),
                      const SizedBox(height: 6),
                      const Text('Set a goal, stay on track, and\nmake your commute work for you.',
                          style: TextStyle(fontSize: 11, color: Colors.grey, height: 1.4)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Decorative icon — neutral, no sensitive imagery
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        top: 10, right: 10,
                        child: Icon(Icons.monetization_on_rounded,
                            color: AppColors.amber, size: 22),
                      ),
                      Icon(Icons.account_balance_wallet_rounded,
                          color: AppColors.mint, size: 34),
                      Positioned(
                        bottom: 8, right: 8,
                        child: Icon(Icons.eco_rounded,
                            color: const Color(0xFF4DB6AC), size: 16),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Total Savings ────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Savings', style: TextStyle(color: Colors.grey, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text('RM ${_totalSaved.toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.teal)),
                  ],
                ),
                const Spacer(),
                Text('${_goals.length} goal${_goals.length == 1 ? '' : 's'}',
                    style: TextStyle(fontSize: 12, color: AppColors.mint, fontWeight: FontWeight.w600)),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Quick Start Suggestions ──────────────────────────────
          const Text('Suggestions',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.teal)),
          const SizedBox(height: 10),
          SizedBox(
            height: 78,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _suggestions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (ctx, i) {
                final s = _suggestions[i];
                return GestureDetector(
                  onTap: () => _showGoalForm(
                    prefillName: s['name'] as String,
                    prefillAmount: s['amount'] as double,
                  ),
                  child: Container(
                    width: 78,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(s['icon'] as IconData, color: AppColors.mint, size: 20),
                        const SizedBox(height: 6),
                        Text(s['name'] as String,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                                color: AppColors.teal),
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 20),

          // ── Your Goals Header ────────────────────────────────────
          const Text('Your Goals',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.teal)),

          const SizedBox(height: 10),

          // Active goals only
          if (_goals.where((g) => g.progressPercent < 100).isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Icon(Icons.flag_outlined, size: 44, color: Colors.grey.shade300),
                  const SizedBox(height: 10),
                  const Text('No active goals',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 4),
                  const Text('Tap a suggestion or Set a New Goal to begin',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            )
          else
            ..._goals.where((g) => g.progressPercent < 100).map((goal) => _goalCard(goal)),

          // Completed goals section
          if (_goals.any((g) => g.progressPercent >= 100)) ...[
            const SizedBox(height: 20),
            Row(children: [
              Icon(Icons.check_circle, color: Colors.green, size: 18),
              const SizedBox(width: 6),
              const Text('Completed',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.green)),
            ]),
            const SizedBox(height: 10),
            ..._goals.where((g) => g.progressPercent >= 100).map((goal) => _completedCard(goal)),
          ],

          const SizedBox(height: 12),

          // ── Set a New Goal Button ────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () => _showGoalForm(),
              icon: const Icon(Icons.track_changes_rounded, size: 20),
              label: const Text('Set a New Goal',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.mint,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
            ),
          ),

          SizedBox(height: MediaQuery.of(context).padding.bottom + 80),
        ],
      ),
    );
  }
}