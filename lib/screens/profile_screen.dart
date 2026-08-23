import 'package:flutter/material.dart';
import 'saved_locations_screen.dart';
import '../theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Widget _sectionCard(String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5)),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _row(BuildContext context, {required IconData icon, required String label, String? sub, VoidCallback? onTap, Widget? trailing}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.teal)),
                  if (sub != null) Text(sub, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
            trailing ?? Icon(Icons.chevron_right, color: Colors.grey.shade300),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.teal, Color(0xFF025D6A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              ),
              child: Row(
                children: [
                  const CircleAvatar(radius: 30, backgroundColor: AppColors.mint, child: Text('AH', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Amir Hadziq', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.white)),
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                        child: const Text('Eco Commuter', style: TextStyle(color: AppColors.mint, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _sectionCard('SAVED LOCATIONS', [
                  _row(context, icon: Icons.location_on_outlined, label: 'Manage Saved Locations', sub: 'Home, Work, and more',
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedLocationsScreen()))),
                ]),
                _sectionCard('NOTIFICATIONS', [
                  _row(context, icon: Icons.notifications_none, label: 'Daily Commute Reminder', sub: '7:30 AM on weekdays',
                      trailing: Switch(value: true, activeColor: AppColors.mint, onChanged: (_) {})),
                ]),
                _sectionCard('ABOUT', [
                  _row(context, icon: Icons.info_outline, label: 'About DriveOrRide', sub: 'v1.0.0 · Built for Malaysia', onTap: () {}),
                  _row(context, icon: Icons.description_outlined, label: 'Terms & Conditions', onTap: () {}),
                  _row(context, icon: Icons.privacy_tip_outlined, label: 'Privacy Policy', onTap: () {}),
                ]),
                const SizedBox(height: 8),
                const Center(child: Text('Powered by open mobility data · SDG Goal 9 🇲🇾', style: TextStyle(fontSize: 10, color: Colors.grey))),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
