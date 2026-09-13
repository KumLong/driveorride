import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'saved_locations_screen.dart';
import 'splash_screen.dart';
import 'login_screen.dart';
import 'info_screen.dart';
import 'trip_history_screen.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/supabase_service.dart';
import '../services/notification_service.dart';
import '../services/fuel_preference_service.dart';
import '../models/models.dart';
import '../theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _auth = AuthService();
  final _db = DatabaseService();
  final _supabase = SupabaseService();
  final _notifications = NotificationService();
  final _fuelPreference = FuelPreferenceService();
  ProfileModel? _profile;
  bool _loading = true;
  bool _notificationsEnabled = false;
  double _totalSaved = 0;
  int _tripCount = 0;
  String _fuelType = 'ron95';

  File? _profileImage;
  final _picker = ImagePicker();

  String get _ownerId => _auth.currentUser?.id ?? 'guest';

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadProfileImage();
    _syncNotificationSwitchWithRealState();
    _loadStats();
    _loadFuelType();
  }

  Future<void> _loadStats() async {
    final trips = await _db.getTrips();
    final total = await _db.getTotalSaved();
    if (mounted) setState(() { _tripCount = trips.length; _totalSaved = total; });
  }

  Future<void> _loadFuelType() async {
    final type = await _fuelPreference.getFuelType();
    if (mounted) setState(() => _fuelType = type);
  }

  void _showFuelTypeDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(color: AppColors.mintLight, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.local_gas_station, color: AppColors.mint),
                  ),
                  const SizedBox(width: 12),
                  const Text('Fuel Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.teal)),
                ]),
                const SizedBox(height: 8),
                const Text(
                  "Choose the fuel your car actually uses — this is used to fetch the correct live price for your drive cost calculations.",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                RadioListTile<String>(
                  value: 'ron95',
                  groupValue: _fuelType,
                  activeColor: AppColors.mint,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('RON95', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Most Malaysian vehicles', style: TextStyle(fontSize: 11)),
                  onChanged: (value) => setDialogState(() => _fuelType = value!),
                ),
                RadioListTile<String>(
                  value: 'ron97',
                  groupValue: _fuelType,
                  activeColor: AppColors.mint,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('RON97', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Higher-performance/turbo vehicles', style: TextStyle(fontSize: 11)),
                  onChanged: (value) => setDialogState(() => _fuelType = value!),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      await _fuelPreference.setFuelType(_fuelType);
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                      if (mounted) setState(() {});
                    },
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _syncNotificationSwitchWithRealState() async {
    final actuallyScheduled = await _notifications.isReminderScheduled(_ownerId);
    if (mounted) setState(() => _notificationsEnabled = actuallyScheduled);
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _auth.fetchCurrentProfile();
      if (mounted) setState(() { _profile = profile; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadProfileImage() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final imagePath = '${appDocDir.path}/profile_$_ownerId.png';
    final file = File(imagePath);
    if (await file.exists()) {
      if (mounted) setState(() => _profileImage = file);
    } else {
      if (mounted) setState(() => _profileImage = null);
    }
  }

  Future<void> _changeProfilePicture() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (pickedFile == null) return;
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final newImagePath = '${appDocDir.path}/profile_$_ownerId.png';
      final savedImage = await File(pickedFile.path).copy(newImagePath);
      if (mounted) setState(() => _profileImage = savedImage);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile picture updated.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save profile picture: $e')));
    }
  }

  Widget _styledEditField({required TextEditingController ctrl, required String label, required IconData icon, TextInputType? keyboardType, String? errorText, ValueChanged<String>? onChanged}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: errorText != null ? Colors.redAccent : AppColors.mint, size: 20),
        filled: true,
        fillColor: AppColors.bg,
        errorText: errorText,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      ),
    );
  }

  String? _validateName(String value) {
    final name = value.trim();
    if (name.isEmpty) return null;
    if (!RegExp(r"^[a-zA-Z\s\-']+$").hasMatch(name)) return 'Name can only contain letters, spaces, hyphens, and apostrophes.';
    if (name.length < 2) return 'Please enter your full name.';
    return null;
  }

  String? _validatePhone(String value) {
    final phone = value.trim();
    if (phone.isEmpty) return null;
    if (!RegExp(r'^[0-9]+$').hasMatch(phone)) return 'Numbers only, no letters or symbols.';
    if (phone.length < 9 || phone.length > 11) return 'Enter a valid phone number (9-11 digits).';
    return null;
  }

  Future<void> _editProfile() async {
    final nameCtrl = TextEditingController(text: _profile?.fullName ?? '');
    final phoneCtrl = TextEditingController(text: _profile?.phone ?? '');
    String? nameError;
    String? phoneError;
    bool canSave() => nameCtrl.text.trim().isNotEmpty && _validateName(nameCtrl.text) == null && _validatePhone(phoneCtrl.text) == null;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(color: AppColors.mintLight, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.person_outline, color: AppColors.mint),
                  ),
                  const SizedBox(width: 12),
                  const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.teal)),
                ]),
                const SizedBox(height: 20),
                _styledEditField(ctrl: nameCtrl, label: 'Full Name', icon: Icons.badge_outlined, errorText: nameError,
                    onChanged: (v) => setDialogState(() => nameError = _validateName(v))),
                const SizedBox(height: 12),
                _styledEditField(ctrl: phoneCtrl, label: 'Phone', icon: Icons.phone_outlined, keyboardType: TextInputType.phone, errorText: phoneError,
                    onChanged: (v) => setDialogState(() => phoneError = _validatePhone(v))),
                const SizedBox(height: 24),
                Row(children: [
                  Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel'))),
                  const SizedBox(width: 12),
                  Expanded(child: ElevatedButton(onPressed: canSave() ? () => Navigator.pop(dialogContext, true) : null, child: const Text('Save'))),
                ]),
              ],
            ),
          ),
        ),
      ),
    );

    if (saved != true) return;
    try {
      await _auth.updateProfile(fullName: nameCtrl.text.trim(), phone: phoneCtrl.text.trim());
      await _loadProfile();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update profile.')));
    }
  }

  Future<void> _onToggleNotifications(bool value) async {
    try {
      if (value) {
        final granted = await _notifications.requestPermission();
        if (!granted) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Notification permission denied. Please enable it in your phone\'s settings.')));
          return;
        }
        await _notifications.scheduleWeekdayReminder(_ownerId, hour: 7, minute: 30);
      } else {
        await _notifications.cancelWeekdayReminder(_ownerId);
      }
      setState(() => _notificationsEnabled = value);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(value ? 'Daily reminder set for 7:30 AM on weekdays.' : 'Daily reminder turned off.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not set up the reminder: $e')));
    }
  }

  Future<void> _logout() async {
    await _auth.logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const SplashScreen()), (route) => false);
    }
  }

  void _confirmDeleteAccount() {
    bool deleting = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
                  child: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 32),
                ),
                const SizedBox(height: 16),
                const Text('Delete your account?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.teal)),
                const SizedBox(height: 8),
                const Text(
                  'This permanently deletes all your trips, saved locations, savings goals, and profile information — both on this device and in the cloud. This cannot be undone.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(child: OutlinedButton(onPressed: deleting ? null : () => Navigator.pop(dialogContext), child: const Text('Cancel'))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                      onPressed: deleting ? null : () async {
                        setDialogState(() => deleting = true);
                        await _performAccountDeletion(dialogContext);
                      },
                      child: deleting
                          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Delete Account'),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _performAccountDeletion(BuildContext dialogContext) async {
    try {
      await _db.deleteAllLocalDataForCurrentUser();
      try { await _supabase.deleteAllTrips(); } catch (e) { print(e); }
      try { await _supabase.deleteAllWalletTransactions(); } catch (e) { print(e); }
      try {
        if (_profileImage != null && await _profileImage!.exists()) await _profileImage!.delete();
      } catch (e) { print(e); }
      try { await _auth.deleteProfile(); } catch (e) { print(e); }
      await _auth.logout();
      if (mounted) {
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const SplashScreen()), (route) => false);
      }
    } catch (e) {
      if (dialogContext.mounted) Navigator.pop(dialogContext);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Something went wrong: $e')));
    }
  }

  Widget _menuRow({required IconData icon, required String label, String? sub, VoidCallback? onTap, Widget? trailing, Color? iconBgColor, Color? iconColor, Color? textColor}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: iconBgColor ?? AppColors.mintLight, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: iconColor ?? AppColors.mint),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor ?? const Color(0xFF1A1A2E))),
                if (sub != null) ...[
                  const SizedBox(height: 2),
                  Text(sub, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ],
            ),
          ),
          trailing ?? Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
        ]),
      ),
    );
  }

  Widget _divider() => Divider(height: 1, indent: 66, color: Colors.grey.shade100);

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = _auth.isLoggedIn;
    final name = _loading ? 'Loading…' : (isLoggedIn ? (_profile?.fullName ?? 'User') : 'Guest User');
    final email = isLoggedIn ? (_profile?.email ?? '') : 'Not logged in';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: CustomScrollView(
        slivers: [

          // ── Header with KL cityscape background ──────────────────
          SliverToBoxAdapter(
            child: Stack(
              children: [
                // KL cityscape image
                Positioned.fill(
                  child: Image.asset(
                    'assets/icon/homescreen.png',
                    fit: BoxFit.cover,
                  ),
                ),
                // Teal overlay for readability
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.mint.withOpacity(0.78),
                          const Color(0xFF025D6A).withOpacity(0.78),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ),
                // Content on top
                Container(
                  padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 24, 20, 28),
                  child: Row(
                    children: [
                      // Avatar with camera button
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: AppColors.teal,
                            backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
                            child: _loading
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : (_profileImage == null
                                ? Text(_profile?.initials ?? '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22))
                                : null),
                          ),
                          if (!_loading && isLoggedIn)
                            Positioned(
                              bottom: 0, right: 0,
                              child: GestureDetector(
                                onTap: _changeProfilePicture,
                                child: Container(
                                  width: 24, height: 24,
                                  decoration: BoxDecoration(
                                    color: AppColors.amber, shape: BoxShape.circle,
                                    border: Border.all(color: AppColors.teal, width: 2),
                                  ),
                                  child: const Icon(Icons.camera_alt, size: 12, color: Colors.white),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text(email, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13)),
                            const SizedBox(height: 10),
                            if (!_loading && isLoggedIn)
                              GestureDetector(
                                onTap: _editProfile,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.white38),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.edit_outlined, color: Colors.white, size: 13),
                                      SizedBox(width: 4),
                                      Text('Edit', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // ── Stats Card ──────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(children: [
                            Text('$_tripCount', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.mint)),
                            const SizedBox(height: 2),
                            const Text('Trips Taken', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black)),
                          ]),
                        ),
                        Container(width: 1, height: 40, color: Colors.grey.shade200),
                        Expanded(
                          child: Column(children: [
                            Text('RM ${_totalSaved.toStringAsFixed(2)}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.mint)),
                            const SizedBox(height: 2),
                            const Text('Total Savings', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black)),
                          ]),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Menu Card ──────────────────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    child: Column(
                      children: [
                        _menuRow(icon: Icons.history_outlined, label: 'My Trips',
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TripHistoryScreen())).then((_) => _loadStats())),
                        _divider(),
                        _menuRow(icon: Icons.bookmark_outline, label: 'Saved Locations', sub: 'Home, Work, and more',
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedLocationsScreen()))),
                        _divider(),
                        _menuRow(
                          icon: Icons.notifications_outlined,
                          label: 'Notifications',
                          sub: '7:30 AM on weekdays',
                          trailing: Transform.scale(scale: 0.8, child: Switch(value: _notificationsEnabled, activeColor: AppColors.mint, onChanged: _onToggleNotifications)),
                        ),
                        _divider(),
                        _menuRow(icon: Icons.local_gas_station_outlined, label: 'Fuel Type', sub: _fuelType.toUpperCase(), onTap: _showFuelTypeDialog),
                        _divider(),
                        _menuRow(icon: Icons.info_outline, label: 'About DriveOrRide', sub: 'v1.0.0 · Built for Malaysia',
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InfoScreen(title: 'About DriveOrRide', sections: AppInfoContent.about)))),
                        _divider(),
                        _menuRow(icon: Icons.description_outlined, label: 'Terms & Conditions',
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InfoScreen(title: 'Terms & Conditions', sections: AppInfoContent.terms)))),
                        _divider(),
                        _menuRow(icon: Icons.privacy_tip_outlined, label: 'Privacy Policy',
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InfoScreen(title: 'Privacy Policy', sections: AppInfoContent.privacy)))),
                        _divider(),
                        _menuRow(icon: Icons.help_outline, label: 'Help & Support',
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InfoScreen(title: 'About DriveOrRide', sections: AppInfoContent.about)))),
                        if (isLoggedIn) ...[
                          _divider(),
                          _menuRow(
                            icon: Icons.delete_forever_outlined,
                            label: 'Delete Account',
                            iconBgColor: Colors.red.shade50,
                            iconColor: Colors.redAccent,
                            textColor: Colors.redAccent,
                            onTap: _confirmDeleteAccount,
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Log Out / Login ────────────────────────────────
                  if (isLoggedIn)
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton(
                        onPressed: _logout,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.redAccent),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Log Out', style: TextStyle(color: Colors.redAccent, fontSize: 15, fontWeight: FontWeight.bold)),
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()))
                            .then((_) { _loadProfile(); _loadProfileImage(); _syncNotificationSwitchWithRealState(); }),
                        icon: const Icon(Icons.login),
                        label: const Text('Login / Register'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.mint,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),
                  const Text('Powered by open mobility data · SDG Goal 9 🇲🇾', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}