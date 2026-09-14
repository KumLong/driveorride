import 'package:flutter/material.dart';

class AppColors {
  static const teal = Color(0xFF013A40);
  static const mint = Color(0xFF02C39A);
  static const amber = Color(0xFFF59E0B);
  static const mintLight = Color(0xFFE6FAF5);
  static const amberLight = Color(0xFFFEF3C7);
  static const bg = Color(0xFFF0F7F5);
}

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.mint),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: AppColors.teal,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(color: AppColors.teal, fontSize: 17, fontWeight: FontWeight.bold),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.zero,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.mint,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(backgroundColor: AppColors.mint, foregroundColor: Colors.white),
  );
}
