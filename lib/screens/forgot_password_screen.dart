import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme.dart';

/// Sends a real, working password-reset link — the user taps it and
/// completes the reset on a separate webpage (see reset-password.html),
/// since Supabase's free-tier email template can't be customised to
/// show an in-app code instead (a real platform restriction, not a
/// choice made here).
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _auth = AuthService();
  final _emailCtrl = TextEditingController();

  bool _loading = false;
  bool _linkSent = false;
  String? _error;

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  Future<void> _sendLink() async {
    final email = _emailCtrl.text.trim();
    if (!_emailPattern.hasMatch(email)) {
      setState(() => _error = 'Please enter a valid email address.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await _auth.resetPassword(email);
      setState(() { _linkSent = true; _loading = false; });
    } catch (e) {
      setState(() { _loading = false; _error = 'Could not send the link. Please try again.'; });
    }
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
              const SizedBox(height: 40),

              // Logo + app name + tagline
              Image.asset('assets/icon/logo.png', width: 100, height: 100),
              const SizedBox(height: 10),
              RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                  children: [
                    TextSpan(text: 'DriveOr', style: TextStyle(color: AppColors.teal)),
                    TextSpan(text: 'Ride', style: TextStyle(color: AppColors.mint)),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              const Text('Smarter rides. Better choices.',
                  style: TextStyle(color: Colors.grey, fontSize: 15)),

              const SizedBox(height: 32),

              // Page title
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Reset password',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _linkSent
                      ? "We've sent a reset link to ${_emailCtrl.text.trim()}. Open it on any device to set a new password."
                      : "Enter your email and we'll send you a link to reset your password.",
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),

              const SizedBox(height: 24),

              _label('Email'),
              const SizedBox(height: 6),
              _field(
                controller: _emailCtrl,
                hint: 'you@example.com',
                keyboardType: TextInputType.emailAddress,
                enabled: !_linkSent,
              ),

              if (_error != null) ...[
                const SizedBox(height: 12),
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
                    Expanded(child: Text(_error!,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 12))),
                  ]),
                ),
              ],

              const SizedBox(height: 20),

              if (!_linkSent)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _sendLink,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.mint,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: _loading
                        ? const SizedBox(height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Send Link', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),

              // Check inbox info box — shown after the link is sent
              if (_linkSent) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.mintLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    const Icon(Icons.mark_email_read_outlined, color: AppColors.mint, size: 22),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Check your inbox',
                            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.teal, fontSize: 13)),
                        SizedBox(height: 2),
                        Text('Tap the link in the email, set a new password there, then come back and log in.',
                            style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ]),
                    ),
                  ]),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _loading ? null : () async {
                    setState(() { _loading = true; _error = null; });
                    try {
                      await _auth.resetPassword(_emailCtrl.text.trim());
                      setState(() => _loading = false);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('A new link has been sent.')),
                        );
                      }
                    } catch (e) {
                      setState(() { _loading = false; _error = 'Could not resend. Try again.'; });
                    }
                  },
                  child: const Text('Resend link',
                      style: TextStyle(color: AppColors.mint, fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ],

              const SizedBox(height: 16),

              TextButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, size: 16, color: Colors.grey),
                label: const Text('Back to Log In',
                    style: TextStyle(color: Colors.grey, fontSize: 13)),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Align(
    alignment: Alignment.centerLeft,
    child: Text(text,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E))),
  );

  Widget _field({
    required TextEditingController controller,
    String? hint,
    TextInputType? keyboardType,
    bool enabled = true,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: enabled,
      style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A2E)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
        filled: true,
        fillColor: enabled ? const Color(0xFFF5F5F5) : const Color(0xFFEEEEEE),
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
          borderSide: const BorderSide(color: AppColors.mint, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}