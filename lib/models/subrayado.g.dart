part of 'subrayado.dart';

class SubrayadoAdapter extends TypeAdapter<Subrayado> {
  @override
  final int typeId = 1;

  @override
  Subrayado read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Subrayado(
      id: fields[0] as String,
      libroId: fields[1] as String,
      pagina: fields[2] as int,
      texto: fields[3] as String,
      color: fields[4] as String,
      fecha: fields[5] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, Subrayado obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.libroId)
      ..writeByte(2)
      ..write(obj.pagina)
      ..writeByte(3)
      ..write(obj.texto)
      ..writeByte(4)
      ..write(obj.color)
      ..writeByte(5)
      ..write(obj.fecha);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubrayadoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
