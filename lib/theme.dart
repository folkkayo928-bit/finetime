import 'package:flutter/material.dart';

class FT {
  static const gold = Color(0xFFC6A664);      // Champagne Gold
  static const ivory = Color(0xFFFAF7F0);     // Ivory
  static const charcoal = Color(0xFF232323);  // Deep Charcoal

  static ThemeData theme() => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: ivory,
    colorScheme: ColorScheme.fromSeed(seedColor: gold, primary: gold, surface: ivory),
    appBarTheme: const AppBarTheme(
      backgroundColor: charcoal, foregroundColor: ivory, elevation: 0,
      titleTextStyle: TextStyle(color: ivory, fontSize: 18, fontWeight: FontWeight.w600),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: charcoal, selectedItemColor: gold, unselectedItemColor: Colors.white54,
      type: BottomNavigationBarType.fixed,
    ),
    cardTheme: CardThemeData(color: Colors.white, elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
      backgroundColor: gold, foregroundColor: charcoal,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      minimumSize: const Size.fromHeight(48))),
    inputDecorationTheme: InputDecorationTheme(
      filled: true, fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
  );

  static Widget badge(String label, {Color? bg}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: bg ?? gold, borderRadius: BorderRadius.circular(6)),
    child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: charcoal)));
}
