import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class GpsService {
  static final GpsService _instance = GpsService._internal();
  factory GpsService() => _instance;
  GpsService._internal();

  bool _hasPermission = false;
  bool _isLocationEnabled = false;

  /// Acquisition partagée par tous les formulaires. Les délais empêchent
  /// l'interface de rester bloquée lorsque le signal satellite est faible.
  Future<Position> acquirePosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const GpsAcquisitionException('Le GPS du téléphone est désactivé.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const GpsAcquisitionException(
        'Permission GPS refusée définitivement. Ouvrez les paramètres.',
      );
    }
    if (permission == LocationPermission.denied) {
      throw const GpsAcquisitionException('Permission GPS refusée.');
    }

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );
    } catch (_) {
      try {
        return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 8),
        );
      } catch (_) {
        final lastPosition = await Geolocator.getLastKnownPosition();
        if (lastPosition != null) return lastPosition;
        throw const GpsAcquisitionException(
          'Position indisponible. Placez-vous à l’extérieur puis réessayez.',
        );
      }
    }
  }

  // Vérifier et demander les permissions au démarrage
  Future<bool> checkAndRequestPermissions(BuildContext context) async {
    try {
      // 1. Vérifier si le GPS est activé
      _isLocationEnabled = await Geolocator.isLocationServiceEnabled();
      if (!_isLocationEnabled) {
        _showEnableLocationDialog(context);
        return false;
      }

      // 2. Vérifier les permissions
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showPermissionDeniedDialog(context);
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showPermissionDeniedForeverDialog(context);
        return false;
      }

      _hasPermission = true;
      return true;
    } catch (e) {
      debugPrint('Erreur GPS: $e');
      return false;
    }
  }

  // Récupérer la position actuelle
  Future<Position?> getCurrentPosition() async {
    if (!_hasPermission) return null;

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      debugPrint('Erreur récupération position: $e');
      return null;
    }
  }

  // Dialogue pour activer le GPS
  void _showEnableLocationDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('📍 Activer la localisation'),
        content: const Text(
          'Pour enregistrer la position des placettes et des arbres, '
          'vous devez activer la localisation sur votre téléphone.\n\n'
          'Vous pouvez aussi saisir les coordonnées manuellement.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Saisir manuellement'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await Geolocator.openLocationSettings();
              checkAndRequestPermissions(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E5D3A),
            ),
            child: const Text('Activer le GPS'),
          ),
        ],
      ),
    );
  }

  // Dialogue pour permission refusée
  void _showPermissionDeniedDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('📍 Permission de localisation'),
        content: const Text(
          'L\'application a besoin de votre position pour géolocaliser les placettes.\n\n'
          'Vous pouvez refuser mais vous devrez saisir les coordonnées manuellement.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Saisir manuellement'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await Geolocator.openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E5D3A),
            ),
            child: const Text('Autoriser'),
          ),
        ],
      ),
    );
  }

  // Dialogue pour permission refusée définitivement
  void _showPermissionDeniedForeverDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Permission refusée'),
        content: const Text(
          'Vous avez refusé définitivement l\'accès à la localisation.\n\n'
          'Pour utiliser le GPS, veuillez autoriser manuellement dans les paramètres.\n\n'
          'Sinon, vous pouvez saisir les coordonnées manuellement.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Saisir manuellement'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await Geolocator.openAppSettings();
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
}

class GpsAcquisitionException implements Exception {
  final String message;
  const GpsAcquisitionException(this.message);

  @override
  String toString() => message;
}
