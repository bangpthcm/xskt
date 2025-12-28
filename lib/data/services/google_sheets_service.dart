import 'package:dio/dio.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http; // ✅ Thêm import này để dùng cho Auth

import '../models/app_config.dart';

class GoogleSheetsService {
  final Dio _dio = Dio();
  GoogleSheetsConfig? _config;

  // Quản lý Token
  AccessCredentials? _credentials;
  static const List<String> _scopes = [
    'https://www.googleapis.com/auth/spreadsheets'
  ];

  // Cache
  final Map<String, List<List<String>>> _batchReadCache = {};
  // ignore: unused_field
  DateTime? _batchReadCacheTime;

  Future<void> initialize(GoogleSheetsConfig config) async {
    _config = config;
    // Lấy token lần đầu để kiểm tra
    await _getAccessToken();
    print('✅ Google Sheets Service initialized (REST Mode)');
  }

  /// ✅ Lấy hoặc làm mới Access Token
  Future<String> _getAccessToken() async {
    if (_config == null) throw Exception('Config is null');

    // Nếu token còn hạn thì dùng tiếp
    if (_credentials != null &&
        _credentials!.accessToken.expiry.isAfter(DateTime.now())) {
      return _credentials!.accessToken.data;
    }

    // Nếu hết hạn hoặc chưa có, lấy mới từ googleapis_auth
    final serviceAccountCredentials = ServiceAccountCredentials.fromJson({
      "type": "service_account",
      "project_id": _config!.projectId,
      "private_key_id": _config!.privateKeyId,
      "private_key": _config!.privateKey,
      "client_email": _config!.clientEmail,
      "client_id": _config!.clientId,
      "token_uri": "https://oauth2.googleapis.com/token",
    });

    // ✅ FIX: Tạo http.Client để truyền vào hàm obtainAccessCredentialsViaServiceAccount
    final client = http.Client();
    try {
      _credentials = await obtainAccessCredentialsViaServiceAccount(
        serviceAccountCredentials,
        _scopes,
        client, // ✅ Tham số thứ 3 bắt buộc
      );
    } finally {
      client.close(); // Đóng client sau khi dùng xong
    }

    return _credentials!.accessToken.data;
  }

  /// ✅ Helper để tạo Header có Auth
  Future<Options> _getAuthOptions() async {
    final token = await _getAccessToken();
    return Options(
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
  }

  Future<bool> testConnection() async {
    try {
      final token = await _getAccessToken();
      final url =
          'https://sheets.googleapis.com/v4/spreadsheets/${_config!.sheetName}';

      final response = await _dio.get(
        url,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      print(
          '✅ Connection successful! Sheet: ${response.data['properties']['title']}');
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Connection test failed: $e');
      return false;
    }
  }

  // ============================================
  // ✅ BATCH READ (REST API)
  // ============================================
  Future<Map<String, List<List<dynamic>>>> batchGetValues(
      List<String> sheetNames) async {
    try {
      // Gọi song song các request
      final futures = sheetNames.map((name) => getAllValues(name)).toList();
      final results = await Future.wait(futures);

      final Map<String, List<List<dynamic>>> dataMap = {};
      for (int i = 0; i < sheetNames.length; i++) {
        // Ép kiểu kết quả về dynamic để tránh lỗi Type mismatch
        dataMap[sheetNames[i]] = results[i] as List<List<dynamic>>;
      }
      return dataMap;
    } catch (e) {
      print('❌ Batch get failed: $e');
      rethrow;
    }
  }

  // ============================================
  // ✅ BATCH UPDATE (REST API)
  // ============================================
  Future<void> batchUpdateRanges(Map<String, BatchUpdateData> updates) async {
    if (updates.isEmpty) return;

    try {
      final url =
          'https://sheets.googleapis.com/v4/spreadsheets/${_config!.sheetName}/values:batchUpdate';

      final body = {
        "valueInputOption": "USER_ENTERED",
        "data": updates.entries
            .map((entry) => {
                  "range": "${entry.key}!${entry.value.range}",
                  "values": entry.value.values
                })
            .toList()
      };

      await _dio.post(
        url,
        data: body,
        options: await _getAuthOptions(),
      );

      // Invalidate cache
      for (final worksheetName in updates.keys) {
        _batchReadCache.remove(worksheetName);
      }
    } catch (e) {
      print('❌ Batch update error: $e');
      rethrow;
    }
  }

  // ============================================
  // EXISTING METHODS (REST Implementation)
  // ============================================
  Future<List<List<String>>> getAllValues(String worksheetName) async {
    try {
      final url =
          'https://sheets.googleapis.com/v4/spreadsheets/${_config!.sheetName}/values/$worksheetName!A:AD';
      final response = await _dio.get(url, options: await _getAuthOptions());

      final values = (response.data['values'] as List?)?.map((row) {
            return (row as List).map((cell) => cell.toString()).toList();
          }).toList() ??
          [];

      return values;
    } catch (e) {
      print('Error getting values: $e');
      rethrow;
    }
  }

  Future<void> updateRange(
      String worksheetName, String range, List<List<String>> values) async {
    try {
      final url =
          'https://sheets.googleapis.com/v4/spreadsheets/${_config!.sheetName}/values/$worksheetName!$range';

      await _dio.put(
        url,
        queryParameters: {'valueInputOption': 'USER_ENTERED'},
        data: {"values": values},
        options: await _getAuthOptions(),
      );
    } catch (e) {
      print('Error updating range: $e');
      rethrow;
    }
  }

  Future<void> appendRows(String worksheetName, List<List<String>> rows) async {
    try {
      final url =
          'https://sheets.googleapis.com/v4/spreadsheets/${_config!.sheetName}/values/$worksheetName!A:AD:append';

      await _dio.post(
        url,
        queryParameters: {'valueInputOption': 'USER_ENTERED'},
        data: {"values": rows},
        options: await _getAuthOptions(),
      );
    } catch (e) {
      print('Error appending rows: $e');
      rethrow;
    }
  }

  Future<void> clearSheet(String worksheetName) async {
    try {
      final url =
          'https://sheets.googleapis.com/v4/spreadsheets/${_config!.sheetName}/values/$worksheetName!A:AD:clear';
      await _dio.post(url, options: await _getAuthOptions());
    } catch (e) {
      print('Error clearing sheet: $e');
      rethrow;
    }
  }

  void clearBatchCache() {
    _batchReadCache.clear();
    _batchReadCacheTime = null;
  }

  Future<List<List<String>>> getAnalysisCycleData() async {
    try {
      if (_config == null) {
        throw Exception('Google Sheets Config chưa được khởi tạo');
      }

      // Lấy dư ra một chút (J10) để chắc chắn không sót dữ liệu
      final url =
          'https://sheets.googleapis.com/v4/spreadsheets/${_config!.sheetName}/values/analysis_cycle!A1:J13';
      final response = await _dio.get(url, options: await _getAuthOptions());

      // Kiểm tra data null
      if (response.data == null || response.data['values'] == null) {
        return [];
      }

      final rawValues = response.data['values'] as List;

      // Parse an toàn: Chuyển mọi thứ thành String, nếu null thì thành ""
      final values = rawValues.map((row) {
        if (row == null || row is! List) return <String>[];
        return row.map((cell) => cell?.toString() ?? "").toList();
      }).toList();

      return values;
    } catch (e) {
      print('❌ Error getting analysis cycle data: $e');
      rethrow;
    }
  }
}

class BatchUpdateData {
  final String range;
  final List<List<String>> values;
  BatchUpdateData({required this.range, required this.values});
}
