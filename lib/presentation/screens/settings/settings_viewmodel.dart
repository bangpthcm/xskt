// lib/presentation/screens/settings/settings_viewmodel.dart
import 'package:flutter/material.dart';
import '../../../data/models/app_config.dart';
import '../../../data/models/api_account.dart';
import '../../../data/services/storage_service.dart';
import '../../../data/services/google_sheets_service.dart';
import '../../../data/services/telegram_service.dart';
import '../../../data/services/betting_api_service.dart';
import '../../../data/services/backfill_service.dart';
import '../../../data/services/rss_parser_service.dart';

class SettingsViewModel extends ChangeNotifier {
  final StorageService _storageService;
  final GoogleSheetsService _sheetsService;
  final TelegramService _telegramService;
  final RssParserService _rssService;

  SettingsViewModel({
    required StorageService storageService,
    required GoogleSheetsService sheetsService,
    required TelegramService telegramService,
    required RssParserService rssService,
  })  : _storageService = storageService,
        _sheetsService = sheetsService,
        _telegramService = telegramService,
        _rssService = rssService;

  AppConfig _config = AppConfig.defaultConfig();
  bool _isLoading = false;
  String? _errorMessage;
  
  // ✅ Trạng thái kết nối
  bool _isGoogleSheetsConnected = false;
  bool _isTelegramConnected = false;
  
  // ✅ THÊM: Trạng thái API accounts
  final List<bool?> _apiAccountStatus = [null, null, null]; // null = chưa test, true = thành công, false = thất bại

  AppConfig get config => _config;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isGoogleSheetsConnected => _isGoogleSheetsConnected;
  bool get isTelegramConnected => _isTelegramConnected;
  List<bool?> get apiAccountStatus => _apiAccountStatus; // ✅ THÊM getter

  Future<void> loadConfig() async {
    _isLoading = true;
    notifyListeners();

    try {
      final loadedConfig = await _storageService.loadConfig();
      if (loadedConfig != null) {
        _config = loadedConfig;
      }
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Lỗi tải cấu hình: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> saveConfig(AppConfig newConfig) async {
    _isLoading = true;
    notifyListeners();

    try {
      // ✅ 1. Lưu config
      await _storageService.saveConfig(newConfig);
      _config = newConfig;
      
      // ✅ 2. Tự động reinitialize services
      print('🔄 Reinitializing services with new config...');
      
      try {
        await _sheetsService.initialize(newConfig.googleSheets);
        _telegramService.initialize(newConfig.telegram);
        print('✅ Services reinitialized successfully');
      } catch (e) {
        print('⚠️ Error reinitializing services: $e');
      }
      
      _errorMessage = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Lỗi lưu cấu hình: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> testGoogleSheetsConnection() async {
    try {
      await _sheetsService.initialize(_config.googleSheets);
      _isGoogleSheetsConnected = await _sheetsService.testConnection();
      
      if (!_isGoogleSheetsConnected) {
        _errorMessage = 'Không thể kết nối Google Sheets';
      }
      
      notifyListeners();
      return _isGoogleSheetsConnected;
    } catch (e) {
      _errorMessage = 'Lỗi kết nối Google Sheets: $e';
      _isGoogleSheetsConnected = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> testTelegramConnection() async {
    try {
      _telegramService.initialize(_config.telegram);
      _isTelegramConnected = await _telegramService.testConnection();
      
      if (!_isTelegramConnected) {
        _errorMessage = 'Không thể kết nối Telegram (bot token không hợp lệ)';
      }
      
      notifyListeners();
      return _isTelegramConnected;
    } catch (e) {
      _errorMessage = 'Lỗi kết nối Telegram: $e';
      _isTelegramConnected = false;
      notifyListeners();
      return false;
    }
  }

  // ✅ THÊM: Test tất cả API accounts
  Future<void> testAllApiAccounts(List<ApiAccount> accounts, String domain) async {  // ✅ THÊM domain
    // Reset trạng thái
    for (int i = 0; i < 3; i++) {
      _apiAccountStatus[i] = null;
    }
    notifyListeners();

    // Test từng account
    for (int i = 0; i < accounts.length && i < 3; i++) {
      final account = accounts[i];
      
      if (account.username.isEmpty || account.password.isEmpty) {
        _apiAccountStatus[i] = null;
        continue;
      }

      try {
        print('🔐 Testing API account ${i + 1}: ${account.username}');
        
        final apiService = BettingApiService();
        final token = await apiService.authenticateAndGetToken(account, domain);  // ✅ Truyền domain
        
        _apiAccountStatus[i] = (token != null && token.isNotEmpty);
        
        if (_apiAccountStatus[i] == true) {
          print('✅ Account ${i + 1} authentication successful');
        } else {
          print('❌ Account ${i + 1} authentication failed');
        }
        
        apiService.clearCache();
      } catch (e) {
        print('❌ Error testing account ${i + 1}: $e');
        _apiAccountStatus[i] = false;
      }
      
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
  
  // ✅ Reset trạng thái kết nối
  void resetConnectionStatus() {
    _isGoogleSheetsConnected = false;
    _isTelegramConnected = false;
    for (int i = 0; i < 3; i++) {
      _apiAccountStatus[i] = null;
    }
    notifyListeners();
  }

  Future<String> syncRSSData() async {
    _isLoading = true;
    notifyListeners();

    try {
      final backfillService = BackfillService(
        sheetsService: _sheetsService,
        rssService: _rssService,
      );

      final result = await backfillService.syncAllFromRSS();

      _isLoading = false;
      notifyListeners();

      return result.message;
    } catch (e) {
      _errorMessage = 'Lỗi đồng bộ RSS: $e';
      _isLoading = false;
      notifyListeners();
      return 'Lỗi đồng bộ RSS: $e';
    }
  }
}