// lib/data/services/storage_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_config.dart';  // ✅ ADD

class StorageService {
  static const String _configKey = 'app_config';
  
  // ✅ THÊM: Memory cache
  AppConfig? _configCache;
  DateTime? _configCacheTime;
  static const Duration _configCacheDuration = Duration(minutes: 5);

  Future<AppConfig?> loadConfig() async {
    // ✅ Check memory cache
    if (_configCache != null && _configCacheTime != null) {
      final age = DateTime.now().difference(_configCacheTime!);
      if (age < _configCacheDuration) {
        print('📦 Using cached config');
        return _configCache;
      }
    }
    
    final prefs = await SharedPreferences.getInstance();
    final configStr = prefs.getString(_configKey);
    
    if (configStr == null) return null;
    
    try {
      final json = jsonDecode(configStr);
      final config = AppConfig.fromJson(json);
      
      // ✅ Cache it
      _configCache = config;
      _configCacheTime = DateTime.now();
      
      return config;
    } catch (e) {
      return null;
    }
  }

  Future<void> saveConfig(AppConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_configKey, jsonEncode(config.toJson()));
    
    // ✅ Update cache
    _configCache = config;
    _configCacheTime = DateTime.now();
  }
}