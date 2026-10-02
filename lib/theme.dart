import 'package:flutter/material.dart';

class FT {
  static const obsidian = Color(0xFF0C0A06);
  static const charcoal = Color(0xFF14110C);
  static const surface = Color(0xFF1B1815);
  static const surfaceSubtle = Color(0xFF241F17);
  static const cardDark = Color(0xFF181510);
  
  static const gold = Color(0xFFE3A82D);
  static const goldLight = Color(0xFFEEB843);
  static const goldDark = Color(0xFFB48728);
  static const ivory = Color(0xFFF5F1E8);
  static const cream = Color(0xFFD2D0CA);
  static const muted = Color(0xFF8E8982);
  static const terracotta = Color(0xFFB85C38);

  static const goldGradient = LinearGradient(
    colors: [Color(0xFFE3A82D), Color(0xFFEEB843)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData theme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: gold,
      brightness: Brightness.dark,
      primary: gold,
      secondary: terracotta,
      surface: surface,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: obsidian,
      colorScheme: scheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: obsidian,
        foregroundColor: ivory,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: ivory,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF0C0A06),
        selectedItemColor: gold,
        unselectedItemColor: Color(0xFF756F67),
        selectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        type: BottomNavigationBarType.fixed,
        elevation: 12,
      ),
      cardTheme: const CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: Color(0xFF28231C)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: gold,
          foregroundColor: const Color(0xFF1E1607),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
          minimumSize: const Size.fromHeight(52),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceSubtle,
        labelStyle: const TextStyle(color: Color(0xFFA09B93)),
        hintStyle: const TextStyle(color: Color(0xFF6B665E)),
        prefixIconColor: gold,
        suffixIconColor: gold,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF332C24)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF332C24)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: gold, width: 1.5),
        ),
      ),
      dividerColor: const Color(0xFF241F17),
    );
  }

  static Widget badge(String label, {Color? bg, Color? fg}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: bg ?? gold,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: fg ?? const Color(0xFF1E1607),
            letterSpacing: 0.5,
          ),
        ),
      );
}
