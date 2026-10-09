import 'package:shared_preferences/shared_preferences.dart';

class InventoryModeService {
  static const String dendrometrique = 'dendrometrique';
  static const String simple = 'simple';

  static String _key(String placetteId) =>
      'dernier_mode_inventaire_${placetteId.trim()}';

  static Future<void> remember(String placetteId, String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(placetteId), mode);
  }

  static Future<String> get(String placetteId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key(placetteId)) ?? dendrometrique;
  }
}
