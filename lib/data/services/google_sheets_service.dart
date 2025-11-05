// lib/data/services/google_sheets_service.dart
import 'package:googleapis/sheets/v4.dart';
import 'package:googleapis_auth/auth_io.dart';
import '../models/app_config.dart';

class GoogleSheetsService {
  SheetsApi? _sheetsApi;
  GoogleSheetsConfig? _config;

  Future<void> initialize(GoogleSheetsConfig config) async {
    _config = config;
    
    // ✅ Credentials đầy đủ từ CREDS_DICT Python
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