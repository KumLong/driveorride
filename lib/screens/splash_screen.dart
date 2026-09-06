import 'package:flutter/material.dart';
import '../theme.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.teal,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/icon/logo.png', width: 100, height: 100),
            const SizedBox(height: 16),
            const Text('DriveOrRide', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
            const Text('Smarter choices. Better commute.', style: TextStyle(color: AppColors.mint, fontSize: 13)),
            const SizedBox(height: 40),
            SizedBox(
              width: 220,
              child: ElevatedButton(
                onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                child: const Text('Get Started'),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
              child: const Text('Log In', style: TextStyle(color: AppColors.mint)),
            ),
          ],
        ),
      ),
    );
  }
}
