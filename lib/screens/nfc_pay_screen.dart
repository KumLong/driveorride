import 'dart:async';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/database_service.dart';
import '../services/supabase_service.dart';
import '../theme.dart';

class NfcPayScreen extends StatefulWidget {
  final double amount;
  final String label;

  const NfcPayScreen({super.key, required this.amount, required this.label});

  @override
  State<NfcPayScreen> createState() => _NfcPayScreenState();
}

class _NfcPayScreenState extends State<NfcPayScreen> with SingleTickerProviderStateMixin {
  final _db = DatabaseService();
  final _supabase = SupabaseService();
  late final AnimationController _pulseController;
  bool _processing = false;
  bool _success = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();

    Timer(const Duration(seconds: 5), _simulateTap);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _simulateTap() async {
    if (_processing || _success) return;
    setState(() => _processing = true);

    final balance = await _db.getWalletBalance();
    if (balance < widget.amount) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _error = 'Insufficient balance';
      });
      return;
    }

    await _db.adjustWalletBalance(-widget.amount);
    final tx = WalletTransactionModel(
      label: widget.label,
      amount: -widget.amount,
      createdOn: DateTime.now().toIso8601String(),
    );
    await _db.insertWalletTransaction(tx);
    try {
      await _supabase.uploadWalletTransaction(tx);
    } catch (_) {

    }

    if (!mounted) return;
    setState(() {
      _processing = false;
      _success = true;
    });

    await Future.delayed(const Duration(milliseconds: 900));
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: GestureDetector(
          onTap: _simulateTap,
          behavior: HitTestBehavior.opaque,
          child: Column(
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.pop(context, false),
                ),
              ),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 260,
                        height: 260,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (!_success)
                              AnimatedBuilder(
                                animation: _pulseController,
                                builder: (context, child) {
                                  final t = _pulseController.value;
                                  return Container(
                                    width: 140 + (120 * t),
                                    height: 140 + (120 * t),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.mint.withOpacity((1 - t) * 0.6),
                                        width: 2,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            Container(
                              width: 130,
                              height: 90,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [AppColors.teal, Color(0xFF025D6A)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('DriveOrRide', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: const [
                                      Icon(Icons.wifi, color: Colors.white70, size: 14),
                                      Icon(Icons.contactless, color: Colors.white, size: 16),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (_success)
                              const CircleAvatar(radius: 130, backgroundColor: Colors.black87, child: Icon(Icons.check_circle, color: AppColors.mint, size: 64)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'RM ${widget.amount.toStringAsFixed(2)} · ${widget.label}',
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _success
                            ? 'Payment successful'
                            : (_error ?? 'Place your phone near the card reader'),
                        style: TextStyle(
                          color: _error != null ? Colors.orangeAccent : Colors.white70,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Go back', style: TextStyle(color: AppColors.mint)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}