// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'arbre.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ArbreAdapter extends TypeAdapter<Arbre> {
  @override
  final int typeId = 1;

  @override
  Arbre read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Arbre(
      id: fields[0] as String,
      placetteId: fields[1] as String,
      nomEspece: fields[2] as String,
      dap: fields[3] as double,
      hauteur: fields[4] as double,
      diametreCouronne: fields[5] as double?,
      etatSanitaire: fields[6] as String?,
      observations: fields[7] as String?,
      dateCreation: fields[8] as DateTime,
      typeTronc: fields[9] as String? ?? 'Tronc unique',
      nombreTroncs: fields[10] as int? ?? 1,
      latitude: (fields[11] as num?)?.toDouble(),
      longitude: (fields[12] as num?)?.toDouble(),
      formeTronc: fields[13] as String?,
      methodeHauteur: fields[14] as String?,
      distanceClinometre: (fields[15] as num?)?.toDouble(),
      angleCime: (fields[16] as num?)?.toDouble(),
      angleBase: (fields[17] as num?)?.toDouble(),
      houppierNS: (fields[18] as num?)?.toDouble(),
      houppierEO: (fields[19] as num?)?.toDouble(),
      photoLocale: fields[20] as String?,
      modeInventaire: fields[21] as String? ?? 'dendrometrique',
    );
  }

  @override
  void write(BinaryWriter writer, Arbre obj) {
    writer
      ..writeByte(22)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.placetteId)
      ..writeByte(2)
      ..write(obj.nomEspece)
      ..writeByte(3)
      ..write(obj.dap)
      ..writeByte(4)
      ..write(obj.hauteur)
      ..writeByte(5)
      ..write(obj.diametreCouronne)
      ..writeByte(6)
      ..write(obj.etatSanitaire)
      ..writeByte(7)
      ..write(obj.observations)
      ..writeByte(8)
      ..write(obj.dateCreation)
      ..writeByte(9)
      ..write(obj.typeTronc)
      ..writeByte(10)
      ..write(obj.nombreTroncs)
      ..writeByte(11)
      ..write(obj.latitude)
      ..writeByte(12)
      ..write(obj.longitude)
      ..writeByte(13)
      ..write(obj.formeTronc)
      ..writeByte(14)
      ..write(obj.methodeHauteur)
      ..writeByte(15)
      ..write(obj.distanceClinometre)
      ..writeByte(16)
      ..write(obj.angleCime)
      ..writeByte(17)
      ..write(obj.angleBase)
      ..writeByte(18)
      ..write(obj.houppierNS)
      ..writeByte(19)
      ..write(obj.houppierEO)
      ..writeByte(20)
      ..write(obj.photoLocale)
      ..writeByte(21)
      ..write(obj.modeInventaire);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ArbreAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
