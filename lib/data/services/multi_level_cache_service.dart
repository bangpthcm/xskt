import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/lottery_result.dart';

/// ✅ OPTIMIZATION: Multi-level cache
/// - Level 1: Memory (nhanh nhất, mất khi restart)
/// - Level 2: Persistent (SharedPreferences, tồn tại giữa sessions)
class MultiLevelCacheService {
  // ✅ Level 1: Memory cache
  final Map<String, dynamic> _memoryCache = {};
  
  // ✅ Level 2: Persistent cache keys
  static const String _kqxsCacheKey = 'kqxs_cache_v2';
  static const String _analysisKey = 'analysis_cache_v2';
  static const String _timestampKey = 'cache_timestamp_v2';
  
  static const Duration _cacheDuration = Duration(minutes: 30);
  
  /// ✅ Get from cache (memory first, then persistent)
  Future<T?> get<T>(
    String key, {
    T Function(dynamic)? deserializer,
  }) async {
    // Level 1: Check memory
    if (_memoryCache.containsKey(key)) {
      print('📦 Cache HIT (memory): $key');
      return _memoryCache[key] as T?;
    }
    
    // Level 2: Check persistent
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt('${key}_timestamp');
      
      if (timestamp != null) {
        final age = DateTime.now().millisecondsSinceEpoch - timestamp;
        if (age < _cacheDuration.inMilliseconds) {
          final jsonStr = prefs.getString(key);
          if (jsonStr != null) {
            print('📦 Cache HIT (persistent): $key');
            final data = deserializer != null
                ? deserializer(json.decode(jsonStr))
                : json.decode(jsonStr) as T;
            
            // Store in memory for next time
            _memoryCache[key] = data;
            return data;
          }
        }
      }
    } catch (e) {
      print('⚠️ Cache read error: $e');
    }
    
    print('❌ Cache MISS: $key');
    return null;
  }
  
  /// ✅ Set cache (both levels)
  Future<void> set<T>(
    String key,
    T value, {
    dynamic Function(T)? serializer,
  }) async {
    // Level 1: Memory
    _memoryCache[key] = value;
    
    // Level 2: Persistent
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = json.encode(
        serializer != null ? serializer(value) : value,
      );
      
      await prefs.setString(key, jsonStr);
      await prefs.setInt(
        '${key}_timestamp',
        DateTime.now().millisecondsSinceEpoch,
      );
      
      print('💾 Cache SET: $key');
    } catch (e) {
      print('⚠️ Cache write error: $e');
    }
  }
  
  /// ✅ Clear specific cache
  Future<void> clear(String key) async {
    _memoryCache.remove(key);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
    await prefs.remove('${key}_timestamp');
    
    print('🗑️ Cache cleared: $key');
  }
  
  /// ✅ Clear all cache
  Future<void> clearAll() async {
    _memoryCache.clear();
    
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys()
        .where((k) => k.contains('cache'))
        .toList();
    
    for (final key in keys) {
      await prefs.remove(key);
    }
    
    print('🗑️ All cache cleared');
  }
  
  /// ✅ Get cache info
  Map<String, dynamic> getCacheInfo() {
    return {
      'memory_keys': _memoryCache.keys.toList(),
      'memory_size': _memoryCache.length,
    };
  }
}