import 'package:flutter/material.dart';
import '../theme.dart';
import 'main_shell.dart';

/// Matches the "Trip Added!" step in the reference flow — a distinct
/// confirmation that the trip was saved, with quick links to view
/// savings or return home, separate from the Trip Summary screen.
class TripAddedScreen extends StatelessWidget {
  final String route;
  final double savedVsAlternative;
  const TripAddedScreen({super.key, required this.route, required this.savedVsAlternative});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Trip Added!'), automaticallyImplyLeading: false),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Container(
              width: 90, height: 90,
              decoration: BoxDecoration(color: AppColors.mintLight, shape: BoxShape.circle),
              child: const Icon(Icons.event_available, color: AppColors.mint, size: 46),
            ),
            const SizedBox(height: 20),
            const Text('Your trip has been saved.', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.teal)),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
              child: Row(
                children: [
                  const Icon(Icons.route, color: AppColors.mint),
                  const SizedBox(width: 10),
                  Expanded(child: Text(route, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (savedVsAlternative > 0)
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
                          Text('You saved RM ${savedVsAlternative.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          const Text('Great job! Keep it up.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const MainShell(initialTab: 2)), (route) => false),
                child: const Text('View My Savings'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const MainShell()), (route) => false),
                child: const Text('Back to Home'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
