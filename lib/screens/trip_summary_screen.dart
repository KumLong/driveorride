import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/database_service.dart';
import '../services/supabase_service.dart';
import '../theme.dart';

class TripSummaryScreen extends StatefulWidget {
  final String route;
  final String mode;
  const TripSummaryScreen({super.key, required this.route, required this.mode});

  @override
  State<TripSummaryScreen> createState() => _TripSummaryScreenState();
}

class _TripSummaryScreenState extends State<TripSummaryScreen> {
  final _db = DatabaseService();
  final _supabase = SupabaseService();
  bool _saving = false;

  Future<void> _logTripAndFinish() async {
    setState(() => _saving = true);

    // TODO: replace these placeholder numbers with the real calculated
    // cost/savings passed in from the Compare/Route Details screens.
    final trip = TripLogModel(
      route: widget.route,
      mode: widget.mode,
      cost: widget.mode == 'transit' ? 4.10 : 13.40,
      savedVsAlternative: widget.mode == 'transit' ? 9.30 : 0,
      createdOn: DateTime.now().toIso8601String(),
    );

    await _db.insertTrip(trip); // LOCAL save (SQLite)
    try {
      await _supabase.uploadTrip(trip); // REMOTE sync (Supabase)
    } catch (e) {
      // ignore: avoid_print
      print('Supabase sync failed: $e');
    }

    if (mounted) {
      Navigator.popUntil(context, (route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final saved = widget.mode == 'transit' ? 9.30 : 0.0;
    return Scaffold(
      appBar: AppBar(title: const Text('Trip Summary')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircleAvatar(radius: 48, backgroundColor: AppColors.mintLight, child: Icon(Icons.check_circle, color: AppColors.mint, size: 52)),
            const SizedBox(height: 20),
            const Text('Great choice!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.teal)),
            const SizedBox(height: 8),
            Text(
              widget.mode == 'transit'
                  ? 'You took public transport and saved RM ${saved.toStringAsFixed(2)} today!'
                  : 'Trip logged.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.mint, foregroundColor: Colors.white, padding: const EdgeInsets.all(16)),
                onPressed: _saving ? null : _logTripAndFinish,
                child: _saving ? const CircularProgressIndicator(color: Colors.white) : const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
