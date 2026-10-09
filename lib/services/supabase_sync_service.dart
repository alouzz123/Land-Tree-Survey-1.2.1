import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/arbre.dart';
import '../models/placette.dart';

/// Synchronise les données Hive vers Supabase sans bloquer la collecte terrain.
class SupabaseSyncService {
  SupabaseSyncService._internal();
  static final SupabaseSyncService _instance =
      SupabaseSyncService._internal();
  factory SupabaseSyncService() => _instance;

  static const String _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String _supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');
  static const String _photoBucket = 'land-tree-photos';

  bool _initialized = false;
  bool _initializing = false;
  bool _supabaseCreated = false;
  String? _deviceId;
  StreamSubscription<List<ConnectivityResult>>? _networkSubscription;

  bool get isConfigured =>
      _supabaseUrl.trim().isNotEmpty && _supabaseAnonKey.trim().isNotEmpty;
  bool get isInitialized => _initialized;

  SupabaseClient? get _client =>
      _initialized ? Supabase.instance.client : null;

  Future<void> initialize() async {
    if (_initialized || _initializing) return;
    if (!isConfigured) {
      debugPrint(
        'Supabase non configuré : utilisez SUPABASE_URL et SUPABASE_ANON_KEY.',
      );
      return;
    }

    _initializing = true;
    try {
      if (!_supabaseCreated) {
        await Supabase.initialize(
          url: _supabaseUrl,
          anonKey: _supabaseAnonKey,
        );
        _supabaseCreated = true;
      }
      _deviceId ??= await _getOrCreateDeviceId();
      // L'interface peut démarrer dès que le client local est prêt. La création
      // de la session anonyme, qui dépend du réseau, continue sans bloquer l'UI.
      _initialized = true;
      await _ensureAuthenticated();
      debugPrint('✅ Supabase initialisé');
    } catch (error) {
      _initialized = false;
      debugPrint('⚠️ Initialisation Supabase impossible : $error');
    } finally {
      _initializing = false;
    }
  }

  Future<String> _getOrCreateDeviceId() async {
    final preferences = await SharedPreferences.getInstance();
    final existing = preferences.getString('land_tree_device_id');
    if (existing != null && existing.isNotEmpty) return existing;

    final now = DateTime.now().microsecondsSinceEpoch;
    final generated = 'device-$now';
    await preferences.setString('land_tree_device_id', generated);
    return generated;
  }

  Future<void> _ensureAuthenticated() async {
    final client = Supabase.instance.client;
    if (client.auth.currentSession == null) {
      await client.auth.signInAnonymously();
    }
  }

  void startAutomaticSync(Future<void> Function() onConnectionAvailable) {
    _networkSubscription?.cancel();
    _networkSubscription = Connectivity().onConnectivityChanged.listen(
      (results) {
        final online = results.any(
          (result) => result != ConnectivityResult.none,
        );
        if (online) {
          unawaited(() async {
            if (!_initialized) await initialize();
            if (_initialized) await onConnectionAvailable();
          }());
        }
      },
    );
  }

  Future<void> syncAll(
    List<Placette> placettes,
    List<Arbre> arbres,
  ) async {
    if (!_initialized || _client == null) return;
    await _ensureAuthenticated();

    // Les placettes doivent être présentes avant leurs arbres (clé étrangère).
    for (final placette in placettes) {
      try {
        await syncPlacette(placette);
      } catch (error) {
        debugPrint('Placette ${placette.id} non synchronisée : $error');
      }
    }
    for (final arbre in arbres) {
      try {
        await syncArbre(arbre);
      } catch (error) {
        // Un arbre en erreur ne doit pas empêcher les suivants d'être envoyés.
        debugPrint('Arbre ${arbre.id} non synchronisé : $error');
      }
    }
  }

  void syncAllSilently(List<Placette> placettes, List<Arbre> arbres) {
    unawaited(
      syncAll(placettes, arbres).catchError((error) {
        debugPrint('Synchronisation Supabase différée : $error');
      }),
    );
  }

  Future<void> syncPlacetteSilently(Placette placette) async {
    if (!_initialized) return;
    try {
      await syncPlacette(placette);
    } catch (error) {
      debugPrint('Placette conservée hors ligne, synchronisation différée : $error');
    }
  }

  Future<void> syncArbreSilently(Arbre arbre) async {
    if (!_initialized) return;
    try {
      await syncArbre(arbre);
    } catch (error) {
      debugPrint('Arbre conservé hors ligne, synchronisation différée : $error');
    }
  }

  Future<void> deleteArbreSilently(String placetteId, String arbreId) async {
    if (!_initialized || _client == null) return;
    try {
      await _client!
          .from('arbres')
          .delete()
          .eq('id', arbreId)
          .eq('placette_id', placetteId)
          .eq('device_id', _deviceId!);
    } catch (error) {
      debugPrint('Suppression cloud différée pour $arbreId : $error');
    }
  }

  Future<void> deletePlacetteSilently(String placetteId) async {
    if (!_initialized || _client == null) return;
    try {
      await _client!
          .from('placettes')
          .delete()
          .eq('id', placetteId)
          .eq('device_id', _deviceId!);
    } catch (error) {
      debugPrint('Suppression cloud différée pour $placetteId : $error');
    }
  }

  /// Synchronise d'abord la placette parente, puis l'arbre. Cette séquence
  /// évite le rejet de l'arbre par la clé étrangère Supabase.
  Future<void> syncArbreWithParentSilently(
    Arbre arbre, {
    Placette? placette,
  }) async {
    if (!_initialized) return;
    try {
      if (placette != null) await syncPlacette(placette);
      await syncArbre(arbre);
    } catch (error) {
      debugPrint(
        'Arbre ${arbre.id} conservé hors ligne, synchronisation différée : '
        '$error',
      );
    }
  }

  Future<String?> _uploadPhotoSafely({
    required String type,
    required String recordId,
    required String placetteId,
  }) async {
    try {
      return await _uploadPhotoIfPresent(
        type: type,
        recordId: recordId,
        placetteId: placetteId,
      );
    } catch (error) {
      // Les données textuelles restent prioritaires. La photo sera retentée
      // lors de la prochaine synchronisation complète.
      debugPrint('Photo $type/$recordId non synchronisée : $error');
      return null;
    }
  }

  Future<void> syncPlacette(Placette placette) async {
    final client = _client;
    if (client == null) return;
    final photoPath = await _uploadPhotoSafely(
      type: 'placettes',
      recordId: placette.id,
      placetteId: placette.id,
    );

    await client.from('placettes').upsert(
      {
        'id': placette.id,
        'device_id': _deviceId,
        'user_id': client.auth.currentUser?.id,
        'region': placette.region,
        'pays': placette.pays,
        'superficie': placette.superficie,
        'latitude': placette.latitude,
        'longitude': placette.longitude,
        'occupation_sol': placette.occupationSol,
        'presence_culture': placette.presenceCulture,
        'presence_feux': placette.presenceFeux,
        'observations': placette.observations,
        'agent': placette.agent,
        'photo_path': photoPath,
        'date_creation': placette.dateCreation.toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'id,device_id',
    );
  }

  Future<void> syncArbre(Arbre arbre) async {
    final client = _client;
    if (client == null) return;
    final photoPath = await _uploadPhotoSafely(
      type: 'arbres',
      recordId: arbre.id,
      placetteId: arbre.placetteId,
    );

    final donneesCompletes = <String, dynamic>{
      'id': arbre.id,
      'placette_id': arbre.placetteId,
      'device_id': _deviceId,
      'user_id': client.auth.currentUser?.id,
      'nom_espece': arbre.nomScientifique,
      'mode_inventaire': arbre.modeInventaire,
      'dap': arbre.dap,
      'type_tronc': arbre.typeTronc,
      'nombre_troncs': arbre.nombreTroncs,
      'diametre_cumule': arbre.diametreCumule,
      'hauteur': arbre.hauteur,
      'diametre_couronne': arbre.diametreCouronne,
      'latitude': arbre.latitude,
      'longitude': arbre.longitude,
      'forme_tronc': arbre.formeTronc,
      'methode_hauteur': arbre.methodeHauteur,
      'distance_clinometre': arbre.distanceClinometre,
      'angle_cime': arbre.angleCime,
      'angle_base': arbre.angleBase,
      'houppier_ns': arbre.houppierNS,
      'houppier_eo': arbre.houppierEO,
      'observations': arbre.observations,
      'volume_estime': arbre.volumeEstime,
      'photo_path': photoPath,
      'date_creation': arbre.dateCreation.toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      await client.from('arbres').upsert(
        donneesCompletes,
        onConflict: 'id,placette_id,device_id',
      );
    } on PostgrestException catch (error) {
      final ancienneStructure =
          error.code == 'PGRST204' || error.code == '42P10';
      if (!ancienneStructure) rethrow;

      // Compatibilité avec une table créée avant les champs multi-troncs ou
      // avant la clé composite. Les données essentielles sont quand même
      // sauvegardées ; la migration SQL complétera ensuite la structure.
      debugPrint(
        'Ancienne structure Supabase détectée pour arbres : ${error.code}',
      );
      await client.from('arbres').upsert({
        'id': arbre.id,
        'placette_id': arbre.placetteId,
        'device_id': _deviceId,
        'user_id': client.auth.currentUser?.id,
        'nom_espece': arbre.nomScientifique,
        'dap': arbre.dap,
        'hauteur': arbre.hauteur,
        'diametre_couronne': arbre.diametreCouronne,
        'observations': arbre.observations,
        'photo_path': photoPath,
        'date_creation': arbre.dateCreation.toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    }
  }

  Future<String?> _uploadPhotoIfPresent({
    required String type,
    required String recordId,
    required String placetteId,
  }) async {
    final client = _client;
    final userId = client?.auth.currentUser?.id;
    if (client == null || _deviceId == null || userId == null) return null;

    final photo = await _findPhoto(type: type, recordId: recordId);
    if (photo == null) return null;

    final safeRecordId = recordId.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final safePlacetteId =
        placetteId.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final storagePath = type == 'placettes'
        ? '$userId/$_deviceId/placettes/$safeRecordId.jpg'
        : '$userId/$_deviceId/arbres/$safePlacetteId/$safeRecordId.jpg';

    await client.storage.from(_photoBucket).upload(
          storagePath,
          photo,
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'image/jpeg',
          ),
        );
    return storagePath;
  }

  Future<File?> _findPhoto({
    required String type,
    required String recordId,
  }) async {
    // Les photos Web ne disposent pas d'un chemin File local persistant.
    // Les données textuelles doivent néanmoins continuer à être synchronisées.
    if (kIsWeb) return null;

    final folder = type == 'placettes' ? 'Placettes' : 'Arbres';
    final publicFile = File(
      '/storage/emulated/0/Pictures/LandTree_Survey/$folder/$recordId.jpg',
    );
    if (await publicFile.exists()) return publicFile;

    final documents = await getApplicationDocumentsDirectory();
    final localFolder = type == 'placettes' ? 'placettes_photos' : 'arbres_photos';
    final privateFile = File('${documents.path}/$localFolder/$recordId.jpg');
    if (await privateFile.exists()) return privateFile;
    return null;
  }
}
