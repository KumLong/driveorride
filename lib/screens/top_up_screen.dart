import 'package:flutter/material.dart';
import '../theme.dart';
import 'touch_n_go_payment_screen.dart';

/// Step 1 of topping up the wallet: pick a preset amount or type a
/// custom one, then continue to the (simulated) Touch & Go payment step.
class TopUpScreen extends StatefulWidget {
  const TopUpScreen({super.key});

  @override
  State<TopUpScreen> createState() => _TopUpScreenState();
}

class _TopUpScreenState extends State<TopUpScreen> {
  static const List<double> _presets = [10, 20, 30, 50, 100];

  double? _selectedPreset;
  final _customCtrl = TextEditingController();

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  static const double _minimumTopUp = 10.0;

  double? get _amount {
    if (_selectedPreset != null) return _selectedPreset;
    final v = double.tryParse(_customCtrl.text.trim());
    return (v != null && v >= _minimumTopUp) ? v : null;
  }

  /// Only shown once the person has typed something invalid — stays
  /// quiet while the field is empty or they're still mid-typing a
  /// value that could still become valid.
  String? get _customAmountError {
    final text = _customCtrl.text.trim();
    if (text.isEmpty) return null;
    final v = double.tryParse(text);
    if (v == null) return 'Enter a valid number';
    if (v < _minimumTopUp) return 'Minimum top up is RM ${_minimumTopUp.toStringAsFixed(0)}';
    return null;
  }

  void _pickPreset(double amount) {
    setState(() {
      _selectedPreset = amount;
      _customCtrl.clear();
    });
  }

  Future<void> _continue() async {
    final amount = _amount;
    if (amount == null) return;

    final success = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => TouchNGoPaymentScreen(amount: amount)),
    );

    if (success == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final amount = _amount;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Top Up Wallet')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Choose an amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.teal)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _presets.map((p) {
                final selected = _selectedPreset == p;
                return ChoiceChip(
                  label: Text('RM ${p.toStringAsFixed(0)}'),
                  selected: selected,
                  onSelected: (_) => _pickPreset(p),
                  selectedColor: AppColors.mint,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : AppColors.teal,
                    fontWeight: FontWeight.bold,
                  ),
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                    side: BorderSide(color: selected ? AppColors.mint : Colors.grey.shade300),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            Text('Or enter a custom amount (min. RM ${_minimumTopUp.toStringAsFixed(0)})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.teal)),
            const SizedBox(height: 12),
            TextField(
              controller: _customCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() => _selectedPreset = null),
              style: const TextStyle(color: AppColors.teal, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                prefixText: 'RM ',
                hintText: '0.00',
                filled: true,
                fillColor: Colors.white,
                errorText: _customAmountError,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: amount == null ? null : _continue,
                icon: const Icon(Icons.account_balance_wallet_outlined, size: 18),
                label: Text(amount == null ? 'Use Touch & Go to Top Up' : 'Use Touch & Go to Top Up RM ${amount.toStringAsFixed(2)}'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}