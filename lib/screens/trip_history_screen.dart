import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/models.dart';
import '../services/database_service.dart';
import '../services/supabase_service.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import 'trip_detail_dialog.dart';

/// "Track Savings" screen — matches the reference flow's step 7.
/// Trip History CRUD, PLUS a real savings-over-time chart, trip count,
/// and a CO2-saved estimate, all computed from actual logged trips
/// (not placeholder numbers).
///
/// IMPORTANT design note: the displayed trip LIST is paginated (a
/// growing list can otherwise load an unbounded amount of data into
/// memory over months of real use), but the STATS (trip count, CO2,
/// chart) are calculated from separate, lightweight SQL aggregate
/// queries against the TRUE full history — never from just whatever
/// page happens to be currently loaded, so they stay accurate no
/// matter how much of the list has been paged through.
class TripHistoryScreen extends StatefulWidget {
  const TripHistoryScreen({super.key});

  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen> {
  final _db = DatabaseService();
  final _supabase = SupabaseService();
  final _authService = AuthService();

  static const _pageSize = 15;

  List<TripLogModel> _trips = [];
  bool _hasMore = true;
  bool _loadingMore = false;

  double _totalSaved = 0;
  int _totalTripCount = 0;
  double _co2SavedKg = 0;
  List<FlSpot> _savingsOverTimeSpots = [];

  // Average car CO2 emission factor (kg CO2 per km) — a commonly cited
  // figure for a typical passenger car. CO2 "saved" is estimated only
  // for transit trips, using the real distance travelled for that trip.
  static const _carEmissionKgPerKm = 0.171;

  @override
  void initState() {
    super.initState();
    _refreshAll();
  }

  /// Refreshes EVERYTHING — the first page of the list, plus every
  /// stat, from scratch. Used after any change (add/delete/clear).
  Future<void> _refreshAll() async {
    final firstPage = await _db.getTrips(limit: _pageSize, offset: 0);
    await _loadStats();
    if (mounted) {
      setState(() {
        _trips = firstPage;
        _hasMore = firstPage.length == _pageSize;
      });
    }
  }

  /// Loads the real aggregate stats independently of the paginated
  /// list — this is what keeps them accurate regardless of how much
  /// of the list has actually been paged through.
  Future<void> _loadStats() async {
    final total = await _db.getTotalSaved();
    final count = await _db.getTripCount();
    final transitDistance = await _db.getTotalDistanceForMode('transit');
    final timeline = await _db.getSavingsTimeline();

    double running = 0;
    final spots = <FlSpot>[];
    for (int i = 0; i < timeline.length; i++) {
      running += (timeline[i]['savedVsAlternative'] as num).toDouble();
      spots.add(FlSpot(i.toDouble(), running));
    }

    if (mounted) {
      setState(() {
        _totalSaved = total;
        _totalTripCount = count;
        _co2SavedKg = transitDistance * _carEmissionKgPerKm;
        _savingsOverTimeSpots = spots;
      });
    }
  }

  /// Fetches the NEXT page and appends it — this is the real
  /// pagination, only loading more from SQLite when actually asked
  /// to, instead of the whole history up front.
  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    final nextPage = await _db.getTrips(limit: _pageSize, offset: _trips.length);
    if (mounted) {
      setState(() {
        _trips = [..._trips, ...nextPage];
        _hasMore = nextPage.length == _pageSize;
        _loadingMore = false;
      });
    }
  }

  Future<void> _addManualTrip(TripLogModel trip) async {
    await _db.insertTrip(trip);
    if (_authService.isLoggedIn) {
      try {
        await _supabase.uploadTrip(trip);
      } catch (e) {
        // ignore: avoid_print
        print('Supabase sync failed (check your URL/key in main.dart): $e');
      }
    }
    _refreshAll();
  }

  Future<void> _deleteTrip(TripLogModel trip) async {
    await _db.deleteTrip(trip.id!); // local
    if (_authService.isLoggedIn) {
      try {
        await _supabase.deleteTripByMatch(trip.route, trip.createdOn); // remote — keeps both in sync
      } catch (e) {
        // ignore: avoid_print
        print('Supabase delete failed (local delete still succeeded): $e');
      }
    }
    _refreshAll();
  }

  /// Rounds the chart's top value up to a clean number (e.g. next
  /// multiple of 5, 10, 20...) so axis labels land on tidy values
  /// instead of fl_chart auto-picking an interval that overlaps labels
  /// (which is what caused the "1.26" overlapping "1.00" issue).
  /// Rounds a value down to a clean number matching the chart's scale
  /// (nearest 10 for small ranges, 20/50 for larger ones).
  double _roundDownToStep(double value, double step) => (value / step).floor() * step;
  double _roundUpToStep(double value, double step) => (value / step).ceil() * step;

  /// Instead of always starting the Y-axis at RM 0 (which squashes the
  /// line into a tiny sliver at the top if savings are already large,
  /// e.g. sitting around RM 140-150), this zooms into the actual range
  /// of the real data — showing meaningful variation instead of a
  /// near-flat line.
  double get _chartMinY {
    if (_savingsOverTimeSpots.isEmpty) return 0;
    final minVal = _savingsOverTimeSpots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final step = minVal <= 50 ? 10.0 : (minVal <= 200 ? 20.0 : 50.0);
    final rounded = _roundDownToStep(minVal, step);
    return rounded < 0 ? 0 : rounded;
  }

  double get _chartMaxY {
    if (_savingsOverTimeSpots.isEmpty) return 10;
    final maxVal = _savingsOverTimeSpots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final step = maxVal <= 50 ? 10.0 : (maxVal <= 200 ? 20.0 : 50.0);
    final rounded = _roundUpToStep(maxVal, step);
    // Ensure there's always some visible range even if all values are equal.
    return rounded <= _chartMinY ? _chartMinY + step : rounded;
  }

  double get _chartYInterval => ((_chartMaxY - _chartMinY) / 4).clamp(1, double.infinity);

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

  void _confirmClearHistory() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear all trip history?'),
        content: Text(
          _authService.isLoggedIn
              ? 'This clears all your trips everywhere — this device and your account — and resets your savings, trip count, and CO2 saved back to zero. This can\'t be undone.'
              : 'This clears all your trips on this device and resets your savings, trip count, and CO2 saved back to zero. This can\'t be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await _db.clearAllTrips(); // local
              if (_authService.isLoggedIn) {
                try {
                  await _supabase.deleteAllTrips(); // remote — keeps both in sync, real accounts only
                } catch (e) {
                  // ignore: avoid_print
                  print('Supabase clear-all failed (local clear still succeeded): $e');
                }
              }
              if (ctx.mounted) Navigator.pop(ctx);
              _refreshAll();
            },
            child: const Text('Clear Everything', style: TextStyle(color: Colors.redAccent)),
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
        title: const Text('History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Clear all trip history',
            onPressed: _confirmClearHistory,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.mint, Color(0xFF025D6A)]), borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                const Icon(Icons.account_balance_wallet, color: Colors.white, size: 32),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Saved', style: TextStyle(color: Colors.white, fontSize: 12)),
                    Text('RM ${_totalSaved.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                    const Text('vs. always driving', style: TextStyle(color: Colors.white, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Uses the TRUE total count from a real SQL count query
              // — accurate regardless of how much of the list below
              // has actually been paged through.
              Expanded(child: _statCard(Icons.route, 'Trips Taken', '$_totalTripCount', AppColors.mint)),
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
                    height: 160,
                    child: LineChart(LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: _chartYInterval,
                        getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade200, strokeWidth: 1),
                      ),
                      minY: _chartMinY,
                      maxY: _chartMaxY,
                      titlesData: FlTitlesData(
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 42,
                            interval: _chartYInterval,
                            getTitlesWidget: (value, meta) => Text('RM${value.toStringAsFixed(0)}', style: const TextStyle(fontSize: 9, color: Colors.grey)),
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipColor: (_) => AppColors.teal,
                          tooltipBorderRadius: BorderRadius.circular(8),
                          getTooltipItems: (spots) => spots.map((spot) => LineTooltipItem(
                            'RM ${spot.y.toStringAsFixed(2)}',
                            const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                          )).toList(),
                        ),
                      ),
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
          else ...[
            ..._trips.map((trip) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                onTap: () => showTripDetailDialog(context, trip),
                leading: Icon(trip.mode == 'transit' ? Icons.directions_bus : Icons.directions_car, color: trip.mode == 'transit' ? AppColors.mint : AppColors.amber),
                title: Text(trip.route),
                subtitle: Text('${trip.createdOn.substring(0, 10)} • RM ${trip.cost.toStringAsFixed(2)} • ${trip.distanceKm.toStringAsFixed(1)} km'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('+RM ${trip.savedVsAlternative.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.mint, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.delete_outline, size: 18), onPressed: () => _deleteTrip(trip)),
                  ],
                ),
              ),
            )),
            // Real pagination — only fetches the next batch from
            // SQLite when actually asked to, keeping memory usage
            // bounded no matter how many trips accumulate over time.
            if (_hasMore)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _loadingMore ? null : _loadMore,
                    child: _loadingMore
                        ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Load More'),
                  ),
                ),
              ),
          ],
        ],
      ),
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