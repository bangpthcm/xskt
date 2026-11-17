// lib/data/services/cached_data_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart'; // ✅ Import compute
import 'package:shared_preferences/shared_preferences.dart';
import '../models/lottery_result.dart';
import 'google_sheets_service.dart';

class CachedDataService {
  final GoogleSheetsService _sheetsService;
  
  static const String _kqxsCacheKey = 'kqxs_cache';
  static const String _kqxsTimestampKey = 'kqxs_timestamp';
  static const String _lastRowCountKey = 'kqxs_last_row_count';
  static const String _kqxsMinimalCacheKey = 'kqxs_minimal_cache';
  static const int _minimalCacheSize = 1200;
  static const Duration _cacheDuration = Duration(minutes: 30);
  
  List<LotteryResult>? _cachedResults;
  DateTime? _cacheTimestamp;
  
  CachedDataService({required GoogleSheetsService sheetsService})
      : _sheetsService = sheetsService;

  Future<List<LotteryResult>> loadKQXS({
    bool forceRefresh = false,
    bool incrementalOnly = false,
    bool minimalMode = true,
  }) async {
    // ... Logic cache RAM giữ nguyên ...
    if (!forceRefresh && _cachedResults != null && _cacheTimestamp != null) {
      final age = DateTime.now().difference(_cacheTimestamp!);
      if (age < _cacheDuration) return _cachedResults!;
    }

    // ✅ Load Persistent Cache (Dùng compute để không đơ UI khi đọc cache lớn)
    if (!forceRefresh) {
      final cachedData = await _loadFromPersistentCache();
      if (cachedData != null) {
        _cachedResults = cachedData;
        _cacheTimestamp = DateTime.now();
        // Load ngầm full data nếu đang ở minimal
        if (cachedData.length <= _minimalCacheSize && !minimalMode) {
           _loadFullDataInBackground();
        }
        return cachedData;
      }
    }

    // Fetch from Sheets
    final allValues = await _sheetsService.getAllValues('KQXS');
    if (allValues.length < 2) return [];

    // ✅ Parse Sheet Rows trong Isolate (Chạy nền)
    final results = await compute(_parseSheetData, allValues);

    // Save cache (cũng chạy nền)
    _saveToPersistentCache(results); // Không cần await để trả về UI nhanh hơn
    _saveRowCount(allValues.length);
    
    _cachedResults = results;
    _cacheTimestamp = DateTime.now();
    
    return results;
  }

  // ⚡ Hàm static chạy trong Isolate
  static List<LotteryResult> _parseSheetData(List<List<String>> allValues) {
    final results = <LotteryResult>[];
    for (int i = 1; i < allValues.length; i++) {
      try {
        results.add(LotteryResult.fromSheetRow(allValues[i]));
      } catch (e) { /* ignore */ }
    }
    return results;
  }

  // ⚡ Hàm static decode JSON
  static List<LotteryResult> _decodeJson(String jsonStr) {
    final List<dynamic> jsonList = json.decode(jsonStr);
    return jsonList.map((json) => LotteryResult.fromMap(json)).toList();
  }

  // ⚡ Hàm static encode JSON
  static String _encodeJson(List<Map<String, dynamic>> jsonList) {
    return json.encode(jsonList);
  }

  Future<List<LotteryResult>?> _loadFromPersistentCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_kqxsTimestampKey);
      if (timestamp == null) return null;
      
      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      if (DateTime.now().difference(cacheTime) > _cacheDuration) return null;

      final jsonStr = prefs.getString(_kqxsCacheKey);
      if (jsonStr == null) return null;

      // ✅ Compute decode
      return await compute(_decodeJson, jsonStr);
    } catch (e) {
      return null;
    }
  }

  Future<void> _saveToPersistentCache(List<LotteryResult> results) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = results.map((r) => r.toMap()).toList();
      
      // ✅ Compute encode
      final jsonStr = await compute(_encodeJson, jsonList);
      
      await prefs.setString(_kqxsCacheKey, jsonStr);
      await prefs.setInt(_kqxsTimestampKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      print('Error saving cache: $e');
    }
  }

  /// ✅ NEW: Background load full data (không block UI)
  void _loadFullDataInBackground() {
    Future.delayed(const Duration(milliseconds: 500), () async {
      try {
        print('📊 Background: Loading full data...');
        final fullData = await loadKQXS(
          forceRefresh: false,
          minimalMode: false,
        );
        print('✅ Background: Loaded ${fullData.length} rows');
      } catch (e) {
        print('⚠️ Background load error: $e');
      }
    });
  }

  /// ✅ Save row count
  Future<void> _saveRowCount(int count) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastRowCountKey, count);
  }

  /// ✅ Clear cache
  Future<void> clearCache() async {
    _cachedResults = null;
    _cacheTimestamp = null;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kqxsCacheKey);
    await prefs.remove(_kqxsMinimalCacheKey);
    await prefs.remove(_kqxsTimestampKey);
    await prefs.remove(_lastRowCountKey);
    
    print('🗑️ Cache cleared');
  }
}
