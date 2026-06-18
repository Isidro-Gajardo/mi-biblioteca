import 'dart:io';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sfpdf;
import 'package:path_provider/path_provider.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class PdfService {
  static final PdfService _instance = PdfService._internal();
  factory PdfService() => _instance;
  PdfService._internal();

  Future<int> obtenerTotalPaginas(String rutaArchivo) async {
    final doc = await pdfx.PdfDocument.openFile(rutaArchivo);
    final total = doc.pagesCount;
    doc.close();
    return total;
  }

  Future<String?> guardarThumbnail(String rutaArchivo, String libroId) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final carpetaThumbnails = Directory('${dir.path}/thumbnails');
      await carpetaThumbnails.create(recursive: true);

      final rutaThumbnail = '${carpetaThumbnails.path}/$libroId.jpg';

      if (await File(rutaThumbnail).exists()) {
        return rutaThumbnail;
      }

      final imagen = await renderizarPagina(rutaArchivo, 1, escala: 0.4);
      if (imagen == null) return null;

      await File(rutaThumbnail).writeAsBytes(imagen.bytes);
      return rutaThumbnail;
    } catch (e) {
      return null;
    }
  }

  Future<void> eliminarThumbnail(String libroId) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final archivo = File('${dir.path}/thumbnails/$libroId.jpg');
      if (await archivo.exists()) await archivo.delete();
    } catch (_) {}
  }

  Future<List<String>> extraerTextoOCR(
    String rutaArchivo, {
    void Function(int pagina, int total)? onProgreso,
  }) async {
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final List<String> paginas = [];

    try {
      final doc = await pdfx.PdfDocument.openFile(rutaArchivo);
      final total = doc.pagesCount;

      for (int i = 1; i <= total; i++) {
        try {
          onProgreso?.call(i, total);

          await Future.delayed(Duration.zero);

          final pagina = await doc.getPage(i);
          final imagen = await pagina.render(
            width: pagina.width * 1.5,
            height: pagina.height * 1.5,
            format: pdfx.PdfPageImageFormat.jpeg,
            backgroundColor: '#ffffff',
          );
          await pagina.close();

          if (imagen != null) {
            final dir = await getTemporaryDirectory();
            final rutaImg = '${dir.path}/ocr_page_$i.jpg';
            await File(rutaImg).writeAsBytes(imagen.bytes);

            final inputImage = InputImage.fromFilePath(rutaImg);
            final resultado = await textRecognizer.processImage(inputImage);
            paginas.add(resultado.text.trim());

            await File(rutaImg).delete();
          } else {
            paginas.add('');
          }
        } catch (_) {
          paginas.add('');
        }

        await Future.delayed(Duration.zero);
      }

      doc.close();
    } catch (e) {
      // ignore
    } finally {
      textRecognizer.close();
    }

    return paginas;
  }

  Future<bool> tieneTextoExtraible(String rutaArchivo) async {
    try {
      final bytes = await File(rutaArchivo).readAsBytes();
      final doc = sfpdf.PdfDocument(inputBytes: bytes);
      final extractor = sfpdf.PdfTextExtractor(doc);

      String textoTotal = '';
      final paginas = doc.pages.count < 3 ? doc.pages.count : 3;

      for (int i = 0; i < paginas; i++) {
        textoTotal += extractor.extractText(startPageIndex: i, endPageIndex: i);
      }

      doc.dispose();
      return textoTotal.trim().length > 50;
    } catch (e) {
      return false;
    }
  }

  Future<String> extraerTextoPagina(String rutaArchivo, int pagina) async {
    try {
      final bytes = await File(rutaArchivo).readAsBytes();
      final doc = sfpdf.PdfDocument(inputBytes: bytes);
      final extractor = sfpdf.PdfTextExtractor(doc);
      final texto = extractor.extractText(
        startPageIndex: pagina,
        endPageIndex: pagina,
      );
      doc.dispose();
      return _limpiarTexto(texto);
    } catch (e) {
      return '';
    }
  }

  Future<List<String>> extraerTextoCompleto(String rutaArchivo) async {
    try {
      final bytes = await File(rutaArchivo).readAsBytes();
      final doc = sfpdf.PdfDocument(inputBytes: bytes);
      final extractor = sfpdf.PdfTextExtractor(doc);
      final List<String> paginas = [];

      for (int i = 0; i < doc.pages.count; i++) {
        final texto = extractor.extractText(startPageIndex: i, endPageIndex: i);
        paginas.add(_limpiarTexto(texto.trim()));
      }

      doc.dispose();
      return paginas;
    } catch (e) {
      return [];
    }
  }

  String _limpiarTexto(String texto) {
    for (int i = 0; i < texto.length && i < 200; i++) {
      final code = texto.codeUnitAt(i);
      if (code == 32) continue;
      if (texto[i] == '\n') continue;
      if (code > 127 || code < 32) {
        print(
          'Char especial en pos $i: U+${code.toRadixString(16).padLeft(4, '0')} = "${texto[i]}"',
        );
      }
    }
    return texto
        .replaceAll(
          RegExp(r'[\u00A0\u1680\u2000-\u200A\u202F\u205F\u3000]'),
          ' ',
        )
        .replaceAll(RegExp(r' {2,}'), ' ')
        .replaceAllMapped(RegExp(r' ([,\.\!\?\;\:])'), (m) => m.group(1)!)
        .split('\n')
        .map((linea) => linea.trim())
        .join('\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n');
  }

  Future<pdfx.PdfPageImage?> renderizarPagina(
    String rutaArchivo,
    int numeroPagina, {
    double escala = 1.0,
  }) async {
    try {
      final doc = await pdfx.PdfDocument.openFile(rutaArchivo);
      final pagina = await doc.getPage(numeroPagina);
      final imagen = await pagina.render(
        width: pagina.width * escala,
        height: pagina.height * escala,
        format: pdfx.PdfPageImageFormat.jpeg,
        backgroundColor: '#ffffff',
      );
      await pagina.close();
      doc.close();
      return imagen;
    } catch (e) {
      return null;
    }
  }
}
