import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../services/routing_service.dart';
import '../services/fuel_price_service.dart';
import '../services/fuel_preference_service.dart';
import '../main.dart' show gtfsService;
import '../theme.dart';
import 'route_details_screen.dart';
import 'trip_history_screen.dart';

class CompareScreen extends StatefulWidget {
  final LatLng origin;
  final LatLng destination;
  final String originName;
  final String destinationName;
  const CompareScreen({super.key, required this.origin, required this.destination, required this.originName, required this.destinationName});

  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
  final _routingService = RoutingService();
  final _fuelService = FuelPriceService();
  final _fuelPreference = FuelPreferenceService();
  String _fuelType = 'ron95';

  bool _loading = true;
  double _driveDistanceKm = 0;
  double _driveDurationMin = 0;
  double _fuelCost = 0;
  double _tollCost = 0;
  double get _driveCost => _fuelCost + _tollCost;
  double _transitFareEstimate = 0;
  double _transitDurationMin = 0;
  String? _originStationName;
  String? _destStationName;

  double _fuelPricePerLitre = 0;

  static const _litresPerKm = 0.07;
  static const _tollRatePerKm = 0.12;

  @override
  void initState() {
    super.initState();
    _calculate();
  }

  Future<void> _calculate() async {
    final fuelType = await _fuelPreference.getFuelType();
    final route = await _routingService.getDrivingRoute(widget.origin, widget.destination);
    final fuelPrice = await _fuelService.getLatestPrice(fuelType);
    final originStation = gtfsService.findNearestStation(widget.origin);
    final destStation = gtfsService.findNearestStation(widget.destination);
    final journey = (originStation != null && destStation != null) ? gtfsService.findJourney(originStation, destStation) : null;

    setState(() {
      _driveDistanceKm = route?.distanceKm ?? 0;
      _driveDurationMin = route?.durationMinutes ?? 0;
      _fuelPricePerLitre = fuelPrice;
      _fuelType = fuelType;
      _fuelCost = _driveDistanceKm * _litresPerKm * fuelPrice;
      _tollCost = _driveDistanceKm * _tollRatePerKm;
      _originStationName = originStation?.name;
      _destStationName = destStation?.name;
      if (journey != null) {
        _transitDurationMin = journey.totalDurationMinutes.toDouble();
        const baseFare = 1.20, ratePerKm = 0.18, maxFare = 6.40;
        _transitFareEstimate = (baseFare + ratePerKm * journey.totalDistanceKm).clamp(baseFare, maxFare);
      }
      _loading = false;
    });
  }

  double get _savings => (_driveCost - _transitFareEstimate).clamp(0, double.infinity).toDouble();
  bool get _transitIsCheaper => _transitFareEstimate > 0 && _transitFareEstimate < _driveCost;

  void _goToDetails() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => RouteDetailsScreen(
      origin: widget.origin,
      destination: widget.destination,
      originName: widget.originName,
      destinationName: widget.destinationName,
    )));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Compare Results'),
        actions: [IconButton(icon: const Icon(Icons.history), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TripHistoryScreen())))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
            child: Row(
              children: [
                const Icon(Icons.circle, size: 10, color: AppColors.teal),
                const SizedBox(width: 8),
                Expanded(child: Text(widget.originName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis)),
                Icon(Icons.arrow_forward, size: 14, color: Colors.grey.shade400),
                const SizedBox(width: 8),
                const Icon(Icons.location_on, size: 14, color: AppColors.amber),
                const SizedBox(width: 4),
                Expanded(child: Text(widget.destinationName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(width: 34, height: 34, decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.directions_car, color: AppColors.amber, size: 18)),
                    const SizedBox(width: 10),
                    const Text('Drive', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.teal)),
                    const Spacer(),
                    if (!_transitIsCheaper)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: AppColors.amberLight, borderRadius: BorderRadius.circular(20)),
                        child: const Text('Typically faster', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.amber)),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _bigStat('Time', '${_driveDurationMin.toStringAsFixed(0)} min')),
                    const SizedBox(width: 8),
                    Expanded(child: _bigStat('Est. total cost', 'RM ${_driveCost.toStringAsFixed(2)}', valueColor: AppColors.amber)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _miniStat(Icons.local_gas_station, 'Fuel', 'RM ${_fuelCost.toStringAsFixed(2)}')),
                    const SizedBox(width: 8),
                    Expanded(child: _miniStat(Icons.toll, 'Toll', 'RM ${_tollCost.toStringAsFixed(2)}')),
                  ],
                ),
                const SizedBox(height: 8),

                Row(
                  children: [
                    Icon(Icons.bolt, size: 12, color: Colors.grey.shade400),
                    const SizedBox(width: 4),
                    Text(
                      '${_fuelType.toUpperCase()}: RM ${_fuelPricePerLitre.toStringAsFixed(2)}/L (live, data.gov.my)',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(width: 34, height: 34, decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.directions_bus, color: AppColors.mint, size: 18)),
                    const SizedBox(width: 10),
                    const Text('Public Transport', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.teal)),
                    const Spacer(),
                    if (_transitIsCheaper)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: AppColors.mint, borderRadius: BorderRadius.circular(20)),
                        child: const Text('CHEAPER', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_originStationName != null) ...[
                  Row(children: [
                    Expanded(child: _bigStat('Time', '${_transitDurationMin.toStringAsFixed(0)} min')),
                    const SizedBox(width: 8),
                    Expanded(child: _bigStat('Est. fare', 'RM ${_transitFareEstimate.toStringAsFixed(2)}', valueColor: AppColors.mint)),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: _miniStat(Icons.trip_origin, 'Board', _originStationName ?? '-')),
                    const SizedBox(width: 8),
                    Expanded(child: _miniStat(Icons.flag, 'Alight', _destStationName ?? '-')),
                  ]),
                ] else
                  const Text('No nearby transit station found.', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),

          if (_savings > 0) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.amberLight, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFFDE68A))),
              child: Row(
                children: [
                  Container(width: 44, height: 44, decoration: const BoxDecoration(color: AppColors.amber, shape: BoxShape.circle), child: const Icon(Icons.savings, color: Colors.white)),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('You save by taking public transport', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      Text('RM ${_savings.toStringAsFixed(2)} today', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.teal)),
                    ],
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _goToDetails,
              label: const Text('See Full Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bigStat(String label, String value, {Color valueColor = AppColors.teal}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19, color: valueColor)),
        ],
      ),
    );
  }

  Widget _miniStat(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4)]),
      child: Row(
        children: [
          Icon(icon, size: 13, color: Colors.grey.shade400),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey)),
                Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}