import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/libro.dart';
import '../theme/app_theme.dart';

class ResultadoBusqueda {
  final int pagina;
  final String fragmento;
  final String palabraClave;

  ResultadoBusqueda({
    required this.pagina,
    required this.fragmento,
    required this.palabraClave,
  });
}

class BusquedaScreen extends StatefulWidget {
  final Libro libro;

  const BusquedaScreen({super.key, required this.libro});

  @override
  State<BusquedaScreen> createState() => _BusquedaScreenState();
}

class _BusquedaScreenState extends State<BusquedaScreen> {
  final _controller = TextEditingController();
  List<ResultadoBusqueda> _resultados = [];
  bool _buscando = false;
  bool _buscado = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _buscar(String query) {
    if (query.trim().isEmpty) {
      setState(() {
        _resultados = [];
        _buscado = false;
      });
      return;
    }

    setState(() => _buscando = true);

    final queryLower = query.trim().toLowerCase();
    final resultados = <ResultadoBusqueda>[];

    // Primero es buscar frase exacta
    for (int i = 0; i < widget.libro.textoPaginas.length; i++) {
      final textoPagina = widget.libro.textoPaginas[i];
      final textoLower = textoPagina.toLowerCase();

      int posicion = textoLower.indexOf(queryLower);
      int contadorPagina = 0;

      while (posicion != -1 && contadorPagina < 3) {
        final inicio = (posicion - 150).clamp(0, textoPagina.length);
        final fin = (posicion + queryLower.length + 150).clamp(
          0,
          textoPagina.length,
        );

        String fragmento = textoPagina
            .substring(inicio, fin)
            .trim()
            .replaceAll('\n', ' ');

        final prefijo = inicio > 0 ? '...' : '';
        final sufijo = fin < textoPagina.length ? '...' : '';

        resultados.add(
          ResultadoBusqueda(
            pagina: i + 1,
            fragmento: '$prefijo$fragmento$sufijo',
            palabraClave: queryLower,
          ),
        );

        posicion = textoLower.indexOf(queryLower, posicion + 1);
        contadorPagina++;
      }
    }

    // Si no hay resultados exactos, buscar por palabras clave
    if (resultados.isEmpty) {
      final palabras = queryLower
          .split(' ')
          .where((p) => p.length >= 3)
          .toList();

      for (int i = 0; i < widget.libro.textoPaginas.length; i++) {
        final textoPagina = widget.libro.textoPaginas[i];
        final textoLower = textoPagina.toLowerCase();

        for (final palabra in palabras) {
          int posicion = textoLower.indexOf(palabra);
          int contadorPagina = 0;

          while (posicion != -1 && contadorPagina < 2) {
            final inicio = (posicion - 150).clamp(0, textoPagina.length);
            final fin = (posicion + palabra.length + 150).clamp(
              0,
              textoPagina.length,
            );

            String fragmento = textoPagina
                .substring(inicio, fin)
                .trim()
                .replaceAll('\n', ' ');

            final prefijo = inicio > 0 ? '...' : '';
            final sufijo = fin < textoPagina.length ? '...' : '';
            
            final yaExiste = resultados.any(
              (r) =>
                  r.pagina == i + 1 &&
                  r.fragmento == '$prefijo$fragmento$sufijo',
            );

            if (!yaExiste) {
              resultados.add(
                ResultadoBusqueda(
                  pagina: i + 1,
                  fragmento: '$prefijo$fragmento$sufijo',
                  palabraClave: palabra,
                ),
              );
            }

            posicion = textoLower.indexOf(palabra, posicion + 1);
            contadorPagina++;
          }
        }
      }
    }

    resultados.sort((a, b) => a.pagina.compareTo(b.pagina));

    setState(() {
      _resultados = resultados;
      _buscando = false;
      _buscado = true;
    });
  }

  List<TextSpan> _resaltarTexto(
    String fragmento,
    String palabra,
    Color colorTexto,
  ) {
    final spans = <TextSpan>[];
    final lower = fragmento.toLowerCase();
    int inicio = 0;

    int pos = lower.indexOf(palabra.toLowerCase());
    while (pos != -1) {
      if (pos > inicio) {
        spans.add(
          TextSpan(
            text: fragmento.substring(inicio, pos),
            style: GoogleFonts.merriweather(
              color: colorTexto,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        );
      }

      spans.add(
        TextSpan(
          text: fragmento.substring(pos, pos + palabra.length),
          style: GoogleFonts.merriweather(
            color: Colors.black87,
            fontSize: 13,
            height: 1.5,
            backgroundColor: AppTheme.amarilloSubrayado,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

      inicio = pos + palabra.length;
      pos = lower.indexOf(palabra.toLowerCase(), inicio);
    }

    if (inicio < fragmento.length) {
      spans.add(
        TextSpan(
          text: fragmento.substring(inicio),
          style: GoogleFonts.merriweather(
            color: colorTexto,
            fontSize: 13,
            height: 1.5,
          ),
        ),
      );
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.fondoOscuro,
      appBar: AppBar(
        backgroundColor: AppTheme.fondoTarjeta,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: AppTheme.textoClaro,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _controller,
          autofocus: true,
          style: GoogleFonts.inter(color: AppTheme.textoClaro, fontSize: 15),
          decoration: InputDecoration(
            hintText: 'Buscar en "${widget.libro.titulo}"...',
            hintStyle: GoogleFonts.inter(
              color: AppTheme.textoGris,
              fontSize: 15,
            ),
            border: InputBorder.none,
          ),
          onChanged: _buscar,
          onSubmitted: _buscar,
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close, color: AppTheme.textoGris),
              onPressed: () {
                _controller.clear();
                _buscar('');
              },
            ),
        ],
      ),
      body: _buscando
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.azulPrimario),
            )
          : !_buscado
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.search, size: 64, color: AppTheme.textoGris),
                  const SizedBox(height: 16),
                  Text(
                    'Escribe para buscar en el libro',
                    style: GoogleFonts.inter(
                      color: AppTheme.textoGris,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${widget.libro.totalPaginas} páginas disponibles',
                    style: GoogleFonts.inter(
                      color: AppTheme.textoGris.withOpacity(0.6),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            )
          : _resultados.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.search_off,
                    size: 64,
                    color: AppTheme.textoGris,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Sin resultados para "${_controller.text}"',
                    style: GoogleFonts.inter(
                      color: AppTheme.textoGris,
                      fontSize: 15,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Contador de resultados
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  color: AppTheme.fondoTarjeta,
                  child: Text(
                    '${_resultados.length} resultado${_resultados.length != 1 ? 's' : ''} encontrado${_resultados.length != 1 ? 's' : ''}',
                    style: GoogleFonts.inter(
                      color: AppTheme.textoGris,
                      fontSize: 13,
                    ),
                  ),
                ),
                // Lista de resultados
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _resultados.length,
                    separatorBuilder: (_, __) =>
                        const Divider(color: Colors.white12, height: 24),
                    itemBuilder: (_, i) {
                      final r = _resultados[i];
                      return GestureDetector(
                        onTap: () => Navigator.pop(context, r.pagina),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.fondoTarjeta,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.06),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Página
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.azulPrimario.withOpacity(
                                        0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Página ${r.pagina}',
                                      style: GoogleFonts.inter(
                                        color: AppTheme.azulPrimario,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.arrow_forward_ios,
                                    size: 12,
                                    color: AppTheme.textoGris,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              // Fragmento con resaltado
                              RichText(
                                text: TextSpan(
                                  children: _resaltarTexto(
                                    r.fragmento,
                                    r.palabraClave,
                                    AppTheme.textoGris,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
