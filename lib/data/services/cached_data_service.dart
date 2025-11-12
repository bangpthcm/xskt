// lib/data/services/cached_data_service.dart

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/lottery_result.dart';
import 'google_sheets_service.dart';

/// Service quản lý cache và tối ưu API calls
class CachedDataService {
  final GoogleSheetsService _sheetsService;
  
  // Cache keys
  static const String _kqxsCacheKey = 'kqxs_cache';
  static const String _kqxsTimestampKey = 'kqxs_timestamp';
  static const String _lastRowCountKey = 'kqxs_last_row_count';
  
  // Cache duration (30 phút)
  static const Duration _cacheDuration = Duration(minutes: 30);
  
  // In-memory cache
  List<LotteryResult>? _cachedResults;
  DateTime? _cacheTimestamp;
  
  CachedDataService({required GoogleSheetsService sheetsService})
      : _sheetsService = sheetsService;

  /// ✅ Load KQXS với caching thông minh
  Future<List<LotteryResult>> loadKQXS({
    bool forceRefresh = false,
    bool incrementalOnly = false,
  }) async {
    print('📊 Loading KQXS (forceRefresh: $forceRefresh, incremental: $incrementalOnly)');
    
    // 1. CHECK IN-MEMORY CACHE
    if (!forceRefresh && _cachedResults != null && _cacheTimestamp != null) {
      final age = DateTime.now().difference(_cacheTimestamp!);
      if (age < _cacheDuration) {
        print('   ✅ Using in-memory cache (age: ${age.inMinutes}min)');
        return _cachedResults!;
      }
    }

    // 2. CHECK PERSISTENT CACHE
    if (!forceRefresh) {
      final cachedData = await _loadFromPersistentCache();
      if (cachedData != null) {
        _cachedResults = cachedData;
        _cacheTimestamp = DateTime.now();
        print('   ✅ Using persistent cache (${cachedData.length} rows)');
        return cachedData;
      }
    }

    // 3. CHECK IF WE CAN DO INCREMENTAL UPDATE
    if (incrementalOnly && !forceRefresh) {
      final incremental = await _loadIncrementalData();
      if (incremental != null) {
        return incremental;
      }
    }

    // 4. FULL REFRESH từ Google Sheets
    print('   🔄 Fetching from Google Sheets...');
    final allValues = await _sheetsService.getAllValues('KQXS');
    
    if (allValues.length < 2) {
      print('   ⚠️ No data in sheet');
      return [];
    }

    final results = <LotteryResult>[];
    for (int i = 1; i < allValues.length; i++) {
      try {
        results.add(LotteryResult.fromSheetRow(allValues[i]));
      } catch (e) {
        print('   ⚠️ Skip invalid row $i: $e');
      }
    }

    // 5. SAVE TO CACHE
    await _saveToPersistentCache(results);
    await _saveRowCount(allValues.length);
    
    _cachedResults = results;
    _cacheTimestamp = DateTime.now();
    
    print('   ✅ Loaded ${results.length} rows from Sheets');
    return results;
  }

  /// ✅ Load chỉ data mới (incremental update)
  Future<List<LotteryResult>?> _loadIncrementalData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastRowCount = prefs.getInt(_lastRowCountKey) ?? 0;
      
      if (lastRowCount == 0) {
        print('   ⚠️ No previous row count, cannot do incremental');
        return null;
      }

      // Load cached data
      final cached = await _loadFromPersistentCache();
      if (cached == null) {
        print('   ⚠️ No cached data, cannot do incremental');
        return null;
      }

      // Check current row count
      print('   🔍 Checking for new rows (last count: $lastRowCount)...');
      final currentValues = await _sheetsService.getAllValues('KQXS');
      
      if (currentValues.length <= lastRowCount) {
        print('   ✅ No new rows, using cache');
        _cachedResults = cached;
        _cacheTimestamp = DateTime.now();
        return cached;
      }

      // Load only new rows
      print('   📥 Loading ${currentValues.length - lastRowCount} new rows...');
      final newResults = <LotteryResult>[];
      for (int i = lastRowCount; i < currentValues.length; i++) {
        try {
          newResults.add(LotteryResult.fromSheetRow(currentValues[i]));
        } catch (e) {
          print('   ⚠️ Skip invalid row $i: $e');
        }
      }

      // Merge with cached data
      final merged = [...cached, ...newResults];
      
      // Save updated cache
      await _saveToPersistentCache(merged);
      await _saveRowCount(currentValues.length);
      
      _cachedResults = merged;
      _cacheTimestamp = DateTime.now();
      
      print('   ✅ Incremental update: ${newResults.length} new rows');
      return merged;
      
    } catch (e) {
      print('   ❌ Incremental load failed: $e');
      return null;
    }
  }

  /// ✅ Load từ persistent cache
  Future<List<LotteryResult>?> _loadFromPersistentCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Check timestamp
      final timestamp = prefs.getInt(_kqxsTimestampKey);
      if (timestamp == null) return null;
      
      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final age = DateTime.now().difference(cacheTime);
      
      if (age > _cacheDuration) {
        print('   ⚠️ Persistent cache expired (age: ${age.inMinutes}min)');
        return null;
      }

      // Load data
      final jsonStr = prefs.getString(_kqxsCacheKey);
      if (jsonStr == null) return null;

      final List<dynamic> jsonList = json.decode(jsonStr);
      final results = jsonList
          .map((json) => LotteryResult.fromMap(json))
          .toList();
      
      return results;
    } catch (e) {
      print('   ⚠️ Error loading persistent cache: $e');
      return null;
    }
  }

  /// ✅ Save vào persistent cache
  Future<void> _saveToPersistentCache(List<LotteryResult> results) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final jsonList = results.map((r) => r.toMap()).toList();
      final jsonStr = json.encode(jsonList);
      
      await prefs.setString(_kqxsCacheKey, jsonStr);
      await prefs.setInt(_kqxsTimestampKey, DateTime.now().millisecondsSinceEpoch);
      
      print('   💾 Saved ${results.length} rows to persistent cache');
    } catch (e) {
      print('   ⚠️ Error saving persistent cache: $e');
    }
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
    await prefs.remove(_kqxsTimestampKey);
    await prefs.remove(_lastRowCountKey);
    
    print('🗑️ Cache cleared');
  }

  /// ✅ Get cache status
  Future<CacheStatus> getCacheStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(_kqxsTimestampKey);
    final rowCount = prefs.getInt(_lastRowCountKey);
    
    if (timestamp == null) {
      return CacheStatus(
        isValid: false,
        rowCount: 0,
        age: Duration.zero,
      );
    }

    final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final age = DateTime.now().difference(cacheTime);
    
    return CacheStatus(
      isValid: age < _cacheDuration,
      rowCount: rowCount ?? 0,
      age: age,
    );
  }
}

/// Model cho cache status
class CacheStatus {
  final bool isValid;
  final int rowCount;
  final Duration age;

  CacheStatus({
    required this.isValid,
    required this.rowCount,
    required this.age,
  });

  @override
  String toString() {
    return 'Cache: ${isValid ? "Valid" : "Expired"} - '
           '$rowCount rows - Age: ${age.inMinutes}min';
  }
}