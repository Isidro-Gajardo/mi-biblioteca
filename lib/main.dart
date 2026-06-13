import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/libro.dart';
import 'models/subrayado.dart';
import 'screens/biblioteca_screen.dart';
import 'screens/onboarding_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(LibroAdapter());
  Hive.registerAdapter(SubrayadoAdapter());
  await Hive.openBox<Libro>('libros');
  await Hive.openBox<Subrayado>('subrayados');

  final prefs = await SharedPreferences.getInstance();
  final onboardingCompletado =
      prefs.getBool('onboarding_completado') ?? false;

  runApp(MiBibliotecaApp(
    mostrarOnboarding: !onboardingCompletado,
  ));
}

class MiBibliotecaApp extends StatelessWidget {
  final bool mostrarOnboarding;
  const MiBibliotecaApp({super.key, required this.mostrarOnboarding});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mi Biblioteca',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.temaOscuro,
      home: mostrarOnboarding
          ? const OnboardingScreen()
          : const BibliotecaScreen(),
    );
  }
}