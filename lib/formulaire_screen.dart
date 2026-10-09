import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'models/placette.dart';
import 'services/database_service.dart';
import 'services/project_country_service.dart';
import 'services/gps_service.dart';
import 'theme/app_theme.dart';
import 'widgets/responsive_fields.dart';

class FormulaireScreen extends StatefulWidget {
  final Placette? placetteAEditer;

  const FormulaireScreen({super.key, this.placetteAEditer});

  @override
  State<FormulaireScreen> createState() => _FormulaireScreenState();
}

class _FormulaireScreenState extends State<FormulaireScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _superficieController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final _agentController = TextEditingController();
  final _observationsController = TextEditingController();
  final _occupationManuelleController = TextEditingController();

  // Options Oui/Non
  bool _presenceCulture = false;
  bool _presenceFeux = false;

  // ID généré automatiquement
  String _generatedId = '';

  bool _isSaving = false;
  bool _isLoadingLocation = false;
  bool _isResetting = false;

  // 📸 PHOTO
  File? _photoFile;
  String? _savedPhotoPath;
  final ImagePicker _picker = ImagePicker();

  // Région sélectionnée et régions déjà enregistrées.
  String _regionSelectionnee = '';
  final List<String> _regions = [];

  // 📋 LISTE DES TYPES D'OCCUPATION DU SOL
  final List<String> _typesOccupation = [
    'Savane arbustive',
    'Savane arbustive à arborée',
    'Forêt galerie',
    'Plantation',
    'Céréales (mil, maïs, sorgho, riz)',
    'Légumineuses (arachide, niébé)',
    'Autres cultures (pastèque, bissap, coton)',
    'Parc agroforestier',
    'Mare',
    'Vallée',
    'Zone nue',
    'Bâti',
    'Autre (à préciser)',
  ];

  // Variable pour l'occupation du sol sélectionnée
  String _selectedOccupation = '';
  String _paysProjet = 'Sénégal';
  List<String> _occupationsPersonnalisees = [];

  bool get _estSenegal => _paysProjet.toLowerCase() == 'sénégal' ||
      _paysProjet.toLowerCase() == 'senegal';
  bool get _saisieOccupation =>
      _selectedOccupation == 'Autre (à préciser)' ||
      _selectedOccupation == 'Ajouter une occupation';
  List<String> get _occupationOptions {
    final values = _estSenegal
        ? List<String>.from(_typesOccupation)
        : <String>[..._occupationsPersonnalisees, 'Ajouter une occupation'];
    if (_selectedOccupation.isNotEmpty &&
        !_saisieOccupation &&
        !values.contains(_selectedOccupation)) {
      values.insert(0, _selectedOccupation);
    }
    return values;
  }

  bool get _modeEdition => widget.placetteAEditer != null;

  @override
  void initState() {
    super.initState();
    _chargerRegionsEtGenererId();
    _chargerConfigurationPays();
    if (!_modeEdition) _getCurrentLocation();
    _requestPermissions();
  }

  Future<void> _chargerConfigurationPays() async {
    final country = await ProjectCountryService.getCountry();
    final occupations = await ProjectCountryService.getCustomOccupations();
    if (!mounted) return;
    setState(() {
      _paysProjet = country ?? 'Sénégal';
      _occupationsPersonnalisees = occupations;
    });
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
    return true; // À adapter selon votre besoin
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

  // 📂 Obtenir le dossier de sauvegarde visible dans la galerie (AMÉLIORÉ)
  Future<Directory> _getPhotosDirectory() async {
    try {
      final hasPermission = await _checkStoragePermission();
      if (!hasPermission) {
        _showSnackBar(context, '⚠️ Permission de stockage refusée', false);
        return await getApplicationDocumentsDirectory();
      }

      if (Platform.isAndroid) {
        // ✅ Dossier visible dans la galerie pour les placettes
        final directory =
            Directory('/storage/emulated/0/Pictures/LandTree_Survey/Placettes');
        if (!await directory.exists()) {
          await directory.create(recursive: true);
          debugPrint('📁 Dossier créé: ${directory.path}');
        }
        return directory;
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final photosDir = Directory('${directory.path}/placettes_photos');
        if (!await photosDir.exists()) {
          await photosDir.create(recursive: true);
        }
        return photosDir;
      }
    } catch (e) {
      debugPrint('Erreur création dossier photos: $e');
      final directory = await getApplicationDocumentsDirectory();
      final photosDir = Directory('${directory.path}/placettes_photos');
      if (!await photosDir.exists()) {
        await photosDir.create(recursive: true);
      }
      return photosDir;
    }
  }

  Future<void> _chargerRegionsEtGenererId() async {
    final regionsEnregistrees = DatabaseService()
        .getAllPlacettes()
        .map((placette) => placette.region.trim())
        .where((region) => region.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    if (!mounted) return;
    setState(() {
      _regions
        ..clear()
        ..addAll(regionsEnregistrees);
      if (_modeEdition) {
        final placette = widget.placetteAEditer!;
        if (!_regions.contains(placette.region)) _regions.add(placette.region);
        _regionSelectionnee = placette.region;
        _generatedId = placette.id;
        _superficieController.text = placette.superficie.toString();
        _latitudeController.text = placette.latitude.toString();
        _longitudeController.text = placette.longitude.toString();
        _selectedOccupation = placette.occupationSol;
        _presenceCulture = placette.presenceCulture;
        _presenceFeux = placette.presenceFeux;
        _agentController.text = placette.agent;
        _observationsController.text = placette.observations
            .replaceAll(RegExp(r'📸 Photo: [^•]+\s*•?\s*'), '')
            .trim();
      } else if (_regions.isNotEmpty) {
        _regionSelectionnee = _regions.first;
      }
    });
    if (!_modeEdition) _genererId();
    await _chargerPhotoExistante();
  }

  String _normaliserRegionPourId(String region) {
    const accents = 'ÀÁÂÃÄÅàáâãäåÈÉÊËèéêëÌÍÎÏìíîïÒÓÔÕÖòóôõöÙÚÛÜùúûüÇçÑñ';
    const simples = 'AAAAAAaaaaaaEEEEeeeeIIIIiiiiOOOOOoooooUUUUuuuuCcNn';
    var resultat = region.trim();
    for (var i = 0; i < accents.length; i++) {
      resultat = resultat.replaceAll(accents[i], simples[i]);
    }
    return resultat
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  void _genererId() {
    if (_modeEdition) return;
    final now = DateTime.now();
    final jour = now.day.toString().padLeft(2, '0');
    final mois = now.month.toString().padLeft(2, '0');
    final annee = now.year;
    final regionCode = _normaliserRegionPourId(_regionSelectionnee);

    if (regionCode.isEmpty) {
      if (mounted) setState(() => _generatedId = 'CHOISIR-REGION');
      return;
    }

    final nombrePlacettesDuJour = DatabaseService()
        .getAllPlacettes()
        .where((placette) {
          final date = placette.dateCreation;
          return placette.region.trim().toLowerCase() ==
                  _regionSelectionnee.trim().toLowerCase() &&
              date.year == now.year &&
              date.month == now.month &&
              date.day == now.day;
        })
        .length;
    var numero = nombrePlacettesDuJour + 1;
    var idCandidat =
        '$regionCode-$jour$mois$annee-${numero.toString().padLeft(4, '0')}';
    while (DatabaseService().getPlacette(idCandidat) != null) {
      numero++;
      idCandidat =
          '$regionCode-$jour$mois$annee-${numero.toString().padLeft(4, '0')}';
    }

    setState(() {
      _generatedId = idCandidat;
    });
  }

  Future<void> _ajouterRegion() async {
    final nouvelleRegion = await showDialog<String>(
      context: context,
      builder: (_) => const _AjouterRegionDialog(),
    );

    if (nouvelleRegion == null || nouvelleRegion.trim().isEmpty || !mounted) {
      return;
    }

    final regionExistante = _regions.cast<String?>().firstWhere(
          (region) =>
              region!.toLowerCase() == nouvelleRegion.trim().toLowerCase(),
          orElse: () => null,
        );
    final regionFinale = regionExistante ?? nouvelleRegion.trim();

    setState(() {
      if (regionExistante == null) {
        _regions.add(regionFinale);
        _regions.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      }
      _regionSelectionnee = regionFinale;
    });
    _genererId();
  }

  // 📸 Charger une photo existante depuis le dossier visible
  Future<void> _chargerPhotoExistante() async {
    if (kIsWeb) return;
    try {
      final photosDir = await _getPhotosDirectory();
      final photoPath = '${photosDir.path}/${_generatedId}.jpg';
      final photoFile = File(photoPath);

      if (await photoFile.exists()) {
        if (!mounted) return;
        setState(() {
          _photoFile = photoFile;
          _savedPhotoPath = photoPath;
        });
      }
    } catch (e) {
      debugPrint('Erreur chargement photo: $e');
    }
  }

  Future<void> _getCurrentLocation() async {
    if (!mounted) return;
    setState(() => _isLoadingLocation = true);
    try {
      final position = await GpsService().acquirePosition();
      if (!mounted) return;
      setState(() {
        _latitudeController.text = position.latitude.toStringAsFixed(6);
        _longitudeController.text = position.longitude.toStringAsFixed(6);
      });
      _showSnackBar(context, '📍 Coordonnées GPS actualisées', true);
    } catch (e) {
      debugPrint('Erreur GPS: $e');
      if (!mounted) return;
      _showSnackBar(context, '⚠️ $e', false);
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  // 📸 Prendre une photo (sauvegarde visible dans la galerie) - AMÉLIORÉ
  Future<void> _prendrePhoto() async {
    try {
      // ✅ Vérifier la permission caméra
      final hasCameraPermission = await _checkCameraPermission();
      if (!hasCameraPermission) {
        _showSnackBar(context, '❌ Permission caméra refusée', false);
        _showPermissionDialog(
            'Caméra', 'Pour prendre des photos de la placette');
        return;
      }

      // ✅ Vérifier la permission de stockage
      final hasStoragePermission = await _checkStoragePermission();
      if (!hasStoragePermission) {
        _showSnackBar(context, '❌ Permission de stockage refusée', false);
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
        final photosDir = await _getPhotosDirectory();
        final String fileName = '${_generatedId}.jpg';
        final String newPath = '${photosDir.path}/$fileName';

        final File oldFile = File(newPath);
        if (await oldFile.exists()) {
          await oldFile.delete();
        }

        final File newFile = await File(photo.path).copy(newPath);

        // ✅ Vérifier que la photo a bien été sauvegardée
        if (await newFile.exists()) {
          if (!mounted) return;
          setState(() {
            _photoFile = newFile;
            _savedPhotoPath = newPath;
          });

          _showSnackBar(
            context,
            '📸 Photo enregistrée: ${_generatedId}.jpg',
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
      _showSnackBar(context, '❌ Erreur photo: $e', false);
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
        });
        _showSnackBar(context, '🗑️ Photo supprimée', true);
      } catch (e) {
        if (!mounted) return;
        _showSnackBar(context, '❌ Erreur lors de la suppression: $e', false);
      }
    } else {
      if (!mounted) return;
      setState(() {
        _photoFile = null;
        _savedPhotoPath = null;
      });
    }
  }

  // 📂 Afficher l'emplacement des photos (AMÉLIORÉ)
  void _afficherEmplacementPhotos() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('📂 Emplacement des photos'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('📸 Les photos des placettes sont sauvegardées ici :'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const SelectableText(
                '/storage/emulated/0/Pictures/LandTree_Survey/Placettes/',
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
            const Text('3. Puis le dossier "Placettes"'),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.info_outline,
                    color: Colors.orange.shade700, size: 14),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '⚠️ Si vous ne voyez pas les photos, redémarrez la galerie ou utilisez un gestionnaire de fichiers.',
                    style:
                        TextStyle(fontSize: 12, color: Colors.orange.shade700),
                  ),
                ),
              ],
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

  void _showSnackBar(BuildContext context, String message, bool success) {
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

  Future<void> _effacerFormulaire() async {
    if (_isResetting) return;
    setState(() => _isResetting = true);
    setState(() {
      _superficieController.clear();
      _latitudeController.clear();
      _longitudeController.clear();
      _selectedOccupation = '';
      _observationsController.clear();
      _agentController.clear();
      _presenceCulture = false;
      _presenceFeux = false;
    });
    try {
      await _getCurrentLocation();
    } finally {
      if (mounted) setState(() => _isResetting = false);
    }
  }

  String _buildObservations() {
    List<String> obs = [];

    if (_savedPhotoPath != null) {
      obs.add("📸 Photo: $_generatedId.jpg");
    }

    if (_observationsController.text.isNotEmpty) {
      obs.add(_observationsController.text.trim());
    }

    return obs.join(" • ");
  }

  Future<void> _enregistrer() async {
    if (_regionSelectionnee.isEmpty) {
      _showSnackBar(context, '⚠️ Veuillez sélectionner une région', false);
      return;
    }

    final occupationFinale = _saisieOccupation
        ? _occupationManuelleController.text.trim()
        : _selectedOccupation.trim();
    if (occupationFinale.isEmpty) {
      _showSnackBar(
          context, '⚠️ Veuillez sélectionner l\'occupation du sol', false);
      return;
    }
    if (_saisieOccupation || !_estSenegal) {
      await ProjectCountryService.rememberOccupation(occupationFinale);
    }

    // ✅ Vérifier que la photo a bien été sauvegardée
    if (_savedPhotoPath != null) {
      final photoFile = File(_savedPhotoPath!);
      if (!await photoFile.exists()) {
        _showSnackBar(
            context, '⚠️ La photo a été perdue, veuillez la reprendre', false);
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final placette = Placette(
        id: _modeEdition ? widget.placetteAEditer!.id : _generatedId,
        region: _regionSelectionnee,
        superficie:
            double.tryParse(_superficieController.text.replaceAll(',', '.')) ??
                0.0,
        latitude:
            double.tryParse(_latitudeController.text.replaceAll(',', '.')) ??
                0.0,
        longitude:
            double.tryParse(_longitudeController.text.replaceAll(',', '.')) ??
                0.0,
        occupationSol: occupationFinale,
        presenceCulture: _presenceCulture,
        presenceFeux: _presenceFeux,
        observations: _buildObservations(),
        agent: _agentController.text.trim(),
        dateCreation: _modeEdition
            ? widget.placetteAEditer!.dateCreation
            : DateTime.now(),
        pays: _paysProjet,
      );

      if (_modeEdition) {
        await DatabaseService().updatePlacette(placette);
      } else {
        await DatabaseService().savePlacette(placette);
      }

      debugPrint('=== PLACETTE ENREGISTRÉE ===');
      debugPrint('ID: $_generatedId');
      debugPrint('Région: ${placette.region}');
      debugPrint('Superficie: ${placette.superficie} ha');
      debugPrint('GPS: ${placette.latitude}, ${placette.longitude}');
      debugPrint('Occupation: ${placette.occupationSol}');
      debugPrint('Culture: ${placette.presenceCulture ? "Oui" : "Non"}');
      debugPrint('Feux: ${placette.presenceFeux ? "Oui" : "Non"}');
      debugPrint('Observations: ${placette.observations}');
      debugPrint('Agent: ${placette.agent}');
      if (_savedPhotoPath != null) {
        debugPrint('📸 Photo: $_savedPhotoPath');
      }
      debugPrint('===============================');

      if (mounted) {
        _showSnackBar(
          context,
          _modeEdition
              ? '✅ Placette $_generatedId mise à jour !'
              : '✅ Placette $_generatedId enregistrée !',
          true,
        );
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) Navigator.pop(context);
        });
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(context, '❌ Erreur: $e', false);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _superficieController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _agentController.dispose();
    _observationsController.dispose();
    _occupationManuelleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final isTablet = screenWidth >= 600;

    return Scaffold(
      backgroundColor: AppColors.sand,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Color(0xFF2E5D3A), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            const Text(
              'Land.Tree Survey',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E5D3A),
                  letterSpacing: 1.5),
            ),
            Text(
              _modeEdition ? 'Modifier la placette' : 'Nouvelle Placette',
              style: TextStyle(
                  fontSize: 11,
                  color: const Color(0xFF5C3A21).withOpacity(0.7)),
            ),
          ],
        ),
        actions: [
          // ✅ Bouton pour voir l'emplacement des photos
          IconButton(
            icon: const Icon(Icons.folder_open, color: Color(0xFF2E5D3A)),
            onPressed: _afficherEmplacementPhotos,
            tooltip: 'Emplacement des photos',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2.0),
          child: Container(
            height: 2.0,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [
                Color(0xFF2E5D3A),
                Color(0xFF8B5E3C),
                Color(0xFF2E5D3A)
              ]),
            ),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.all(isTablet ? 30 : (screenWidth < 360 ? 12 : 20)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ID GÉNÉRÉ
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF2E5D3A), Color(0xFF4A7C59)]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: const Color(0xFF2E5D3A).withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 3))
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.qr_code, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('ID DE LA PLACETTE',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.white70,
                                letterSpacing: 1.5)),
                        const SizedBox(height: 4),
                        Text(_generatedId,
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 1)),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.check_circle,
                          color: Colors.white, size: 20),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // RÉGION
              _buildSectionTitle('Région', Icons.location_on_outlined),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonFormField<String>(
                        value: _regionSelectionnee.isEmpty
                            ? null
                            : _regionSelectionnee,
                        isExpanded: true,
                        hint: const Text('Sélectionnez une région'),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          icon: Icon(
                            Icons.location_on,
                            color: Color(0xFF2E5D3A),
                          ),
                        ),
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF2E5D3A),
                          fontWeight: FontWeight.w500,
                        ),
                        items: _regions.map((region) {
                          return DropdownMenuItem<String>(
                            value: region,
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.forest,
                                  size: 20,
                                  color: Color(0xFF2E5D3A),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(region,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          if (newValue == null) return;
                          setState(() => _regionSelectionnee = newValue);
                          if (!_modeEdition) _genererId();
                        },
                        dropdownColor: Colors.white,
                        icon: const Icon(
                          Icons.arrow_drop_down,
                          color: Color(0xFF2E5D3A),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Material(
                    color: const Color(0xFF2E5D3A),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: _ajouterRegion,
                      borderRadius: BorderRadius.circular(12),
                      child: const SizedBox(
                        width: 52,
                        height: 56,
                        child: Icon(
                          Icons.add_location_alt_outlined,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              const Text(
                'Sélectionnez une région existante ou utilisez le bouton + '
                'pour en ajouter une nouvelle.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),

              const SizedBox(height: 16),

              // SUPERFICIE
              TextFormField(
                controller: _superficieController,
                decoration: InputDecoration(
                  labelText: 'Superficie',
                  hintText: 'Surface en hectares',
                  suffixText: 'ha',
                  prefixIcon:
                      const Icon(Icons.square_foot, color: Color(0xFF2E5D3A)),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  filled: true,
                  fillColor: Colors.white,
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
              ),

              const SizedBox(height: 24),

              // LOCALISATION GPS
              _buildSectionTitle('Localisation GPS', Icons.location_on),
              const SizedBox(height: 12),
              if (_isLoadingLocation)
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 12),
                      Text('Récupération des coordonnées GPS...'),
                    ],
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _latitudeController,
                      decoration: InputDecoration(
                        labelText: 'Latitude',
                        hintText: 'Récupération automatique...',
                        prefixIcon: const Icon(Icons.swap_vert,
                            color: Color(0xFF2E5D3A)),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      keyboardType:
                          TextInputType.numberWithOptions(decimal: true),
                      readOnly: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _longitudeController,
                      decoration: InputDecoration(
                        labelText: 'Longitude',
                        hintText: 'Récupération automatique...',
                        prefixIcon: const Icon(Icons.swap_horiz,
                            color: Color(0xFF2E5D3A)),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      keyboardType:
                          TextInputType.numberWithOptions(decimal: true),
                      readOnly: true,
                    ),
                  ),
                  IconButton(
                    onPressed: _isLoadingLocation ? null : _getCurrentLocation,
                    icon: _isLoadingLocation
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.gps_fixed, color: Color(0xFF2E5D3A)),
                    tooltip: 'Rafraîchir la position GPS',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                '📍 Les coordonnées GPS sont récupérées automatiquement',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),

              const SizedBox(height: 24),

              // OCCUPATION DU SOL - LISTE DÉROULANTE
              _buildSectionTitle('Occupation du sol', Icons.landscape),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonFormField<String>(
                  value:
                      _selectedOccupation.isEmpty ? null : _selectedOccupation,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    icon: Icon(Icons.landscape, color: Color(0xFF2E5D3A)),
                  ),
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF2E5D3A),
                    fontWeight: FontWeight.w500,
                  ),
                  hint: const Text(
                    'Sélectionnez le type d\'occupation',
                    style: TextStyle(color: Colors.grey),
                  ),
                  items: _occupationOptions.map((String occupation) {
                    return DropdownMenuItem<String>(
                      value: occupation,
                      child: Row(
                        children: [
                          Icon(
                            _getIconForOccupation(occupation),
                            size: 20,
                            color: const Color(0xFF2E5D3A),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              occupation,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedOccupation = newValue;
                      });
                    }
                  },
                  dropdownColor: Colors.white,
                  icon: const Icon(Icons.arrow_drop_down,
                      color: Color(0xFF2E5D3A)),
                  selectedItemBuilder: (context) =>
                      _occupationOptions.map((String occupation) {
                    return Row(
                      children: [
                        Icon(
                          _getIconForOccupation(occupation),
                          size: 20,
                          color: const Color(0xFF2E5D3A),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            occupation,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Veuillez sélectionner l\'occupation du sol';
                    }
                    return null;
                  },
                ),
              ),
              if (_saisieOccupation) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _occupationManuelleController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Occupation du sol à enregistrer *',
                    hintText: _estSenegal
                        ? 'Exemple : Mangrove dégradée'
                        : 'Saisissez une valeur réutilisable dans ce projet',
                    prefixIcon: const Icon(Icons.edit_note_rounded),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.info_outline, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: Text(
                      '🌍 Sélectionnez le type d\'occupation du sol dominant sur la parcelle',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // OBSERVATIONS TERRAIN
              _buildSectionTitle('Observations terrain', Icons.visibility),
              const SizedBox(height: 12),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: SwitchListTile(
                    title: const Text('Présence de culture',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2E5D3A))),
                    subtitle: const Text('Culture associée aux arbres'),
                    value: _presenceCulture,
                    onChanged: (value) =>
                        setState(() => _presenceCulture = value),
                    activeColor: const Color(0xFF4A7C59),
                    secondary: Icon(
                        _presenceCulture
                            ? Icons.agriculture
                            : Icons.agriculture_outlined,
                        color: const Color(0xFF2E5D3A)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: SwitchListTile(
                    title: const Text('Présence de feux',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFD32F2F))),
                    subtitle: const Text('Traces de feu récent'),
                    value: _presenceFeux,
                    onChanged: (value) => setState(() => _presenceFeux = value),
                    activeColor: const Color(0xFFD32F2F),
                    secondary: Icon(
                        _presenceFeux
                            ? Icons.local_fire_department
                            : Icons.local_fire_department_outlined,
                        color: const Color(0xFFD32F2F)),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 📸 PHOTO - AMÉLIORÉ
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
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12)),
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
                                  borderRadius: BorderRadius.circular(8),
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
                            '📸 Photo sauvegardée avec le nom: ${_generatedId}.jpg',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '📁 Dossier: Pictures/LandTree_Survey/Placettes/',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // AUTRES OBSERVATIONS
              TextFormField(
                controller: _observationsController,
                decoration: InputDecoration(
                  labelText: 'Autres observations',
                  hintText: 'Ex: Parasites, sol érodé, inondation...',
                  prefixIcon:
                      const Icon(Icons.comment, color: Color(0xFF2E5D3A)),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  filled: true,
                  fillColor: Colors.white,
                ),
                maxLines: 3,
              ),

              const SizedBox(height: 24),

              // INFORMATIONS TERRAIN
              _buildSectionTitle('Informations terrain', Icons.person),
              const SizedBox(height: 12),
              TextFormField(
                controller: _agentController,
                decoration: InputDecoration(
                  labelText: 'Nom de l\'observateur',
                  hintText: 'Agent de terrain',
                  prefixIcon: const Icon(Icons.person_outline,
                      color: Color(0xFF2E5D3A)),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  filled: true,
                  fillColor: Colors.white,
                ),
                textCapitalization: TextCapitalization.words,
              ),

              const SizedBox(height: 40),

              // BOUTONS
              ResponsiveFields(
                breakpoint: 390,
                first: OutlinedButton(
                  onPressed: _isResetting
                      ? null
                      : _modeEdition
                      ? () => Navigator.pop(context)
                      : _effacerFormulaire,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 55),
                    foregroundColor: const Color(0xFF8B5E3C),
                    side: const BorderSide(color: Color(0xFF8B5E3C)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isResetting
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 19,
                              height: 19,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 9),
                            Text('CHARGEMENT…'),
                          ],
                        )
                      : Text(_modeEdition ? 'ANNULER' : 'EFFACER',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                ),
                second: ElevatedButton(
                  onPressed: _isSaving ? null : _enregistrer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E5D3A),
                    minimumSize: const Size(double.infinity, 55),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 3,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white))
                      : Text(_modeEdition ? 'METTRE À JOUR' : 'ENREGISTRER',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // Fonction pour associer une icône à chaque type d'occupation
  IconData _getIconForOccupation(String occupation) {
    switch (occupation) {
      case 'Savane arbustive':
      case 'Savane arbustive à arborée':
        return Icons.forest;
      case 'Forêt galerie':
        return Icons.park;
      case 'Plantation':
        return Icons.grass;
      case 'Céréales (mil, maïs, sorgho, riz)':
      case 'Légumineuses (arachide, niébé)':
      case 'Autres cultures (pastèque, bissap, coton)':
        return Icons.agriculture;
      case 'Parc agroforestier':
        return Icons.eco;
      case 'Mare':
      case 'Vallée':
        return Icons.water_drop;
      case 'Zone nue':
        return Icons.landscape;
      case 'Bâti':
        return Icons.house;
      default:
        return Icons.landscape;
    }
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
            width: 5,
            height: 24,
            decoration: BoxDecoration(
                color: const Color(0xFF2E5D3A),
                borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 12),
        Icon(icon, size: 22, color: const Color(0xFF2E5D3A)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E5D3A))),
        ),
      ],
    );
  }
}

class _AjouterRegionDialog extends StatefulWidget {
  const _AjouterRegionDialog();

  @override
  State<_AjouterRegionDialog> createState() => _AjouterRegionDialogState();
}

class _AjouterRegionDialogState extends State<_AjouterRegionDialog> {
  final TextEditingController _controller = TextEditingController();

  void _valider() {
    final region = _controller.text.trim();
    if (region.isNotEmpty) Navigator.of(context).pop(region);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.add_location_alt_outlined, color: AppColors.forest),
          SizedBox(width: 10),
          Expanded(child: Text('Ajouter une région')),
        ],
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(
          labelText: 'Nom de la région',
          hintText: 'Exemple : Ouarkhokh',
          prefixIcon: Icon(Icons.public_rounded),
        ),
        onSubmitted: (_) => _valider(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton.icon(
          onPressed: _valider,
          icon: const Icon(Icons.check_rounded),
          label: const Text('Ajouter'),
        ),
      ],
    );
  }
}
