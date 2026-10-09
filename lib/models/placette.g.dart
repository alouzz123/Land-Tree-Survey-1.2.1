// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'placette.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PlacetteAdapter extends TypeAdapter<Placette> {
  @override
  final int typeId = 0;

  @override
  Placette read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Placette(
      id: fields[0] as String,
      region: fields[1] as String,
      superficie: fields[2] as double,
      latitude: fields[3] as double,
      longitude: fields[4] as double,
      occupationSol: fields[5] as String,
      presenceCulture: fields[6] as bool,
      presenceFeux: fields[7] as bool,
      observations: fields[8] as String,
      agent: fields[9] as String,
      dateCreation: fields[10] as DateTime,
      pays: fields[11] as String? ?? 'Sénégal',
    );
  }

  @override
  void write(BinaryWriter writer, Placette obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.region)
      ..writeByte(2)
      ..write(obj.superficie)
      ..writeByte(3)
      ..write(obj.latitude)
      ..writeByte(4)
      ..write(obj.longitude)
      ..writeByte(5)
      ..write(obj.occupationSol)
      ..writeByte(6)
      ..write(obj.presenceCulture)
      ..writeByte(7)
      ..write(obj.presenceFeux)
      ..writeByte(8)
      ..write(obj.observations)
      ..writeByte(9)
      ..write(obj.agent)
      ..writeByte(10)
      ..write(obj.dateCreation)
      ..writeByte(11)
      ..write(obj.pays);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlacetteAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
