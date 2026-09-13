import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme.dart';

/// Shows full details for a single trip — reused from both Home's
/// recent trip preview and the full Trip History list, so both
/// places behave consistently. The genuinely new piece of
/// information this adds beyond the compact row is the EXACT time
/// (the row only shows the date), since TripLogModel doesn't carry
/// much else beyond what's already visible.
void showTripDetailDialog(BuildContext context, TripLogModel trip) {
  final date = DateTime.tryParse(trip.createdOn);
  String formattedDateTime = trip.createdOn;
  if (date != null) {
    final period = date.hour >= 12 ? 'PM' : 'AM';
    int hour12 = date.hour % 12;
    if (hour12 == 0) hour12 = 12;
    final minuteStr = date.minute.toString().padLeft(2, '0');
    formattedDateTime = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} · $hour12:$minuteStr $period';
  }

  showDialog(
    context: context,
    builder: (dialogContext) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: trip.mode == 'transit' ? AppColors.mintLight : AppColors.amberLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  trip.mode == 'transit' ? Icons.directions_bus : Icons.directions_car,
                  color: trip.mode == 'transit' ? AppColors.mint : AppColors.amber,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(trip.route, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.teal))),
            ]),
            const SizedBox(height: 16),
            _row('Mode', trip.mode == 'transit' ? 'Public Transport' : 'Drive'),
            _row('Date & time', formattedDateTime),
            _row('Distance', '${trip.distanceKm.toStringAsFixed(1)} km'),
            _row('Cost', 'RM ${trip.cost.toStringAsFixed(2)}'),
            if (trip.savedVsAlternative > 0)
              _row('Saved vs alternative', 'RM ${trip.savedVsAlternative.toStringAsFixed(2)}', valueColor: AppColors.mint),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close')),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _row(String label, String value, {Color valueColor = Colors.black87}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        SizedBox(width: 130, child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600))),
        Expanded(child: Text(value, style: TextStyle(fontSize: 12, color: valueColor, fontWeight: FontWeight.w600))),
      ],
    ),
  );
}