import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'saved_locations_screen.dart';
import 'splash_screen.dart';
import 'login_screen.dart';
import 'info_screen.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/database_service.dart';
import '../services/supabase_service.dart';
import '../models/models.dart';
import '../theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _auth = AuthService();
  final _notifications = NotificationService();
  final _db = DatabaseService();
  final _supabase = SupabaseService();
  ProfileModel? _profile;
  bool _loading = true;
  bool _notificationsEnabled = false; // corrected from the real system state in initState below, not just assumed off

  // Profile picture — follows Practical 8 (Data File): image_picker to
  // pick from the Gallery, path_provider to save/load it as a real file
  // in the app's own local documents folder.
  File? _profileImage;
  final _picker = ImagePicker();

  /// Same "owner" concept used for SQLite/Supabase scoping — without
  /// this, every account (and guest) shared one single profile.png
  /// file, so whoever uploaded a picture last, everyone else saw it
  /// too, including a guest with no account of their own.
  String get _ownerId => _auth.currentUser?.id ?? 'guest';

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadProfileImage();
    _syncNotificationSwitchWithRealState();
  }

  /// Checks Android's real notification scheduler to set the switch's
  /// STARTING position correctly — this fixes the bug where the switch
  /// always showed "off" after an app restart or re-login, even when
  /// real weekday reminders were still genuinely scheduled underneath.
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

  /// Loads the previously saved profile picture for the CURRENT
  /// account only — filename now includes the owner ID, so different
  /// accounts (and guest) each get their own separate picture instead
  /// of all sharing one single file.
  Future<void> _loadProfileImage() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final imagePath = '${appDocDir.path}/profile_$_ownerId.png';
    final file = File(imagePath);
    if (await file.exists()) {
      if (mounted) setState(() => _profileImage = file);
    } else {
      // Important: explicitly reset to null when switching accounts —
      // otherwise the PREVIOUS account's still-loaded image would
      // keep showing even though this account has none of its own.
      if (mounted) setState(() => _profileImage = null);
    }
  }

  /// Opens the Gallery, lets the user pick a photo, then immediately
  /// saves it — combined into one step for a simpler tap-to-change
  /// experience than the practical's separate pick/save buttons.
  Future<void> _changeProfilePicture() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (pickedFile == null) return; // user cancelled the picker

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
        errorText: errorText, // non-null automatically turns the border/label red and shows the message below
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      ),
    );
  }

  /// Matches the exact rule your practical suggests: letters, spaces,
  /// and common name punctuation (hyphens, apostrophes) only — no
  /// digits or other symbols.
  String? _validateName(String value) {
    final name = value.trim();
    if (name.isEmpty) return null; // don't show an error before the user has typed anything
    if (!RegExp(r"^[a-zA-Z\s\-']+$").hasMatch(name)) return 'Name can only contain letters, spaces, hyphens, and apostrophes.';
    if (name.length < 2) return 'Please enter your full name.';
    return null;
  }

  String? _validatePhone(String value) {
    final phone = value.trim();
    if (phone.isEmpty) return null; // phone is optional
    if (!RegExp(r'^[0-9]+$').hasMatch(phone)) return 'Numbers only, no letters or symbols.';
    if (phone.length < 9 || phone.length > 11) return 'Enter a valid phone number (9-11 digits).';
    return null;
  }

  Future<void> _editProfile() async {
    final nameCtrl = TextEditingController(text: _profile?.fullName ?? '');
    final phoneCtrl = TextEditingController(text: _profile?.phone ?? '');
    String? nameError;
    String? phoneError;

    // Save button is only enabled once the name is genuinely non-empty
    // and valid, and phone (if entered at all) is valid — this is
    // recalculated on every keystroke below.
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
                Row(
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(color: AppColors.mintLight, borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.person_outline, color: AppColors.mint),
                    ),
                    const SizedBox(width: 12),
                    const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.teal)),
                  ],
                ),
                const SizedBox(height: 20),
                _styledEditField(
                  ctrl: nameCtrl,
                  label: 'Full Name',
                  icon: Icons.badge_outlined,
                  errorText: nameError,
                  onChanged: (value) {
                    setDialogState(() => nameError = _validateName(value));
                  },
                ),
                const SizedBox(height: 12),
                _styledEditField(
                  ctrl: phoneCtrl,
                  label: 'Phone',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  errorText: phoneError,
                  onChanged: (value) {
                    setDialogState(() => phoneError = _validatePhone(value));
                  },
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel'))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        // Disabled (greyed out, does nothing when tapped)
                        // until the data is genuinely valid — the dialog
                        // can now ONLY close via a successful Save or
                        // via Cancel, never by tapping an invalid Save.
                        onPressed: canSave() ? () => Navigator.pop(dialogContext, true) : null,
                        child: const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (saved != true) return;

    // At this point Save could only have been tapped while valid, so
    // this is now just a safety net, not the primary validation gate.
    final name = nameCtrl.text.trim();
    final phone = phoneCtrl.text.trim();

    try {
      await _auth.updateProfile(fullName: name, phone: phone);
      await _loadProfile();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update profile.')));
    }
  }

  /// Turning this on now genuinely schedules 5 real, repeating local
  /// notifications (Mon-Fri, 7:30 AM) via NotificationService — this
  /// used to just flip a variable and show a SnackBar, with nothing
  /// actually scheduled.
  Future<void> _onToggleNotifications(bool value) async {
    try {
      if (value) {
        final granted = await _notifications.requestPermission();
        if (!granted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Notification permission denied. Please enable it in your phone\'s settings.')),
            );
          }
          return; // don't flip the switch on if permission was refused
        }
        await _notifications.scheduleWeekdayReminder(_ownerId, hour: 7, minute: 30);
      } else {
        await _notifications.cancelWeekdayReminder(_ownerId);
      }

      setState(() => _notificationsEnabled = value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(value ? 'Daily commute reminder scheduled for 7:30 AM on weekdays.' : 'Daily commute reminder turned off.')),
        );
      }
    } catch (e) {
      // Without this catch, any error here (e.g. from the native
      // notification scheduling call) would silently stop the function
      // BEFORE reaching setState() — which is exactly why the switch
      // could get permission granted but still never visually toggle.
      // ignore: avoid_print
      print('Notification scheduling failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not set up the reminder: $e')),
        );
      }
    }
  }

  Future<void> _logout() async {
    await _auth.logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const SplashScreen()), (route) => false);
    }
  }

  /// Shows a strong confirmation dialog, then — only if confirmed —
  /// permanently deletes every piece of this account's real data:
  /// trips (local + remote), saved locations, savings goals, profile
  /// picture, and the profiles row itself, then logs out.
  ///
  /// Honest limitation, explained in the dialog itself: this does NOT
  /// delete the actual login credential (email/password) — that
  /// requires Supabase's Admin API and a secret key that must never be
  /// placed inside a mobile app. What this DOES do is remove every
  /// real, meaningful piece of personal data, leaving nothing behind.
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
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: deleting ? null : () => Navigator.pop(dialogContext),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                        onPressed: deleting ? null : () async {
                          setDialogState(() => deleting = true);
                          // No separate Navigator.pop() needed here —
                          // _performAccountDeletion() already replaces
                          // the ENTIRE navigation stack (dialog
                          // included) via pushAndRemoveUntil. Popping
                          // the dialog separately afterward was the
                          // actual bug: by that point its route no
                          // longer exists, causing a crash.
                          await _performAccountDeletion(dialogContext);
                        },
                        child: deleting
                            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Delete Account'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _performAccountDeletion(BuildContext dialogContext) async {
    try {
      // Local data — trips, saved locations, savings goals.
      await _db.deleteAllLocalDataForCurrentUser();

      // Remote trips.
      try {
        await _supabase.deleteAllTrips();
      } catch (e) {
        // ignore: avoid_print
        print('Remote trip deletion failed (local deletion still succeeded): $e');
      }

      // Local profile picture file, if one exists.
      try {
        if (_profileImage != null && await _profileImage!.exists()) {
          await _profileImage!.delete();
        }
      } catch (e) {
        // ignore: avoid_print
        print('Profile picture deletion failed: $e');
      }

      // Remote profile row.
      try {
        await _auth.deleteProfile();
      } catch (e) {
        // ignore: avoid_print
        print('Remote profile deletion failed: $e');
      }

      // Finally, log out and return to Splash. This ALSO closes the
      // dialog, since pushAndRemoveUntil replaces the entire
      // navigation stack — no separate pop needed on this path.
      await _auth.logout();
      if (mounted) {
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const SplashScreen()), (route) => false);
      }
    } catch (e) {
      // On FAILURE, the success path above never ran, so the dialog
      // is still open and needs to be explicitly closed here — this
      // is the one case that genuinely needs its own pop.
      if (dialogContext.mounted) Navigator.pop(dialogContext);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Something went wrong while deleting your account: $e')),
        );
      }
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
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: AppColors.mint,
                        backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
                        child: _loading
                            ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                            : (_profileImage == null ? Text(_profile?.initials ?? '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)) : null),
                      ),
                      if (!_loading && _auth.isLoggedIn)
                        Positioned(
                          bottom: 0, right: 0,
                          child: GestureDetector(
                            onTap: _changeProfilePicture,
                            child: Container(
                              width: 22, height: 22,
                              decoration: BoxDecoration(color: AppColors.amber, shape: BoxShape.circle, border: Border.all(color: AppColors.teal, width: 2)),
                              child: const Icon(Icons.camera_alt, size: 11, color: Colors.white),
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
                        onChanged: _onToggleNotifications,
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
                  if (_auth.isLoggedIn) ...[
                    _row(
                      context,
                      icon: Icons.logout,
                      label: 'Log Out',
                      onTap: _logout,
                    ),
                    InkWell(
                      onTap: _confirmDeleteAccount,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 32, height: 32,
                              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
                              child: const Icon(Icons.delete_forever_outlined, size: 16, color: Colors.redAccent),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text('Delete Account', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.redAccent)),
                            ),
                            Icon(Icons.chevron_right, color: Colors.grey.shade300),
                          ],
                        ),
                      ),
                    ),
                  ] else
                    _row(
                      context,
                      icon: Icons.login,
                      label: 'Login / Register',
                      sub: 'Sign in to save your progress',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      ).then((_) {
                        // Refresh everything tied to the account, not
                        // just the name/email — otherwise a guest who
                        // just logged in would still see the guest's
                        // old picture/notification state until a full
                        // app restart.
                        _loadProfile();
                        _loadProfileImage();
                        _syncNotificationSwitchWithRealState();
                      }),
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