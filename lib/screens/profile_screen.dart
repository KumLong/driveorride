import 'package:flutter/material.dart';
import 'saved_locations_screen.dart';
import 'splash_screen.dart';
import 'login_screen.dart';
import 'info_screen.dart';
import '../services/auth_service.dart';
import '../models/models.dart';
import '../theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _auth = AuthService();
  ProfileModel? _profile;
  bool _loading = true;
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _auth.fetchCurrentProfile();
      if (mounted) setState(() { _profile = profile; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editProfile() async {
    final nameCtrl = TextEditingController(text: _profile?.fullName ?? '');
    final phoneCtrl = TextEditingController(text: _profile?.phone ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full Name')),
            const SizedBox(height: 12),
            TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone'), keyboardType: TextInputType.phone),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Save')),
        ],
      ),
    );

    if (saved != true) return;
    if (nameCtrl.text.trim().isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name cannot be empty.')));
      return;
    }

    try {
      await _auth.updateProfile(fullName: nameCtrl.text.trim(), phone: phoneCtrl.text.trim());
      await _loadProfile();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update profile.')));
    }
  }

  Future<void> _logout() async {
    await _auth.logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const SplashScreen()), (route) => false);
    }
  }

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
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppColors.mint,
                    child: _loading
                        ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                        : Text(_profile?.initials ?? '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _loading
                              ? 'Loading…'
                              : _auth.isLoggedIn
                              ? (_profile?.fullName ?? 'No profile found')
                              : 'Guest User',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.white),
                        ),
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                          child: Text(
                            _auth.isLoggedIn ? 'Eco Commuter' : 'Not logged in',
                            style: const TextStyle(color: AppColors.mint, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!_loading && _auth.isLoggedIn)
                    IconButton(
                      onPressed: _editProfile,
                      icon: const Icon(Icons.edit_outlined, color: Colors.white70, size: 20),
                      tooltip: 'Edit Profile',
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
                      trailing: Switch(
                        value: _notificationsEnabled,
                        activeColor: AppColors.mint,
                        onChanged: (value) {
                          setState(() => _notificationsEnabled = value);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(value ? 'Daily commute reminder turned on.' : 'Daily commute reminder turned off.')),
                          );
                        },
                      )),
                ]),
                _sectionCard('ABOUT', [
                  _row(context, icon: Icons.info_outline, label: 'About DriveOrRide', sub: 'v1.0.0 · Built for Malaysia',
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InfoScreen(title: 'About DriveOrRide', sections: AppInfoContent.about)))),
                  _row(context, icon: Icons.description_outlined, label: 'Terms & Conditions',
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InfoScreen(title: 'Terms & Conditions', sections: AppInfoContent.terms)))),
                  _row(context, icon: Icons.privacy_tip_outlined, label: 'Privacy Policy',
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InfoScreen(title: 'Privacy Policy', sections: AppInfoContent.privacy)))),
                ]),
                _sectionCard('ACCOUNT', [
                  if (_auth.isLoggedIn)
                    _row(
                      context,
                      icon: Icons.logout,
                      label: 'Log Out',
                      onTap: _logout,
                    )
                  else
                    _row(
                      context,
                      icon: Icons.login,
                      label: 'Login / Register',
                      sub: 'Sign in to save your progress',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      ).then((_) => _loadProfile()),
                    ),
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