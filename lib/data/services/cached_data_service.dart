// lib/data/services/cached_data_service.dart - OPTIMIZED VERSION

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/lottery_result.dart';
import 'google_sheets_service.dart';

/// ✅ OPTIMIZED: Service quản lý cache với incremental loading
class CachedDataService {
  final GoogleSheetsService _sheetsService;
  
  // Cache keys
  static const String _kqxsCacheKey = 'kqxs_cache';
  static const String _kqxsTimestampKey = 'kqxs_timestamp';
  static const String _lastRowCountKey = 'kqxs_last_row_count';
  
  // ✅ NEW: Cache cho data tối thiểu (1200 rows gần nhất)
  static const String _kqxsMinimalCacheKey = 'kqxs_minimal_cache';
  static const int _minimalCacheSize = 1200;
  
  // Cache duration (30 phút)
  static const Duration _cacheDuration = Duration(minutes: 30);
  
  // In-memory cache
  List<LotteryResult>? _cachedResults;
  DateTime? _cacheTimestamp;
  
  CachedDataService({required GoogleSheetsService sheetsService})
      : _sheetsService = sheetsService;

  /// ✅ OPTIMIZED: Load KQXS với incremental loading
  /// - Mặc định load 100 rows gần nhất (nhanh ~80%)
  /// - Option load full data khi cần
  Future<List<LotteryResult>> loadKQXS({
    bool forceRefresh = false,
    bool incrementalOnly = false,
    bool minimalMode = true, // ✅ NEW: Load tối thiểu trước
  }) async {
    print('📊 Loading KQXS (refresh: $forceRefresh, minimal: $minimalMode)');
    
    // ✅ STEP 1: Nếu minimal mode, load 100 rows trước
    if (minimalMode && !forceRefresh) {
      final minimal = await _loadMinimalCache();
      if (minimal != null && minimal.isNotEmpty) {
        print('   ✅ Using minimal cache (${minimal.length} rows) - FAST!');
        
        // ✅ Background load full data (không block)
        _loadFullDataInBackground();
        
        return minimal;
      }
    }
    
    // ✅ STEP 2: CHECK IN-MEMORY CACHE (full data)
    if (!forceRefresh && _cachedResults != null && _cacheTimestamp != null) {
      final age = DateTime.now().difference(_cacheTimestamp!);
      if (age < _cacheDuration) {
        print('   ✅ Using in-memory cache (age: ${age.inMinutes}min)');
        return _cachedResults!;
      }
    }

    // ✅ STEP 3: CHECK PERSISTENT CACHE
    if (!forceRefresh) {
      final cachedData = await _loadFromPersistentCache();
      if (cachedData != null) {
        _cachedResults = cachedData;
        _cacheTimestamp = DateTime.now();
        print('   ✅ Using persistent cache (${cachedData.length} rows)');
        return cachedData;
      }
    }

    // ✅ STEP 4: CHECK IF WE CAN DO INCREMENTAL UPDATE
    if (incrementalOnly && !forceRefresh) {
      final incremental = await _loadIncrementalData();
      if (incremental != null) {
        return incremental;
      }
    }

    // ✅ STEP 5: FULL REFRESH từ Google Sheets
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

    // ✅ STEP 6: SAVE TO CACHE
    await _saveToPersistentCache(results);
    await _saveRowCount(allValues.length);
    
    // ✅ Save minimal cache (100 rows gần nhất)
    await _saveMinimalCache(results);
    
    _cachedResults = results;
    _cacheTimestamp = DateTime.now();
    
    print('   ✅ Loaded ${results.length} rows from Sheets');
    return results;
  }

  /// ✅ NEW: Load minimal cache (100 rows gần nhất)
  Future<List<LotteryResult>?> _loadMinimalCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Check timestamp
      final timestamp = prefs.getInt(_kqxsTimestampKey);
      if (timestamp == null) return null;
      
      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final age = DateTime.now().difference(cacheTime);
      
      if (age > _cacheDuration) {
        print('   ⚠️ Minimal cache expired (age: ${age.inMinutes}min)');
        return null;
      }

      // Load minimal data
      final jsonStr = prefs.getString(_kqxsMinimalCacheKey);
      if (jsonStr == null) return null;

      final List<dynamic> jsonList = json.decode(jsonStr);
      final results = jsonList
          .map((json) => LotteryResult.fromMap(json))
          .toList();
      
      return results;
    } catch (e) {
      print('   ⚠️ Error loading minimal cache: $e');
      return null;
    }
  }

  /// ✅ NEW: Save minimal cache
  Future<void> _saveMinimalCache(List<LotteryResult> results) async {
    try {
      // Lấy 100 rows gần nhất
      final minimal = results.length > _minimalCacheSize
          ? results.sublist(results.length - _minimalCacheSize)
          : results;
      
      final prefs = await SharedPreferences.getInstance();
      final jsonList = minimal.map((r) => r.toMap()).toList();
      final jsonStr = json.encode(jsonList);
      
      await prefs.setString(_kqxsMinimalCacheKey, jsonStr);
      print('   💾 Saved minimal cache (${minimal.length} rows)');
    } catch (e) {
      print('   ⚠️ Error saving minimal cache: $e');
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
      await _saveMinimalCache(merged);
      
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
    await prefs.remove(_kqxsMinimalCacheKey);
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