import 'package:shared_preferences/shared_preferences.dart';

class ProjectCountryService {
  ProjectCountryService._();

  static const _countryKey = 'project_country_v1';
  static const _occupationsKey = 'custom_land_occupations_v1';
  static const _speciesKey = 'custom_scientific_species_v1';

  static Future<String?> getCountry() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_countryKey)?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  static Future<void> setCountryOnce(String country) async {
    final prefs = await SharedPreferences.getInstance();
    if ((prefs.getString(_countryKey) ?? '').trim().isEmpty) {
      await prefs.setString(_countryKey, country.trim());
    }
  }

  static Future<List<String>> getCustomOccupations() =>
      _readSortedList(_occupationsKey);

  static Future<List<String>> getCustomSpecies() => _readSortedList(_speciesKey);

  static Future<void> rememberOccupation(String value) =>
      _rememberUnique(_occupationsKey, value);

  static Future<void> rememberSpecies(String value) =>
      _rememberUnique(_speciesKey, value);

  static Future<List<String>> _readSortedList(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final values = (prefs.getStringList(key) ?? <String>[])
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
    values.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return values;
  }

  static Future<void> _rememberUnique(String key, String rawValue) async {
    final value = rawValue.trim();
    if (value.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final values = await _readSortedList(key);
    if (!values.any((item) => item.toLowerCase() == value.toLowerCase())) {
      values.add(value);
      values.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      await prefs.setStringList(key, values);
    }
  }
}
