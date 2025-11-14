// lib/data/services/google_sheets_service.dart
import 'package:googleapis/sheets/v4.dart';
import 'package:googleapis_auth/auth_io.dart';
import '../models/app_config.dart';

class GoogleSheetsService {
  SheetsApi? _sheetsApi;
  GoogleSheetsConfig? _config;
  
  // ✅ NEW: Cache for batch operations
  final Map<String, List<List<String>>> _batchReadCache = {};
  DateTime? _batchReadCacheTime;
  static const Duration _batchCacheDuration = Duration(minutes: 5);

  Future<void> initialize(GoogleSheetsConfig config) async {
    _config = config;
    
    final credentials = ServiceAccountCredentials.fromJson({
      "type": "service_account",
      "project_id": config.projectId,
      "private_key_id": config.privateKeyId,
      "private_key": config.privateKey,
      "client_email": config.clientEmail,
      "client_id": config.clientId,
      "auth_uri": "https://accounts.google.com/o/oauth2/auth",
      "token_uri": "https://oauth2.googleapis.com/token",
      "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
      "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/xskt-0311%40fresh-heuristic-469212-h6.iam.gserviceaccount.com",
      "universe_domain": "googleapis.com"
    });

    final scopes = [SheetsApi.spreadsheetsScope];
    
    try {
      final client = await clientViaServiceAccount(credentials, scopes);
      _sheetsApi = SheetsApi(client);
      print('✅ Google Sheets initialized successfully');
    } catch (e) {
      print('❌ Error initializing Google Sheets: $e');
      rethrow;
    }
  }

  Future<bool> testConnection() async {
    if (_sheetsApi == null || _config == null) {
      print('❌ Sheets API or config is null');
      return false;
    }
    
    try {
      print('Testing connection with Sheet ID: ${_config!.sheetName}');
      final spreadsheet = await _sheetsApi!.spreadsheets.get(
        _config!.sheetName,
      );
      print('✅ Connection successful! Sheet: ${spreadsheet.properties?.title}');
      return spreadsheet.spreadsheetId != null;
    } catch (e) {
      print('❌ Connection test failed: $e');
      return false;
    }
  }

  // ============================================
  // ✅ NEW: BATCH READ OPERATIONS
  // ============================================
  
  /// Batch read multiple worksheets at once
  /// Returns: Map<worksheetName, List<List<String>>>
  Future<Map<String, List<List<String>>>> batchGetValues(
    List<String> worksheetNames, {
    bool useCache = true,
  }) async {
    if (_sheetsApi == null || _config == null) {
      throw Exception('Google Sheets not initialized');
    }
    
    // ✅ Check cache
    if (useCache && _isBatchCacheValid()) {
      print('📦 Using batch cache (${_batchReadCache.length} sheets)');
      final result = <String, List<List<String>>>{};
      for (final name in worksheetNames) {
        if (_batchReadCache.containsKey(name)) {
          result[name] = _batchReadCache[name]!;
        }
      }
      if (result.length == worksheetNames.length) {
        return result;
      }
    }
    
    try {
      print('📥 Batch reading ${worksheetNames.length} worksheets...');
      
      // ✅ Build ranges for batch request
      final ranges = worksheetNames.map((name) => '$name!A:AD').toList();
      
      // ✅ Single API call for all sheets
      final response = await _sheetsApi!.spreadsheets.values.batchGet(
        _config!.sheetName,
        ranges: ranges,
      );
      
      // ✅ Parse results
      final result = <String, List<List<String>>>{};
      final valueRanges = response.valueRanges ?? [];
      
      for (int i = 0; i < worksheetNames.length; i++) {
        if (i < valueRanges.length) {
          final values = valueRanges[i].values ?? [];
          final parsed = values.map((row) {
            return row.map((cell) => cell?.toString() ?? '').toList();
          }).toList();
          
          result[worksheetNames[i]] = parsed;
          _batchReadCache[worksheetNames[i]] = parsed; // Cache it
        } else {
          result[worksheetNames[i]] = [];
        }
      }
      
      _batchReadCacheTime = DateTime.now();
      
      print('✅ Batch read complete (1 API call instead of ${worksheetNames.length})');
      return result;
      
    } catch (e) {
      print('❌ Batch read error: $e');
      rethrow;
    }
  }

  /// Check if batch cache is still valid
  bool _isBatchCacheValid() {
    if (_batchReadCacheTime == null || _batchReadCache.isEmpty) {
      return false;
    }
    
    final age = DateTime.now().difference(_batchReadCacheTime!);
    return age < _batchCacheDuration;
  }

  /// Clear batch cache
  void clearBatchCache() {
    _batchReadCache.clear();
    _batchReadCacheTime = null;
    print('🗑️ Batch cache cleared');
  }

  // ============================================
  // ✅ NEW: BATCH WRITE OPERATIONS
  // ============================================
  
  /// Batch update multiple ranges at once
  Future<void> batchUpdateRanges(
    Map<String, BatchUpdateData> updates,
  ) async {
    if (_sheetsApi == null || _config == null) {
      throw Exception('Google Sheets not initialized');
    }
    
    if (updates.isEmpty) return;
    
    try {
      print('📤 Batch updating ${updates.length} ranges...');
      
      // ✅ Build batch update request
      final batchUpdateRequest = BatchUpdateValuesRequest(
        valueInputOption: 'USER_ENTERED',
        data: updates.entries.map((entry) {
          return ValueRange(
            range: '${entry.key}!${entry.value.range}',
            values: entry.value.values,
          );
        }).toList(),
      );
      
      // ✅ Single API call for all updates
      await _sheetsApi!.spreadsheets.values.batchUpdate(
        batchUpdateRequest,
        _config!.sheetName,
      );
      
      // ✅ Invalidate cache for updated sheets
      for (final worksheetName in updates.keys) {
        _batchReadCache.remove(worksheetName);
      }
      
      print('✅ Batch update complete (1 API call instead of ${updates.length})');
      
    } catch (e) {
      print('❌ Batch update error: $e');
      rethrow;
    }
  }

  // ============================================
  // EXISTING METHODS (Keep for backward compatibility)
  // ============================================
  
  Future<List<List<String>>> getAllValues(String worksheetName) async {
    if (_sheetsApi == null || _config == null) {
      throw Exception('Google Sheets not initialized');
    }
    
    try {
      final range = '$worksheetName!A:AD';
      
      final response = await _sheetsApi!.spreadsheets.values.get(
        _config!.sheetName,
        range,
      );
      
      final values = response.values ?? [];
      return values.map((row) {
        return row.map((cell) => cell?.toString() ?? '').toList();
      }).toList();
    } catch (e) {
      print('Error getting values: $e');
      rethrow;
    }
  }

  Future<void> updateRange(
    String worksheetName,
    String range,
    List<List<String>> values,
  ) async {
    if (_sheetsApi == null || _config == null) {
      throw Exception('Google Sheets not initialized');
    }
    
    try {
      final valueRange = ValueRange(values: values);
      
      await _sheetsApi!.spreadsheets.values.update(
        valueRange,
        _config!.sheetName,
        '$worksheetName!$range',
        valueInputOption: 'USER_ENTERED',
      );
    } catch (e) {
      print('Error updating range: $e');
      rethrow;
    }
  }

  Future<void> appendRows(
    String worksheetName,
    List<List<String>> rows,
  ) async {
    if (_sheetsApi == null || _config == null) {
      throw Exception('Google Sheets not initialized');
    }
    
    try {
      final valueRange = ValueRange(values: rows);
      
      await _sheetsApi!.spreadsheets.values.append(
        valueRange,
        _config!.sheetName,
        '$worksheetName!A:AD',
        valueInputOption: 'USER_ENTERED',
      );
    } catch (e) {
      print('Error appending rows: $e');
      rethrow;
    }
  }

  Future<void> clearSheet(String worksheetName) async {
    if (_sheetsApi == null || _config == null) {
      throw Exception('Google Sheets not initialized');
    }
    
    try {
      await _sheetsApi!.spreadsheets.values.clear(
        ClearValuesRequest(),
        _config!.sheetName,
        '$worksheetName!A:AD',
      );
    } catch (e) {
      print('Error clearing sheet: $e');
      rethrow;
    }
  }
}

// ============================================
// ✅ NEW: Helper Classes
// ============================================

/// Data for batch update operation
class BatchUpdateData {
  final String range;
  final List<List<String>> values;

  BatchUpdateData({
    required this.range,
    required this.values,
  });
}