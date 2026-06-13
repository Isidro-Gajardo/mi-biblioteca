import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color cafe1 = Color(0xFF1C0A00);
  static const Color cafe2 = Color(0xFF3D1C02);
  static const Color cafe3 = Color(0xFF6B3A2A);
  static const Color cafe4 = Color(0xFF9C6B4E);
  static const Color cafe5 = Color(0xFFC4956A);
  static const Color cafe6 = Color(0xFFDEB898);
  static const Color cafe7 = Color(0xFFEDD5B8);
  static const Color cafe8 = Color(0xFFF5EDE0);

  static const Color fondoOscuro = cafe1;
  static const Color fondoTarjeta = cafe2;
  static const Color azulPrimario = cafe4;
  static const Color textoClaro = cafe8;
  static const Color textoGris = cafe6;
  static const Color amarilloSubrayado = Color(0xFFFBBF24);
  static const Color verdeTeal = cafe5;

  static const Map<String, Map<String, Color>> temasLectura = {
    'claro': {
      'fondo': Color(0xFFF5EDE0),
      'texto': Color(0xFF1C0A00),
      'barra': Color(0xFFEDD5B8),
    },
    'oscuro': {
      'fondo': Color(0xFF1C0A00),
      'texto': Color(0xFFEDD5B8),
      'barra': Color(0xFF3D1C02),
    },
    'sepia': {
      'fondo': Color(0xFFDEB898),
      'texto': Color(0xFF3D1C02),
      'barra': Color(0xFFC4956A),
    },
  };

  static ThemeData get temaOscuro {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: fondoOscuro,
      colorScheme: const ColorScheme.dark(
        primary: cafe4,
        surface: cafe2,
        onSurface: cafe8,
      ),
      textTheme: GoogleFonts.interTextTheme(
        ThemeData.dark().textTheme,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: cafe2,
        foregroundColor: cafe8,
        elevation: 0,
      ),
      cardTheme: const CardThemeData(
        color: cafe2,
        elevation: 0,
      ),
    );
  }
}
