import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'trip_history_screen.dart';
import 'savings_goals_screen.dart';
import 'profile_screen.dart';
import '../theme.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  final _screens = const [
    HomeScreen(),
    TripHistoryScreen(),
    SavingsGoalsScreen(),
    ProfileScreen(),
  ];

  final _labels = const ['Home', 'History', 'Savings', 'Profile'];
  final _icons = const [Icons.home_outlined, Icons.history, Icons.savings_outlined, Icons.person_outline];
  final _filledIcons = const [Icons.home, Icons.history, Icons.savings, Icons.person];

  Widget _navItem(int i) {
    final selected = _index == i;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _index = i),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40, height: 26,
              decoration: BoxDecoration(
                color: selected ? AppColors.mintLight : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(selected ? _filledIcons[i] : _icons[i], size: 18, color: selected ? AppColors.mint : Colors.grey.shade400),
            ),
            const SizedBox(height: 2),
            Text(_labels[i], style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: selected ? AppColors.mint : Colors.grey.shade400)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_index],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, -2))],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 72, // was 68 — small extra headroom fixes the 1px overflow
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _navItem(0),
                _navItem(1),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Transform.translate(
                        offset: const Offset(0, -12),
                        child: GestureDetector(
                          onTap: () => setState(() => _index = 0),
                          child: Container(
                            width: 54, height: 54,
                            decoration: BoxDecoration(
                              color: _index == 0 ? AppColors.teal : AppColors.mint,
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: AppColors.mint.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))],
                            ),
                            child: const Icon(Icons.bar_chart, color: Colors.white, size: 24),
                          ),
                        ),
                      ),
                      Transform.translate(
                        offset: const Offset(0, -8),
                        child: Text('Compare', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: _index == 0 ? AppColors.teal : AppColors.mint)),
                      ),
                    ],
                  ),
                ),
                _navItem(2),
                _navItem(3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
