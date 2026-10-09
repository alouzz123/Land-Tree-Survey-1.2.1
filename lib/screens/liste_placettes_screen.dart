import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:permission_handler/permission_handler.dart';
import '../services/database_service.dart';
import '../services/inventory_mode_service.dart';
import '../models/placette.dart';
import '../formulaire_screen.dart';
import '../theme/app_theme.dart';
import 'formulaire_arbres_screen.dart';
import 'placette_details_screen.dart';
import 'releve_simple_screen.dart';

class ListePlacettesScreen extends StatefulWidget {
  const ListePlacettesScreen({super.key});

  @override
  State<ListePlacettesScreen> createState() => _ListePlacettesScreenState();
}

class _ListePlacettesScreenState extends State<ListePlacettesScreen> {
  List<Placette> _placettes = [];
  bool _isLoading = true;
  bool _hasStoragePermission = false;
  bool _isCheckingPermissions = false;

  @override
  void initState() {
    super.initState();
    _initScreen();
  }

  // ✅ Initialisation avec vérification des permissions
  Future<void> _initScreen() async {
    await _checkStoragePermission();
    _chargerPlacettes();
  }

  // ✅ Vérification des permissions de stockage
  Future<bool> _checkStoragePermission() async {
    // Le navigateur gère lui-même les téléchargements. Permission.photos et
    // Permission.storage ne sont pas implémentées par permission_handler_web.
    if (kIsWeb) {
      if (mounted) {
        setState(() {
          _hasStoragePermission = true;
          _isCheckingPermissions = false;
        });
      }
      return true;
    }

    if (_isCheckingPermissions) return _hasStoragePermission;

    if (!mounted) return false;
    setState(() => _isCheckingPermissions = true);

    bool hasPermission = false;

    // Pour Android 13+ (API 33+)
    if (await _isAndroid13OrHigher()) {
      // Android 13+ : permissions granulaires
      final photosStatus = await Permission.photos.status;
      final videosStatus = await Permission.videos.status;

      if (photosStatus.isGranted && videosStatus.isGranted) {
        hasPermission = true;
      } else {
        // Demander les permissions
        final statuses = await [
          Permission.photos,
          Permission.videos,
        ].request();

        hasPermission = statuses[Permission.photos]!.isGranted &&
            statuses[Permission.videos]!.isGranted;
      }
    } else {
      // Android 12 et moins
      final status = await Permission.storage.status;
      if (status.isGranted) {
        hasPermission = true;
      } else {
        // Demander la permission
        final newStatus = await Permission.storage.request();
        hasPermission = newStatus.isGranted;
      }
    }

    if (!mounted) return hasPermission;
    setState(() {
      _hasStoragePermission = hasPermission;
      _isCheckingPermissions = false;
    });

    // Si permission refusée définitivement, ouvrir les paramètres
    if (!hasPermission) {
      if (await _isPermissionPermanentlyDenied()) {
        if (mounted) _showPermissionDeniedDialog();
      }
    }

    return hasPermission;
  }

  // ✅ Vérifier si la permission est définitivement refusée
  Future<bool> _isPermissionPermanentlyDenied() async {
    if (kIsWeb) return false;
    if (await _isAndroid13OrHigher()) {
      return await Permission.photos.isPermanentlyDenied;
    } else {
      return await Permission.storage.isPermanentlyDenied;
    }
  }

  // ✅ Vérifier la version Android
  Future<bool> _isAndroid13OrHigher() async {
    // Méthode simple : on suppose que c'est Android 13+
    // Pour une solution plus robuste, utilisez device_info_plus
    return true; // À adapter selon votre besoin
  }

  // ✅ Afficher un dialogue si permissions refusées définitivement
  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Permission de stockage refusée'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'L\'application a besoin d\'accéder au stockage pour :',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('📸 Sauvegarder les photos des arbres'),
            Text('📊 Exporter les données en CSV/Excel'),
            Text('💾 Créer des sauvegardes locales'),
            SizedBox(height: 8),
            Text(
              'Veuillez activer la permission dans les paramètres.',
              style: TextStyle(color: Colors.orange),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Plus tard'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await openAppSettings();
              // Re-vérifier après retour des paramètres
              _checkStoragePermission();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E5D3A),
            ),
            child: const Text('Ouvrir les paramètres'),
          ),
        ],
      ),
    );
  }

  // ✅ Fonction pour gérer l'export avec vérification de permission
  Future<void> _handleExport(String type) async {
    try {
      // Vérifier les permissions avant d'exporter
      final hasPermission = await _checkStoragePermission();

      if (!hasPermission) {
        // Afficher un message d'erreur avec possibilité d'ouvrir les paramètres
        final shouldOpenSettings = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('⚠️ Permission de stockage refusée'),
            content: const Text(
              'Pour exporter les données, vous devez autoriser l\'accès au stockage.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E5D3A),
                ),
                child: const Text('Ouvrir paramètres'),
              ),
            ],
          ),
        );

        if (shouldOpenSettings == true) {
          await openAppSettings();
          // Re-vérifier après retour des paramètres
          final hasPermissionNow = await _checkStoragePermission();
          if (!hasPermissionNow) {
            _showSnackBar(context, '❌ Permission toujours refusée', false);
            return;
          }
        } else {
          return;
        }
      }

      // Exécuter l'export
      if (type == 'csv') {
        await DatabaseService().exportToCSV();
        _showSnackBar(context, '✅ Export CSV réussi !', true);
      } else if (type == 'excel') {
        await DatabaseService().exportToExcel();
        _showSnackBar(context, '✅ Export Excel réussi !', true);
      }
    } catch (e) {
      _showSnackBar(context, '❌ Erreur : $e', false);
    }
  }

  // ✅ Fonction pour gérer l'inventaire avec vérification de permission
  Future<void> _handleInventaire(Placette p) async {
    // Vérifier les permissions de stockage avant d'ouvrir le formulaire
    final hasPermission = await _checkStoragePermission();

    if (!mounted) return;
    if (!hasPermission) {
      _showSnackBar(
        context,
        '⚠️ Permission de stockage refusée. Les photos ne seront pas sauvegardées.',
        false,
      );
    }

    await InventoryModeService.remember(
      p.id,
      InventoryModeService.dendrometrique,
    );
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FormulaireArbresScreen(
          placetteId: p.id,
          regionNom: p.region,
        ),
      ),
    );
    if (mounted) _chargerPlacettes();
  }

  Future<void> _handleReleveSimple(Placette p) async {
    await InventoryModeService.remember(
      p.id,
      InventoryModeService.simple,
    );
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReleveSimpleScreen(
          placetteId: p.id,
          regionNom: p.region,
        ),
      ),
    );
    if (mounted) _chargerPlacettes();
  }

  void _chargerPlacettes() {
    if (!mounted) return;
    setState(() {
      _placettes = DatabaseService().getAllPlacettes();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.sand,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF2E5D3A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            const Text('Land.Tree Survey',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E5D3A))),
            Text('${_placettes.length} placette(s)',
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        actions: [
          // ✅ Indicateur de permission
          IconButton(
            icon: Icon(
              _hasStoragePermission ? Icons.check_circle : Icons.warning,
              color: _hasStoragePermission
                  ? const Color(0xFF4A7C59)
                  : Colors.orange,
              size: 20,
            ),
            onPressed: _checkStoragePermission,
            tooltip: _hasStoragePermission
                ? '✅ Stockage disponible'
                : '⚠️ Permission de stockage nécessaire',
          ),
          if (_placettes.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.download, color: Color(0xFF2E5D3A)),
              onSelected: _handleExport,
              itemBuilder: (context) => [
                const PopupMenuItem(
                    value: 'csv',
                    child: Row(children: [
                      Icon(Icons.table_chart, size: 20),
                      SizedBox(width: 12),
                      Text('Exporter en CSV')
                    ])),
                const PopupMenuItem(
                    value: 'excel',
                    child: Row(children: [
                      Icon(Icons.table_chart_outlined, size: 20),
                      SizedBox(width: 12),
                      Text('Exporter en Excel')
                    ])),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _placettes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox, size: 80, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text('Aucune placette enregistrée',
                          style: TextStyle(
                              fontSize: 18, color: Colors.grey.shade600)),
                      const SizedBox(height: 8),
                      Text('Appuyez sur + pour en ajouter',
                          style: TextStyle(
                              fontSize: 14, color: Colors.grey.shade500)),
                      const SizedBox(height: 16),
                      // ✅ Bouton pour vérifier les permissions
                      OutlinedButton.icon(
                        onPressed: _checkStoragePermission,
                        icon: const Icon(Icons.settings, size: 16),
                        label: const Text('Vérifier les permissions'),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: const Color(0xFF2E5D3A).withOpacity(0.3),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    await _checkStoragePermission();
                    _chargerPlacettes();
                    return Future.value();
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _placettes.length,
                    itemBuilder: (context, index) {
                      final p = _placettes[index];
                      final arbresCount =
                          DatabaseService().countArbresByPlacetteId(p.id);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: const BorderSide(color: AppColors.outline),
                        ),
                        child: Column(
                          children: [
                            // Informations placette
                            ListTile(
                              leading: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [AppColors.forest, AppColors.leaf],
                                  ),
                                  borderRadius: BorderRadius.circular(15),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.forest.withOpacity(.18),
                                      blurRadius: 12,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.landscape_rounded,
                                    color: Colors.white),
                              ),
                              title: Text(p.region,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      '${p.superficie} ha • ${p.occupationSol}'),
                                  Text(
                                      'Culture: ${p.presenceCulture ? "Oui" : "Non"} • Feux: ${p.presenceFeux ? "Oui" : "Non"}',
                                      style: const TextStyle(fontSize: 11)),
                                  if (arbresCount > 0)
                                    Container(
                                      margin: const EdgeInsets.only(top: 4),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                          color: const Color(0xFF2E5D3A)
                                              .withOpacity(0.15),
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                      child: Text('🌳 $arbresCount arbre(s)',
                                          style: const TextStyle(
                                              fontSize: 10,
                                              color: Color(0xFF2E5D3A))),
                                    ),
                                  // ✅ Afficher un warning si pas de permission
                                  if (!_hasStoragePermission)
                                    Container(
                                      margin: const EdgeInsets.only(top: 4),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                          color: Colors.orange.withOpacity(0.2),
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.warning,
                                              color: Colors.orange, size: 12),
                                          SizedBox(width: 4),
                                          Text('Stockage non autorisé',
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.orange)),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () => _ouvrirDetailsPlacette(p),
                            ),
                            // DEUX PROTOCOLES : DENDROMÉTRIQUE ET RELEVÉ SIMPLE
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final dendrometrique = ElevatedButton.icon(
                                    onPressed: () => _handleInventaire(p),
                                    icon: const Icon(Icons.straighten, size: 18),
                                    label: const Text('DENDROMÉTRIQUE'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2E5D3A),
                                      foregroundColor: Colors.white,
                                      minimumSize: const Size(0, 44),
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8)),
                                    ),
                                  );
                                  final releveSimple = OutlinedButton.icon(
                                    onPressed: () => _handleReleveSimple(p),
                                    icon: const Icon(Icons.my_location, size: 18),
                                    label: const Text('RELEVÉ SIMPLE'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.forestDark,
                                      minimumSize: const Size(0, 44),
                                      side: const BorderSide(color: AppColors.forest),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  );
                                  final actions = Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: 'Voir la placette',
                                        icon: const Icon(Icons.visibility_outlined,
                                            color: Color(0xFF2E5D3A)),
                                        onPressed: () => _ouvrirDetailsPlacette(p),
                                      ),
                                      IconButton(
                                        tooltip: 'Supprimer la placette',
                                        icon: const Icon(Icons.delete_outline,
                                            color: Color(0xFFD32F2F)),
                                        onPressed: () =>
                                            _confirmerSuppression(context, p),
                                      ),
                                    ],
                                  );
                                  if (constraints.maxWidth < 600) {
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        dendrometrique,
                                        const SizedBox(height: 8),
                                        releveSimple,
                                        const SizedBox(height: 6),
                                        Align(alignment: Alignment.centerRight, child: actions),
                                      ],
                                    );
                                  }
                                  return Row(
                                    children: [
                                      Expanded(child: dendrometrique),
                                      const SizedBox(width: 8),
                                      Expanded(child: releveSimple),
                                      const SizedBox(width: 8),
                                      actions,
                                    ],
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FormulaireScreen()),
          );
          if (!mounted) return;
          _chargerPlacettes();
        },
        icon: const Icon(Icons.add_location_alt_rounded),
        label: const Text('Nouvelle placette'),
      ),
    );
  }

  Future<void> _ouvrirDetailsPlacette(Placette placette) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlacetteDetailsScreen(placette: placette),
      ),
    );
    if (mounted) _chargerPlacettes();
  }

  void _showSnackBar(BuildContext context, String message, bool success) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: success ? const Color(0xFF2E5D3A) : Colors.red,
      duration: const Duration(seconds: 4),
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _confirmerSuppression(BuildContext context, Placette p) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer ?'),
        content: Text('Supprimer "${p.region}" ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              await DatabaseService().deletePlacette(p.id);
              if (mounted) {
                Navigator.pop(context);
                _chargerPlacettes();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

}
