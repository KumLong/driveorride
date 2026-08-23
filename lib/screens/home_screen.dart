import 'package:flutter/material.dart';
import '../services/routing_service.dart';
import '../theme.dart';
import 'compare_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _fromCtrl = TextEditingController(text: 'Kuala Lumpur Sentral');
  final _toCtrl = TextEditingController();
  final _routingService = RoutingService();
  bool _loading = false;

  static const double _headerHeight = 170;
  static const double _cardTopMargin = 130; // < headerHeight, creates the overlap

  Future<void> _onCompareNow() async {
    if (_toCtrl.text.isEmpty) return;
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
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => CompareScreen(origin: origin, destination: destination)),
      );
    }
  }

  Widget _fieldRow({required IconData icon, required Color iconBg, required Color iconColor, required String label, required TextEditingController ctrl, String? hint}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5)),
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
    // Stack layout: header paints first (behind), scrollable foreground
    // content paints on top of it — this avoids the hit-test/overflow
    // issues that came from the previous Transform.translate approach.
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          // ── Fixed decorative header, sits behind everything ──
          // (wrapped in Positioned so this fixed-height child doesn't
          // force the whole Stack to shrink to just its own height)
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
            height: _headerHeight,
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.teal, Color(0xFF025D6A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
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
                              Text('Good morning! \u{1F44B}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                              SizedBox(height: 4),
                              Text('Where will your journey take you today?', style: TextStyle(fontSize: 12, color: Colors.white70)),
                            ],
                          ),
                        ),
                        Container(
                          width: 38, height: 38,
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
                          child: const Icon(Icons.notifications_none, color: Colors.white, size: 20),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          ),

          // ── Scrollable foreground content, starts partway over the header ──
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
                        _fieldRow(icon: Icons.my_location, iconBg: AppColors.mintLight, iconColor: AppColors.mint, label: 'FROM', ctrl: _fromCtrl),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(children: [
                            const SizedBox(width: 18),
                            Container(width: 1.5, height: 18, color: Colors.grey.shade200),
                            Expanded(child: Container(height: 1, color: Colors.grey.shade100, margin: const EdgeInsets.only(left: 18))),
                          ]),
                        ),
                        _fieldRow(icon: Icons.location_on_outlined, iconBg: AppColors.amberLight, iconColor: AppColors.amber, label: 'TO', ctrl: _toCtrl, hint: 'Search destination...'),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _loading ? null : _onCompareNow,
                            icon: _loading
                                ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.bar_chart, size: 18),
                            label: Text(_loading ? 'Searching...' : 'Compare Now'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [AppColors.mintLight, Colors.teal.shade50], begin: Alignment.topLeft, end: Alignment.bottomRight),
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
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Your savings so far', style: TextStyle(fontSize: 11, color: Color(0xFF026B53), fontWeight: FontWeight.w600)),
                            Text('RM 0.00', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.teal)),
                          ],
                        ),
                        const Spacer(),
                        const Icon(Icons.emoji_events_outlined, color: AppColors.mint, size: 26),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
