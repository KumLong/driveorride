import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../services/gtfs_service.dart';
import '../theme.dart';
import 'trip_progress_drive_screen.dart';
import 'trip_progress_transit_screen.dart';

/// Matches the reference flow's step 4 ("Choose Option") — a dedicated
/// screen letting the user pick between Drive and Public Transport one
/// more time, seeing both real calculated costs side by side, before
/// the trip actually starts.
class ConfirmChoiceScreen extends StatefulWidget {
  final LatLng destination;
  final String originName;
  final String destinationName;
  final List<LatLng> driveRoutePoints;
  final double driveDistanceKm;
  final double driveDurationMin;
  final double driveCost;
  final List<String> driveSteps;
  final MultiLegJourney? journey;
  final double transitFare;

  const ConfirmChoiceScreen({
    super.key,
    required this.destination,
    required this.originName,
    required this.destinationName,
    required this.driveRoutePoints,
    required this.driveDistanceKm,
    required this.driveDurationMin,
    required this.driveCost,
    required this.driveSteps,
    required this.journey,
    required this.transitFare,
  });

  @override
  State<ConfirmChoiceScreen> createState() => _ConfirmChoiceScreenState();
}

class _ConfirmChoiceScreenState extends State<ConfirmChoiceScreen> {
  String? _selected; // 'drive' or 'transit'

  double get _savedIfTransit => (widget.driveCost - widget.transitFare).clamp(0, double.infinity).toDouble();

  void _onContinue() {
    if (_selected == 'drive') {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => TripProgressDriveScreen(
          destination: widget.destination,
          routeName: '${widget.originName} -> ${widget.destinationName}',
          routePoints: widget.driveRoutePoints,
          distanceKm: widget.driveDistanceKm,
          durationMin: widget.driveDurationMin,
          steps: widget.driveSteps,
          cost: widget.driveCost,
          savedVsAlternative: 0,
        ),
      ));
    } else if (_selected == 'transit' && widget.journey != null) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => TripProgressTransitScreen(
          journey: widget.journey!,
          fare: widget.transitFare,
          savedVsAlternative: _savedIfTransit,
        ),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Confirm Your Choice')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('You can change this anytime.', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 16),
            _optionCard(
              value: 'drive',
              icon: Icons.directions_car,
              iconColor: AppColors.amber,
              iconBg: AppColors.amberLight,
              title: 'Drive',
              subtitle: '${widget.driveDurationMin.toStringAsFixed(0)} min • RM ${widget.driveCost.toStringAsFixed(2)}',
            ),
            const SizedBox(height: 12),
            _optionCard(
              value: 'transit',
              icon: Icons.directions_bus,
              iconColor: AppColors.mint,
              iconBg: AppColors.mintLight,
              title: 'Public Transport',
              subtitle: widget.journey != null
                  ? '${widget.journey!.totalDurationMinutes} min • RM ${widget.transitFare.toStringAsFixed(2)}'
                  : 'No route found',
              enabled: widget.journey != null,
            ),
            if (_selected == 'transit' && _savedIfTransit > 0) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.amberLight, borderRadius: BorderRadius.circular(14)),
                child: Row(
                  children: [
                    const Icon(Icons.savings, color: AppColors.amber),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('You save', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          Text('RM ${_savedIfTransit.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.teal)),
                          const Text('by taking public transport', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selected != null ? _onContinue : null,
                child: const Text('Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _optionCard({
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    bool enabled = true,
  }) {
    final selected = _selected == value;
    return GestureDetector(
      onTap: enabled ? () => setState(() => _selected = value) : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? AppColors.mint : Colors.transparent, width: 2),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
          ),
          child: Row(
            children: [
              Container(width: 44, height: 44, decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: iconColor)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.teal)),
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              Radio<String>(value: value, groupValue: _selected, onChanged: enabled ? (v) => setState(() => _selected = v) : null, activeColor: AppColors.mint),
            ],
          ),
        ),
      ),
    );
  }
}