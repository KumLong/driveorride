import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/database_service.dart';
import '../services/supabase_service.dart';

class TouchNGoPaymentScreen extends StatefulWidget {
  final double amount;

  const TouchNGoPaymentScreen({super.key, required this.amount});

  @override
  State<TouchNGoPaymentScreen> createState() => _TouchNGoPaymentScreenState();
}

class _TouchNGoPaymentScreenState extends State<TouchNGoPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  final _db = DatabaseService();
  final _supabase = SupabaseService();

  bool _obscurePin = true;
  bool _processing = false;
  String? _error;

  static final _phonePattern = RegExp(r'^01[0-9]{8,9}$');

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmPayment() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _processing = true);

    await Future.delayed(const Duration(milliseconds: 1200));

    await _db.adjustWalletBalance(widget.amount);
    final tx = WalletTransactionModel(
      label: 'Top Up (Touch \'n Go)',
      amount: widget.amount,
      createdOn: DateTime.now().toIso8601String(),
    );
    await _db.insertWalletTransaction(tx);
    try {
      await _supabase.uploadWalletTransaction(tx);
    } catch (_) {

    }

    if (!mounted) return;
    setState(() => _processing = false);

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Color(0xFF0868AC), size: 48),
        title: const Text('Top Up Successful'),
        content: Text('RM ${widget.amount.toStringAsFixed(2)} has been added to your wallet.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    );

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    const tngBlue = Color(0xFF0868AC);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F7FA),
      appBar: AppBar(
        backgroundColor: tngBlue,
        foregroundColor: Colors.white,
        title: const Text("Touch 'n Go eWallet"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: tngBlue, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Paying to', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const Text('DriveOrRide Wallet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    Text('RM ${widget.amount.toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text('Registered Phone Number', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                decoration: InputDecoration(
                  hintText: 'e.g. 0123456789',
                  prefixIcon: const Icon(Icons.phone_android),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Enter your phone number';
                  if (!_phonePattern.hasMatch(v.trim())) return 'Enter a valid Malaysian mobile number';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              const Text('6-Digit PIN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _pinCtrl,
                obscureText: _obscurePin,
                keyboardType: TextInputType.number,
                maxLength: 6,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '••••••',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePin ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                    onPressed: () => setState(() => _obscurePin = !_obscurePin),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                validator: (v) {
                  if (v == null || v.length != 6) return 'Enter your 6-digit PIN';
                  if (!RegExp(r'^\d{6}$').hasMatch(v)) return 'PIN must be 6 digits';
                  return null;
                },
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: _processing ? null : _confirmPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: tngBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _processing
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text('Confirm Payment · RM ${widget.amount.toStringAsFixed(2)}'),
              ),
              const SizedBox(height: 12),
              const Center(
                child: Text('This is a simulated payment for demo purposes.', style: TextStyle(fontSize: 11, color: Colors.grey)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}