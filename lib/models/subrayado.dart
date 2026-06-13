import 'package:hive/hive.dart';

part 'subrayado.g.dart';

@HiveType(typeId: 1)
class Subrayado extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String libroId;

  @HiveField(2)
  int pagina;

  @HiveField(3)
  String texto;

  @HiveField(4)
  String color;

  @HiveField(5)
  DateTime fecha;

  Subrayado({
    required this.id,
    required this.libroId,
    required this.pagina,
    required this.texto,
    this.color = 'amarillo',
    required this.fecha,
  });
}