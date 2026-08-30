import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/models.dart';
import '../services/database_service.dart';
import '../services/supabase_service.dart';
import '../theme.dart';

/// "Track Savings" screen — matches the reference flow's step 7.
/// Trip History CRUD, PLUS a real savings-over-time chart, trip count,
/// and a CO2-saved estimate, all computed from actual logged trips
/// (not placeholder numbers).
class TripHistoryScreen extends StatefulWidget {
  const TripHistoryScreen({super.key});

  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen> {
  final _db = DatabaseService();
  final _supabase = SupabaseService();
  List<TripLogModel> _trips = [];
  double _totalSaved = 0;

  // Average car CO2 emission factor (kg CO2 per km) — a commonly cited
  // figure for a typical passenger car. CO2 "saved" is estimated only
  // for transit trips, using the real distance travelled for that trip.
  static const _carEmissionKgPerKm = 0.171;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final trips = await _db.getTrips();
    final total = await _db.getTotalSaved();
    setState(() {
      _trips = trips;
      _totalSaved = total;
    });
  }

  Future<void> _addManualTrip(TripLogModel trip) async {
    await _db.insertTrip(trip);
    try {
      await _supabase.uploadTrip(trip);
    } catch (e) {
      // ignore: avoid_print
      print('Supabase sync failed (check your URL/key in main.dart): $e');
    }
    _refresh();
  }

  Future<void> _deleteTrip(int id) async {
    await _db.deleteTrip(id);
    _refresh();
  }

  double get _co2SavedKg {
    return _trips.where((t) => t.mode == 'transit').fold(0.0, (sum, t) => sum + (t.distanceKm * _carEmissionKgPerKm));
  }

  /// Builds cumulative savings points for the chart, ordered oldest to
  /// newest, from the real trip log — not fake sample data.
  List<FlSpot> get _savingsOverTimeSpots {
    if (_trips.isEmpty) return [];
    final sorted = List<TripLogModel>.from(_trips)..sort((a, b) => a.createdOn.compareTo(b.createdOn));
    double running = 0;
    final spots = <FlSpot>[];
    for (int i = 0; i < sorted.length; i++) {
      running += sorted[i].savedVsAlternative;
      spots.add(FlSpot(i.toDouble(), running));
    }
    return spots;
  }

  void _showAddTripForm() {
    final routeCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    final savedCtrl = TextEditingController();
    final distanceCtrl = TextEditingController();
    String mode = 'transit';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Trip (manual — for testing)'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: routeCtrl, decoration: const InputDecoration(labelText: 'Route (e.g. KL Sentral -> Sunway)')),
                TextField(controller: costCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Cost (RM)')),
                TextField(controller: savedCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Saved vs alternative (RM)')),
                TextField(controller: distanceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Distance (km)')),
                DropdownButton<String>(
                  value: mode,
                  items: const [
                    DropdownMenuItem(value: 'transit', child: Text('Transit')),
                    DropdownMenuItem(value: 'drive', child: Text('Drive')),
                  ],
                  onChanged: (v) => setDialogState(() => mode = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (routeCtrl.text.isEmpty) return;
                await _addManualTrip(TripLogModel(
                  route: routeCtrl.text,
                  mode: mode,
                  cost: double.tryParse(costCtrl.text) ?? 0,
                  savedVsAlternative: double.tryParse(savedCtrl.text) ?? 0,
                  distanceKm: double.tryParse(distanceCtrl.text) ?? 0,
                  createdOn: DateTime.now().toIso8601String(),
                ));
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Track Savings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.teal, Color(0xFF025D6A)]), borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                const Icon(Icons.account_balance_wallet, color: Colors.white, size: 32),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Saved', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    Text('RM ${_totalSaved.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                    const Text('vs. always driving', style: TextStyle(color: Colors.white54, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _statCard(Icons.route, 'Trips Taken', '${_trips.length}', AppColors.mint)),
              const SizedBox(width: 12),
              Expanded(child: _statCard(Icons.eco, 'CO₂ Saved', '${_co2SavedKg.toStringAsFixed(1)} kg', Colors.green)),
            ],
          ),
          const SizedBox(height: 12),
          if (_savingsOverTimeSpots.length >= 2)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Savings Over Time', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.teal)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 140,
                    child: LineChart(LineChartData(
                      gridData: const FlGridData(show: true, drawVerticalLine: false),
                      titlesData: const FlTitlesData(
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: _savingsOverTimeSpots,
                          isCurved: true,
                          color: AppColors.mint,
                          barWidth: 3,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(show: true, color: AppColors.mintLight),
                        ),
                      ],
                    )),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          const Text('Recent Trips', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.teal)),
          const SizedBox(height: 8),
          if (_trips.isEmpty)
            const Padding(padding: EdgeInsets.all(16), child: Center(child: Text('No trips logged yet.')))
          else
            ..._trips.map((trip) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(trip.mode == 'transit' ? Icons.directions_bus : Icons.directions_car, color: trip.mode == 'transit' ? AppColors.mint : AppColors.amber),
                    title: Text(trip.route),
                    subtitle: Text('${trip.createdOn.substring(0, 10)} • RM ${trip.cost.toStringAsFixed(2)} • ${trip.distanceKm.toStringAsFixed(1)} km'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('+RM ${trip.savedVsAlternative.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.mint, fontWeight: FontWeight.bold)),
                        IconButton(icon: const Icon(Icons.delete_outline, size: 18), onPressed: () => _deleteTrip(trip.id!)),
                      ],
                    ),
                  ),
                )),
        ],
      ),
      floatingActionButton: FloatingActionButton(onPressed: _showAddTripForm, child: const Icon(Icons.add)),
    );
  }

  Widget _statCard(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.teal)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
