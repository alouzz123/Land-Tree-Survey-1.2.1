import 'package:hive_flutter/hive_flutter.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart' as xlsx;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../models/placette.dart';
import '../models/arbre.dart';
import 'supabase_sync_service.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static const String _placettesBoxName = 'placettes_box';
  static const String _arbresBoxName = 'arbres_box';

  Box<Placette>? _placettesBox;
  Box<Arbre>? _arbresBox;

  // ========== INITIALISATION ==========
  Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(PlacetteAdapter());
    Hive.registerAdapter(ArbreAdapter());
    _placettesBox = await Hive.openBox<Placette>(_placettesBoxName);
    _arbresBox = await Hive.openBox<Arbre>(_arbresBoxName);
    await _migrerAnciensArbresHive();
  }

  /// Convertit une seule fois les anciennes valeurs concaténées dans
  /// `observations` vers les champs Hive structurés, sans changer les ID.
  Future<void> _migrerAnciensArbresHive() async {
    final box = _arbresBox;
    if (box == null) return;
    for (final key in box.keys.toList()) {
      final arbre = box.get(key);
      if (arbre == null || arbre.formeTronc != null) continue;
      final texte = arbre.observations ?? '';
      final valeurs = _extraireObservations(texte);
      final methode = RegExp(r'Méthode hauteur: ([^•]+)')
          .firstMatch(texte)?.group(1)?.trim();
      final clinometre = RegExp(
        r'Clinomètre: distance ([\d.,-]+) m, angle cime ([\d.,-]+)°, angle base ([\d.,-]+)°',
      ).firstMatch(texte);
      final contientAncienFormat = RegExp(
        r'(GPS:|Forme tronc:|Type tronc:|Nombre troncs:|Diamètre cumulé:|Méthode hauteur:|Clinomètre:|Houppier:|📸 Photo:)',
      ).hasMatch(texte);
      double? nombre(String? valeur) => valeur == null || valeur.isEmpty
          ? null
          : double.tryParse(valeur.replaceAll(',', '.'));

      final migre = Arbre(
        id: arbre.id,
        placetteId: arbre.placetteId,
        nomEspece: arbre.nomScientifique,
        dap: arbre.dap,
        hauteur: arbre.hauteur,
        diametreCouronne: arbre.diametreCouronne,
        etatSanitaire: null,
        observations: contientAncienFormat
            ? (valeurs['notes'] ?? '')
            : texte.trim(),
        dateCreation: arbre.dateCreation,
        typeTronc: arbre.typeTronc,
        nombreTroncs: arbre.nombreTroncs,
        latitude: nombre(valeurs['latitude']),
        longitude: nombre(valeurs['longitude']),
        formeTronc: (valeurs['forme_tronc'] ?? '').isEmpty
            ? null
            : valeurs['forme_tronc'],
        methodeHauteur: methode,
        distanceClinometre: nombre(clinometre?.group(1)),
        angleCime: nombre(clinometre?.group(2)),
        angleBase: nombre(clinometre?.group(3)),
        houppierNS: nombre(valeurs['houppier_ns']),
        houppierEO: nombre(valeurs['houppier_eo']),
        // Un marqueur suffit pour conserver « Oui » dans les exports des
        // anciens arbres. La synchronisation retrouve la vraie photo par ID.
        photoLocale: texte.contains('📸 Photo:')
            ? 'legacy://${arbre.id}.jpg'
            : null,
        modeInventaire: arbre.modeInventaire,
      );
      await box.put(key, migre);
    }
  }

  // ========== PLACETTES CRUD ==========
  Future<void> savePlacette(Placette placette) async {
    await _placettesBox?.put(placette.id, placette);
    await SupabaseSyncService().syncPlacetteSilently(placette);
  }

  List<Placette> getAllPlacettes() {
    final placettes = _placettesBox?.values.toList() ?? [];
    placettes.sort((a, b) => b.dateCreation.compareTo(a.dateCreation));
    return placettes;
  }

  Placette? getPlacette(String id) {
    return _placettesBox?.get(id);
  }

  Future<void> deletePlacette(String id) async {
    final arbres = getArbresByPlacetteId(id);
    for (var arbre in arbres) {
      await deleteArbre(id, arbre.id);
    }
    await _placettesBox?.delete(id);
    await SupabaseSyncService().deletePlacetteSilently(id);
  }

  /// Remplace la placette locale et la met à jour dans Supabase en gardant
  /// le même identifiant afin de ne créer aucun doublon.
  Future<void> updatePlacette(Placette placette) => savePlacette(placette);

  int getCount() {
    return _placettesBox?.length ?? 0;
  }

  // ========== ARBRES CRUD ==========
  String _arbreStorageKey(String placetteId, String arbreId) =>
      '$placetteId::$arbreId';

  Future<void> saveArbre(Arbre arbre) async {
    // L'ID visible est unique dans une placette. La clé Hive inclut donc
    // aussi la placette pour éviter les collisions entre plusieurs placettes.
    await _arbresBox?.put(
      _arbreStorageKey(arbre.placetteId, arbre.id),
      arbre,
    );
    await SupabaseSyncService().syncArbreWithParentSilently(
      arbre,
      placette: getPlacette(arbre.placetteId),
    );
  }

  List<Arbre> getArbresByPlacetteId(String placetteId) {
    final arbres = _arbresBox?.values
            .where((arbre) => arbre.placetteId == placetteId)
            .toList() ??
        [];
    arbres.sort((a, b) => b.dateCreation.compareTo(a.dateCreation));
    return arbres;
  }

  Arbre? getArbre(String placetteId, String id) {
    return _arbresBox?.get(_arbreStorageKey(placetteId, id));
  }

  /// Remplace l'arbre local et le met à jour dans Supabase avec sa clé stable.
  Future<void> updateArbre(Arbre arbre) => saveArbre(arbre);

  Future<void> deleteArbre(String placetteId, String id) async {
    final nouvelleCle = _arbreStorageKey(placetteId, id);
    if (_arbresBox?.containsKey(nouvelleCle) == true) {
      await _arbresBox?.delete(nouvelleCle);
      await SupabaseSyncService().deleteArbreSilently(placetteId, id);
      return;
    }

    // Compatibilité avec les anciennes données dont la clé était seulement ID.
    dynamic ancienneCle;
    for (final key in _arbresBox?.keys ?? const <dynamic>[]) {
      final arbre = _arbresBox?.get(key);
      if (arbre?.placetteId == placetteId && arbre?.id == id) {
        ancienneCle = key;
        break;
      }
    }
    if (ancienneCle != null) await _arbresBox?.delete(ancienneCle);
    await SupabaseSyncService().deleteArbreSilently(placetteId, id);
  }

  int countArbresByPlacetteId(String placetteId) {
    return _arbresBox?.values
            .where((arbre) => arbre.placetteId == placetteId)
            .length ??
        0;
  }

  int getTotalArbresCount() {
    return _arbresBox?.length ?? 0;
  }

  List<Arbre> getAllArbres() {
    final arbres = _arbresBox?.values.toList() ?? [];
    arbres.sort((a, b) => b.dateCreation.compareTo(a.dateCreation));
    return arbres;
  }

  List<String> getAllEspeces() {
    final especes = <String>{};
    final arbres = _arbresBox?.values;
    if (arbres != null) {
      for (var arbre in arbres) {
        if (arbre.nomEspece.toLowerCase() != 'inconnue') {
          especes.add(arbre.nomScientifique);
        }
      }
    }
    return especes.toList();
  }

  Map<String, dynamic> getStatistiquesArbres(String placetteId) {
    final arbres = getArbresByPlacetteId(placetteId);
    final arbresDendrometriques =
        arbres.where((a) => a.modeInventaire != 'simple').toList();
    final arbresConnus = arbresDendrometriques
        .where((a) => a.nomEspece.toLowerCase() != 'inconnue')
        .toList();

    if (arbresConnus.isEmpty) {
      return {
        'total': arbres.length,
        'connus': 0,
        'inconnus': arbresDendrometriques.length,
        'dapMoyen': 0.0,
        'hauteurMoyenne': 0.0,
        'volumeTotal': 0.0,
      };
    }

    double dapTotal = 0;
    double hauteurTotal = 0;
    double volumeTotal = 0;

    for (var arbre in arbresConnus) {
      dapTotal += arbre.dap;
      hauteurTotal += arbre.hauteur;
      volumeTotal += arbre.volumeEstime;
    }

    return {
      'total': arbres.length,
      'connus': arbresConnus.length,
      'inconnus': arbresDendrometriques.length - arbresConnus.length,
      'dapMoyen': dapTotal / arbresConnus.length,
      'hauteurMoyenne': hauteurTotal / arbresConnus.length,
      'volumeTotal': volumeTotal,
    };
  }

  // ========== FONCTIONS POUR EXTRAIRE TOUTES LES DONNÉES DES OBSERVATIONS ==========
  Map<String, String> _extraireObservations(String? observations) {
    Map<String, String> result = {
      'gps': '',
      'forme_tronc': '',
      'houppier_ns': '',
      'houppier_eo': '',
      'notes': '',
      'photo': '',
      'latitude': '',
      'longitude': '',
    };

    if (observations != null && observations.isNotEmpty) {
      final obs = observations;

      // Extraire GPS complet
      if (obs.contains('GPS:')) {
        final gpsMatch = RegExp(r'GPS: ([^•]+)').firstMatch(obs);
        if (gpsMatch != null) {
          result['gps'] = gpsMatch.group(1)?.trim() ?? '';
          // Extraire latitude et longitude séparément
          final gpsParts = result['gps']!.split(',');
          if (gpsParts.length >= 2) {
            result['latitude'] = gpsParts[0].trim();
            result['longitude'] = gpsParts[1].trim();
          }
        }
      }

      // Extraire forme du tronc
      if (obs.contains('Forme tronc:')) {
        final formeMatch = RegExp(r'Forme tronc: ([^•]+)').firstMatch(obs);
        if (formeMatch != null)
          result['forme_tronc'] = formeMatch.group(1)?.trim() ?? '';
      }

      // Extraire houppier
      if (obs.contains('Houppier:')) {
        final houppierMatch = RegExp(r'Houppier: ([^•]+)').firstMatch(obs);
        if (houppierMatch != null) {
          final houppierText = houppierMatch.group(1)?.trim() ?? '';
          final nsMatch = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(houppierText);
          final eoMatch =
              RegExp(r'x\s*(\d+(?:\.\d+)?)').firstMatch(houppierText);
          if (nsMatch != null) result['houppier_ns'] = nsMatch.group(1) ?? '';
          if (eoMatch != null) result['houppier_eo'] = eoMatch.group(1) ?? '';
        }
      }

      // Extraire notes
      if (obs.contains('Notes:')) {
        final notesMatch = RegExp(r'Notes: ([^•]+)').firstMatch(obs);
        if (notesMatch != null)
          result['notes'] = notesMatch.group(1)?.trim() ?? '';
      }

      // Extraire photo
      if (obs.contains('📸 Photo:') || obs.contains('Photo prise')) {
        result['photo'] = 'Oui';
      }
    }

    return result;
  }

  // ========== FONCTIONS POUR LE DOSSIER DE TÉLÉCHARGEMENT ==========
  Future<Directory> _getDownloadDirectory() async {
    if (Platform.isAndroid) {
      final directory =
          Directory('/storage/emulated/0/Download/LandTree_Survey');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      return directory;
    } else {
      return await getApplicationDocumentsDirectory();
    }
  }

  // ✅ Vérifier la version Android (API 33+)
  Future<bool> _isAndroid13OrHigher() async {
    try {
      // Pour une solution robuste, utilisez device_info_plus
      return true; // À adapter selon votre besoin
    } catch (e) {
      return false;
    }
  }

  // ✅ Vérifier les permissions de stockage (compatible Android 13+)
  Future<bool> _checkStoragePermission() async {
    if (kIsWeb) return true;
    if (Platform.isAndroid) {
      if (await _isAndroid13OrHigher()) {
        final photosStatus = await Permission.photos.status;
        final videosStatus = await Permission.videos.status;

        if (photosStatus.isGranted && videosStatus.isGranted) {
          return true;
        }

        final statuses = await [
          Permission.photos,
          Permission.videos,
        ].request();

        return statuses[Permission.photos]!.isGranted &&
            statuses[Permission.videos]!.isGranted;
      } else {
        final status = await Permission.storage.status;
        if (status.isGranted) {
          return true;
        }

        final newStatus = await Permission.storage.request();
        return newStatus.isGranted;
      }
    }
    return true;
  }

  static const List<String> _placetteExportHeaders = [
    'ID Placette',
    'Pays',
    'Région',
    'Superficie (ha)',
    'Latitude',
    'Longitude',
    'Occupation du sol',
    'Présence culture',
    'Présence feux',
    'Observations',
    'Agent',
    'Date création',
    'Heure création',
    "Nombre d'arbres",
  ];

  static const List<String> _dendrometriqueExportHeaders = [
    'ID Arbre',
    'ID Placette',
    'Pays',
    'Région',
    'Nom scientifique',
    'DAP (cm)',
    'Type de tronc',
    'Nombre de troncs',
    'Diamètre cumulé (cm)',
    'Hauteur totale (m)',
    'Diamètre houppier N-S (m)',
    'Diamètre houppier E-O (m)',
    'Diamètre houppier moyen (m)',
    'Forme du tronc',
    'Méthode de hauteur',
    'Distance clinomètre (m)',
    'Angle cime (°)',
    'Angle base (°)',
    'Latitude GPS arbre',
    'Longitude GPS arbre',
    'Volume estimé (m³)',
    'Photo',
    'Commentaires',
    'Date création',
    'Heure création',
  ];

  static const List<String> _releveSimpleExportHeaders = [
    'ID Relevé',
    'ID Placette',
    'Pays',
    'Région',
    'Nom scientifique',
    'Latitude GPS arbre',
    'Longitude GPS arbre',
    'Photo',
    'Date création',
    'Heure création',
  ];

  String _dateFr(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';

  String _heure(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}:'
      '${date.second.toString().padLeft(2, '0')}';

  List<List<dynamic>> _lignesPlacettes(List<Placette> placettes) {
    return [
      _placetteExportHeaders,
      for (final p in placettes)
        [
          p.id,
          p.pays,
          p.region,
          p.superficie,
          p.latitude,
          p.longitude,
          p.occupationSol,
          p.presenceCulture ? 'Oui' : 'Non',
          p.presenceFeux ? 'Oui' : 'Non',
          p.observations,
          p.agent,
          _dateFr(p.dateCreation),
          _heure(p.dateCreation),
          countArbresByPlacetteId(p.id),
        ],
    ];
  }

  List<List<dynamic>> _lignesDendrometriques(List<Placette> placettes) {
    final rows = <List<dynamic>>[_dendrometriqueExportHeaders];
    for (final p in placettes) {
      for (final a in getArbresByPlacetteId(p.id)
          .where((arbre) => arbre.modeInventaire != 'simple')) {
        final obs = _extraireObservations(a.observations);
        rows.add([
          a.id,
          p.id,
          p.pays,
          p.region,
          a.nomScientifique,
          a.dap,
          a.typeTronc,
          a.nombreTroncs,
          double.parse(a.diametreCumule.toStringAsFixed(2)),
          a.hauteur,
          a.houppierNS ?? double.tryParse(obs['houppier_ns'] ?? '') ?? '',
          a.houppierEO ?? double.tryParse(obs['houppier_eo'] ?? '') ?? '',
          a.diametreCouronne ?? '',
          a.formeTronc ?? obs['forme_tronc'] ?? '',
          a.methodeHauteur ?? '',
          a.distanceClinometre ?? '',
          a.angleCime ?? '',
          a.angleBase ?? '',
          a.latitude ?? double.tryParse(obs['latitude'] ?? '') ?? '',
          a.longitude ?? double.tryParse(obs['longitude'] ?? '') ?? '',
          double.parse(a.volumeEstime.toStringAsFixed(3)),
          _statutPhoto(a, obs),
          _commentaireArbre(a, obs),
          _dateFr(a.dateCreation),
          _heure(a.dateCreation),
        ]);
      }
    }
    return rows;
  }

  List<List<dynamic>> _lignesRelevesSimples(List<Placette> placettes) {
    final rows = <List<dynamic>>[_releveSimpleExportHeaders];
    for (final p in placettes) {
      for (final a in getArbresByPlacetteId(p.id)
          .where((arbre) => arbre.modeInventaire == 'simple')) {
        rows.add([
          a.id,
          p.id,
          p.pays,
          p.region,
          a.nomScientifique,
          a.latitude ?? '',
          a.longitude ?? '',
          (a.photoLocale?.trim().isNotEmpty ?? false) ? 'Oui' : 'Non',
          _dateFr(a.dateCreation),
          _heure(a.dateCreation),
        ]);
      }
    }
    return rows;
  }

  String _statutPhoto(Arbre arbre, Map<String, String> ancienFormat) {
    final chemin = arbre.photoLocale?.trim() ?? '';
    final ancienneValeur = (ancienFormat['photo'] ?? '').trim();
    return chemin.isNotEmpty || ancienneValeur == 'Oui' ? 'Oui' : 'Non';
  }

  String _commentaireArbre(
    Arbre arbre,
    Map<String, String> ancienFormat,
  ) {
    // Les nouveaux modèles possèdent les champs structurés. Leur observation
    // est donc directement le commentaire libre, sans extraction fragile.
    if (arbre.formeTronc != null || arbre.methodeHauteur != null) {
      return arbre.observations?.trim() ?? '';
    }
    final noteExtraite = (ancienFormat['notes'] ?? '').trim();
    if (noteExtraite.isNotEmpty) return noteExtraite;
    return arbre.observations?.trim() ?? '';
  }

  void _verifierTableauExport(
    List<List<dynamic>> rows,
    String nomTableau,
  ) {
    if (rows.isEmpty) throw StateError('$nomTableau ne contient aucun en-tête');
    final nombreColonnes = rows.first.length;
    for (var index = 1; index < rows.length; index++) {
      if (rows[index].length != nombreColonnes) {
        throw StateError(
          '$nomTableau : la ligne ${index + 1} contient '
          '${rows[index].length} valeurs au lieu de $nombreColonnes.',
        );
      }
    }
  }

  String _creerCsv(List<List<dynamic>> rows) {
    final localizedRows = rows
        .map((row) => row
            .map((value) => value is double
                ? value.toString().replaceAll('.', ',')
                : value)
            .toList())
        .toList();
    final body = const ListToCsvConverter(
      fieldDelimiter: ';',
      textDelimiter: '"',
      textEndDelimiter: '"',
      eol: '\r\n',
    ).convert(localizedRows);
    // CSV standard : BOM UTF-8 + séparateur point-virgule + CRLF. On évite
    // la ligne propriétaire « sep=; », qui gêne R, Python, QGIS et LibreOffice.
    return '\u{FEFF}$body';
  }

  Future<XFile> _creerFichierPartage(
    Uint8List bytes,
    String fileName,
    String mimeType,
  ) async {
    if (kIsWeb) {
      return XFile.fromData(bytes, name: fileName, mimeType: mimeType);
    }
    final directory = await _getDownloadDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return XFile(file.path, name: fileName, mimeType: mimeType);
  }

  xlsx.CellValue _celluleExcel(dynamic value) {
    if (value is int) return xlsx.IntCellValue(value);
    if (value is double) return xlsx.DoubleCellValue(value);
    if (value is bool) return xlsx.BoolCellValue(value);
    return xlsx.TextCellValue(value?.toString() ?? '');
  }

  void _remplirFeuille(
    xlsx.Sheet sheet,
    List<List<dynamic>> rows,
  ) {
    for (final row in rows) {
      sheet.appendRow(row.map(_celluleExcel).toList());
    }
    for (var column = 0; column < rows.first.length; column++) {
      sheet.setColumnWidth(column, column < 3 ? 22 : 18);
    }
  }

  // ========== EXPORT CSV EXCEL : 3 TABLEAUX SCIENTIFIQUES ==========
  Future<void> exportToCSV() async {
    try {
      final hasPermission = await _checkStoragePermission();
      if (!hasPermission) {
        throw Exception('Permission de stockage refusée');
      }

      final placettes = getAllPlacettes();

      if (placettes.isEmpty) {
        throw Exception('Aucune donnée à exporter');
      }

      final timestamp = DateTime.now();
      final lignesPlacettes = _lignesPlacettes(placettes);
      final lignesDendrometriques = _lignesDendrometriques(placettes);
      final lignesRelevesSimples = _lignesRelevesSimples(placettes);
      _verifierTableauExport(lignesPlacettes, 'Placettes');
      _verifierTableauExport(lignesDendrometriques, 'Dendrométrique');
      _verifierTableauExport(lignesRelevesSimples, 'Relevé simple');
      final suffix =
          '${timestamp.day.toString().padLeft(2, '0')}_'
          '${timestamp.month.toString().padLeft(2, '0')}_${timestamp.year}_'
          '${timestamp.hour.toString().padLeft(2, '0')}h'
          '${timestamp.minute.toString().padLeft(2, '0')}';
      final placettesFile = await _creerFichierPartage(
        Uint8List.fromList(utf8.encode(_creerCsv(lignesPlacettes))),
        'LandTree_Placettes_$suffix.csv',
        'text/csv',
      );
      final dendrometriqueFile = await _creerFichierPartage(
        Uint8List.fromList(utf8.encode(_creerCsv(lignesDendrometriques))),
        'LandTree_Dendrometrique_$suffix.csv',
        'text/csv',
      );
      final releveSimpleFile = await _creerFichierPartage(
        Uint8List.fromList(utf8.encode(_creerCsv(lignesRelevesSimples))),
        'LandTree_Releve_Simple_$suffix.csv',
        'text/csv',
      );

      await Share.shareXFiles(
        [placettesFile, dendrometriqueFile, releveSimpleFile],
        text:
            'Export Land.Tree Survey : ${placettes.length} placettes et '
            '${getTotalArbresCount()} observations. Trois tableaux séparés.',
      );
    } catch (e) {
      debugPrint('Erreur export CSV: $e');
      throw Exception('Erreur d\'export CSV: $e');
    }
  }

  // ========== VRAI CLASSEUR EXCEL XLSX : 3 FEUILLES ==========
  Future<void> exportToExcel() async {
    try {
      final hasPermission = await _checkStoragePermission();
      if (!hasPermission) {
        throw Exception('Permission de stockage refusée');
      }

      final placettes = getAllPlacettes();

      if (placettes.isEmpty) {
        throw Exception('Aucune donnée à exporter');
      }

      final timestamp = DateTime.now();
      final lignesPlacettes = _lignesPlacettes(placettes);
      final lignesDendrometriques = _lignesDendrometriques(placettes);
      final lignesRelevesSimples = _lignesRelevesSimples(placettes);
      _verifierTableauExport(lignesPlacettes, 'Placettes');
      _verifierTableauExport(lignesDendrometriques, 'Dendrométrique');
      _verifierTableauExport(lignesRelevesSimples, 'Relevé simple');
      final fileName =
          'LandTree_Export_${timestamp.day.toString().padLeft(2, '0')}_'
          '${timestamp.month.toString().padLeft(2, '0')}_${timestamp.year}_'
          '${timestamp.hour.toString().padLeft(2, '0')}h'
          '${timestamp.minute.toString().padLeft(2, '0')}.xlsx';

      final workbook = xlsx.Excel.createExcel();
      workbook.rename('Sheet1', 'Placettes');
      _remplirFeuille(workbook['Placettes'], lignesPlacettes);
      _remplirFeuille(
          workbook['Dendrometrique'], lignesDendrometriques);
      _remplirFeuille(workbook['Releve simple'], lignesRelevesSimples);
      workbook.setDefaultSheet('Placettes');

      if (kIsWeb) {
        workbook.save(fileName: fileName);
        return;
      }

      final bytes = workbook.save();
      if (bytes == null) throw Exception('Impossible de créer le classeur Excel');
      final exportFile = await _creerFichierPartage(
        Uint8List.fromList(bytes),
        fileName,
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );

      await Share.shareXFiles(
        [exportFile],
        text:
            'Classeur Land.Tree Survey : feuille Placettes et feuille Arbres.',
      );
    } catch (e) {
      debugPrint('Erreur export Excel: $e');
      throw Exception('Erreur d\'export Excel: $e');
    }
  }

  // ========== DEBUG ==========
  void printAllPlacettes() {
    final placettes = getAllPlacettes();
    debugPrint('=== 📊 ${placettes.length} PLACETTES DANS LA BASE ===');
    for (var p in placettes) {
      final arbresCount = countArbresByPlacetteId(p.id);
      final stats = getStatistiquesArbres(p.id);
      debugPrint('---');
      debugPrint('🆔 ID: ${p.id}');
      debugPrint('📍 Région: ${p.region}');
      debugPrint('📐 Superficie: ${p.superficie} ha');
      debugPrint('🗺️ GPS: ${p.latitude}, ${p.longitude}');
      debugPrint('🌾 Occupation: ${p.occupationSol}');
      debugPrint('🌱 Culture: ${p.presenceCulture ? "Oui" : "Non"}');
      debugPrint('🔥 Feux: ${p.presenceFeux ? "Oui" : "Non"}');
      debugPrint('📝 Observations: ${p.observations}');
      debugPrint('👤 Agent: ${p.agent}');
      debugPrint('📅 Date: ${p.dateCreation}');
      debugPrint('🌳 Arbres: $arbresCount');
      if (stats['connus'] > 0) {
        debugPrint(
            '   📊 DAP moyen: ${(stats['dapMoyen'] as double).toStringAsFixed(1)} cm');
        debugPrint(
            '   📊 Hauteur moyenne: ${(stats['hauteurMoyenne'] as double).toStringAsFixed(2)} m');
        debugPrint(
            '   📊 Volume total: ${(stats['volumeTotal'] as double).toStringAsFixed(3)} m³');
      }
    }
    debugPrint('=====================================');
  }

  void printAllArbres() {
    final arbres = _arbresBox?.values;
    if (arbres == null) {
      debugPrint('Aucun arbre dans la base');
      return;
    }

    final arbresList = arbres.toList();
    debugPrint('=== 🌳 ${arbresList.length} ARBRES DANS LA BASE ===');
    for (var a in arbresList) {
      debugPrint('---');
      debugPrint('🆔 ID: ${a.id}');
      debugPrint('📍 Placette: ${a.placetteId}');
      debugPrint('🌿 Espèce: ${a.nomEspece}');
      debugPrint('📏 DAP: ${a.formattedDAP}');
      debugPrint('📐 Hauteur: ${a.formattedHauteur}');
      debugPrint('📦 Volume: ${a.formattedVolume}');
      if (a.observations != null) debugPrint('📝 Notes: ${a.observations}');
      debugPrint('📅 Date: ${a.formattedDate}');
    }
    debugPrint('=====================================');
  }
}
