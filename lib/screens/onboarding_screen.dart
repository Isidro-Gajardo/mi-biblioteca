import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import 'biblioteca_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _paginaActual = 0;

  final List<Map<String, dynamic>> _slides = [
    {
      'icono': Icons.menu_book_rounded,
      'titulo': 'Tu biblioteca personal',
      'descripcion':
          'Importa tus PDFs y tenlos siempre a mano. '
          'Organiza tus libros, apuntes y documentos en un solo lugar.',
      'color': AppTheme.cafe4,
    },
    {
      'icono': Icons.chrome_reader_mode_outlined,
      'titulo': 'Modo lectura inteligente',
      'descripcion':
          'Lee tus PDFs como si fueran libros digitales. '
          'Ajusta la fuente, el espaciado y el tema a tu gusto.',
      'color': AppTheme.cafe5,
    },
    {
      'icono': Icons.highlight,
      'titulo': 'Subrayados y notas',
      'descripcion':
          'Selecciona texto y subraya con 4 colores distintos. '
          'Todas tus marcas quedan guardadas y organizadas por página.',
      'color': AppTheme.cafe3,
    },
    {
      'icono': Icons.document_scanner_outlined,
      'titulo': 'PDFs escaneados',
      'descripcion':
          'La app detecta si tu PDF es escaneado y puede extraer '
          'el texto con OCR para que también puedas leerlo en modo lectura.',
      'color': AppTheme.cafe4,
    },
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _terminar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completado', true);
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const BibliotecaScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.fondoOscuro,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _paginaActual < _slides.length - 1
                    ? TextButton(
                        onPressed: _terminar,
                        child: Text(
                          'Saltar',
                          style: GoogleFonts.inter(
                            color: AppTheme.textoGris,
                            fontSize: 14,
                          ),
                        ),
                      )
                    : const SizedBox(height: 40),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _paginaActual = i),
                itemCount: _slides.length,
                itemBuilder: (_, i) => _buildSlide(_slides[i]),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _slides.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _paginaActual == i ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _paginaActual == i
                        ? AppTheme.cafe4
                        : AppTheme.cafe3.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (_paginaActual < _slides.length - 1) {
                      _controller.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    } else {
                      _terminar();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.cafe4,
                    foregroundColor: AppTheme.cafe8,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    _paginaActual < _slides.length - 1
                        ? 'Siguiente'
                        : 'Comenzar',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSlide(Map<String, dynamic> slide) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: (slide['color'] as Color).withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(
                color: (slide['color'] as Color).withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Icon(
              slide['icono'] as IconData,
              size: 56,
              color: slide['color'] as Color,
            ),
          ),

          const SizedBox(height: 48),

          Text(
            slide['titulo'] as String,
            textAlign: TextAlign.center,
            style: GoogleFonts.merriweather(
              color: AppTheme.textoClaro,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
          ),

          const SizedBox(height: 20),

          Text(
            slide['descripcion'] as String,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: AppTheme.textoGris,
              fontSize: 15,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
