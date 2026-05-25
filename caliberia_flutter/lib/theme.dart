import 'package:flutter/material.dart';

class AppColors {
  static const zinc50 = Color(0xFFFAFAFA);
  static const zinc100 = Color(0xFFF4F4F5);
  static const zinc200 = Color(0xFFE4E4E7);
  static const zinc300 = Color(0xFFD4D4D8);
  static const zinc400 = Color(0xFFA1A1AA);
  static const zinc500 = Color(0xFF71717A);
  static const zinc600 = Color(0xFF52525B);
  static const zinc700 = Color(0xFF3F3F46);
  static const zinc800 = Color(0xFF27272A);
  static const zinc900 = Color(0xFF18181B);
  static const zinc950 = Color(0xFF09090B);

  static const emerald400 = Color(0xFF34D399);
  static const emerald500 = Color(0xFF10B981);
  static const emerald600 = Color(0xFF059669);

  static const red400 = Color(0xFFF87171);
  static const red500 = Color(0xFFEF4444);

  static const amber400 = Color(0xFFFBBF24);
  static const blue400 = Color(0xFF60A5FA);
}

class AppTheme {
  static ThemeData get darkTheme => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.zinc950,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.emerald500,
          secondary: AppColors.emerald400,
          surface: AppColors.zinc900,
          error: AppColors.red500,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.zinc950,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: AppColors.zinc900,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.emerald500,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.zinc900,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.zinc700),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.zinc700),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.emerald500),
          ),
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          headlineMedium: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          bodyLarge: TextStyle(fontSize: 14, color: AppColors.zinc300),
          bodyMedium: TextStyle(fontSize: 13, color: AppColors.zinc400),
          labelSmall: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: AppColors.zinc500,
            letterSpacing: 2,
          ),
        ),
      );
}
