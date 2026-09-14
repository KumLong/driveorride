import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import 'login_screen.dart';
import 'info_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _auth = AuthService();
  final _fullNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static final _namePattern = RegExp(r"^[a-zA-Z\s\-']+$");

  static final _phonePattern = RegExp(r'^01[0-9]{8,9}$');

  String? _validateName(String name) {
    if (name.isEmpty) return 'Please enter your full name.';
    if (name.length < 2) return 'Name must be at least 2 characters.';
    if (!_namePattern.hasMatch(name)) return 'Name cannot contain numbers or special characters.';
    return null;
  }

  String? _validatePhone(String raw) {

    final digits = raw.replaceAll(RegExp(r'[\s\-()]'), '');
    if (digits.isEmpty) return 'Please enter your phone number.';
    if (RegExp(r'[a-zA-Z]').hasMatch(raw)) return 'Phone number cannot contain letters.';
    if (RegExp(r'[^0-9\s\-()]').hasMatch(raw)) return 'Phone number cannot contain special characters.';
    if (!digits.startsWith('01')) return 'Malaysian phone numbers must start with 01.';
    if (!_phonePattern.hasMatch(digits)) return 'Enter a valid Malaysian number (e.g. 012-3456789).';
    return null;
  }

  Future<void> _register() async {
    final fullName = _fullNameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final password = _passwordCtrl.text;

    final nameError = _validateName(fullName);
    if (nameError != null) {
      setState(() => _error = nameError);
      return;
    }

    if (email.isEmpty || !_emailPattern.hasMatch(email)) {
      setState(() => _error = 'Please enter a valid email address (e.g. you@example.com).');
      return;
    }

    final phoneError = _validatePhone(phone);
    if (phoneError != null) {
      setState(() => _error = phoneError);
      return;
    }

    if (password.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }

    setState(() { _loading = true; _error = null; });
    try {
      await _auth.register(email, password, fullName: fullName, phone: phone);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account created! Please log in.')),
        );
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const LoginScreen()));
      }
    } on AuthException catch (e) {
      setState(() => _error = _friendlyError(e));
    } catch (e) {
      setState(() => _error = 'Something went wrong. Please check your connection.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyError(AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('already registered') || msg.contains('already exists')) {
      return 'This email is already registered. Try logging in instead.';
    }
    if (msg.contains('password')) return 'Password must be at least 6 characters.';
    if (msg.contains('invalid') && msg.contains('email')) return 'Please enter a valid email address.';
    return 'Registration failed. Please try again.';
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

              Image.asset('assets/icon/logo.png', width: 80, height: 80),
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
              const Text(
                'Smarter rides. Better choices.',
                style: TextStyle(color: Colors.grey, fontSize: 15),
              ),

              const SizedBox(height: 32),

              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Create account',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
              ),
              const SizedBox(height: 4),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Start making smarter travel choices.',
                    style: TextStyle(color: Colors.grey, fontSize: 13)),
              ),

              const SizedBox(height: 24),

              _label('Name'),
              const SizedBox(height: 6),
              _field(controller: _fullNameCtrl, hint: 'Your name'),
              const SizedBox(height: 14),

              _label('Email'),
              const SizedBox(height: 6),
              _field(
                controller: _emailCtrl,
                hint: 'you@example.com',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 14),

              _label('Phone'),
              const SizedBox(height: 6),
              _field(
                controller: _phoneCtrl,
                hint: '01X-XXXXXXXX',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 14),

              _label('Password'),
              const SizedBox(height: 6),
              _field(
                controller: _passwordCtrl,
                hint: 'Create a password',
                obscure: _obscurePassword,
                suffix: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: Colors.grey, size: 20,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
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

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.mint,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _loading
                      ? const SizedBox(height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Create Account',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),

              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('By continuing, you agree to our ',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                  GestureDetector(
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const InfoScreen(
                          title: 'Terms & Conditions',
                          sections: AppInfoContent.terms,
                        ))),
                    child: Text('Terms',
                        style: TextStyle(color: AppColors.mint, fontWeight: FontWeight.w600, fontSize: 12)),
                  ),
                  const Text(' & ', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  GestureDetector(
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const InfoScreen(
                          title: 'Privacy Policy',
                          sections: AppInfoContent.privacy,
                        ))),
                    child: Text('Privacy Policy',
                        style: TextStyle(color: AppColors.mint, fontWeight: FontWeight.w600, fontSize: 12)),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Already have an account? ',
                      style: TextStyle(color: Colors.grey, fontSize: 13)),
                  GestureDetector(
                    onTap: () => Navigator.pushReplacement(context,
                        MaterialPageRoute(builder: (_) => const LoginScreen())),
                    child: Text('Log in',
                        style: TextStyle(color: AppColors.mint, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ],
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