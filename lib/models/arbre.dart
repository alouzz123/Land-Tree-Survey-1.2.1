import 'package:hive/hive.dart';

part 'arbre.g.dart';

@HiveType(typeId: 1)
class Arbre {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String placetteId;

  @HiveField(2)
  final String nomEspece;

  @HiveField(3)
  final double dap; // Diamètre à hauteur de poitrine (cm)

  @HiveField(4)
  final double hauteur; // Hauteur totale (m)

  @HiveField(5)
  final double? diametreCouronne; // Diamètre de la couronne (m)

  @HiveField(6)
  final String? etatSanitaire;

  @HiveField(7)
  final String? observations;

  @HiveField(8)
  final DateTime dateCreation;

  @HiveField(9)
  final String typeTronc; // Tronc unique ou plusieurs troncs

  @HiveField(10)
  final int nombreTroncs;

  // Champs structurés ajoutés à la suite pour conserver la compatibilité
  // avec les arbres déjà enregistrés dans Hive.
  @HiveField(11)
  final double? latitude;

  @HiveField(12)
  final double? longitude;

  @HiveField(13)
  final String? formeTronc;

  @HiveField(14)
  final String? methodeHauteur;

  @HiveField(15)
  final double? distanceClinometre;

  @HiveField(16)
  final double? angleCime;

  @HiveField(17)
  final double? angleBase;

  @HiveField(18)
  final double? houppierNS;

  @HiveField(19)
  final double? houppierEO;

  @HiveField(20)
  final String? photoLocale;

  @HiveField(21)
  final String modeInventaire; // dendrometrique ou simple

  Arbre({
    required this.id,
    required this.placetteId,
    required this.nomEspece,
    required this.dap,
    required this.hauteur,
    this.diametreCouronne,
    this.etatSanitaire,
    this.observations,
    required this.dateCreation,
    this.typeTronc = 'Tronc unique',
    this.nombreTroncs = 1,
    this.latitude,
    this.longitude,
    this.formeTronc,
    this.methodeHauteur,
    this.distanceClinometre,
    this.angleCime,
    this.angleBase,
    this.houppierNS,
    this.houppierEO,
    this.photoLocale,
    this.modeInventaire = 'dendrometrique',
  });

  /// Diamètre cumulé demandé par le protocole terrain.
  double get diametreCumule => dap * nombreTroncs;

  /// Compatibilité avec les anciennes données qui contenaient un nom local
  /// entre parenthèses. Les nouveaux enregistrements utilisent déjà ce format.
  String get nomScientifique =>
      nomEspece.replaceFirst(RegExp(r'\s*\([^)]*\)\s*$'), '').trim();

  // Calcul du volume estimé (formule simplifiée)
  double get volumeEstime {
    return (3.14159 * dap * dap * hauteur) / 40000;
  }

  String get formattedDAP => '${dap.toStringAsFixed(1)} cm';
  String get formattedHauteur => '${hauteur.toStringAsFixed(2)} m';
  String get formattedVolume => '${volumeEstime.toStringAsFixed(3)} m³';

  String get formattedDate {
    return '${dateCreation.day.toString().padLeft(2, '0')}/'
        '${dateCreation.month.toString().padLeft(2, '0')}/'
        '${dateCreation.year}';
  }
}
