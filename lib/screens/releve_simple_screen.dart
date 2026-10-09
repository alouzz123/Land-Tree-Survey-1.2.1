import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/arbre.dart';
import '../services/database_service.dart';
import '../services/gps_service.dart';
import '../services/project_country_service.dart';
import '../services/species_catalog.dart';
import '../theme/app_theme.dart';
import '../widgets/responsive_fields.dart';

class ReleveSimpleScreen extends StatefulWidget {
  final String placetteId;
  final String regionNom;
  const ReleveSimpleScreen({
    super.key,
    required this.placetteId,
    required this.regionNom,
  });

  @override
  State<ReleveSimpleScreen> createState() => _ReleveSimpleScreenState();
}

class _ReleveSimpleScreenState extends State<ReleveSimpleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _indice = TextEditingController(text: 'Arbre');
  final _espece = TextEditingController();
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  File? _photoFile;
  String? _photoPath;
  bool _photoRemoved = false;
  List<String> _especes = [];
  String _paysProjet = 'Sénégal';
  String _selectedEspece = '';
  bool _autreEspece = false;
  List<Arbre> _releves = [];
  Arbre? _edition;
  bool _saving = false;
  bool _loadingGps = false;
  String _id = 'Arbre01';
  String _gpsInfo = '';

  bool get _editing => _edition != null;
  String get _prefixKey => 'indice_arbre_${widget.placetteId}';
  String get _numberKey => 'numero_arbre_${widget.placetteId}';

  @override
  void initState() {
    super.initState();
    _indice.addListener(_generateId);
    _initialize();
  }

  Future<void> _initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final custom = await ProjectCountryService.getCustomSpecies();
    final country = await ProjectCountryService.getCountry() ?? 'Sénégal';
    final recorded = DatabaseService().getAllEspeces();
    final all = DatabaseService().getArbresByPlacetteId(widget.placetteId);
    var prefix = prefs.getString(_prefixKey)?.trim() ?? '';
    if (all.isNotEmpty) {
      final match = RegExp(r'^(.*)(\d{2})$').firstMatch(all.first.id.trim());
      if (match != null) prefix = match.group(1) ?? prefix;
    }
    if (prefix.isEmpty) prefix = 'Arbre';
    final species = SpeciesCatalog.mergeWithCustom(
      country,
      <String>{...custom, ...recorded},
    );
    if (!mounted) return;
    _indice.text = prefix;
    setState(() {
      _especes = species;
      _paysProjet = country;
      _releves = all.where((a) => a.modeInventaire == 'simple').toList();
    });
    _generateId();
    await _refreshGps(showMessage: false);
  }

  String _clean(String value) =>
      value.trim().replaceAll(RegExp(r'[^A-Za-zÀ-ÿ0-9_-]+'), '');

  int _next(String prefix) {
    var maximum = 0;
    final expression =
        RegExp('^${RegExp.escape(prefix)}(\\d+)\$', caseSensitive: false);
    for (final tree
        in DatabaseService().getArbresByPlacetteId(widget.placetteId)) {
      final match = expression.firstMatch(tree.id);
      final number = int.tryParse(match?.group(1) ?? '') ?? 0;
      if (number > maximum) maximum = number;
    }
    return maximum + 1;
  }

  void _generateId() {
    if (_editing) {
      if (mounted) setState(() => _id = _edition!.id);
      return;
    }
    final prefix = _clean(_indice.text);
    final value = prefix.isEmpty
        ? 'DÉFINIR UN INDICE'
        : '$prefix${_next(prefix).toString().padLeft(2, '0')}';
    if (mounted && value != _id) setState(() => _id = value);
  }

  double? _number(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.'));

  Future<bool> _checkCameraPermission() async {
    if (kIsWeb) return true;
    final status = await Permission.camera.status;
    return status.isGranted || (await Permission.camera.request()).isGranted;
  }

  Future<bool> _checkStoragePermission() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    final photos = await Permission.photos.request();
    // Sur Android 12 et antérieur, la permission historique reste utilisée.
    if (photos.isGranted || photos.isLimited) return true;
    final storage = await Permission.storage.request();
    return storage.isGranted;
  }

  Future<Directory> _getPhotosDirectory() async {
    try {
      if (Platform.isAndroid && await _checkStoragePermission()) {
        final directory =
            Directory('/storage/emulated/0/Pictures/LandTree_Survey/Arbres');
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }
        return directory;
      }
    } catch (_) {
      // Le dossier privé ci-dessous garantit la sauvegarde si le stockage
      // partagé n'est pas disponible sur le téléphone.
    }
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory('${documents.path}/arbres_photos');
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }

  Future<void> _takePhoto() async {
    try {
      if (!await _checkCameraPermission()) {
        _snack('Permission caméra refusée', false);
        return;
      }
      final photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (photo == null || !mounted) return;
      if (kIsWeb) {
        setState(() {
          _photoPath = photo.path;
          _photoRemoved = false;
        });
        return;
      }
      final directory = await _getPhotosDirectory();
      final temporaryPath =
          '${directory.path}/PHOTO_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedFile = await File(photo.path).copy(temporaryPath);
      if (!mounted) return;
      setState(() {
        _photoFile = savedFile;
        _photoPath = savedFile.path;
        _photoRemoved = false;
      });
      _snack('Photo enregistrée dans LandTree_Survey/Arbres', true);
    } catch (error) {
      if (mounted) _snack('Impossible d’ouvrir la caméra : $error', false);
    }
  }

  Future<String?> _persistPhoto(String id) async {
    if (kIsWeb || _photoFile == null) return _photoPath;
    final directory = await _getPhotosDirectory();
    final destination = '${directory.path}/$id.jpg';
    if (_photoFile!.path == destination) return destination;
    final oldDestination = File(destination);
    if (await oldDestination.exists()) await oldDestination.delete();
    await _photoFile!.copy(destination);
    return destination;
  }

  Future<void> _refreshGps({bool showMessage = true}) async {
    if (_loadingGps) return;
    setState(() {
      _loadingGps = true;
      _gpsInfo = '';
    });
    try {
      final position = await GpsService().acquirePosition();
      if (!mounted) return;
      setState(() {
        _latitude.text = position.latitude.toStringAsFixed(6);
        _longitude.text = position.longitude.toStringAsFixed(6);
        _gpsInfo = 'Coordonnées actualisées';
      });
      if (showMessage) _snack('📍 Coordonnées GPS actualisées', true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _gpsInfo = '$error Saisie manuelle possible.');
      if (showMessage) _snack('⚠️ $error', false);
    } finally {
      if (mounted) setState(() => _loadingGps = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    try {
      final prefix = _clean(_indice.text);
      final id =
          _editing ? _edition!.id : '$prefix${_next(prefix).toString().padLeft(2, '0')}';
      if (_photoRemoved && !kIsWeb && _edition?.photoLocale != null) {
        final oldPhoto = File(_edition!.photoLocale!);
        if (await oldPhoto.exists()) await oldPhoto.delete();
      }
      final savedPhoto = _photoRemoved
          ? null
          : (await _persistPhoto(id) ?? _edition?.photoLocale);
      final tree = Arbre(
        id: id,
        placetteId: widget.placetteId,
        nomEspece: _autreEspece
            ? _espece.text.trim()
            : _selectedEspece.trim(),
        dap: 0,
        hauteur: 0,
        latitude: _number(_latitude.text),
        longitude: _number(_longitude.text),
        dateCreation: _edition?.dateCreation ?? DateTime.now(),
        modeInventaire: 'simple',
        photoLocale: savedPhoto,
      );
      if (_editing) {
        await DatabaseService().updateArbre(tree);
      } else {
        await DatabaseService().saveArbre(tree);
      }
      await ProjectCountryService.rememberSpecies(tree.nomScientifique);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefixKey, prefix);
      await prefs.setInt(_numberKey, _next(prefix) - 1);
      if (!mounted) return;
      _snack(_editing ? '✅ Relevé $id mis à jour' : '✅ Relevé $id enregistré', true);
      _reset(keepGps: true);
      _reload();
    } catch (error) {
      if (mounted) _snack('Impossible d’enregistrer : $error', false);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _reload() {
    final data = DatabaseService()
        .getArbresByPlacetteId(widget.placetteId)
        .where((a) => a.modeInventaire == 'simple')
        .toList();
    if (mounted) setState(() => _releves = data);
    _generateId();
  }

  void _reset({bool keepGps = false}) {
    setState(() {
      _edition = null;
      _espece.clear();
      _selectedEspece = '';
      _autreEspece = false;
      _photoFile = null;
      _photoPath = null;
      _photoRemoved = false;
      if (!keepGps) {
        _latitude.clear();
        _longitude.clear();
        _gpsInfo = '';
      }
    });
    _generateId();
  }

  Future<void> _edit(Arbre tree) async {
    Navigator.pop(context);
    final accepted = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Modifier ce relevé ?'),
            content: Text('Le relevé ${tree.id} sera chargé dans le formulaire.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Modifier'),
              ),
            ],
          ),
        ) ??
        false;
    if (!accepted || !mounted) return;
    setState(() {
      _edition = tree;
      _id = tree.id;
      if (_especes.contains(tree.nomScientifique)) {
        _selectedEspece = tree.nomScientifique;
        _autreEspece = false;
        _espece.clear();
      } else {
        _selectedEspece = '';
        _autreEspece = true;
        _espece.text = tree.nomScientifique;
      }
      _latitude.text = tree.latitude?.toStringAsFixed(6) ?? '';
      _longitude.text = tree.longitude?.toStringAsFixed(6) ?? '';
      _gpsInfo = 'Position enregistrée chargée';
      _photoPath = tree.photoLocale;
      _photoRemoved = false;
      _photoFile = !kIsWeb && tree.photoLocale != null
          ? File(tree.photoLocale!)
          : null;
    });
  }

  Future<void> _delete(Arbre tree) async {
    Navigator.pop(context);
    final accepted = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Supprimer ce relevé ?'),
            content: Text('Le relevé ${tree.id} sera supprimé.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Supprimer'),
              ),
            ],
          ),
        ) ??
        false;
    if (!accepted) return;
    final localPhoto = tree.photoLocale;
    await DatabaseService().deleteArbre(widget.placetteId, tree.id);
    if (!kIsWeb && localPhoto != null) {
      final file = File(localPhoto);
      if (await file.exists()) await file.delete();
    }
    if (!mounted) return;
    _snack('Relevé ${tree.id} supprimé', true);
    _reload();
  }

  void _showRecords() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .72,
          child: Column(children: [
            const SizedBox(height: 10),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Row(children: [
                const Icon(Icons.location_on_outlined, color: AppColors.forest),
                const SizedBox(width: 9),
                Text('Relevés simples (${_releves.length})',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.forestDark)),
              ]),
            ),
            const Divider(height: 1),
            Expanded(
              child: _releves.isEmpty
                  ? const Center(child: Text('Aucun relevé simple enregistré'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _releves.length,
                      itemBuilder: (context, index) {
                        final tree = _releves[index];
                        return Card(
                          child: ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.park_outlined),
                            ),
                            title: Text(tree.nomScientifique,
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(
                              '${tree.id}\\n'
                              '${tree.latitude?.toStringAsFixed(6) ?? '—'}, '
                              '${tree.longitude?.toStringAsFixed(6) ?? '—'}',
                            ),
                            isThreeLine: true,
                            trailing: Wrap(children: [
                              IconButton(
                                tooltip: 'Modifier',
                                onPressed: () => _edit(tree),
                                icon: const Icon(Icons.edit_outlined,
                                    color: AppColors.forest),
                              ),
                              IconButton(
                                tooltip: 'Supprimer',
                                onPressed: () => _delete(tree),
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.red),
                              ),
                            ]),
                          ),
                        );
                      },
                    ),
            ),
          ]),
        ),
      ),
    );
  }

  void _snack(String message, bool success) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: success ? AppColors.forest : Colors.red.shade700,
    ));
  }

  @override
  void dispose() {
    _indice.removeListener(_generateId);
    _indice.dispose();
    _espece.dispose();
    _latitude.dispose();
    _longitude.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.sand,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        centerTitle: true,
        title: Column(children: [
          const Text('Land.Tree Survey', style: TextStyle(fontSize: 14)),
          Text('Relevé simple · ${widget.regionNom}',
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ]),
        actions: [
          Stack(children: [
            IconButton(
              tooltip: 'Relevés enregistrés',
              onPressed: _showRecords,
              icon: const Icon(Icons.format_list_bulleted,
                  color: AppColors.forest),
            ),
            if (_releves.isNotEmpty)
              Positioned(
                right: 3,
                top: 3,
                child: CircleAvatar(
                  radius: 9,
                  backgroundColor: AppColors.gold,
                  child: Text('${_releves.length}',
                      style: const TextStyle(fontSize: 9, color: Colors.white)),
                ),
              ),
          ]),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
            children: [
              Row(children: [
                const Expanded(
                  child: Text('Ajouter un relevé',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.forestDark)),
                ),
                TextButton(
                  onPressed: () => _reset(),
                  child: const Text('Effacer tout'),
                ),
              ]),
              if (_editing)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withOpacity(.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text('Mode modification · ${_edition!.id}',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              _informationCard(),
              const SizedBox(height: 16),
              TextFormField(
                controller: _indice,
                enabled: !_editing,
                decoration: const InputDecoration(
                  labelText: 'Indice de l’identifiant *',
                  helperText: 'Exemple : Arbre ou P050-A0',
                  prefixIcon: Icon(Icons.label_outline),
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    _clean(value ?? '').isEmpty ? 'Définissez un indice' : null,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.forest.withOpacity(.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text('ID DU RELEVÉ  ·  $_id',
                    style: const TextStyle(
                        color: AppColors.forestDark,
                        fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 20),
              const Text('1. IDENTIFICATION',
                  style: TextStyle(
                      color: AppColors.forest, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                isExpanded: true,
                value: _autreEspece
                    ? '__autre__'
                    : (_selectedEspece.isEmpty ? null : _selectedEspece),
                decoration: InputDecoration(
                  labelText: 'Nom scientifique · $_paysProjet *',
                  hintText: 'Sélectionnez une espèce',
                  prefixIcon: const Icon(Icons.park_outlined),
                  border: const OutlineInputBorder(),
                ),
                items: [
                  ..._especes.map(
                    (species) => DropdownMenuItem(
                      value: species,
                      child: Text(
                        species,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const DropdownMenuItem(
                    value: '__autre__',
                    child: Text('Autre espèce (à saisir)'),
                  ),
                ],
                onChanged: (value) => setState(() {
                  _autreEspece = value == '__autre__';
                  _selectedEspece = _autreEspece ? '' : (value ?? '');
                  if (!_autreEspece) _espece.clear();
                }),
                validator: (value) => value == null || value.isEmpty
                    ? 'Sélectionnez une espèce'
                    : null,
              ),
              if (_autreEspece) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _espece,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Autre nom scientifique *',
                    hintText: 'Exemple : Genre espèce',
                    prefixIcon: Icon(Icons.edit_note_rounded),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => _autreEspece &&
                          (value == null || value.trim().isEmpty)
                      ? 'Saisissez le nom scientifique'
                      : null,
                ),
              ],
              const SizedBox(height: 22),
              const Text('2. PHOTO (FACULTATIVE)',
                  style: TextStyle(
                      color: AppColors.forest, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.outline),
                ),
                child: Column(children: [
                  if (_photoFile != null && _photoFile!.existsSync()) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(_photoFile!,
                          height: 150,
                          width: double.infinity,
                          fit: BoxFit.cover),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _takePhoto,
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: Text(_photoPath == null
                            ? 'Prendre une photo'
                            : 'Reprendre la photo'),
                      ),
                    ),
                    if (_photoPath != null) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Retirer la photo',
                        onPressed: () => setState(() {
                          _photoFile = null;
                          _photoPath = null;
                          _photoRemoved = true;
                        }),
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.red),
                      ),
                    ],
                  ]),
                  const Text(
                    'La photo est optionnelle et reste disponible hors ligne.',
                    style: TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                ]),
              ),
              const SizedBox(height: 22),
              Row(children: [
                const Expanded(
                  child: Text('3. LOCALISATION GPS',
                      style: TextStyle(
                          color: AppColors.forest,
                          fontWeight: FontWeight.w800)),
                ),
                IconButton.filledTonal(
                  tooltip: 'Actualiser la position',
                  onPressed: _loadingGps ? null : () => _refreshGps(),
                  icon: _loadingGps
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.gps_fixed),
                ),
              ]),
              const SizedBox(height: 8),
              ResponsiveFields(
                first: TextFormField(
                  controller: _latitude,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Latitude *',
                    prefixIcon: Icon(Icons.north),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final n = _number(value ?? '');
                    return n == null || n < -90 || n > 90
                        ? 'Latitude invalide'
                        : null;
                  },
                ),
                second: TextFormField(
                  controller: _longitude,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Longitude *',
                    prefixIcon: Icon(Icons.east),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final n = _number(value ?? '');
                    return n == null || n < -180 || n > 180
                        ? 'Longitude invalide'
                        : null;
                  },
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _gpsInfo.isEmpty
                    ? 'Touchez le bouton GPS pour actualiser la position.'
                    : _gpsInfo,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.large(
        tooltip: _editing ? 'Mettre à jour' : 'Enregistrer',
        backgroundColor: AppColors.forest,
        foregroundColor: Colors.white,
        onPressed: _saving ? null : _save,
        child: _saving
            ? const CircularProgressIndicator(color: Colors.white)
            : Icon(_editing ? Icons.sync_rounded : Icons.save_rounded, size: 31),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _informationCard() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.forest.withOpacity(.2)),
        ),
        child: const Row(children: [
          Icon(Icons.science_outlined, color: AppColors.forest, size: 28),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Relevé floristique rapide : identifiant, nom scientifique et '
              'position GPS. Aucune mesure dendrométrique n’est demandée.',
              style: TextStyle(height: 1.35),
            ),
          ),
        ]),
      );
}
