import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const primaryGreen = Color(0xFF4CAF50);
  static const secondaryTeal = Color(0xFF009688);
  static const backgroundLight = Color(0xFFF5F5F5);
  static const backgroundDark = Color(0xFF1E1E1E);
  static const cardLight = Colors.white;
  static const cardDark = Color(0xFF2D2D2D);

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryGreen,
      brightness: Brightness.light,
      background: backgroundLight,
      surface: cardLight,
    ),
    textTheme: GoogleFonts.poppinsTextTheme(),
    cardTheme: CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
    ),
    appBarTheme: AppBarTheme(
      elevation: 0,
      backgroundColor: cardLight,
      foregroundColor: Colors.black,
      centerTitle: true,
      titleTextStyle: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Colors.black,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      elevation: 8,
      backgroundColor: cardLight,
      indicatorShape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      labelTextStyle: MaterialStateProperty.all(
        GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryGreen,
      brightness: Brightness.dark,
      background: backgroundDark,
      surface: cardDark,
    ),
    textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
    cardTheme: CardThemeData(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      color: cardDark,
    ),
    appBarTheme: AppBarTheme(
      elevation: 0,
      backgroundColor: cardDark,
      centerTitle: true,
      titleTextStyle: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      elevation: 8,
      backgroundColor: cardDark,
      indicatorShape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      labelTextStyle: MaterialStateProperty.all(
        GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );
}
