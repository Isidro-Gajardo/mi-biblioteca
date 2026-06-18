import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/libro.dart';
import '../models/subrayado.dart';
import '../services/pdf_service.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';

Future<List<String>> _extraerTextoIsolate(String ruta) async {
  return await PdfService().extraerTextoCompleto(ruta);
}

Future<String?> _generarThumbnailIsolate(List<String> args) async {
  return await PdfService().guardarThumbnail(args[0], args[1]);
}

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  final _uuid = const Uuid();
  late Box<Libro> _librosBox;
  late Box<Subrayado> _subrayadosBox;

  void init() {
    _librosBox = Hive.box<Libro>('libros');
    _subrayadosBox = Hive.box<Subrayado>('subrayados');
  }

  List<Libro> obtenerLibros() {
    return _librosBox.values.toList();
  }

  Future<void> procesarOCR(
    String id, {
    void Function(int pagina, int total)? onProgreso,
  }) async {
    final libro = _librosBox.get(id);
    if (libro == null) return;

    libro.procesandoOCR = true;
    libro.tieneTexto = false;
    libro.textoPaginas = [];
    await libro.save();

    try {
      final textoPaginas = await PdfService().extraerTextoOCR(
        libro.rutaArchivo,
        onProgreso: onProgreso,
      );

      final tieneTexto = textoPaginas.any((p) => p.trim().isNotEmpty);
      libro.textoPaginas = textoPaginas;
      libro.tieneTexto = tieneTexto;
      libro.procesandoOCR = false;
      await libro.save();
    } catch (e) {
      libro.procesandoOCR = false;
      libro.tieneTexto = false;
      libro.textoPaginas = [];
      await libro.save();
      rethrow;
    }
  }

  Future<Libro> agregarLibro({
    required String rutaOriginal,
    required String titulo,
    required int totalPaginas,
    required bool tieneTexto,
    bool usarOCR = false,
    void Function(int pagina, int total)? onProgreso,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final id = _uuid.v4();
    final destino = path.join(dir.path, 'libros', '$id.pdf');

    await Directory(path.join(dir.path, 'libros')).create(recursive: true);
    await File(rutaOriginal).copy(destino);

    List<String> textoPaginas = [];

    if (tieneTexto) {
      textoPaginas = await compute(_extraerTextoIsolate, destino);
    } else if (usarOCR) {
      final libroTemporal = Libro(
        id: id,
        titulo: titulo,
        rutaArchivo: destino,
        totalPaginas: totalPaginas,
        fechaAgregado: DateTime.now(),
        tieneTexto: false,
        procesandoOCR: true,
        textoPaginas: [],
      );
      await _librosBox.put(id, libroTemporal);

      try {
        textoPaginas = await PdfService().extraerTextoOCR(
          destino,
          onProgreso: onProgreso,
        );
      } catch (e) {
        libroTemporal.procesandoOCR = false;
        await libroTemporal.save();
        rethrow;
      }
    }

    final bool tieneTextoFinal =
        tieneTexto || (usarOCR && textoPaginas.any((p) => p.trim().isNotEmpty));

    final rutaThumbnail = await compute(_generarThumbnailIsolate,[destino, id],);

    final libro = Libro(
      id: id,
      titulo: titulo,
      rutaArchivo: destino,
      totalPaginas: totalPaginas,
      fechaAgregado: DateTime.now(),
      tieneTexto: tieneTextoFinal,
      procesandoOCR: false,
      textoPaginas: textoPaginas,
      rutaThumbnail: rutaThumbnail,
    );

    await _librosBox.put(id, libro);
    return libro;
  }

  void limpiarOCRAtascados() {
    final librosAtascados = _librosBox.values
        .where((l) => l.procesandoOCR)
        .toList();
    for (final libro in librosAtascados) {
      libro.procesandoOCR = false;
      libro.save();
    }
  }

  Future<void> actualizarTitulo(String id, String nuevoTitulo) async {
    final libro = _librosBox.get(id);
    if (libro != null) {
      libro.titulo = nuevoTitulo;
      await libro.save();
    }
  }

  Future<void> guardarProgreso(String id, int pagina) async {
    final libro = _librosBox.get(id);
    if (libro != null) {
      libro.ultimaPagina = pagina;
      libro.fechaUltimaLectura = DateTime.now();
      await libro.save();
    }
  }

  Future<void> eliminarLibro(String id) async {
    final libro = _librosBox.get(id);
    if (libro != null) {
      try {
        await File(libro.rutaArchivo).delete();
      } catch (_) {}
      await PdfService().eliminarThumbnail(id);
      await libro.delete();
      final subrayados = _subrayadosBox.values
          .where((s) => s.libroId == id)
          .toList();
      for (final s in subrayados) {
        await s.delete();
      }
    }
  }

  List<Subrayado> obtenerSubrayados(String libroId) {
    return _subrayadosBox.values.where((s) => s.libroId == libroId).toList()
      ..sort((a, b) => a.pagina.compareTo(b.pagina));
  }

  Future<Subrayado> agregarSubrayado({
    required String libroId,
    required int pagina,
    required String texto,
    String color = 'amarillo',
  }) async {
    final subrayado = Subrayado(
      id: _uuid.v4(),
      libroId: libroId,
      pagina: pagina,
      texto: texto,
      color: color,
      fecha: DateTime.now(),
    );
    await _subrayadosBox.put(subrayado.id, subrayado);
    return subrayado;
  }

  Future<void> eliminarSubrayado(String id) async {
    await _subrayadosBox.delete(id);
  }
}
