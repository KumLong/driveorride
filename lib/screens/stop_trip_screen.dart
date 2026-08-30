import 'package:flutter/material.dart';
import '../theme.dart';
import 'main_shell.dart';

class StopTripScreen extends StatelessWidget {
  const StopTripScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black54,
      body: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(color: AppColors.amberLight, borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.warning_amber_rounded, color: AppColors.amber, size: 28),
              ),
              const SizedBox(height: 16),
              const Text('Stop this trip?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.teal)),
              const SizedBox(height: 8),
              const Text('This trip won\'t be counted in your savings if you stop now.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                      onPressed: () => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const MainShell()), (route) => false),
                      child: const Text('Stop Trip'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
