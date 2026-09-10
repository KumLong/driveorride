import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import 'main_shell.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = AuthService();
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
      if (mounted) {
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const MainShell()), (route) => false);
      }
    } on AuthException catch (e) {
      setState(() => _error = _friendlyLoginError(e));
    } catch (e) {
      setState(() => _error = 'Something went wrong. Please check your connection and try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Maps Supabase's raw auth error text to a plain, user-facing message —
  /// the person logging in doesn't know what "Supabase" is and shouldn't
  /// need to.
  String _friendlyLoginError(AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('invalid login credentials') || msg.contains('invalid email or password')) {
      return 'Invalid email or password.';
    }
    if (msg.contains('email not confirmed')) {
      return 'Please confirm your email before logging in. Check your inbox for the confirmation link.';
    }
    if (msg.contains('too many requests') || msg.contains('rate limit')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    return 'Invalid email or password.';
  }

  /// Two-step, fully in-app password reset — no email link, no
  /// redirect page needed. Step 1: request a 6-digit code by email.
  /// Step 2: enter that code plus a new password, right here.
  void _showForgotPasswordDialog() {
    final emailCtrl = TextEditingController(text: _emailCtrl.text.trim());
    final codeCtrl = TextEditingController();
    final newPasswordCtrl = TextEditingController();
    int step = 1; // 1 = enter email, 2 = enter code + new password
    bool busy = false;
    String? dialogError;

    showDialog(
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
                      child: const Icon(Icons.lock_reset, color: AppColors.mint),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(child: Text('Reset Password', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.teal))),
                  ],
                ),
                const SizedBox(height: 12),

                if (step == 1) ...[
                  const Text(
                    "Enter your email and we'll send you a 6-digit code.",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: 'Email',
                      prefixIcon: const Icon(Icons.email_outlined, color: AppColors.mint, size: 20),
                      filled: true, fillColor: AppColors.bg,
                      errorText: dialogError,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: OutlinedButton(onPressed: busy ? null : () => Navigator.pop(dialogContext), child: const Text('Cancel'))),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: busy ? null : () async {
                            final email = emailCtrl.text.trim();
                            if (!_emailPattern.hasMatch(email)) {
                              setDialogState(() => dialogError = 'Please enter a valid email address.');
                              return;
                            }
                            setDialogState(() { busy = true; dialogError = null; });
                            try {
                              await _auth.resetPassword(email);
                              setDialogState(() { busy = false; step = 2; });
                            } catch (e) {
                              setDialogState(() { busy = false; dialogError = 'Could not send the code. Please try again.'; });
                            }
                          },
                          child: busy
                              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Send Code'),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Text(
                    'Enter the 6-digit code sent to ${emailCtrl.text.trim()}, and your new password.',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: codeCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: InputDecoration(
                      hintText: '6-digit code',
                      prefixIcon: const Icon(Icons.pin_outlined, color: AppColors.mint, size: 20),
                      filled: true, fillColor: AppColors.bg,
                      counterText: '',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: newPasswordCtrl,
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: 'New password (6+ characters)',
                      prefixIcon: const Icon(Icons.lock_outline, color: AppColors.mint, size: 20),
                      filled: true, fillColor: AppColors.bg,
                      errorText: dialogError,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: OutlinedButton(onPressed: busy ? null : () => Navigator.pop(dialogContext), child: const Text('Cancel'))),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: busy ? null : () async {
                            final code = codeCtrl.text.trim();
                            final newPassword = newPasswordCtrl.text;
                            if (code.length != 6) {
                              setDialogState(() => dialogError = 'Please enter the 6-digit code.');
                              return;
                            }
                            if (newPassword.length < 6) {
                              setDialogState(() => dialogError = 'Password must be at least 6 characters.');
                              return;
                            }
                            setDialogState(() { busy = true; dialogError = null; });
                            try {
                              await _auth.verifyPasswordResetCode(emailCtrl.text.trim(), code);
                              await _auth.setNewPassword(newPassword);
                              if (dialogContext.mounted) Navigator.pop(dialogContext);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Password updated — you can now log in with your new password.')),
                                );
                              }
                            } catch (e) {
                              setDialogState(() { busy = false; dialogError = 'Invalid or expired code. Please try again.'; });
                            }
                          },
                          child: busy
                              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Reset Password'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          // Decorative teal header, matching the app's established
          // gradient style (Home, Profile) instead of a flat solid color.
          Container(
            height: 260,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.teal, Color(0xFF025D6A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 24),
                  Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
                    child: const Icon(Icons.directions_transit, color: Colors.white, size: 36),
                  ),
                  const SizedBox(height: 16),
                  const Text('Welcome Back', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text('Log in to continue', style: TextStyle(color: AppColors.mint, fontSize: 13)),
                  const SizedBox(height: 28),
                  // Card lifts the form off the gradient header, matching
                  // the card-based style used across Home/Profile/etc.
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 8))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _field(_emailCtrl, 'Email', Icons.email_outlined),
                        const SizedBox(height: 12),
                        _field(_passwordCtrl, 'Password', Icons.lock_outline, obscure: _obscurePassword, isPassword: true),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _showForgotPasswordDialog,
                            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
                            child: const Text('Forgot Password?', style: TextStyle(color: AppColors.mint, fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                        ),
                        if (_error != null) Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
                            child: Row(children: [
                              const Icon(Icons.error_outline, color: Colors.redAccent, size: 16),
                              const SizedBox(width: 8),
                              Expanded(child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12))),
                            ]),
                          ),
                        ),
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _login,
                            child: _loading
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Log In'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                    child: const Text.rich(
                      TextSpan(
                        text: "Don't have an account? ",
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                        children: [TextSpan(text: 'Register', style: TextStyle(color: AppColors.mint, fontWeight: FontWeight.bold))],
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const MainShell()), (route) => false),
                    child: const Text('Skip for now', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon, {bool obscure = false, bool isPassword = false}) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      style: const TextStyle(color: AppColors.teal),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.mint, size: 20),
        suffixIcon: isPassword
            ? IconButton(
          icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.grey, size: 20),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        )
            : null,
        filled: true,
        fillColor: AppColors.bg,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      ),
    );
  }
}