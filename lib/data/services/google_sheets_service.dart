// lib/data/services/google_sheets_service.dart

import 'dart:async'; // ✅ Import để dùng Future.delayed

import 'package:dio/dio.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

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

    final client = http.Client();
    try {
      _credentials = await obtainAccessCredentialsViaServiceAccount(
        serviceAccountCredentials,
        _scopes,
        client,
      );
    } finally {
      client.close();
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
      validateStatus: (status) {
        // Cho phép xử lý 429 thủ công thay vì throw ngay ở tầng Dio
        return status != null && status < 500;
      },
    );
  }

  // ============================================
  // ✅ CƠ CHẾ RETRY (TỰ ĐỘNG THỬ LẠI KHI GẶP 429)
  // ============================================
  Future<T> _retryOperation<T>(Future<T> Function() operation) async {
    int retries = 0;
    const maxRetries = 5;

    while (true) {
      try {
        return await operation();
      } on DioException catch (e) {
        // Kiểm tra lỗi 429 (Too Many Requests) hoặc 500/503 (Server Busy)
        final statusCode = e.response?.statusCode;
        if ((statusCode == 429 || statusCode == 500 || statusCode == 503) &&
            retries < maxRetries) {
          retries++;
          // Backoff: Chờ 2s, 4s, 8s, 16s...
          int delaySeconds = (1 << retries);
          print(
              '⚠️ Google Sheets API quá tải ($statusCode). Đang chờ ${delaySeconds}s để thử lại lần $retries/$maxRetries...');
          await Future.delayed(Duration(seconds: delaySeconds));
          continue;
        }
        rethrow; // Nếu lỗi khác hoặc hết lượt retry thì ném lỗi ra ngoài
      } catch (e) {
        rethrow;
      }
    }
  }

  Future<bool> testConnection() async {
    return _retryOperation(() async {
      final token = await _getAccessToken();
      final url =
          'https://sheets.googleapis.com/v4/spreadsheets/${_config!.sheetName}';

      final response = await _dio.get(
        url,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200) {
        print(
            '✅ Connection successful! Sheet: ${response.data['properties']['title']}');
        return true;
      }
      return false;
    });
  }

  // ============================================
  // ✅ BATCH READ (REST API) - Có Retry
  // ============================================
  Future<Map<String, List<List<dynamic>>>> batchGetValues(
      List<String> sheetNames) async {
    return _retryOperation(() async {
      // Gọi song song các request
      final futures = sheetNames.map((name) => getAllValues(name)).toList();
      final results = await Future.wait(futures);

      final Map<String, List<List<dynamic>>> dataMap = {};
      for (int i = 0; i < sheetNames.length; i++) {
        dataMap[sheetNames[i]] = results[i] as List<List<dynamic>>;
      }
      return dataMap;
    });
  }

  // ============================================
  // ✅ BATCH UPDATE (REST API) - Có Retry
  // ============================================
  Future<void> batchUpdateRanges(Map<String, BatchUpdateData> updates) async {
    if (updates.isEmpty) return;

    return _retryOperation(() async {
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

      final response = await _dio.post(
        url,
        data: body,
        options: await _getAuthOptions(),
      );

      if (response.statusCode == 429) {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
        );
      }

      // Invalidate cache
      for (final worksheetName in updates.keys) {
        _batchReadCache.remove(worksheetName);
      }
    });
  }

  // ============================================
  // EXISTING METHODS (REST Implementation) - Có Retry
  // ============================================
  Future<List<List<String>>> getAllValues(String worksheetName) async {
    return _retryOperation(() async {
      final url =
          'https://sheets.googleapis.com/v4/spreadsheets/${_config!.sheetName}/values/$worksheetName!A:AD';
      final response = await _dio.get(url, options: await _getAuthOptions());

      if (response.statusCode == 429) {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
        );
      }

      final values = (response.data['values'] as List?)?.map((row) {
            return (row as List).map((cell) => cell.toString()).toList();
          }).toList() ??
          [];

      return values;
    });
  }

  Future<void> updateRange(
      String worksheetName, String range, List<List<String>> values) async {
    return _retryOperation(() async {
      final url =
          'https://sheets.googleapis.com/v4/spreadsheets/${_config!.sheetName}/values/$worksheetName!$range';

      final response = await _dio.put(
        url,
        queryParameters: {'valueInputOption': 'USER_ENTERED'},
        data: {"values": values},
        options: await _getAuthOptions(),
      );

      if (response.statusCode == 429) {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
        );
      }
    });
  }

  Future<void> appendRows(String worksheetName, List<List<String>> rows) async {
    return _retryOperation(() async {
      final url =
          'https://sheets.googleapis.com/v4/spreadsheets/${_config!.sheetName}/values/$worksheetName!A:AD:append';

      final response = await _dio.post(
        url,
        queryParameters: {'valueInputOption': 'USER_ENTERED'},
        data: {"values": rows},
        options: await _getAuthOptions(),
      );

      if (response.statusCode == 429) {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
        );
      }
    });
  }

  Future<void> clearSheet(String worksheetName) async {
    return _retryOperation(() async {
      final url =
          'https://sheets.googleapis.com/v4/spreadsheets/${_config!.sheetName}/values/$worksheetName!A:AD:clear';
      final response = await _dio.post(url, options: await _getAuthOptions());

      if (response.statusCode == 429) {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
        );
      }
    });
  }

  void clearBatchCache() {
    _batchReadCache.clear();
    _batchReadCacheTime = null;
  }

  Future<List<List<String>>> getAnalysisCycleData() async {
    return _retryOperation(() async {
      if (_config == null) {
        throw Exception('Google Sheets Config chưa được khởi tạo');
      }

      final url =
          'https://sheets.googleapis.com/v4/spreadsheets/${_config!.sheetName}/values/analysis_cycle!A1:J13';
      final response = await _dio.get(url, options: await _getAuthOptions());

      if (response.statusCode == 429) {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
        );
      }

      if (response.data == null || response.data['values'] == null) {
        return [];
      }

      final rawValues = response.data['values'] as List;

      final values = rawValues.map((row) {
        if (row == null || row is! List) return <String>[];
        return row.map((cell) => cell?.toString() ?? "").toList();
      }).toList();

      return values;
    });
  }
}

class BatchUpdateData {
  final String range;
  final List<List<String>> values;
  BatchUpdateData({required this.range, required this.values});
}
