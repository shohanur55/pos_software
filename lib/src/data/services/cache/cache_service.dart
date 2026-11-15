import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Small key-value store backed by [SharedPreferencesWithCache].
class CacheService {
  CacheService(this._preferences);

  final SharedPreferencesWithCache _preferences;

  static Future<CacheService> create() async {
    final preferences = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(),
    );
    return CacheService(preferences);
  }

  Map<String, dynamic>? readJson(String key) {
    final raw = _preferences.getString(key);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  Future<void> writeJson(String key, Map<String, dynamic> value) =>
      _preferences.setString(key, jsonEncode(value));

  bool readBool(String key) => _preferences.getBool(key) ?? false;

  Future<void> writeBool(String key, {required bool value}) =>
      _preferences.setBool(key, value);

  Future<void> remove(String key) => _preferences.remove(key);
}
