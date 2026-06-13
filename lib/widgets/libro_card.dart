import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/libro.dart';
import '../services/pdf_service.dart';
import '../theme/app_theme.dart';
import 'package:pdfx/pdfx.dart';

class LibroCard extends StatefulWidget {
  final Libro libro;
  final VoidCallback onTap;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;
  final VoidCallback onOCR;

  const LibroCard({
    super.key,
    required this.libro,
    required this.onTap,
    required this.onEditar,
    required this.onEliminar,
    required this.onOCR,
  });

  @override
  State<LibroCard> createState() => _LibroCardState();
}

class _LibroCardState extends State<LibroCard> {
  PdfPageImage? _thumbnail;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarThumbnail();
  }

  Future<void> _cargarThumbnail() async {
    final imagen = await PdfService().renderizarPagina(
      widget.libro.rutaArchivo,
      1,
      escala: 0.5,
    );
    if (mounted) {
      setState(() {
        _thumbnail = imagen;
        _cargando = false;
      });
    }
  }

  void _mostrarOpciones(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.fondoTarjeta,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: AppTheme.textoGris.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                widget.libro.titulo,
                style: GoogleFonts.inter(
                  color: AppTheme.textoClaro,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            ListTile(
              leading: const Icon(
                Icons.edit_outlined,
                color: AppTheme.azulPrimario,
              ),
              title: Text(
                'Editar título',
                style: GoogleFonts.inter(color: AppTheme.textoClaro),
              ),
              onTap: () {
                Navigator.pop(context);
                widget.onEditar();
              },
            ),
            // Botón OCR — solo si no tiene texto
            // Botón OCR
            if (!widget.libro.tieneTexto)
              widget.libro.procesandoOCR
                  ? ListTile(
                      leading: const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.verdeTeal,
                        ),
                      ),
                      title: Text(
                        'OCR en proceso...',
                        style: GoogleFonts.inter(color: AppTheme.textoGris),
                      ),
                      subtitle: Text(
                        'El libro se completará pronto',
                        style: GoogleFonts.inter(
                          color: AppTheme.textoGris,
                          fontSize: 11,
                        ),
                      ),
                    )
                  : ListTile(
                      leading: const Icon(
                        Icons.document_scanner_outlined,
                        color: AppTheme.verdeTeal,
                      ),
                      title: Text(
                        'Activar modo lectura (OCR)',
                        style: GoogleFonts.inter(color: AppTheme.verdeTeal),
                      ),
                      subtitle: Text(
                        'Extrae texto del PDF escaneado',
                        style: GoogleFonts.inter(
                          color: AppTheme.textoGris,
                          fontSize: 11,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        widget.onOCR();
                      },
                    ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: Colors.redAccent,
              ),
              title: Text(
                'Eliminar libro',
                style: GoogleFonts.inter(color: Colors.redAccent),
              ),
              onTap: () {
                Navigator.pop(context);
                widget.onEliminar();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Portada
          Expanded(
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppTheme.fondoTarjeta,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: _cargando
                        ? const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : _thumbnail != null
                        ? Image.memory(_thumbnail!.bytes, fit: BoxFit.cover)
                        : const Center(
                            child: Icon(
                              Icons.picture_as_pdf,
                              size: 40,
                              color: AppTheme.textoGris,
                            ),
                          ),
                  ),
                ),
                // 3 puntos arriba a la derecha
                Positioned(
                  top: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: () => _mostrarOpciones(context),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.more_vert,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                // Progreso de lectura
                if (widget.libro.ultimaPagina > 0)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(10),
                        bottomRight: Radius.circular(10),
                      ),
                      child: LinearProgressIndicator(
                        value:
                            widget.libro.ultimaPagina /
                            widget.libro.totalPaginas,
                        backgroundColor: Colors.black38,
                        valueColor: const AlwaysStoppedAnimation(
                          AppTheme.verdeTeal,
                        ),
                        minHeight: 4,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Solo título y páginas — sin botón abajo
          Text(
            widget.libro.titulo,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AppTheme.textoClaro,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '${widget.libro.totalPaginas} págs.',
            style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textoGris),
          ),
        ],
      ),
    );
  }
}
