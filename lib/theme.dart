import 'package:flutter/material.dart';

class FT {
  static const gold = Color(0xFFC9A227);
  static const ivory = Color(0xFFF5F1E8);
  static const charcoal = Color(0xFF121212);
  static const terracotta = Color(0xFFB85C38);
  static const mutedGray = Color(0xFFA0A0A0);

  static ThemeData theme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: gold,
      brightness: Brightness.dark,
      primary: gold,
      secondary: terracotta,
      surface: charcoal,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: charcoal,
      colorScheme: scheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: charcoal,
        foregroundColor: ivory,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: ivory,
          fontSize: 19,
          fontWeight: FontWeight.w700,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: charcoal,
        selectedItemColor: gold,
        unselectedItemColor: Colors.white54,
        type: BottomNavigationBarType.fixed,
      ),
      cardTheme: CardThemeData(
        color: Color(0xFF1B1B1B),
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: Colors.white10),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: gold,
          foregroundColor: charcoal,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          minimumSize: const Size.fromHeight(48),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        labelStyle: const TextStyle(color: Colors.black54),
        hintStyle: const TextStyle(color: Colors.black38),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      dividerColor: Colors.white12,
    );
  }

  static Widget badge(String label, {Color? bg}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: bg ?? gold,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: charcoal,
          ),
        ),
      );
}
