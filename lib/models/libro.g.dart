part of 'libro.dart';

class LibroAdapter extends TypeAdapter<Libro> {
  @override
  final int typeId = 0;

  @override
  Libro read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Libro(
      id: fields[0] as String,
      titulo: fields[1] as String,
      rutaArchivo: fields[2] as String,
      totalPaginas: fields[3] as int,
      ultimaPagina: fields[4] as int,
      fechaAgregado: fields[5] as DateTime,
      fechaUltimaLectura: fields[6] as DateTime?,
      tieneTexto: fields[7] as bool,
      textoPaginas: (fields[8] as List).cast<String>(),
      procesandoOCR: fields[9] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Libro obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.titulo)
      ..writeByte(2)
      ..write(obj.rutaArchivo)
      ..writeByte(3)
      ..write(obj.totalPaginas)
      ..writeByte(4)
      ..write(obj.ultimaPagina)
      ..writeByte(5)
      ..write(obj.fechaAgregado)
      ..writeByte(6)
      ..write(obj.fechaUltimaLectura)
      ..writeByte(7)
      ..write(obj.tieneTexto)
      ..writeByte(8)
      ..write(obj.textoPaginas)
      ..writeByte(9)
      ..write(obj.procesandoOCR);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LibroAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
