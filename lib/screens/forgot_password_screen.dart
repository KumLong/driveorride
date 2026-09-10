import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../theme.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _auth = AuthService();
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;
  bool _codeSent = false;
  String? _error;

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  Future<void> _sendCode() async {
    final email = _emailCtrl.text.trim();
    if (!_emailPattern.hasMatch(email)) {
      setState(() => _error = 'Please enter a valid email address.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await _auth.resetPassword(email);
      setState(() { _codeSent = true; _loading = false; });
    } catch (e) {
      setState(() { _loading = false; _error = 'Could not send code. Please try again.'; });
    }
  }

  Future<void> _resetPassword() async {
    final code = _codeCtrl.text.trim();
    final newPassword = _newPasswordCtrl.text;
    if (code.length != 6) {
      setState(() => _error = 'Please enter the 6-digit code.');
      return;
    }
    if (newPassword.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await _auth.verifyPasswordResetCode(_emailCtrl.text.trim(), code);
      await _auth.setNewPassword(newPassword);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password updated! Please log in with your new password.')),
        );
        Navigator.pop(context);
      }
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      String friendly;
      if (msg.contains('expired') || msg.contains('invalid') || msg.contains('otp')) {
        friendly = 'Invalid or expired code. Please request a new one.';
      } else if (msg.contains('password')) {
        friendly = 'Password is too weak. Please use at least 6 characters.';
      } else {
        friendly = 'Something went wrong. Please try again.';
      }
      setState(() { _loading = false; _error = friendly; });
    } catch (e) {
      setState(() { _loading = false; _error = 'Invalid or expired code. Please try again.'; });
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
                  _codeSent
                      ? "Enter the 6-digit code sent to ${_emailCtrl.text.trim()} and your new password."
                      : "Enter your email and we'll send you a reset code.",
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),

              const SizedBox(height: 24),

              // Email field — always shown
              _label('Email'),
              const SizedBox(height: 6),
              _field(
                controller: _emailCtrl,
                hint: 'you@example.com',
                keyboardType: TextInputType.emailAddress,
                enabled: !_codeSent,
              ),

              // Step 2 fields — shown after code is sent
              if (_codeSent) ...[
                const SizedBox(height: 14),
                _label('6-Digit Code'),
                const SizedBox(height: 6),
                _field(
                  controller: _codeCtrl,
                  hint: 'Enter code from email',
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                ),
                const SizedBox(height: 14),
                _label('New Password'),
                const SizedBox(height: 6),
                _field(
                  controller: _newPasswordCtrl,
                  hint: 'Create new password',
                  obscure: _obscurePassword,
                  suffix: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: Colors.grey, size: 20,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ],

              // Error
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

              // Action button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : (_codeSent ? _resetPassword : _sendCode),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.mint,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _loading
                      ? const SizedBox(height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(_codeSent ? 'Reset Password' : 'Send Code',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),

              // Check inbox info box — shown after code sent
              if (_codeSent) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.mintLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    Icon(Icons.mark_email_read_outlined, color: AppColors.mint, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Check your inbox',
                            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.teal, fontSize: 13)),
                        const SizedBox(height: 2),
                        const Text('The code expires after 1 hour.',
                            style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ]),
                    ),
                  ]),
                ),
                const SizedBox(height: 12),
                // Resend code
                TextButton(
                  onPressed: _loading ? null : () async {
                    setState(() { _loading = true; _error = null; });
                    try {
                      await _auth.resetPassword(_emailCtrl.text.trim());
                      setState(() => _loading = false);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('A new code has been sent.')),
                        );
                      }
                    } catch (e) {
                      setState(() { _loading = false; _error = 'Could not resend. Try again.'; });
                    }
                  },
                  child: Text('Resend code',
                      style: TextStyle(color: AppColors.mint, fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ],

              const SizedBox(height: 16),

              // Back to login
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
    bool obscure = false,
    bool enabled = true,
    int? maxLength,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      enabled: enabled,
      maxLength: maxLength,
      buildCounter: maxLength != null ? (_, {required currentLength, required isFocused, maxLength}) => null : null,
      style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A2E)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
        suffixIcon: suffix,
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
          borderSide: BorderSide(color: AppColors.mint, width: 1.5),
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