import 'package:hive/hive.dart';

part 'placette.g.dart';

@HiveType(typeId: 0)
class Placette {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String region;

  @HiveField(2)
  final double superficie;

  @HiveField(3)
  final double latitude;

  @HiveField(4)
  final double longitude;

  @HiveField(5)
  final String occupationSol;

  @HiveField(6)
  final bool presenceCulture;

  @HiveField(7)
  final bool presenceFeux;

  @HiveField(8)
  final String observations;

  @HiveField(9)
  final String agent;

  @HiveField(10)
  final DateTime dateCreation;

  @HiveField(11)
  final String pays;

  Placette({
    required this.id,
    required this.region,
    required this.superficie,
    required this.latitude,
    required this.longitude,
    required this.occupationSol,
    required this.presenceCulture,
    required this.presenceFeux,
    required this.observations,
    required this.agent,
    required this.dateCreation,
    this.pays = 'Sénégal',
  });
}
