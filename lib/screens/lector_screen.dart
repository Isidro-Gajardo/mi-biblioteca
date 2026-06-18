import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdfx/pdfx.dart';
import '../models/libro.dart';
import '../models/subrayado.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'busqueda_screen.dart';

List<Map<String, dynamic>> _reconstruirParrafosIsolate(String texto) {
  String textoLimpio = texto
      .replaceAll(RegExp(r'[\u00A0\u1680\u2000-\u200A\u202F\u205F\u3000]'), ' ')
      .replaceAll(RegExp(r'[ \t]+'), ' ')
      .replaceAll(RegExp(r'- \n'), '')
      .replaceAll(RegExp(r'-\n'), '')
      .replaceAllMapped(RegExp(r',\n'), (m) => ', ')
      .replaceAllMapped(RegExp(r';\n'), (m) => '; ')
      .replaceAllMapped(RegExp(r':\n'), (m) => ': ');

  final lineas = textoLimpio.split('\n').map((l) => l.trim()).toList();
  final bloques = <Map<String, dynamic>>[];
  final buffer = StringBuffer();

  for (int i = 0; i < lineas.length; i++) {
    final linea = lineas[i];

    if (linea.isEmpty) {
      if (buffer.isNotEmpty) {
        bloques.add({'tipo': 'parrafo', 'texto': buffer.toString().trim()});
        buffer.clear();
      }
      continue;
    }

    final esMayusculas =
        linea == linea.toUpperCase() &&
        linea.length > 3 &&
        linea.length < 80 &&
        RegExp(r'[A-ZÁÉÍÓÚÑ]').hasMatch(linea);
    final esCapitulo = RegExp(
      r'^(Cap[íi]tulo|CAPÍTULO|Chapter|CHAPTER|Parte|PARTE|\d+\.)\s',
    ).hasMatch(linea);
    final esTituloAislado =
        linea.length < 40 &&
        !linea.endsWith('.') &&
        !linea.endsWith(',') &&
        !linea.endsWith(';') &&
        !linea.endsWith(':') &&
        !linea.contains(',') &&
        i < lineas.length - 1 &&
        (i == 0 || lineas[i - 1].isEmpty) &&
        lineas[i + 1].isEmpty;

    if (esMayusculas || esCapitulo || esTituloAislado) {
      if (buffer.isNotEmpty) {
        bloques.add({'tipo': 'parrafo', 'texto': buffer.toString().trim()});
        buffer.clear();
      }
      bloques.add({'tipo': 'titulo', 'texto': linea});
      continue;
    }

    if (buffer.isNotEmpty) {
      final bufferStr = buffer.toString();
      if (bufferStr.endsWith('-')) {
        buffer.clear();
        buffer.write(bufferStr.substring(0, bufferStr.length - 1) + linea);
      } else {
        buffer.write(' $linea');
      }
    } else {
      buffer.write(linea);
    }

    if (linea.endsWith('.') ||
        linea.endsWith('!') ||
        linea.endsWith('?') ||
        linea.endsWith('."') ||
        linea.endsWith('!"') ||
        linea.endsWith('?"')) {
      final siguiente = i < lineas.length - 1 ? lineas[i + 1].trim() : '';
      if (siguiente.isEmpty ||
          (siguiente.isNotEmpty &&
              siguiente[0] == siguiente[0].toUpperCase() &&
              siguiente.length > 3)) {
        bloques.add({'tipo': 'parrafo', 'texto': buffer.toString().trim()});
        buffer.clear();
      }
    }
  }

  if (buffer.isNotEmpty) {
    bloques.add({'tipo': 'parrafo', 'texto': buffer.toString().trim()});
  }

  return bloques;
}

class _Segmento {
  final int inicio;
  final int fin;
  final List<String> colores;
  const _Segmento({
    required this.inicio,
    required this.fin,
    required this.colores,
  });
}

class LectorScreen extends StatefulWidget {
  final Libro libro;
  const LectorScreen({super.key, required this.libro});

  @override
  State<LectorScreen> createState() => _LectorScreenState();
}

class _LectorScreenState extends State<LectorScreen>
    with SingleTickerProviderStateMixin {
  final _storage = StorageService();

  late PdfController _pdfController;
  final PageController _pageController = PageController();
  final Map<int, List<Map<String, dynamic>>> _cacheParrafos = {};

  bool _barrasVisibles = true;
  bool _modoLectura = false;
  int _paginaActual = 1;

  String _textoSeleccionado = '';
  OverlayEntry? _overlaySubrayar;

  double _tamanoFuente = 16;
  double _espaciado = 1.7;
  String _temaActual = 'claro';
  String _alineacion = 'justificado';

  List<Subrayado> _subrayados = [];
  bool _panelSubrayadosVisible = false;

  static const Map<String, Color> _coloresSubrayado = {
    'amarillo': Color(0xFFFBBF24),
    'verde': Color(0xFF6EE7B7),
    'rojo': Color(0xFFFCA5A5),
    'azul': Color(0xFF93C5FD),
  };

  TextAlign get _textAlign =>
      _alineacion == 'justificado' ? TextAlign.justify : TextAlign.left;

  @override
  void initState() {
    super.initState();
    _pdfController = PdfController(
      document: PdfDocument.openFile(widget.libro.rutaArchivo),
      initialPage: widget.libro.ultimaPagina > 0
          ? widget.libro.ultimaPagina
          : 1,
    );
    _paginaActual = widget.libro.ultimaPagina > 0
        ? widget.libro.ultimaPagina
        : 1;
    _cargarSubrayados();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _overlaySubrayar?.remove();
    _pdfController.dispose();
    _pageController.dispose();
    _cacheParrafos.clear();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _storage.guardarProgreso(widget.libro.id, _paginaActual);
    super.dispose();
  }

  void _cargarSubrayados() {
    setState(() {
      _subrayados = _storage.obtenerSubrayados(widget.libro.id);
    });
  }

  Future<void> _agregarSubrayado(String texto) async {
    if (texto.trim().isEmpty) return;
    await _storage.agregarSubrayado(
      libroId: widget.libro.id,
      pagina: _paginaActual,
      texto: texto.trim(),
    );
    setState(() {
      _subrayados = _storage.obtenerSubrayados(widget.libro.id);
    });
  }

  Future<void> _agregarSubrayadoConColor(String texto, String color) async {
    if (texto.trim().isEmpty) return;
    await _storage.agregarSubrayado(
      libroId: widget.libro.id,
      pagina: _paginaActual,
      texto: texto.trim(),
      color: color,
    );
    setState(() {
      _subrayados = _storage.obtenerSubrayados(widget.libro.id);
    });
  }

  void _toggleBarras() {
    setState(() => _barrasVisibles = !_barrasVisibles);
  }

  void _toggleModoLectura() {
    if (!widget.libro.tieneTexto) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este PDF no tiene texto extraíble'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    setState(() => _modoLectura = !_modoLectura);
    if (_modoLectura) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _pageController.jumpToPage(_paginaActual - 1);
      });
    } else {
      Future.delayed(const Duration(milliseconds: 100), () {
        _pdfController.jumpToPage(_paginaActual);
      });
    }
  }

  Future<List<Map<String, dynamic>>> _obtenerParrafos(int index) async {
    if (_cacheParrafos.containsKey(index)) return _cacheParrafos[index]!;
    final texto = widget.libro.textoPaginas[index];
    final bloques = await compute(_reconstruirParrafosIsolate, texto);
    _cacheParrafos[index] = bloques;
    return bloques;
  }

  void _mostrarBotonSubrayar() {
    _overlaySubrayar?.remove();
    _overlaySubrayar = OverlayEntry(
      builder: (_) => Positioned(
        bottom: 100,
        left: 0,
        right: 0,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.fondoTarjeta,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Subrayar:',
                  style: GoogleFonts.inter(
                    color: AppTheme.textoGris,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 12),
                _botonColor('amarillo', const Color(0xFFFBBF24)),
                const SizedBox(width: 8),
                _botonColor('verde', const Color(0xFF34D399)),
                const SizedBox(width: 8),
                _botonColor('rojo', const Color(0xFFF87171)),
                const SizedBox(width: 8),
                _botonColor('azul', const Color(0xFF60A5FA)),
              ],
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_overlaySubrayar!);
    Future.delayed(const Duration(seconds: 8), () {
      _overlaySubrayar?.remove();
      _overlaySubrayar = null;
    });
  }

  Widget _botonColor(String nombreColor, Color color) {
    return GestureDetector(
      onTap: () {
        _overlaySubrayar?.remove();
        _overlaySubrayar = null;
        _agregarSubrayadoConColor(_textoSeleccionado, nombreColor);
      },
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarConfiguracion() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.fondoTarjeta,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.textoGris.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Configuración de lectura',
                style: GoogleFonts.inter(
                  color: AppTheme.textoClaro,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Tamaño de fuente',
                style: GoogleFonts.inter(
                  color: AppTheme.textoGris,
                  fontSize: 13,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove, color: AppTheme.textoClaro),
                    onPressed: () {
                      setModalState(() {
                        if (_tamanoFuente > 12) _tamanoFuente -= 1;
                      });
                      setState(() {});
                    },
                  ),
                  Text(
                    '${_tamanoFuente.toInt()}',
                    style: GoogleFonts.inter(
                      color: AppTheme.textoClaro,
                      fontSize: 16,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, color: AppTheme.textoClaro),
                    onPressed: () {
                      setModalState(() {
                        if (_tamanoFuente < 28) _tamanoFuente += 1;
                      });
                      setState(() {});
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Espaciado',
                style: GoogleFonts.inter(
                  color: AppTheme.textoGris,
                  fontSize: 13,
                ),
              ),
              Slider(
                value: _espaciado,
                min: 1.2,
                max: 2.5,
                divisions: 6,
                activeColor: AppTheme.azulPrimario,
                onChanged: (v) {
                  setModalState(() => _espaciado = v);
                  setState(() {});
                },
              ),
              const SizedBox(height: 16),
              Text(
                'Tema',
                style: GoogleFonts.inter(
                  color: AppTheme.textoGris,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _botonTema('claro', 'Claro', setModalState),
                  const SizedBox(width: 12),
                  _botonTema('oscuro', 'Oscuro', setModalState),
                  const SizedBox(width: 12),
                  _botonTema('sepia', 'Sepia', setModalState),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Alineación del texto',
                style: GoogleFonts.inter(
                  color: AppTheme.textoGris,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _botonAlineacion(
                    'justificado',
                    'Justificado',
                    Icons.format_align_justify,
                    setModalState,
                  ),
                  const SizedBox(width: 12),
                  _botonAlineacion(
                    'izquierda',
                    'Izquierda',
                    Icons.format_align_left,
                    setModalState,
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _botonTema(String tema, String etiqueta, StateSetter setModalState) {
    final colores = AppTheme.temasLectura[tema]!;
    final seleccionado = _temaActual == tema;
    return GestureDetector(
      onTap: () {
        setModalState(() => _temaActual = tema);
        setState(() {});
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: colores['fondo'],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: seleccionado ? AppTheme.azulPrimario : Colors.transparent,
            width: 2,
          ),
        ),
        child: Text(
          etiqueta,
          style: GoogleFonts.inter(
            color: colores['texto'],
            fontSize: 13,
            fontWeight: seleccionado ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _botonAlineacion(
    String valor,
    String etiqueta,
    IconData icono,
    StateSetter setModalState,
  ) {
    final seleccionado = _alineacion == valor;
    return GestureDetector(
      onTap: () {
        setModalState(() => _alineacion = valor);
        setState(() {});
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: seleccionado
              ? AppTheme.azulPrimario.withOpacity(0.15)
              : AppTheme.fondoOscuro,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: seleccionado
                ? AppTheme.azulPrimario
                : AppTheme.textoGris.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icono,
              size: 16,
              color: seleccionado ? AppTheme.azulPrimario : AppTheme.textoGris,
            ),
            const SizedBox(width: 6),
            Text(
              etiqueta,
              style: GoogleFonts.inter(
                color: seleccionado
                    ? AppTheme.azulPrimario
                    : AppTheme.textoGris,
                fontSize: 13,
                fontWeight: seleccionado ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarDialogoSubrayado() {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.fondoTarjeta,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Agregar nota — Página $_paginaActual',
              style: GoogleFonts.inter(
                color: AppTheme.textoClaro,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 3,
              style: const TextStyle(color: AppTheme.textoClaro),
              decoration: InputDecoration(
                hintText: 'Escribe una nota para esta página...',
                hintStyle: TextStyle(color: AppTheme.textoGris),
                filled: true,
                fillColor: AppTheme.fondoOscuro,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _agregarSubrayado(controller.text);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.amarilloSubrayado,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'Guardar nota',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = AppTheme.temasLectura[_temaActual]!;

    return Scaffold(
      backgroundColor: _modoLectura ? tema['fondo'] : AppTheme.fondoOscuro,
      body: GestureDetector(
        onTap: _toggleBarras,
        child: Stack(
          children: [
            Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  height: _barrasVisibles
                      ? MediaQuery.of(context).padding.top + 60
                      : 0,
                  child: _barrasVisibles
                      ? _barrasSuperior(tema)
                      : const SizedBox.shrink(),
                ),
                Expanded(
                  child: _modoLectura ? _vistaLectura(tema) : _vistaPDF(),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  height: _barrasVisibles
                      ? MediaQuery.of(context).padding.bottom + 56
                      : 0,
                  child: _barrasVisibles
                      ? _barraInferior(tema)
                      : const SizedBox.shrink(),
                ),
              ],
            ),
            if (_panelSubrayadosVisible) _panelSubrayados(),
          ],
        ),
      ),
    );
  }

  Widget _barrasSuperior(Map<String, Color> tema) {
    return Container(
      color: _modoLectura
          ? tema['barra']!.withOpacity(0.95)
          : AppTheme.fondoTarjeta,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 4,
        bottom: 8,
        left: 8,
        right: 8,
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.arrow_back_ios,
              color: _modoLectura ? tema['texto'] : AppTheme.textoClaro,
              size: 20,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(
              widget.libro.titulo,
              style: GoogleFonts.inter(
                color: _modoLectura ? tema['texto'] : AppTheme.textoClaro,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (widget.libro.tieneTexto)
            IconButton(
              icon: Icon(
                _modoLectura ? Icons.picture_as_pdf : Icons.menu_book,
                color: _modoLectura ? tema['texto'] : AppTheme.textoClaro,
                size: 22,
              ),
              onPressed: _toggleModoLectura,
              tooltip: _modoLectura ? 'Ver PDF' : 'Modo lectura',
            ),
          if (_modoLectura)
            IconButton(
              icon: Icon(Icons.text_fields, color: tema['texto'], size: 22),
              onPressed: _mostrarConfiguracion,
            ),
          IconButton(
            icon: Icon(
              Icons.search,
              color: _modoLectura ? tema['texto'] : AppTheme.textoClaro,
              size: 22,
            ),
            onPressed: () async {
              if (widget.libro.textoPaginas.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Este PDF no tiene texto para buscar'),
                    duration: Duration(seconds: 2),
                  ),
                );
                return;
              }
              final pagina = await Navigator.push<int>(
                context,
                MaterialPageRoute(
                  builder: (_) => BusquedaScreen(libro: widget.libro),
                ),
              );
              if (pagina != null) {
                setState(() {
                  _paginaActual = pagina;
                  _modoLectura = false;
                });
                _pdfController.jumpToPage(pagina);
              }
            },
          ),
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  Icons.bookmark_outline,
                  color: _modoLectura ? tema['texto'] : AppTheme.textoClaro,
                  size: 22,
                ),
                if (_subrayados.isNotEmpty)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: const BoxDecoration(
                        color: AppTheme.amarilloSubrayado,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${_subrayados.length}',
                          style: const TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () => setState(
              () => _panelSubrayadosVisible = !_panelSubrayadosVisible,
            ),
          ),
        ],
      ),
    );
  }

  Widget _barraInferior(Map<String, Color> tema) {
    return Container(
      color: _modoLectura
          ? tema['barra']!.withOpacity(0.95)
          : AppTheme.fondoTarjeta,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 4,
        top: 8,
        left: 16,
        right: 16,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Página $_paginaActual de ${widget.libro.totalPaginas}',
            style: GoogleFonts.inter(
              color: _modoLectura
                  ? tema['texto']!.withOpacity(0.6)
                  : AppTheme.textoGris,
              fontSize: 12,
            ),
          ),
          GestureDetector(
            onTap: _mostrarDialogoSubrayado,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.amarilloSubrayado.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppTheme.amarilloSubrayado.withOpacity(0.5),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.note_add_outlined,
                    color: AppTheme.amarilloSubrayado,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Nota',
                    style: GoogleFonts.inter(
                      color: AppTheme.amarilloSubrayado,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _vistaPDF() {
    return PdfView(
      controller: _pdfController,
      onPageChanged: (page) {
        setState(() => _paginaActual = page);
        _storage.guardarProgreso(widget.libro.id, page);
      },
      builders: PdfViewBuilders<DefaultBuilderOptions>(
        options: const DefaultBuilderOptions(),
        documentLoaderBuilder: (_) => const Center(
          child: CircularProgressIndicator(color: AppTheme.azulPrimario),
        ),
        pageLoaderBuilder: (_) => const Center(
          child: CircularProgressIndicator(color: AppTheme.azulPrimario),
        ),
      ),
    );
  }

  Widget _vistaLectura(Map<String, Color> tema) {
    final paginas = widget.libro.textoPaginas;

    if (paginas.isEmpty) {
      return Center(
        child: Text(
          'No hay texto disponible para este PDF',
          style: GoogleFonts.inter(color: AppTheme.textoGris),
        ),
      );
    }

    return PageView.builder(
      controller: _pageController,
      onPageChanged: (index) {
        setState(() => _paginaActual = index + 1);
        _storage.guardarProgreso(widget.libro.id, index + 1);
      },
      itemCount: paginas.length,
      itemBuilder: (_, index) {
        return FutureBuilder<List<Map<String, dynamic>>>(
          key: ValueKey(index),
          future: _obtenerParrafos(index),
          builder: (ctx, snapshot) {
            if (!snapshot.hasData) {
              return Container(
                color: tema['fondo'],
                child: const Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.azulPrimario,
                    strokeWidth: 2,
                  ),
                ),
              );
            }

            final bloques = snapshot.data!;
            final subrayadosPagina = _subrayados
                .where((s) => s.pagina == index + 1)
                .toList();

            return Container(
              color: tema['fondo'],
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
                itemCount: bloques.length,
                itemBuilder: (_, i) {
                  final bloque = bloques[i];
                  final esTitulo = bloque['tipo'] == 'titulo';
                  final linea = bloque['texto'] as String;
                  final subrayadosEnLinea = subrayadosPagina
                      .where(
                        (s) => s.texto.length > 6 && linea.contains(s.texto),
                      )
                      .toList();

                  if (esTitulo) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 32, bottom: 16),
                      child: Text(
                        linea,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.merriweather(
                          color: tema['texto'],
                          fontSize: _tamanoFuente + 3,
                          fontWeight: FontWeight.bold,
                          height: 1.4,
                          letterSpacing: 0.5,
                        ),
                      ),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: subrayadosEnLinea.isNotEmpty
                        ? _parrafoConSubrayado(linea, subrayadosEnLinea, tema)
                        : SelectableText(
                            linea,
                            textAlign: _textAlign,
                            style: GoogleFonts.merriweather(
                              color: tema['texto'],
                              fontSize: _tamanoFuente,
                              height: _espaciado,
                            ),
                            onSelectionChanged: (selection, cause) {
                              if (selection.baseOffset !=
                                  selection.extentOffset) {
                                final seleccionado = linea.substring(
                                  selection.baseOffset.clamp(0, linea.length),
                                  selection.extentOffset.clamp(0, linea.length),
                                );
                                if (seleccionado.trim().length > 6) {
                                  _textoSeleccionado = seleccionado;
                                  _mostrarBotonSubrayar();
                                }
                              }
                            },
                          ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _parrafoConSubrayado(
    String parrafo,
    List<Subrayado> subrayados,
    Map<String, Color> tema,
  ) {
    final segmentos = _calcularSegmentos(parrafo, subrayados);

    if (segmentos.isEmpty) {
      return SelectableText(
        parrafo,
        textAlign: _textAlign,
        style: GoogleFonts.merriweather(
          color: tema['texto'],
          fontSize: _tamanoFuente,
          height: _espaciado,
        ),
      );
    }

    final spans = <TextSpan>[];

    for (final seg in segmentos) {
      final texto = parrafo.substring(seg.inicio, seg.fin);
      if (texto.isEmpty) continue;

      if (seg.colores.isEmpty) {
        spans.add(
          TextSpan(
            text: texto,
            style: GoogleFonts.merriweather(
              color: tema['texto'],
              fontSize: _tamanoFuente,
              height: _espaciado,
            ),
          ),
        );
      } else {
        final colorFinal =
            _coloresSubrayado[seg.colores.last] ?? AppTheme.amarilloSubrayado;
        spans.add(
          TextSpan(
            text: texto,
            style: GoogleFonts.merriweather(
              color: Colors.black,
              fontSize: _tamanoFuente,
              height: _espaciado,
              fontWeight: FontWeight.w600,
              backgroundColor: colorFinal.withOpacity(1.0),
            ),
          ),
        );
      }
    }

    return SelectableText.rich(
      TextSpan(children: spans),
      textAlign: _textAlign,
      onSelectionChanged: (selection, cause) {
        if (selection.baseOffset != selection.extentOffset) {
          final seleccionado = parrafo.substring(
            selection.baseOffset.clamp(0, parrafo.length),
            selection.extentOffset.clamp(0, parrafo.length),
          );
          if (seleccionado.trim().length > 6) {
            _textoSeleccionado = seleccionado;
            _mostrarBotonSubrayar();
          }
        }
      },
    );
  }

  List<_Segmento> _calcularSegmentos(
    String parrafo,
    List<Subrayado> subrayados,
  ) {
    final Set<int> puntos = {0, parrafo.length};
    final List<({int inicio, int fin, String color})> rangos = [];

    for (final sub in subrayados) {
      int idx = parrafo.indexOf(sub.texto);
      if (idx == -1) {
        idx = parrafo.toLowerCase().indexOf(sub.texto.toLowerCase());
      }
      if (idx == -1) continue;

      final fin = idx + sub.texto.length;
      puntos.add(idx);
      puntos.add(fin);
      rangos.add((inicio: idx, fin: fin, color: sub.color));
    }

    final puntosOrdenados = puntos.toList()..sort();
    final segmentos = <_Segmento>[];

    for (int i = 0; i < puntosOrdenados.length - 1; i++) {
      final inicio = puntosOrdenados[i];
      final fin = puntosOrdenados[i + 1];

      final colores = rangos
          .where((r) => r.inicio <= inicio && r.fin >= fin)
          .map((r) => r.color)
          .toList();

      segmentos.add(_Segmento(inicio: inicio, fin: fin, colores: colores));
    }

    return segmentos;
  }

  Widget _panelSubrayados() {
    final Map<int, List<Subrayado>> porPagina = {};
    for (final s in _subrayados) {
      porPagina.putIfAbsent(s.pagina, () => []).add(s);
    }
    final paginas = porPagina.keys.toList()..sort();

    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      width: MediaQuery.of(context).size.width * 0.85,
      child: GestureDetector(
        onTap: () {},
        child: Container(
          color: AppTheme.fondoTarjeta,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Subrayados y notas',
                        style: GoogleFonts.inter(
                          color: AppTheme.textoClaro,
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: AppTheme.textoGris,
                        ),
                        onPressed: () =>
                            setState(() => _panelSubrayadosVisible = false),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12, height: 1),
                Expanded(
                  child: _subrayados.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.highlight_outlined,
                                size: 48,
                                color: AppTheme.textoGris,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Sin subrayados aún',
                                style: GoogleFonts.inter(
                                  color: AppTheme.textoGris,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: paginas.length,
                          itemBuilder: (_, i) =>
                              _grupoPagina(paginas[i], porPagina[paginas[i]]!),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _grupoPagina(int pagina, List<Subrayado> items) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: false,
        tilePadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        childrenPadding: const EdgeInsets.only(bottom: 12),
        leading: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.azulPrimario.withOpacity(0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            'Pág. $pagina',
            style: GoogleFonts.inter(
              color: AppTheme.azulPrimario,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        title: Row(
          children: [
            ...items
                .take(4)
                .map(
                  (s) => Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color:
                          _coloresSubrayado[s.color] ??
                          AppTheme.amarilloSubrayado,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            const SizedBox(width: 4),
            Text(
              '${items.length} subrayado${items.length != 1 ? 's' : ''}',
              style: GoogleFonts.inter(color: AppTheme.textoGris, fontSize: 12),
            ),
          ],
        ),
        iconColor: AppTheme.textoGris,
        collapsedIconColor: AppTheme.textoGris,
        children: items.map((s) => _itemSubrayado(s)).toList(),
      ),
    );
  }

  Widget _itemSubrayado(Subrayado s) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _paginaActual = s.pagina;
          _panelSubrayadosVisible = false;
          if (!_modoLectura) {
            _pdfController.jumpToPage(s.pagina);
          } else {
            _pageController.jumpToPage(s.pagina - 1);
          }
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.fondoOscuro,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: (_coloresSubrayado[s.color] ?? AppTheme.amarilloSubrayado)
                .withOpacity(0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: (_coloresSubrayado[s.color] ?? AppTheme.amarilloSubrayado)
                  .withOpacity(0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color:
                            _coloresSubrayado[s.color] ??
                            AppTheme.amarilloSubrayado,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Text(
                      '${s.fecha.day}/${s.fecha.month}/${s.fecha.year}',
                      style: GoogleFonts.inter(
                        color: AppTheme.textoGris,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () async {
                    final confirmar = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: AppTheme.fondoTarjeta,
                        title: Text(
                          'Eliminar subrayado',
                          style: GoogleFonts.inter(color: AppTheme.textoClaro),
                        ),
                        content: Text(
                          '¿Seguro que quieres eliminar este subrayado?',
                          style: GoogleFonts.inter(color: AppTheme.textoGris),
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
                      await _storage.eliminarSubrayado(s.id);
                      setState(() {
                        _subrayados = _storage.obtenerSubrayados(
                          widget.libro.id,
                        );
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color:
                    (_coloresSubrayado[s.color] ?? AppTheme.amarilloSubrayado)
                        .withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                s.texto,
                style: GoogleFonts.merriweather(
                  color: AppTheme.textoClaro,
                  fontSize: 13,
                  height: 1.5,
                ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
