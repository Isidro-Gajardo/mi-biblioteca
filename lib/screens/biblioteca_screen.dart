import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/libro.dart';
import '../services/storage_service.dart';
import '../services/pdf_service.dart';
import '../theme/app_theme.dart';
import '../widgets/libro_card.dart';
import 'lector_screen.dart';

class BibliotecaScreen extends StatefulWidget {
  const BibliotecaScreen({super.key});

  @override
  State<BibliotecaScreen> createState() => _BibliotecaScreenState();
}

class _BibliotecaScreenState extends State<BibliotecaScreen> {
  final _storage = StorageService();
  final _pdfService = PdfService();
  List<Libro> _libros = [];
  bool _subiendo = false;
  String _busqueda = '';
  String _ordenamiento = 'fecha';

  @override
  void initState() {
    super.initState();
    _storage.init();
    _storage.limpiarOCRAtascados();
    _cargarLibros();
  }

  void _cargarLibros() {
    setState(() {
      _libros = _storage.obtenerLibros();
    });
  }

  List<Libro> get _librosFiltrados {
    List<Libro> resultado = _libros;

    if (_busqueda.isNotEmpty) {
      resultado = resultado
          .where(
            (l) => l.titulo.toLowerCase().contains(_busqueda.toLowerCase()),
          )
          .toList();
    }

    switch (_ordenamiento) {
      case 'nombre':
        resultado.sort((a, b) => a.titulo.compareTo(b.titulo));
        break;
      case 'fecha':
        resultado.sort((a, b) => b.fechaAgregado.compareTo(a.fechaAgregado));
        break;
      case 'lectura':
        resultado.sort((a, b) {
          if (a.fechaUltimaLectura == null) return 1;
          if (b.fechaUltimaLectura == null) return -1;
          return b.fechaUltimaLectura!.compareTo(a.fechaUltimaLectura!);
        });
        break;
    }

    return resultado;
  }

  Future<void> _procesarOCR(Libro libro) async {
    int paginaOCR = 0;
    StateSetter? _setDialogState;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => WillPopScope(
        onWillPop: () async => false,
        child: StatefulBuilder(
          builder: (ctx, setDialogState) {
            _setDialogState = setDialogState;
            return AlertDialog(
              backgroundColor: AppTheme.fondoTarjeta,
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Procesando OCR',
                    style: GoogleFonts.inter(
                      color: AppTheme.textoClaro,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: libro.totalPaginas > 0
                        ? paginaOCR / libro.totalPaginas
                        : 0,
                    backgroundColor: AppTheme.fondoOscuro,
                    color: AppTheme.azulPrimario,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Página $paginaOCR de ${libro.totalPaginas}',
                    style: GoogleFonts.inter(
                      color: AppTheme.textoGris,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No cierres la app durante el proceso',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: AppTheme.amarilloSubrayado,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );

    try {
      await _storage.procesarOCR(
        libro.id,
        onProgreso: (pagina, total) {
          paginaOCR = pagina;
          _setDialogState?.call(() {});
        },
      );

      if (mounted) Navigator.pop(context);
      _cargarLibros();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Modo lectura activado')));
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error en OCR: $e')));
      }
    }
  }

  Future<void> _importarPDF() async {
    final resultado = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (resultado == null || resultado.files.isEmpty) return;

    final archivo = resultado.files.first;
    if (archivo.path == null) return;

    setState(() => _subiendo = true);

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          backgroundColor: AppTheme.fondoTarjeta,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppTheme.azulPrimario),
              const SizedBox(height: 16),
              Text(
                'Analizando PDF...',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: AppTheme.textoClaro),
              ),
            ],
          ),
        ),
      );
    }

    try {
      final ruta = archivo.path!;
      final totalPaginas = await _pdfService.obtenerTotalPaginas(ruta);
      final tieneTexto = await _pdfService.tieneTextoExtraible(ruta);
      final titulo = archivo.name
          .replaceAll('.pdf', '')
          .replaceAll('_', ' ')
          .replaceAll('-', ' ')
          .trim()
          .split(' ')
          .where((p) => p.isNotEmpty)
          .map((p) => p[0].toUpperCase() + p.substring(1))
          .join(' ');

      if (mounted) Navigator.pop(context);

      bool usarOCR = false;
      if (!tieneTexto && mounted) {
        usarOCR =
            await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: AppTheme.fondoTarjeta,
                title: Text(
                  'PDF escaneado detectado',
                  style: GoogleFonts.inter(color: AppTheme.textoClaro),
                ),
                content: Text(
                  'Este PDF parece ser escaneado.\n\n'
                  '¿Quieres extraer el texto con OCR para habilitar '
                  'el modo lectura?\n\n'
                  'Ten en cuenta que el resultado puede no ser perfecto '
                  'y puede tardar varios minutos.',
                  style: GoogleFonts.inter(color: AppTheme.textoGris),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(
                      'No, solo visor',
                      style: TextStyle(color: AppTheme.textoGris),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(
                      'Sí, usar OCR',
                      style: TextStyle(color: AppTheme.azulPrimario),
                    ),
                  ),
                ],
              ),
            ) ??
            false;
      }
      if (usarOCR) {
        int paginaOCR = 0;
        StateSetter? _setDialogState;

        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => StatefulBuilder(
              builder: (ctx, setDialogState) {
                _setDialogState = setDialogState;
                return AlertDialog(
                  backgroundColor: AppTheme.fondoTarjeta,
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Procesando OCR',
                        style: GoogleFonts.inter(
                          color: AppTheme.textoClaro,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      LinearProgressIndicator(
                        value: totalPaginas > 0 ? paginaOCR / totalPaginas : 0,
                        backgroundColor: AppTheme.fondoOscuro,
                        color: AppTheme.azulPrimario,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Página $paginaOCR de $totalPaginas',
                        style: GoogleFonts.inter(
                          color: AppTheme.textoGris,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Esto puede tardar varios minutos\nsegún el tamaño del PDF',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: AppTheme.textoGris.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        }

        await _storage.agregarLibro(
          rutaOriginal: ruta,
          titulo: titulo,
          totalPaginas: totalPaginas,
          tieneTexto: tieneTexto,
          usarOCR: true,
          onProgreso: (pagina, total) {
            paginaOCR = pagina;
            _setDialogState?.call(() {});
          },
        );
      } else {
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => AlertDialog(
              backgroundColor: AppTheme.fondoTarjeta,
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: AppTheme.azulPrimario),
                  const SizedBox(height: 16),
                  Text(
                    'Procesando PDF...\nEsto puede tomar unos segundos',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(color: AppTheme.textoClaro),
                  ),
                ],
              ),
            ),
          );
        }

        await _storage.agregarLibro(
          rutaOriginal: ruta,
          titulo: titulo,
          totalPaginas: totalPaginas,
          tieneTexto: tieneTexto,
        );
      }

      if (mounted) Navigator.pop(context);
      _cargarLibros();
    } catch (e) {
      if (mounted) {
        try {
          Navigator.pop(context);
        } catch (_) {}

        String mensajeError = 'Error al importar el PDF';

        if (e.toString().contains('password') ||
            e.toString().contains('encrypted')) {
          mensajeError = 'Este PDF está protegido con contraseña';
        } else if (e.toString().contains('corrupt') ||
            e.toString().contains('invalid')) {
          mensajeError = 'El PDF parece estar dañado o no es válido';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensajeError),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }

    setState(() => _subiendo = false);
  }

  Future<void> _editarTitulo(Libro libro) async {
    final controller = TextEditingController(text: libro.titulo);
    final nuevo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.fondoTarjeta,
        title: Text(
          'Editar título',
          style: GoogleFonts.inter(color: AppTheme.textoClaro),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textoClaro),
          decoration: InputDecoration(
            hintText: 'Título del libro',
            hintStyle: TextStyle(color: AppTheme.textoGris),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: AppTheme.textoGris),
              borderRadius: BorderRadius.circular(8),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: AppTheme.azulPrimario),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancelar',
              style: TextStyle(color: AppTheme.textoGris),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text(
              'Guardar',
              style: TextStyle(color: AppTheme.azulPrimario),
            ),
          ),
        ],
      ),
    );

    if (nuevo != null && nuevo.isNotEmpty && nuevo != libro.titulo) {
      await _storage.actualizarTitulo(libro.id, nuevo);
      _cargarLibros();
    }
  }

  Future<void> _eliminarLibro(Libro libro) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.fondoTarjeta,
        title: Text(
          'Eliminar libro',
          style: GoogleFonts.inter(color: AppTheme.textoClaro),
        ),
        content: Text(
          '¿Eliminar "${libro.titulo}"? Esta acción no se puede deshacer.',
          style: TextStyle(color: AppTheme.textoGris),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancelar',
              style: TextStyle(color: AppTheme.textoGris),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await _storage.eliminarLibro(libro.id);
      _cargarLibros();
    }
  }

  void _abrirLibro(Libro libro) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LectorScreen(libro: libro)),
    ).then((_) => _cargarLibros());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.fondoOscuro,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Mi Biblioteca',
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textoClaro,
                    ),
                  ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.2),
                  ElevatedButton.icon(
                    onPressed: _subiendo ? null : _importarPDF,
                    icon: _subiendo
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add, size: 18),
                    label: Text(_subiendo ? 'Importando...' : 'Subir PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.azulPrimario,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ).animate().fadeIn(duration: 400.ms),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (v) => setState(() => _busqueda = v),
                      style: const TextStyle(color: AppTheme.textoClaro),
                      decoration: InputDecoration(
                        hintText: 'Buscar...',
                        hintStyle: const TextStyle(color: AppTheme.textoGris),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: AppTheme.textoGris,
                        ),
                        filled: true,
                        fillColor: AppTheme.fondoTarjeta,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  PopupMenuButton<String>(
                    color: AppTheme.fondoTarjeta,
                    icon: const Icon(Icons.sort, color: AppTheme.textoGris),
                    onSelected: (v) => setState(() => _ordenamiento = v),
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'fecha',
                        child: Text(
                          'Por fecha',
                          style: TextStyle(color: AppTheme.textoClaro),
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'nombre',
                        child: Text(
                          'Por nombre',
                          style: TextStyle(color: AppTheme.textoClaro),
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'lectura',
                        child: Text(
                          'Última lectura',
                          style: TextStyle(color: AppTheme.textoClaro),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _librosFiltrados.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.menu_book_rounded,
                            size: 64,
                            color: AppTheme.textoGris,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _busqueda.isNotEmpty
                                ? 'No se encontraron libros'
                                : 'Tu biblioteca está vacía',
                            style: GoogleFonts.inter(
                              color: AppTheme.textoGris,
                              fontSize: 16,
                            ),
                          ),
                          if (_busqueda.isEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Presiona "Subir PDF" para comenzar',
                              style: GoogleFonts.inter(
                                color: AppTheme.textoGris.withOpacity(0.6),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ],
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 20,
                            childAspectRatio: 0.62,
                          ),
                      itemCount: _librosFiltrados.length,
                      itemBuilder: (ctx, i) {
                        final libro = _librosFiltrados[i];
                        return LibroCard(
                          key: ValueKey(libro.id),
                          libro: libro,
                          onTap: () => _abrirLibro(libro),
                          onEditar: () => _editarTitulo(libro),
                          onEliminar: () => _eliminarLibro(libro),
                          onOCR: () => _procesarOCR(libro),
                        ).animate().fadeIn(
                          duration: 300.ms,
                          delay: (i * 50).ms,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
