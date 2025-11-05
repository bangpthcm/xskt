// lib/data/services/storage_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_config.dart';  // ✅ ADD

class StorageService {
  static const String _configKey = 'app_config';
  static const String _cacheKey = 'analysis_cache';

  Future<void> saveConfig(AppConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_configKey, jsonEncode(config.toJson()));
  }

  Future<AppConfig?> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final configStr = prefs.getString(_configKey);
    
    if (configStr == null) return null;
    
    try {
      final json = jsonDecode(configStr);
      return AppConfig.fromJson(json);
    } catch (e) {
      return null;
    }
  }

  Future<void> saveCache(String key, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${_cacheKey}_$key', jsonEncode(data));
  }

  Future<Map<String, dynamic>?> loadCache(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheStr = prefs.getString('${_cacheKey}_$key');
    
    if (cacheStr == null) return null;
    
    try {
      return jsonDecode(cacheStr);
    } catch (e) {
      return null;
    }
  }

  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_cacheKey));
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}