import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:location/location.dart';
import '../services/routing_service.dart';
import '../services/database_service.dart';
import '../services/location_tracking_service.dart';
import '../models/models.dart';
import '../theme.dart';
import 'compare_screen.dart';
import 'trip_detail_dialog.dart';
import 'trip_history_screen.dart';
import 'saved_locations_screen.dart';
import 'savings_goals_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _fromCtrl = TextEditingController();
  final _toCtrl = TextEditingController();
  final _routingService = RoutingService();
  final _db = DatabaseService();
  final _locationService = LocationTrackingService();

  bool _loading = false;
  bool _locating = false;

  double _totalSaved = 0;
  List<TripLogModel> _recentTrips = [];
  List<SavedLocationModel> _savedLocations = [];
  SavingsGoalModel? _activeGoal;

  static const double _headerHeight = 170;
  static const double _cardTopMargin = 130;

  /// Same icon-matching logic as Savings Goals screen — kept
  /// identical so a goal always shows the same icon everywhere in
  /// the app, not a generic one here and a matched one there.
  IconData _goalIcon(String name) {
    final n = name.toLowerCase();
    if (n.contains('holiday') || n.contains('travel') || n.contains('trip') || n.contains('vacation')) return Icons.flight_takeoff_rounded;
    if (n.contains('phone') || n.contains('gadget')) return Icons.smartphone_rounded;
    if (n.contains('laptop') || n.contains('computer') || n.contains('tech')) return Icons.laptop_rounded;
    if (n.contains('education') || n.contains('study') || n.contains('school') || n.contains('course')) return Icons.school_rounded;
    if (n.contains('car') || n.contains('vehicle')) return Icons.directions_car_rounded;
    if (n.contains('home') || n.contains('house')) return Icons.home_rounded;
    if (n.contains('emergency') || n.contains('safety')) return Icons.shield_rounded;
    if (n.contains('shop') || n.contains('cloth')) return Icons.shopping_bag_rounded;
    return Icons.star_rounded;
  }

  @override
  void initState() {
    super.initState();
    _refreshRealData();
    _detectMyLocation();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refreshRealData();
  }

  Future<void> _refreshRealData() async {
    final total = await _db.getTotalSaved();
    final trips = await _db.getTrips(limit: 2);
    final locations = await _db.getLocations();
    final goals = await _db.getGoals();
    if (mounted) {
      setState(() {
        _totalSaved = total;
        _recentTrips = trips;
        _savedLocations = locations;
        _activeGoal = goals.isNotEmpty
            ? goals.firstWhere(
              (g) => g.progressPercent < 100,
          orElse: () => goals.first,
        )
            : null;
      });
    }
  }

  Future<void> _detectMyLocation() async {
    if (mounted) setState(() => _locating = true);

    final granted = await _locationService.isPermissionGranted();
    if (!granted) {
      await _locationService.requestLocationPermission();
      final grantedNow = await _locationService.isPermissionGranted();
      if (!grantedNow) {
        if (mounted) setState(() => _locating = false); // fixed: mounted check added
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission denied. Please enable it in settings.'),
            ),
          );
        }
        return;
      }
    }

    final gpsOn = await _locationService.requestEnableGps();
    if (!gpsOn) {
      if (mounted) setState(() => _locating = false); // fixed: mounted check added
      return;
    }

    try {
      final loc = Location();
      final data = await loc.getLocation();
      final lat = data.latitude;
      final lng = data.longitude;

      if (lat == null || lng == null) {
        if (mounted) setState(() => _locating = false); // fixed: mounted check added
        return;
      }

      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
            '?lat=$lat&lon=$lng&format=json',
      );
      final response = await http.get(
        url,
        headers: {'User-Agent': 'DriveOrRideApp/1.0 (student project)'},
      );

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        final address = body['address'];
        final shortName = body['name'] ??
            address?['road'] ??
            address?['suburb'] ??
            address?['city'] ??
            body['display_name'] ??
            '$lat, $lng';
        if (mounted) {
          setState(() => _fromCtrl.text = shortName);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not detect location. Please try again.')),
        );
      }
    }

    if (mounted) {
      setState(() => _locating = false);
    }
  }

  Future<void> _onCompareNow() async {
    if (_fromCtrl.text.isEmpty || _toCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both a starting point and a destination.')),
      );
      return;
    }
    setState(() => _loading = true);

    final origin = await _routingService.geocode(_fromCtrl.text);
    final destination = await _routingService.geocode(_toCtrl.text);

    setState(() => _loading = false);

    if (origin == null || destination == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not find one of those locations. Try being more specific.')),
        );
      }
      return;
    }

    if (mounted) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => CompareScreen(
        origin: origin,
        destination: destination,
        originName: _fromCtrl.text,
        destinationName: _toCtrl.text,
      )));
      _refreshRealData();
    }
  }

  void _useSavedLocation(SavedLocationModel loc) {
    _toCtrl.text = loc.address;
    _onCompareNow();
  }

  void _swapFromTo() {
    setState(() {
      final temp = _fromCtrl.text;
      _fromCtrl.text = _toCtrl.text;
      _toCtrl.text = temp;
    });
  }

  Widget _fieldRow({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String label,
    required TextEditingController ctrl,
    String? hint,
    VoidCallback? onIconTap,
    bool iconLoading = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: onIconTap,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
            child: iconLoading
                ? Padding(
              padding: const EdgeInsets.all(8),
              child: CircularProgressIndicator(strokeWidth: 2, color: iconColor),
            )
                : Icon(icon, size: 18, color: iconColor),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5),
              ),
              TextField(
                controller: ctrl,
                decoration: InputDecoration(
                  hintText: hint,
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  filled: false,
                ),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.teal),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              height: _headerHeight,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.teal, Color(0xFF025D6A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: Opacity(
                      opacity: 0.18,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(width: 30, height: 50, color: Colors.white, margin: const EdgeInsets.only(left: 16)),
                          Container(width: 22, height: 75, color: Colors.white, margin: const EdgeInsets.only(left: 6)),
                          const Spacer(),
                          Container(width: 26, height: 85, color: Colors.white),
                          Container(width: 26, height: 85, color: Colors.white, margin: const EdgeInsets.only(left: 4)),
                          const Spacer(),
                          Container(width: 24, height: 60, color: Colors.white, margin: const EdgeInsets.only(right: 16)),
                        ],
                      ),
                    ),
                  ),
                  SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Good morning! \u{1F44B}',
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Where will your journey take you today?',
                                  style: TextStyle(fontSize: 12, color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const SavedLocationsScreen()),
                            ).then((_) => _refreshRealData()),
                            child: Container(
                              width: 38, height: 38,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.location_on_outlined, color: Colors.white, size: 20),
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
          Positioned.fill(
            top: _cardTopMargin,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 16, offset: const Offset(0, 6))],
                    ),
                    child: Column(
                      children: [
                        // FROM field — tap the left icon to re-detect location
                        _fieldRow(
                          icon: Icons.my_location,
                          iconBg: AppColors.mintLight,
                          iconColor: AppColors.mint,
                          label: 'FROM',
                          ctrl: _fromCtrl,
                          hint: 'Enter starting point...',
                          onIconTap: _locating ? null : _detectMyLocation,
                          iconLoading: _locating,
                        ),

                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              const SizedBox(width: 18),
                              Container(width: 1.5, height: 18, color: Colors.grey.shade200),
                              Expanded(child: Container(height: 1, color: Colors.grey.shade100, margin: const EdgeInsets.only(left: 18))),
                              GestureDetector(
                                onTap: _swapFromTo,
                                child: Container(
                                  width: 32, height: 32,
                                  margin: const EdgeInsets.only(left: 8),
                                  decoration: BoxDecoration(color: AppColors.mintLight, shape: BoxShape.circle),
                                  child: const Icon(Icons.swap_vert, size: 18, color: AppColors.mint),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // TO field — unchanged
                        _fieldRow(
                          icon: Icons.location_on_outlined,
                          iconBg: AppColors.amberLight,
                          iconColor: AppColors.amber,
                          label: 'TO',
                          ctrl: _toCtrl,
                          hint: 'Search destination...',
                        ),

                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _loading ? null : _onCompareNow,
                            icon: _loading
                                ? const SizedBox(
                              height: 16, width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                                : const Icon(Icons.bar_chart, size: 18),
                            label: Text(_loading ? 'Searching...' : 'Compare Now'),
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (_savedLocations.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text('Quick Destinations', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.teal)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _savedLocations.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (ctx, i) {
                          final loc = _savedLocations[i];
                          return ActionChip(
                            avatar: const Icon(Icons.place, size: 16, color: AppColors.mint),
                            label: Text(loc.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            backgroundColor: Colors.white,
                            onPressed: () => _useSavedLocation(loc),
                          );
                        },
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.mintLight, Colors.teal.shade50],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(color: AppColors.mint, borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.account_balance_wallet, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Your savings so far', style: TextStyle(fontSize: 11, color: Color(0xFF026B53), fontWeight: FontWeight.w600)),
                            Text('RM ${_totalSaved.toStringAsFixed(2)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.teal)),
                          ],
                        ),
                        const Spacer(),
                        const Icon(Icons.emoji_events_outlined, color: AppColors.mint, size: 26),
                      ],
                    ),
                  ),

                  if (_activeGoal != null) ...[
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SavingsGoalsScreen(showBackButton: true)),
                      ).then((_) => _refreshRealData()),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 32, height: 32,
                                  decoration: BoxDecoration(color: AppColors.mintLight, borderRadius: BorderRadius.circular(8)),
                                  child: Icon(_goalIcon(_activeGoal!.name), color: AppColors.mint, size: 18),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _activeGoal!.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1A1A2E)),
                                  ),
                                ),
                                Text(
                                  '${_activeGoal!.progressPercent.toStringAsFixed(0)}%',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.mint),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: _activeGoal!.progressPercent / 100,
                                backgroundColor: Colors.grey.shade200,
                                color: AppColors.mint,
                                minHeight: 6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Recent Trips', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.teal)),
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const TripHistoryScreen()),
                        ).then((_) => _refreshRealData()),
                        child: const Text('See all', style: TextStyle(fontSize: 12, color: AppColors.mint)),
                      ),
                    ],
                  ),

                  if (_recentTrips.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200, width: 1.5),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(color: AppColors.mintLight, shape: BoxShape.circle),
                            child: const Icon(Icons.route_outlined, color: AppColors.mint, size: 22),
                          ),
                          const SizedBox(height: 10),
                          const Text('No trips yet', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.teal)),
                          const SizedBox(height: 2),
                          const Text('Try comparing a route above to get started!', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    )
                  else
                    ..._recentTrips.map((trip) => GestureDetector(
                      onTap: () => showTripDetailDialog(context, trip),
                      child: Container(
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
                              width: 34, height: 34,
                              decoration: BoxDecoration(
                                color: trip.mode == 'transit' ? AppColors.mintLight : AppColors.amberLight,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                trip.mode == 'transit' ? Icons.directions_bus : Icons.directions_car,
                                size: 16,
                                color: trip.mode == 'transit' ? AppColors.mint : AppColors.amber,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(trip.route, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis),
                                  Text(trip.createdOn.substring(0, 10), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                ],
                              ),
                            ),
                            if (trip.savedVsAlternative > 0)
                              Text(
                                '+RM ${trip.savedVsAlternative.toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.mint),
                              ),
                            const SizedBox(width: 4),
                            Icon(Icons.chevron_right, size: 16, color: Colors.grey.shade400),
                          ],
                        ),
                      ),
                    )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}