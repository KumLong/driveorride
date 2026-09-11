import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/supabase_service.dart';
import '../theme.dart';
import 'main_shell.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = AuthService();
  final _db = DatabaseService();
  final _supabase = SupabaseService();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Please enter both email and password.');
      return;
    }
    if (!_emailPattern.hasMatch(email)) {
      setState(() => _error = 'Please enter a valid email address.');
      return;
    }

    setState(() { _loading = true; _error = null; });
    try {
      await _auth.login(email, password);

      // Block this login immediately if the account was previously
      // deleted — the raw Supabase Auth check itself can't be
      // prevented from succeeding (that would need an admin key that
      // must never be in a mobile app), so instead we let it succeed,
      // detect the deletion right here, and immediately reverse it.
      final wasDeleted = await _auth.checkIfDeletedAndSignOutIfSo();
      if (wasDeleted) {
        setState(() => _error = 'This account has been deleted and can no longer be used.');
        return;
      }

      await _syncMissingTrips();
      if (mounted) {
        Navigator.pushAndRemoveUntil(context,
            MaterialPageRoute(builder: (_) => const MainShell()), (route) => false);
      }
    } on AuthException catch (e) {
      setState(() => _error = _friendlyError(e));
    } catch (e) {
      setState(() => _error = 'Something went wrong. Please check your connection.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Fills in any real trips missing from THIS device's local storage
  /// by comparing against Supabase — fixes the earlier limitation
  /// where trips added on one device wouldn't show up on another
  /// unless local storage started out completely empty. Wrapped in
  /// try/catch so a sync failure (e.g. no internet right now) never
  /// blocks the login itself from completing.
  Future<void> _syncMissingTrips() async {
    try {
      final remoteTrips = await _supabase.fetchTrips();
      if (remoteTrips.isNotEmpty) {
        await _db.syncMissingTripsFromRemote(remoteTrips);
      }
    } catch (e) {
      // ignore: avoid_print
      print('Trip sync failed (login still succeeded): $e');
    }
  }

  String _friendlyError(AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('invalid login credentials') || msg.contains('invalid email or password')) {
      return 'Invalid email or password.';
    }
    if (msg.contains('email not confirmed')) {
      return 'Please confirm your email before logging in.';
    }
    if (msg.contains('too many requests') || msg.contains('rate limit')) {
      return 'Too many attempts. Please wait and try again.';
    }
    return 'Invalid email or password.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 48),

              // Logo + app name + tagline
              Image.asset('assets/icon/logo.png', width: 100, height: 100),
              const SizedBox(height: 12),
              RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
                  children: [
                    TextSpan(text: 'DriveOr', style: TextStyle(color: AppColors.teal)),
                    TextSpan(text: 'Ride', style: TextStyle(color: AppColors.mint)),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Smarter rides. Better choices.',
                style: TextStyle(color: Colors.grey, fontSize: 15),
              ),

              const SizedBox(height: 40),

              // Email field
              _label('Email'),
              const SizedBox(height: 6),
              _field(
                controller: _emailCtrl,
                hint: 'you@example.com',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),

              // Password field
              _label('Password'),
              const SizedBox(height: 6),
              _field(
                controller: _passwordCtrl,
                hint: '••••••••',
                obscure: _obscurePassword,
                suffix: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: Colors.grey, size: 20,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),

              // Forgot password
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
                  child: Text('Forgot password?',
                      style: TextStyle(color: AppColors.mint, fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ),

              // Error message
              if (_error != null) ...[
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12))),
                  ]),
                ),
                const SizedBox(height: 8),
              ],

              const SizedBox(height: 8),

              // Log In button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.mint,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _loading
                      ? const SizedBox(height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Log In',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),

              const SizedBox(height: 24),

              // Don't have account
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don't have an account? ",
                      style: TextStyle(color: Colors.grey, fontSize: 13)),
                  GestureDetector(
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const RegisterScreen())),
                    child: Text('Register',
                        style: TextStyle(color: AppColors.mint, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Skip
              TextButton(
                onPressed: () => Navigator.pushAndRemoveUntil(context,
                    MaterialPageRoute(builder: (_) => const MainShell()), (route) => false),
                child: const Text('Skip for now', style: TextStyle(color: AppColors.mint, fontWeight: FontWeight.bold, fontSize: 13)),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Align(
    alignment: Alignment.centerLeft,
    child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E))),
  );

  Widget _field({
    required TextEditingController controller,
    String? hint,
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A2E)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFFF5F5F5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.mint, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}