import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:math' as math;
import '../models/arbre.dart';
import '../services/database_service.dart';
import '../services/project_country_service.dart';
import '../services/gps_service.dart';
import '../services/species_catalog.dart';
import '../theme/app_theme.dart';
import '../widgets/responsive_fields.dart';

class FormulaireArbresScreen extends StatefulWidget {
  final String placetteId;
  final String regionNom;

  const FormulaireArbresScreen({
    super.key,
    required this.placetteId,
    required this.regionNom,
  });

  @override
  State<FormulaireArbresScreen> createState() => _FormulaireArbresScreenState();
}

class _FormulaireArbresScreenState extends State<FormulaireArbresScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final _diametre130Controller = TextEditingController();
  final _nombreTroncsController = TextEditingController(text: '1');
  final _diametreCumuleController = TextEditingController();
  final _hauteurTotaleController = TextEditingController();
  final _distanceArbreController = TextEditingController();
  final _angleCimeController = TextEditingController();
  final _angleBaseController = TextEditingController();
  final _houppierNSController = TextEditingController();
  final _houppierEOController = TextEditingController();
  final _commentairesController = TextEditingController();
  final _indiceIdController = TextEditingController(text: 'Arbre');
  final _especeInconnueController = TextEditingController();

  // Variables pour les menus déroulants
  String _selectedEspece = '';
  String _formeTronc = 'Droit';
  String _methodeHauteur = 'Mesure directe';
  String _typeTronc = 'Tronc unique';
  bool _isEspeceInconnue = false;

  // Options des menus
  final List<String> _formesTronc = ['Droit', 'Incliné', 'Tordu', 'Fourchu'];
  final List<String> _methodesHauteur = [
    'Mesure directe',
    'Mesure au clinomètre',
  ];
  final List<String> _typesTronc = ['Tronc unique', 'Plusieurs troncs'];

  // 📋 MAP DES ABRÉVIATIONS PAR ESPÈCE
  final Map<String, String> _abreviations = {
    'Acacia nilotica (Ngalam)': 'NGA',
    'Acacia senegal (Verek)': 'VER',
    'Acacia seyal (Surur)': 'SUR',
    'Acacia tortilis (Samar)': 'SAM',
    'Adansonia digitata (Gouye)': 'GOU',
    'Adenium obesum (Baobab du désert)': 'ADE',
    'Anacardium occidentale (Darkase)': 'DAR',
    'Anogeissus leiocarpus (Guéj)': 'GUE',
    'Aphania senegalensis (Khéwar)': 'KHE',
    'Azadirachta indica (Neem)': 'NEE',
    'Balanites aegyptiaca (Soump)': 'SOU',
    'Bauhinia rufescens (Ndiandam)': 'NDI',
    'Bombax costatum (Kapokier rouge)': 'KAP',
    'Borassus aethiopum (Rônier)': 'RON',
    'Boscia senegalensis (Hann)': 'HAN',
    'Calotropis procera (Pomme de Sodome)': 'SOD',
    'Cassia sieberiana (Sindian)': 'SIN',
    'Ceiba pentandra (Fromager)': 'FRO',
    'Celtis integrifolia (Bantignel)': 'BAN',
    'Citrus limon (Citronnier)': 'CIT',
    'Combretum glutinosum (Ratt)': 'RAT',
    'Combretum micranthum (Kinkeliba)': 'KIN',
    'Commiphora africana (Olé)': 'OLE',
    'Cordyla pinnata (Dimb)': 'DIM',
    'Daniellia oliveri (Santan)': 'SAN',
    'Detarium senegalense (Ditakh)': 'DIT',
    'Dichrostachys cinerea (Sount)': 'SOU',
    'Dichrostachys glomerata (Sount)': 'SOU',
    'Diospyros mespiliformis (Alom)': 'ALO',
    'Eucalyptus spp. (Eucalyptus)': 'EUC',
    'Euphorbia balsamifera (Salane)': 'SAL',
    'Faidherbia albida (Kad)': 'KAD',
    'Feretia apodanthera (Koungueul)': 'KOU',
    'Ficus gnaphalocarpa (Figg)': 'FIG',
    'Ficus iteophylla (Figg)': 'FIG',
    'Ficus platyphylla (Figg)': 'FIG',
    'Ficus thonningii (Figg)': 'FIG',
    'Ficus vogelii (Figg)': 'FIG',
    'Gardenia ternifolia (Doundé)': 'DOU',
    'Grewia bicolor (Gadiaye)': 'GAD',
    'Guiera senegalensis (Nger)': 'NGE',
    'Hyphaene thebaica (Palmier doum)': 'PAL',
    'Jatropha curcas (Tabanani)': 'TAB',
    'Lannea acida (Sonk)': 'SON',
    'Leptadenia hastata (Thiouraye)': 'THI',
    'Leptadenia pyrotechnica (Thiouraye sauvage)': 'THS',
    'Mangifera indica (Manguier)': 'MAN',
    'Mitragyna inermis (Kadd)': 'KAD',
    'Moringa oleifera (Nebeday)': 'NEB',
    'Morus mesozygia (Figuier)': 'FIG',
    'Parkia biglobosa (Néré)': 'NER',
    'Parkinsonia aculeata (Képp)': 'KEP',
    'Piliostigma reticulatum (Nguiguis)': 'NGU',
    'Prosopis africana (Yir)': 'YIR',
    'Prosopis juliflora (Prosopis)': 'PRO',
    'Pterocarpus erinaceus (Vène)': 'VEN',
    'Sclerocarya birrea (Birr)': 'BIR',
    'Securidaca longipedunculata (Guedj guedj)': 'GUE',
    'Sterculia setigera (Mbep)': 'MBE',
    'Stereospermum kunthianum (Ngalam)': 'NGA',
    'Tamarindus indica (Dakhar)': 'DAK',
    'Terminalia macroptera (Wolo)': 'WOL',
    'Tinospora bakis (Liane médicinale)': 'TIN',
    'Ziziphus mauritiana (Sidem)': 'SID',
    'Ziziphus mucronata (Sidem)': 'SID',
  };

  // Liste normalisée : seul le nom scientifique est présenté et enregistré.
  String _paysProjet = 'Sénégal';
  List<String> _especesPersonnalisees = [];
  bool get _estSenegal => _paysProjet.toLowerCase() == 'sénégal' ||
      _paysProjet.toLowerCase() == 'senegal';

  List<String> get _especesList {
    final historiques = _estSenegal
        ? _abreviations.keys.map(
            (nom) => nom.replaceFirst(RegExp(r'\s*\([^)]*\)\s*$'), '').trim(),
          )
        : const <String>[];
    return SpeciesCatalog.mergeWithCustom(
      _paysProjet,
      <String>{...historiques, ..._especesPersonnalisees},
    );
  }

  // Variables d'état
  bool _isSaving = false;
  bool _isLoadingLocation = false;
  bool _isResetting = false;
  String _gpsErrorMessage = '';

  // Photo
  File? _photoFile;
  String? _savedPhotoPath;
  final ImagePicker _picker = ImagePicker();

  // Liste des arbres déjà inventoriés
  List<Arbre> _arbresInventories = [];
  int get _nombreDendrometriques => _arbresInventories
      .where((arbre) => arbre.modeInventaire != 'simple')
      .length;
  Arbre? _arbreEnModification;

  bool get _modeEdition => _arbreEnModification != null;

  // ✅ ID courant (peut changer si l'utilisateur change d'espèce)
  String _currentArbreId = '';

  // ✅ ID définitif attribué au moment de la prise de photo
  String _definitiveArbreId = '';

  // ✅ Flag pour savoir si une photo a été prise
  bool _photoPrise = false;
  String _indiceMemorise = 'Arbre';
  int _dernierNumeroMemorise = 0;

  @override
  void initState() {
    super.initState();
    _indiceIdController.addListener(_gererChangementIndice);
    _initialiserInventaireEtIndice();
    _chargerConfigurationPays();
    _getCurrentLocation();
    _requestPermissions();
    _distanceArbreController.addListener(_calculerHauteurClinometre);
    _angleCimeController.addListener(_calculerHauteurClinometre);
    _angleBaseController.addListener(_calculerHauteurClinometre);
    _diametre130Controller.addListener(_calculerDiametreCumule);
    _nombreTroncsController.addListener(_calculerDiametreCumule);
  }

  Future<void> _chargerConfigurationPays() async {
    final country = await ProjectCountryService.getCountry();
    final species = await ProjectCountryService.getCustomSpecies();
    if (!mounted) return;
    setState(() {
      _paysProjet = country ?? 'Sénégal';
      _especesPersonnalisees = species;
    });
  }

  double? _lireNombre(String value) {
    return double.tryParse(value.trim().replaceAll(',', '.'));
  }

  void _calculerDiametreCumule() {
    final diametre = _lireNombre(_diametre130Controller.text);
    final nombre = _typeTronc == 'Tronc unique'
        ? 1
        : int.tryParse(_nombreTroncsController.text.trim());
    final valeur = diametre != null && diametre > 0 && nombre != null && nombre > 0
        ? (diametre * nombre).toStringAsFixed(2)
        : '';
    if (_diametreCumuleController.text != valeur) {
      _diametreCumuleController.text = valeur;
    }
  }

  void _calculerHauteurClinometre() {
    if (_methodeHauteur != 'Mesure au clinomètre') return;
    final distance = _lireNombre(_distanceArbreController.text);
    final angleCime = _lireNombre(_angleCimeController.text);
    final angleBase = _lireNombre(_angleBaseController.text);
    if (distance == null || angleCime == null || angleBase == null || distance <= 0) {
      if (_hauteurTotaleController.text.isNotEmpty) {
        _hauteurTotaleController.clear();
      }
      return;
    }
    final hauteur = distance *
        (math.tan(angleCime * math.pi / 180) -
            math.tan(angleBase * math.pi / 180));
    if (hauteur > 0 && hauteur.isFinite) {
      final value = hauteur.toStringAsFixed(2);
      if (_hauteurTotaleController.text != value) {
        _hauteurTotaleController.text = value;
      }
    } else {
      _hauteurTotaleController.clear();
    }
  }

  // ✅ Demander les permissions nécessaires
  Future<void> _requestPermissions() async {
    if (kIsWeb) return;
    try {
      if (await _isAndroid13OrHigher()) {
        await [
          Permission.photos,
          Permission.videos,
          Permission.camera,
        ].request();
      } else {
        await [
          Permission.storage,
          Permission.camera,
        ].request();
      }
    } catch (e) {
      debugPrint('Erreur permissions: $e');
    }
  }

  // ✅ Vérifier si Android 13+
  Future<bool> _isAndroid13OrHigher() async {
    return true;
  }

  // ✅ Vérifier les permissions de stockage
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

  // ✅ Vérifier la permission caméra
  Future<bool> _checkCameraPermission() async {
    if (kIsWeb) return true;
    final status = await Permission.camera.status;
    if (status.isGranted) {
      return true;
    }

    final newStatus = await Permission.camera.request();
    return newStatus.isGranted;
  }

  // 📂 Obtenir le dossier de sauvegarde visible dans la galerie
  Future<Directory> _getPhotosDirectory() async {
    try {
      final hasPermission = await _checkStoragePermission();
      if (!hasPermission) {
        _showSnackBar(
            '⚠️ Permission de stockage refusée. Les photos ne seront pas sauvegardées.',
            false);
        return await getApplicationDocumentsDirectory();
      }

      if (Platform.isAndroid) {
        final directory =
            Directory('/storage/emulated/0/Pictures/LandTree_Survey/Arbres');
        if (!await directory.exists()) {
          await directory.create(recursive: true);
          debugPrint('📁 Dossier créé: ${directory.path}');
        }
        return directory;
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final photosDir = Directory('${directory.path}/arbres_photos');
        if (!await photosDir.exists()) {
          await photosDir.create(recursive: true);
        }
        return photosDir;
      }
    } catch (e) {
      debugPrint('Erreur création dossier photos: $e');
      final directory = await getApplicationDocumentsDirectory();
      final photosDir = Directory('${directory.path}/arbres_photos');
      if (!await photosDir.exists()) {
        await photosDir.create(recursive: true);
      }
      return photosDir;
    }
  }

  Future<void> _chargerInventaire() async {
    final arbres = DatabaseService().getArbresByPlacetteId(widget.placetteId);
    if (!mounted) return;
    setState(() {
      _arbresInventories = arbres;
    });
    _genererIdArbre();
  }

  String get _cleIndice => 'indice_arbre_${widget.placetteId}';
  String get _cleDernierNumero => 'numero_arbre_${widget.placetteId}';

  Future<void> _initialiserInventaireEtIndice() async {
    final arbres = DatabaseService().getArbresByPlacetteId(widget.placetteId);
    final preferences = await SharedPreferences.getInstance();

    var indice = preferences.getString(_cleIndice)?.trim() ?? '';
    var dernierNumero = preferences.getInt(_cleDernierNumero) ?? 0;

    // La numérotation automatique utilise toujours deux chiffres. Le dernier
    // ID enregistré est donc la source de vérité : P050-A001 devient la base
    // P050-A0 avec le numéro 01, puis la proposition suivante P050-A002.
    if (arbres.isNotEmpty) {
      final dernierId = arbres.first.id.trim();
      final correspondance = RegExp(r'^(.*)(\d{2})$').firstMatch(dernierId);
      if (correspondance != null &&
          (correspondance.group(1)?.isNotEmpty ?? false)) {
        indice = correspondance.group(1)!;
        dernierNumero = int.tryParse(correspondance.group(2)!) ?? 0;
      }
    } else {
      // Première entrée dans une placette sans arbre : valeur par défaut.
      indice = 'Arbre';
      dernierNumero = 0;
    }

    for (final arbre in arbres) {
      final correspondance = RegExp(
        '^${RegExp.escape(indice)}(\\d+)\$',
        caseSensitive: false,
      ).firstMatch(arbre.id);
      final numero = int.tryParse(correspondance?.group(1) ?? '') ?? 0;
      if (numero > dernierNumero) dernierNumero = numero;
    }

    await preferences.setString(_cleIndice, indice);
    await preferences.setInt(_cleDernierNumero, dernierNumero);
    if (!mounted) return;

    _indiceIdController.text = indice;
    setState(() {
      _arbresInventories = arbres;
      _indiceMemorise = indice;
      _dernierNumeroMemorise = dernierNumero;
    });
    _genererIdArbre();
  }

  Future<void> _memoriserIndiceEtNumero(String arbreId) async {
    final indice = _nettoyerIndiceId(_indiceIdController.text);
    final suffixe = arbreId.startsWith(indice)
        ? arbreId.substring(indice.length)
        : '';
    final numero = int.tryParse(suffixe) ?? 0;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_cleIndice, indice);
    await preferences.setInt(_cleDernierNumero, numero);
    _indiceMemorise = indice;
    _dernierNumeroMemorise = numero;
  }

  void _gererChangementIndice() {
    _genererIdArbre();
  }

  String _nettoyerIndiceId(String valeur) {
    return valeur.trim().replaceAll(RegExp(r'[^A-Za-zÀ-ÿ0-9_-]+'), '');
  }

  int _prochainNumeroPourIndice(String indice) {
    var numeroMaximum = indice.toLowerCase() == _indiceMemorise.toLowerCase()
        ? _dernierNumeroMemorise
        : 0;
    final expression = RegExp(
      '^${RegExp.escape(indice)}(\\d+)\$',
      caseSensitive: false,
    );
    for (final arbre in _arbresInventories) {
      final correspondance = expression.firstMatch(arbre.id);
      if (correspondance != null) {
        final numero = int.tryParse(correspondance.group(1) ?? '') ?? 0;
        if (numero > numeroMaximum) numeroMaximum = numero;
      }
    }
    return numeroMaximum + 1;
  }

  // Générer l'ID à partir de l'indice défini par l'utilisateur.
  void _genererIdArbre() {
    if (_modeEdition) {
      if (mounted) setState(() => _currentArbreId = _arbreEnModification!.id);
      return;
    }
    final indice = _nettoyerIndiceId(_indiceIdController.text);
    final nouvelId = indice.isEmpty
        ? 'DÉFINIR UN INDICE'
        : '$indice${_prochainNumeroPourIndice(indice).toString().padLeft(2, '0')}';
    if (mounted) setState(() => _currentArbreId = nouvelId);
  }

  // ✅ Générer un ID définitif unique pour la photo (basé sur timestamp)
  String _genererIdUniquePourPhoto() {
    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch;
    return 'PHOTO_$timestamp';
  }

  // Générer l'ID définitif avec l'indice et le compteur de la placette.
  String _genererIdDefinitifArbre() {
    if (_modeEdition) return _arbreEnModification!.id;
    final indice = _nettoyerIndiceId(_indiceIdController.text);
    if (indice.isEmpty) {
      throw Exception('Veuillez définir l’indice ID');
    }
    return '$indice${_prochainNumeroPourIndice(indice).toString().padLeft(2, '0')}';
  }

  // 📸 Charger une photo existante depuis le dossier visible
  Future<void> _chargerPhotoExistante(String arbreId) async {
    if (kIsWeb) return;
    try {
      final photosDir = await _getPhotosDirectory();
      final photoPath = '${photosDir.path}/$arbreId.jpg';
      final photoFile = File(photoPath);

      if (await photoFile.exists()) {
        if (!mounted) return;
        setState(() {
          _photoFile = photoFile;
          _savedPhotoPath = photoPath;
          _definitiveArbreId = arbreId;
          _photoPrise = true;
        });
      }
    } catch (e) {
      debugPrint('Erreur chargement photo: $e');
    }
  }

  // 📸 Prendre une photo avec ID unique définitif
  Future<void> _prendrePhoto() async {
    try {
      // ✅ Vérifier la permission caméra
      final hasCameraPermission = await _checkCameraPermission();
      if (!hasCameraPermission) {
        _showSnackBar('❌ Permission caméra refusée', false);
        _showPermissionDialog('Caméra', 'Pour prendre des photos');
        return;
      }

      // ✅ Vérifier la permission de stockage
      final hasStoragePermission = await _checkStoragePermission();
      if (!hasStoragePermission) {
        _showSnackBar('❌ Permission de stockage refusée', false);
        _showPermissionDialog('Stockage', 'Pour sauvegarder les photos');
        return;
      }

      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (!mounted) return;

      if (photo != null) {
        // ✅ GÉNÉRER UN ID UNIQUE DÉFINITIF pour cette photo
        final String uniquePhotoId = _genererIdUniquePourPhoto();

        final photosDir = await _getPhotosDirectory();
        final String fileName = '$uniquePhotoId.jpg';
        final String newPath = '${photosDir.path}/$fileName';

        // Supprimer l'ancienne photo si elle existe
        final File oldFile = File(newPath);
        if (await oldFile.exists()) {
          await oldFile.delete();
        }

        // Copier la nouvelle photo
        final File newFile = await File(photo.path).copy(newPath);

        // ✅ Vérifier que la photo a bien été sauvegardée
        if (await newFile.exists()) {
          if (!mounted) return;
          setState(() {
            _photoFile = newFile;
            _savedPhotoPath = newPath;
            _definitiveArbreId = uniquePhotoId;
            _photoPrise = true;
          });

          _showSnackBar(
            '📸 Photo enregistrée: $uniquePhotoId.jpg',
            true,
          );

          if (Platform.isAndroid) {
            debugPrint('📸 Photo sauvegardée dans: $newPath');
          }
        } else {
          throw Exception('La photo n\'a pas pu être sauvegardée');
        }
      }
    } catch (e) {
      debugPrint('Erreur photo: $e');
      _showSnackBar('❌ Erreur lors de la prise de photo: $e', false);
    }
  }

  // ✅ Dialogue pour les permissions refusées
  void _showPermissionDialog(String permission, String action) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('⚠️ Permission $permission requise'),
        content: Text(
          'Pour $action, vous devez autoriser l\'accès à $permission dans les paramètres de l\'application.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await openAppSettings();
              if (permission == 'Caméra') {
                await _checkCameraPermission();
              } else {
                await _checkStoragePermission();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E5D3A),
            ),
            child: const Text('Ouvrir paramètres'),
          ),
        ],
      ),
    );
  }

  // 📸 Supprimer la photo
  Future<void> _supprimerPhoto() async {
    if (_photoFile != null && await _photoFile!.exists()) {
      try {
        await _photoFile!.delete();
        if (!mounted) return;
        setState(() {
          _photoFile = null;
          _savedPhotoPath = null;
          _definitiveArbreId = '';
          _photoPrise = false;
        });
        _showSnackBar('🗑️ Photo supprimée', true);
      } catch (e) {
        if (!mounted) return;
        _showSnackBar('❌ Erreur lors de la suppression: $e', false);
      }
    } else {
      if (!mounted) return;
      setState(() {
        _photoFile = null;
        _savedPhotoPath = null;
        _definitiveArbreId = '';
        _photoPrise = false;
      });
    }
  }

  // 📂 Afficher l'emplacement des photos
  void _afficherEmplacementPhotos() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('📂 Emplacement des photos'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('📸 Les photos sont sauvegardées ici :'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const SelectableText(
                '/storage/emulated/0/Pictures/LandTree_Survey/Arbres/',
                style: TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '📱 Pour voir les photos :',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const Text('1. Ouvrez l\'application "Galerie" ou "Photos"'),
            const Text('2. Cherchez le dossier "LandTree_Survey"'),
            const Text('3. Puis le dossier "Arbres"'),
            const SizedBox(height: 8),
            if (_photoPrise && _definitiveArbreId.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Text(
                  '📸 Photo actuelle: $_definitiveArbreId.jpg',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            FutureBuilder<int>(
              future: _countPhotos(),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data! > 0) {
                  return Text(
                    '📊 ${snapshot.data} photo(s) sauvegardée(s)',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  );
                }
                return const SizedBox();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  // ✅ Compter les photos dans le dossier
  Future<int> _countPhotos() async {
    try {
      final photosDir = await _getPhotosDirectory();
      final files = await photosDir.list().toList();
      return files.where((f) => f.path.endsWith('.jpg')).length;
    } catch (e) {
      return 0;
    }
  }

  Future<void> _getCurrentLocation({bool afficherMessage = true}) async {
    if (!mounted) return;
    setState(() {
      _isLoadingLocation = true;
      _gpsErrorMessage = '';
    });

    try {
      final position = await GpsService().acquirePosition();
      if (!mounted) return;
      setState(() {
        _latitudeController.text = position.latitude.toStringAsFixed(6);
        _longitudeController.text = position.longitude.toStringAsFixed(6);
        _gpsErrorMessage = '';
      });
      if (afficherMessage) {
        _showSnackBar('📍 Coordonnées GPS actualisées', true);
      }
    } catch (e) {
      debugPrint('Erreur GPS: $e');
      if (!mounted) return;
      setState(() {
        _gpsErrorMessage = '⚠️ $e Saisie manuelle possible.';
      });
      if (afficherMessage) {
        _showSnackBar('⚠️ $e', false);
      }
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  void _showLocationSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('📍 GPS désactivé'),
        content: const Text(
            'Veuillez activer la localisation dans les paramètres de votre téléphone pour récupérer automatiquement les coordonnées.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await Geolocator.openLocationSettings();
              _getCurrentLocation();
            },
            child: const Text('Ouvrir les paramètres'),
          ),
        ],
      ),
    );
  }

  void _showOpenSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Permission refusée'),
        content: const Text(
            'Pour utiliser le GPS, veuillez autoriser la localisation dans les paramètres de l\'application.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await Geolocator.openAppSettings();
              _getCurrentLocation();
            },
            child: const Text('Ouvrir les paramètres'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, bool success) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            success ? const Color(0xFF4A7C59) : const Color(0xFFD32F2F),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _verifierEspeceInconnue(String? value) {
    setState(() {
      _isEspeceInconnue = value == 'Inconnue';
      if (!_isEspeceInconnue && value != null && value != '') {
        _selectedEspece = value;
        _especeInconnueController.clear();
      } else {
        _selectedEspece = '';
      }
      _genererIdArbre();
    });
  }

  Future<void> _ajouterArbre() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final arbreExistant = _arbreEnModification;
      final etaitEnModification = arbreExistant != null;
      final now = DateTime.now();

      // Générer l'ID définitif à partir de l'indice saisi.
      final String arbreId = _genererIdDefinitifArbre();

      final nomEspece = _isEspeceInconnue
          ? _especeInconnueController.text.trim()
          : _selectedEspece;
      if (!_estSenegal || _isEspeceInconnue) {
        await ProjectCountryService.rememberSpecies(nomEspece);
      }

      // ✅ Si une photo a été prise, renommer le fichier avec l'ID de l'arbre
      if (_photoPrise && _savedPhotoPath != null) {
        final photosDir = await _getPhotosDirectory();
        final String oldPath = _savedPhotoPath!;
        final String newPath = '${photosDir.path}/$arbreId.jpg';

        // Vérifier si l'ancien fichier existe
        final File oldFile = File(oldPath);
        if (await oldFile.exists() && oldPath != newPath) {
          // Supprimer l'ancienne photo si elle existe déjà avec le nouvel ID
          final File newFile = File(newPath);
          if (await newFile.exists()) {
            await newFile.delete();
          }
          // Renommer le fichier
          await oldFile.rename(newPath);

          setState(() {
            _savedPhotoPath = newPath;
            _photoFile = File(newPath);
          });

          debugPrint('📸 Photo renommée: $oldPath → $newPath');
        }
      }

      final arbre = Arbre(
        id: arbreId,
        placetteId: widget.placetteId,
        nomEspece: nomEspece,
        dap: _lireNombre(_diametre130Controller.text)!,
        typeTronc: _typeTronc,
        nombreTroncs: _typeTronc == 'Tronc unique'
            ? 1
            : int.parse(_nombreTroncsController.text.trim()),
        hauteur: _lireNombre(_hauteurTotaleController.text)!,
        diametreCouronne: (_houppierNSController.text.isNotEmpty &&
                _houppierEOController.text.isNotEmpty)
            ? (_lireNombre(_houppierNSController.text)! +
                    _lireNombre(_houppierEOController.text)!) /
                2
            : null,
        etatSanitaire: null,
        // `observations` ne contient plus que le commentaire libre.
        observations: _commentairesController.text.trim(),
        latitude: _lireNombre(_latitudeController.text),
        longitude: _lireNombre(_longitudeController.text),
        formeTronc: _formeTronc,
        methodeHauteur: _methodeHauteur,
        distanceClinometre: _methodeHauteur == 'Mesure au clinomètre'
            ? _lireNombre(_distanceArbreController.text)
            : null,
        angleCime: _methodeHauteur == 'Mesure au clinomètre'
            ? _lireNombre(_angleCimeController.text)
            : null,
        angleBase: _methodeHauteur == 'Mesure au clinomètre'
            ? _lireNombre(_angleBaseController.text)
            : null,
        houppierNS: _lireNombre(_houppierNSController.text),
        houppierEO: _lireNombre(_houppierEOController.text),
        photoLocale: _savedPhotoPath,
        dateCreation: arbreExistant?.dateCreation ?? now,
      );

      if (etaitEnModification) {
        await DatabaseService().updateArbre(arbre);
      } else {
        await DatabaseService().saveArbre(arbre);
        await _memoriserIndiceEtNumero(arbreId);
      }
      await _effacerFormulaire();
      await _chargerInventaire();
      _showSnackBar(
        etaitEnModification
            ? '✅ Arbre $arbreId mis à jour !'
            : '✅ Arbre $arbreId ajouté à l\'inventaire !',
        true,
      );
    } catch (e) {
      _showSnackBar('❌ Erreur: $e', false);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _effacerFormulaire({bool afficherChargement = false}) async {
    if (_isResetting) return;
    if (afficherChargement && mounted) {
      setState(() => _isResetting = true);
    }
    _selectedEspece = '';
    _diametre130Controller.clear();
    _nombreTroncsController.text = '1';
    _diametreCumuleController.clear();
    _hauteurTotaleController.clear();
    _distanceArbreController.clear();
    _angleCimeController.clear();
    _angleBaseController.clear();
    _houppierNSController.clear();
    _houppierEOController.clear();
    _commentairesController.clear();
    _especeInconnueController.clear();
    setState(() {
      _arbreEnModification = null;
      _isEspeceInconnue = false;
      _formeTronc = 'Droit';
      _typeTronc = 'Tronc unique';
      _methodeHauteur = 'Mesure directe';
      _gpsErrorMessage = '';
      _photoFile = null;
      _savedPhotoPath = null;
      _definitiveArbreId = '';
      _photoPrise = false;
    });
    _genererIdArbre();
    try {
      await _getCurrentLocation(afficherMessage: false);
    } finally {
      if (afficherChargement && mounted) {
        setState(() => _isResetting = false);
      }
    }
  }

  String _valeurObservation(String libelle, String observations) {
    final match = RegExp('${RegExp.escape(libelle)}: ([^•]+)')
        .firstMatch(observations);
    return match?.group(1)?.trim() ?? '';
  }

  Future<void> _chargerArbrePourModification(Arbre arbre) async {
    final observations = arbre.observations ?? '';
    final gps = _valeurObservation('GPS', observations).split(',');
    final forme = _valeurObservation('Forme tronc', observations);
    final methode = _valeurObservation('Méthode hauteur', observations);
    final notes = _valeurObservation('Notes', observations);
    final houppier = RegExp(r'Houppier: ([\d.,]+)m x ([\d.,]+)m')
        .firstMatch(observations);
    final clinometre = RegExp(
      r'Clinomètre: distance ([\d.,-]+) m, angle cime ([\d.,-]+)°, angle base ([\d.,-]+)°',
    ).firstMatch(observations);
    final especeConnue = _especesList.contains(arbre.nomScientifique);
    final indice = arbre.id.replaceFirst(RegExp(r'\d+$'), '');

    setState(() {
      _arbreEnModification = arbre;
      _currentArbreId = arbre.id;
      _indiceIdController.text = indice.isEmpty ? 'Arbre' : indice;
      _selectedEspece = especeConnue ? arbre.nomScientifique : '';
      _isEspeceInconnue = !especeConnue;
      _especeInconnueController.text =
          especeConnue ? '' : arbre.nomScientifique;
      _diametre130Controller.text = arbre.dap.toString();
      _typeTronc = arbre.typeTronc;
      _nombreTroncsController.text = arbre.nombreTroncs.toString();
      _hauteurTotaleController.text = arbre.hauteur.toString();
      _formeTronc = _formesTronc.contains(arbre.formeTronc)
          ? arbre.formeTronc!
          : (_formesTronc.contains(forme) ? forme : 'Droit');
      _methodeHauteur = _methodesHauteur.contains(arbre.methodeHauteur)
          ? arbre.methodeHauteur!
          : _methodesHauteur.contains(methode)
          ? methode
          : 'Mesure directe';
      _latitudeController.text = arbre.latitude?.toString() ??
          (gps.isNotEmpty ? gps.first.trim() : '');
      _longitudeController.text = arbre.longitude?.toString() ??
          (gps.length > 1 ? gps[1].trim() : '');
      _houppierNSController.text = arbre.houppierNS?.toString() ?? houppier?.group(1) ??
          (arbre.diametreCouronne?.toString() ?? '');
      _houppierEOController.text = arbre.houppierEO?.toString() ?? houppier?.group(2) ??
          (arbre.diametreCouronne?.toString() ?? '');
      _distanceArbreController.text = arbre.distanceClinometre?.toString() ?? clinometre?.group(1) ?? '';
      _angleCimeController.text = arbre.angleCime?.toString() ?? clinometre?.group(2) ?? '';
      _angleBaseController.text = arbre.angleBase?.toString() ?? clinometre?.group(3) ?? '';
      _commentairesController.text = arbre.formeTronc != null
          ? observations
          : notes;
      _definitiveArbreId = arbre.id;
    });
    _calculerDiametreCumule();
    await _chargerPhotoExistante(arbre.id);
  }

  Future<void> _confirmerModificationArbre(Arbre arbre) async {
    final confirmer = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Modifier cet arbre ?'),
            content: Text(
              'Voulez-vous réellement modifier l’arbre ${arbre.id} ?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Annuler'),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(dialogContext, true),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Modifier'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmer || !mounted) return;
    await _chargerArbrePourModification(arbre);
  }

  Future<void> _supprimerArbre(Arbre arbre) async {
    try {
      final photosDir = await _getPhotosDirectory();
      final photoPath = '${photosDir.path}/${arbre.id}.jpg';
      final photoFile = File(photoPath);
      if (await photoFile.exists()) {
        await photoFile.delete();
      }
    } catch (e) {
      debugPrint('Erreur suppression photo: $e');
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer cet arbre ?'),
        content: Text('Supprimer "${arbre.nomScientifique}" de l\'inventaire ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              await DatabaseService().deleteArbre(arbre.placetteId, arbre.id);
              Navigator.pop(context);
              await _chargerInventaire();
              _showSnackBar('🗑️ Arbre supprimé', true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  void _showArbreDetails(Arbre arbre) {
    String gps = '';
    String formeTronc = '';
    String houppier = '';
    String notes = '';
    bool aPhoto = false;

    if (arbre.observations != null && arbre.observations!.isNotEmpty) {
      final obs = arbre.observations!;
      if (obs.contains('GPS:')) {
        final gpsMatch = RegExp(r'GPS: ([^•]+)').firstMatch(obs);
        if (gpsMatch != null) gps = gpsMatch.group(1)?.trim() ?? '';
      }
      if (obs.contains('Forme tronc:')) {
        final formeMatch = RegExp(r'Forme tronc: ([^•]+)').firstMatch(obs);
        if (formeMatch != null) formeTronc = formeMatch.group(1)?.trim() ?? '';
      }
      if (obs.contains('Houppier:')) {
        final houppierMatch = RegExp(r'Houppier: ([^•]+)').firstMatch(obs);
        if (houppierMatch != null)
          houppier = houppierMatch.group(1)?.trim() ?? '';
      }
      if (obs.contains('Notes:')) {
        final notesMatch = RegExp(r'Notes: ([^•]+)').firstMatch(obs);
        if (notesMatch != null) notes = notesMatch.group(1)?.trim() ?? '';
      }
      if (obs.contains('📸 Photo:')) {
        aPhoto = true;
      }
    }

    if (arbre.latitude != null && arbre.longitude != null) {
      gps = '${arbre.latitude}, ${arbre.longitude}';
    }
    formeTronc = arbre.formeTronc ?? formeTronc;
    if (arbre.houppierNS != null || arbre.houppierEO != null) {
      houppier = '${arbre.houppierNS?.toString() ?? "—"} m × '
          '${arbre.houppierEO?.toString() ?? "—"} m';
    }
    if (arbre.formeTronc != null) notes = arbre.observations ?? '';
    aPhoto = arbre.photoLocale != null || aPhoto;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.park, color: Color(0xFF2E5D3A)),
            const SizedBox(width: 8),
            Expanded(
                child: Text(arbre.nomScientifique,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold))),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow('🆔 ID', arbre.id),
              const Divider(),
              _detailRow('🌿 Nom scientifique', arbre.nomScientifique),
              const SizedBox(height: 4),
              if (gps.isNotEmpty) ...[
                _detailRow('📍 GPS', gps),
                const SizedBox(height: 4),
              ],
              _detailRow(
                  '📏 Diamètre (1,30m)', '${arbre.dap.toStringAsFixed(1)} cm'),
              _detailRow('🌳 Type de tronc', arbre.typeTronc),
              _detailRow('🔢 Nombre de troncs', '${arbre.nombreTroncs}'),
              _detailRow('📐 Diamètre cumulé',
                  '${arbre.diametreCumule.toStringAsFixed(2)} cm'),
              _detailRow(
                  '📐 Hauteur totale', '${arbre.hauteur.toStringAsFixed(2)} m'),
              if (houppier.isNotEmpty) _detailRow('🌿 Houppier', houppier),
              if (formeTronc.isNotEmpty)
                _detailRow('🌲 Forme du tronc', formeTronc),
              if (arbre.methodeHauteur != null)
                _detailRow('📐 Méthode hauteur', arbre.methodeHauteur!),
              if (arbre.distanceClinometre != null)
                _detailRow('↔️ Distance clinomètre', '${arbre.distanceClinometre} m'),
              if (arbre.angleCime != null)
                _detailRow('🔺 Angle cime', '${arbre.angleCime}°'),
              if (arbre.angleBase != null)
                _detailRow('🔻 Angle base', '${arbre.angleBase}°'),
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 4),
                _detailRow('📝 Commentaires', notes),
              ],
              if (aPhoto) ...[
                const SizedBox(height: 4),
                _detailRow('📸 Photo', 'Oui (${arbre.id}.jpg)'),
              ],
              const SizedBox(height: 8),
              _detailRow('📅 Date création', arbre.formattedDate),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _confirmerModificationArbre(arbre);
            },
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Modifier'),
          ),
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fermer')),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final labelWidget = Text(label,
              style: const TextStyle(fontWeight: FontWeight.bold));
          if (constraints.maxWidth < 330) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [labelWidget, const SizedBox(height: 2), Text(value)],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 120, child: labelWidget),
              Expanded(child: Text(value)),
            ],
          );
        },
      ),
    );
  }

  void _showArbresListPopup() {
    final arbresDendrometriques = _arbresInventories
        .where((arbre) => arbre.modeInventaire != 'simple')
        .toList();
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: MediaQuery.sizeOf(context).width < 380 ? 10 : 40,
          vertical: 24,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: double.maxFinite,
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.forest, color: Color(0xFF2E5D3A)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Liste des arbres (${arbresDendrometriques.length})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2E5D3A))),
                  ),
                  IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context)),
                ],
              ),
              const Divider(),
              Expanded(
                child: arbresDendrometriques.isEmpty
                    ? const Center(child: Text('Aucun arbre inventorié'))
                    : ListView.builder(
                        itemCount: arbresDendrometriques.length,
                        itemBuilder: (context, index) {
                          final a = arbresDendrometriques[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    const Color(0xFF2E5D3A).withOpacity(0.2),
                                child: Text('${index + 1}',
                                    style: const TextStyle(
                                        color: Color(0xFF2E5D3A),
                                        fontWeight: FontWeight.bold)),
                              ),
                              title: Text(a.nomScientifique,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              subtitle: Text('ID: ${a.id} • ${a.formattedDAP}',
                                  style: const TextStyle(fontSize: 12)),
                              trailing: IconButton(
                                tooltip: 'Modifier',
                                icon: const Icon(Icons.edit_outlined,
                                    color: Color(0xFF2E5D3A)),
                                onPressed: () {
                                  Navigator.pop(context);
                                  _confirmerModificationArbre(a);
                                },
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                _showArbreDetails(a);
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _latitudeController.dispose();
    _longitudeController.dispose();
    _diametre130Controller.dispose();
    _nombreTroncsController.dispose();
    _diametreCumuleController.dispose();
    _hauteurTotaleController.dispose();
    _distanceArbreController.dispose();
    _angleCimeController.dispose();
    _angleBaseController.dispose();
    _houppierNSController.dispose();
    _houppierEOController.dispose();
    _commentairesController.dispose();
    _especeInconnueController.dispose();
    _indiceIdController.removeListener(_gererChangementIndice);
    _indiceIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.sand,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF2E5D3A)),
          onPressed: () => Navigator.pop(context, true),
        ),
        title: Column(
          children: [
            const Text('Land.Tree Survey',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E5D3A))),
            Text('Inventaire - ${widget.regionNom}',
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open, color: Color(0xFF2E5D3A)),
            onPressed: _afficherEmplacementPhotos,
            tooltip: 'Emplacement des photos',
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.format_list_bulleted,
                    color: Color(0xFF2E5D3A)),
                onPressed: _showArbresListPopup,
                tooltip: 'Voir la liste des arbres',
              ),
              if (_nombreDendrometriques > 0)
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                        color: const Color(0xFF2E5D3A),
                        borderRadius: BorderRadius.circular(10)),
                    constraints:
                        const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text('$_nombreDendrometriques',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, -2))
                ],
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.all(
                    MediaQuery.sizeOf(context).width < 360 ? 12 : 16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.add_circle,
                              color: Color(0xFF2E5D3A)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_modeEdition
                                ? 'Modifier l’arbre'
                                : 'Ajouter un arbre',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2E5D3A))),
                          ),
                          TextButton(
                            onPressed: _isResetting
                                ? null
                                : () => _effacerFormulaire(
                                      afficherChargement: true,
                                    ),
                            child: _isResetting
                                ? const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Text('Chargement…'),
                                    ],
                                  )
                                : Text(
                                    _modeEdition
                                        ? 'Annuler la modification'
                                        : 'Effacer tout',
                                  ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Indice choisi par l'utilisateur : Arbre, Bordure, etc.
                      TextFormField(
                        controller: _indiceIdController,
                        enabled: !_modeEdition,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Indice ID *',
                          hintText: 'Exemple : Arbre',
                          helperText:
                              'Le numéro est ajouté automatiquement : Arbre01, Arbre02…',
                          prefixIcon: Icon(Icons.label_outline),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null ||
                              _nettoyerIndiceId(value).isEmpty) {
                            return 'Veuillez définir l’indice ID';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // ✅ ID de l'arbre (prévisualisation)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: const Color(0xFF2E5D3A).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          children: [
                            const Icon(Icons.qr_code, color: Color(0xFF2E5D3A)),
                            const SizedBox(width: 12),
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('ID DE L\'ARBRE',
                                    style: TextStyle(
                                        fontSize: 11, color: Colors.grey)),
                                const SizedBox(height: 4),
                                Text(_currentArbreId,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF2E5D3A))),
                              ],
                            )),
                            if (_photoPrise) ...[
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                    color: Colors.green,
                                    borderRadius: BorderRadius.circular(12)),
                                child: const Text(
                                  '📸 PHOTO',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 1. IDENTIFICATION
                      _buildSectionTitle('1. IDENTIFICATION', Icons.tag),
                      const SizedBox(height: 8),

                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: _isEspeceInconnue
                            ? 'Inconnue'
                            : (_selectedEspece.isEmpty
                                ? null
                                : _selectedEspece),
                        decoration: const InputDecoration(
                          labelText: 'Espèce *',
                          hintText: 'Sélectionnez une espèce',
                          prefixIcon: Icon(Icons.forest),
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          ..._especesList.map((espece) => DropdownMenuItem(
                                value: espece,
                                child: Text(espece,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              )),
                          const DropdownMenuItem(
                              value: '',
                              child: Divider(height: 1),
                              enabled: false),
                          const DropdownMenuItem(
                            value: 'Inconnue',
                            child: Row(children: [
                              Icon(Icons.help_outline,
                                  size: 18, color: Colors.grey),
                              SizedBox(width: 8),
                              Text('Saisir une nouvelle espèce',
                                  style: TextStyle(fontStyle: FontStyle.italic))
                            ]),
                          ),
                        ],
                        selectedItemBuilder: (context) => [
                          ..._especesList.map((espece) => Align(
                                alignment: Alignment.centerLeft,
                                child: Text(espece,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              )),
                          const SizedBox.shrink(),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Saisir une nouvelle espèce',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                        onChanged: _verifierEspeceInconnue,
                        validator: (value) {
                          if (value == null || value.isEmpty)
                            return 'Veuillez sélectionner une espèce';
                          return null;
                        },
                      ),
                      if (_isEspeceInconnue) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.gold.withOpacity(0.35),
                            ),
                          ),
                          child: TextFormField(
                            controller: _especeInconnueController,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Nom scientifique *',
                              hintText: 'Exemple : Acacia nilotica',
                              helperText:
                                  'Saisissez uniquement le nom scientifique',
                              prefixIcon: Icon(Icons.edit_note_rounded),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (!_isEspeceInconnue) return null;
                              if (value == null || value.trim().isEmpty) {
                                return 'Veuillez saisir le nom scientifique';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),

                      // 2. LOCALISATION GPS
                      _buildSectionTitle(
                          '2. LOCALISATION GPS', Icons.location_on),
                      const SizedBox(height: 8),

                      if (_gpsErrorMessage.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border:
                                  Border.all(color: Colors.orange.shade300)),
                          child: Row(
                            children: [
                              Icon(Icons.warning_amber,
                                  color: Colors.orange.shade700),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Text(_gpsErrorMessage,
                                      style: TextStyle(
                                          color: Colors.orange.shade800))),
                            ],
                          ),
                        ),

                      if (_isLoadingLocation)
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Row(
                            children: [
                              SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2)),
                              SizedBox(width: 12),
                              Text('Récupération des coordonnées GPS...'),
                            ],
                          ),
                        ),

                      ResponsiveFields(
                        first: TextFormField(
                              controller: _latitudeController,
                              decoration: InputDecoration(
                                labelText: 'Latitude *',
                                hintText: 'Ex: 14.7167',
                                prefixIcon: const Icon(Icons.swap_vert,
                                    color: Color(0xFF2E5D3A)),
                                border: const OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.numberWithOptions(
                                  decimal: true),
                              validator: (value) =>
                                  value == null || value.isEmpty
                                      ? 'Champ requis'
                                      : null,
                            ),
                        second: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: TextFormField(
                              controller: _longitudeController,
                              decoration: InputDecoration(
                                labelText: 'Longitude *',
                                hintText: 'Ex: -17.4677',
                                prefixIcon: const Icon(Icons.swap_horiz,
                                    color: Color(0xFF2E5D3A)),
                                border: const OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.numberWithOptions(
                                  decimal: true),
                              validator: (value) =>
                                  value == null || value.isEmpty
                                      ? 'Champ requis'
                                      : null,
                            )),
                            IconButton(
                            onPressed:
                                _isLoadingLocation ? null : _getCurrentLocation,
                            icon: _isLoadingLocation
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : const Icon(Icons.gps_fixed,
                                    color: Color(0xFF2E5D3A)),
                            tooltip: 'Récupérer la position GPS',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.info_outline,
                              size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '📍 Cliquez sur l\'icône GPS pour récupérer automatiquement votre position. Vous pouvez aussi saisir manuellement.',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey.shade600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 3. MESURES DENDROMÉTRIQUES
                      _buildSectionTitle(
                          '3. MESURES DENDROMÉTRIQUES', Icons.straighten),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.leaf.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.leaf.withOpacity(0.22),
                          ),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.tips_and_updates_rounded,
                                color: AppColors.leaf, size: 21),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Renseignez le diamètre, puis choisissez la méthode de mesure de la hauteur. Les intitulés restent visibles pendant toute la saisie.',
                                style: TextStyle(
                                  color: AppColors.ink,
                                  fontSize: 12.5,
                                  height: 1.4,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      DropdownButtonFormField<String>(
                        value: _typeTronc,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Configuration du tronc *',
                          helperText: 'Indiquez si l’arbre possède un ou plusieurs troncs',
                          prefixIcon: Icon(Icons.forest_rounded),
                          border: OutlineInputBorder(),
                        ),
                        items: _typesTronc
                            .map((type) => DropdownMenuItem(
                                  value: type,
                                  child: Text(type, overflow: TextOverflow.ellipsis),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _typeTronc = value;
                            if (value == 'Tronc unique') {
                              _nombreTroncsController.text = '1';
                            } else if (_nombreTroncsController.text == '1') {
                              _nombreTroncsController.text = '';
                            }
                            _calculerDiametreCumule();
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      if (_typeTronc == 'Plusieurs troncs') ...[
                        TextFormField(
                          controller: _nombreTroncsController,
                          decoration: const InputDecoration(
                            labelText: 'Nombre total de troncs *',
                            hintText: 'Ex. : 3',
                            helperText: 'Comptez tous les troncs appartenant au même arbre',
                            prefixIcon: Icon(Icons.numbers_rounded),
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (_typeTronc != 'Plusieurs troncs') return null;
                            final nombre = int.tryParse((value ?? '').trim());
                            if (nombre == null || nombre < 2) {
                              return 'Saisissez au moins 2 troncs';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextFormField(
                        controller: _diametre130Controller,
                        decoration: const InputDecoration(
                          labelText: 'Diamètre moyen à 1,30 m (cm) *',
                          hintText: 'En cm',
                          helperText: 'Pour plusieurs troncs, saisissez le diamètre moyen représentatif',
                          prefixIcon: Icon(Icons.circle),
                          suffixText: 'cm',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (value) {
                          final nombre = _lireNombre(value ?? '');
                          if (nombre == null || nombre <= 0) return 'Nombre positif requis';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _diametreCumuleController,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'Diamètre cumulé calculé (cm)',
                          helperText: _typeTronc == 'Tronc unique'
                              ? 'Identique au diamètre mesuré'
                              : 'Diamètre moyen × nombre de troncs',
                          prefixIcon: const Icon(Icons.calculate_rounded),
                          suffixText: 'cm',
                          filled: true,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _methodeHauteur,
                        decoration: const InputDecoration(
                          labelText: 'Méthode de mesure de la hauteur *',
                          prefixIcon: Icon(Icons.height),
                          helperText: 'Choisissez la méthode utilisée sur le terrain',
                          border: OutlineInputBorder(),
                        ),
                        items: _methodesHauteur
                            .map((methode) => DropdownMenuItem(
                                  value: methode,
                                  child: Text(methode),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _methodeHauteur = value;
                            _hauteurTotaleController.clear();
                            if (value == 'Mesure directe') {
                              _distanceArbreController.clear();
                              _angleCimeController.clear();
                              _angleBaseController.clear();
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      if (_methodeHauteur == 'Mesure au clinomètre') ...[
                        TextFormField(
                          controller: _distanceArbreController,
                          decoration: const InputDecoration(
                            labelText: '1/3 · Distance arbre–observateur *',
                            hintText: 'Ex. 15',
                            prefixIcon: Icon(Icons.social_distance),
                            suffixText: 'm',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (value) {
                            final nombre = _lireNombre(value ?? '');
                            if (nombre == null || nombre <= 0) return 'Distance positive requise';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _angleCimeController,
                          decoration: const InputDecoration(
                            labelText: '2/3 · Angle vers la cime *',
                            hintText: 'Ex. 35',
                            prefixIcon: Icon(Icons.trending_up_rounded),
                            suffixText: '°',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          validator: (value) => _lireNombre(value ?? '') == null
                              ? 'Angle requis'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _angleBaseController,
                          decoration: const InputDecoration(
                            labelText: '3/3 · Angle vers la base *',
                            hintText: 'Ex. -3',
                            prefixIcon: Icon(Icons.trending_down_rounded),
                            suffixText: '°',
                            helperText: 'Saisir un angle négatif si la base est plus basse que l’observateur',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          validator: (value) => _lireNombre(value ?? '') == null
                              ? 'Angle requis'
                              : null,
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextFormField(
                        controller: _hauteurTotaleController,
                        readOnly: _methodeHauteur == 'Mesure au clinomètre',
                        decoration: InputDecoration(
                          labelText: _methodeHauteur == 'Mesure au clinomètre'
                              ? 'Hauteur calculée (m) *'
                              : 'Hauteur mesurée (m) *',
                          hintText: _methodeHauteur == 'Mesure au clinomètre'
                              ? 'Calcul automatique'
                              : 'Saisir la mesure directe',
                          prefixIcon: const Icon(Icons.height),
                          suffixText: 'm',
                          suffixIcon: _methodeHauteur == 'Mesure au clinomètre'
                              ? const Icon(Icons.calculate_outlined)
                              : null,
                          border: const OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (value) {
                          final nombre = _lireNombre(value ?? '');
                          if (nombre == null || nombre <= 0) {
                            return _methodeHauteur == 'Mesure au clinomètre'
                                ? 'Vérifiez les trois paramètres du clinomètre'
                                : 'Hauteur positive requise';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      ResponsiveFields(
                        first: TextFormField(
                              controller: _houppierNSController,
                              decoration: const InputDecoration(
                                labelText: 'Diamètre houppier N-S (m)',
                                hintText: 'Optionnel',
                                prefixIcon: Icon(Icons.radio_button_unchecked),
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.numberWithOptions(
                                  decimal: true),
                            ),
                        second: TextFormField(
                              controller: _houppierEOController,
                              decoration: const InputDecoration(
                                labelText: 'Diamètre houppier E-O (m)',
                                hintText: 'Optionnel',
                                prefixIcon: Icon(Icons.radio_button_checked),
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.numberWithOptions(
                                  decimal: true),
                            ),
                      ),
                      const SizedBox(height: 16),

                      // 4. FORME DU TRONC
                      _buildSectionTitle('4. FORME DU TRONC', Icons.timeline),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _formeTronc,
                        decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.show_chart)),
                        items: _formesTronc
                            .map((forme) => DropdownMenuItem(
                                value: forme, child: Text(forme)))
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _formeTronc = value!),
                      ),
                      const SizedBox(height: 16),

                      // PHOTO - AMÉLIORÉ
                      _buildSectionTitle('PHOTO', Icons.camera_alt),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _prendrePhoto,
                                    icon: const Icon(Icons.camera),
                                    label: const Text('Prendre une photo'),
                                    style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12)),
                                  ),
                                ),
                                if (_photoFile != null) ...[
                                  const SizedBox(width: 12),
                                  Stack(
                                    children: [
                                      Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          image: DecorationImage(
                                              image: FileImage(_photoFile!),
                                              fit: BoxFit.cover),
                                        ),
                                      ),
                                      Positioned(
                                        right: -4,
                                        top: -4,
                                        child: GestureDetector(
                                          onTap: _supprimerPhoto,
                                          child: Container(
                                            padding: const EdgeInsets.all(2),
                                            decoration: const BoxDecoration(
                                                color: Colors.red,
                                                shape: BoxShape.circle),
                                            child: const Icon(Icons.close,
                                                size: 14, color: Colors.white),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.info_outline,
                                    size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    '📸 La photo sera sauvegardée avec un ID unique puis renommée automatiquement',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              '📁 Dossier: Pictures/LandTree_Survey/Arbres/',
                              style:
                                  TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 10. COMMENTAIRES
                      _buildSectionTitle('10. COMMENTAIRES', Icons.comment),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _commentairesController,
                        decoration: const InputDecoration(
                          labelText: 'Notes',
                          hintText: 'Observations supplémentaires...',
                          prefixIcon: Icon(Icons.edit_note),
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 24),

                      // BOUTON ENREGISTRER
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _ajouterArbre,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E5D3A),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isSaving
                              ? const CircularProgressIndicator(
                                  color: Colors.white)
                              : Text(
                                  _modeEdition
                                      ? 'METTRE À JOUR L’ARBRE'
                                      : 'ENREGISTRER',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white)),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
                color: const Color(0xFF2E5D3A),
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Icon(icon, size: 18, color: const Color(0xFF2E5D3A)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E5D3A))),
        ),
      ],
    );
  }
}
