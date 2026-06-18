import 'package:hive/hive.dart';

part 'libro.g.dart';

@HiveType(typeId: 0)
class Libro extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String titulo;

  @HiveField(2)
  String rutaArchivo;

  @HiveField(3)
  int totalPaginas;

  @HiveField(4)
  int ultimaPagina;

  @HiveField(5)
  DateTime fechaAgregado;

  @HiveField(6)
  DateTime? fechaUltimaLectura;

  @HiveField(7)
  bool tieneTexto;

  @HiveField(8)
  List<String> textoPaginas;

  @HiveField(9)
  bool procesandoOCR;

  @HiveField(10)
  String? rutaThumbnail;

  Libro({
    required this.id,
    required this.titulo,
    required this.rutaArchivo,
    required this.totalPaginas,
    this.ultimaPagina = 0,
    required this.fechaAgregado,
    this.fechaUltimaLectura,
    this.tieneTexto = false,
    this.textoPaginas = const [],
    this.procesandoOCR = false,
    this.rutaThumbnail,
  });
}
