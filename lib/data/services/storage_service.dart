import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_config.dart';

class StorageService {
  static const String _configKey = 'app_config';

  AppConfig? _configCache;
  DateTime? _configCacheTime;
  static const Duration _configCacheDuration = Duration(minutes: 5);

  Future<AppConfig?> loadConfig() async {
    if (_configCache != null &&
        _configCacheTime != null &&
        DateTime.now().difference(_configCacheTime!) < _configCacheDuration) {
      print('📦 Using cached config');
      return _configCache;
    }

    final prefs = await SharedPreferences.getInstance();
    final configStr = prefs.getString(_configKey);
    if (configStr == null) return null;

    try {
      _configCache = AppConfig.fromJson(jsonDecode(configStr));
      _configCacheTime = DateTime.now();
      return _configCache;
    } catch (e) {
      return null;
    }
  }

  Future<void> saveConfig(AppConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_configKey, jsonEncode(config.toJson()));
    _configCache = config;
    _configCacheTime = DateTime.now();
  }
}
