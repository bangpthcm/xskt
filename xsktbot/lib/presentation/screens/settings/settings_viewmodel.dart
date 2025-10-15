// lib/presentation/screens/settings/settings_viewmodel.dart
import 'package:flutter/material.dart';
import '../../../data/models/app_config.dart';
import '../../../data/services/storage_service.dart';
import '../../../data/services/google_sheets_service.dart';
import '../../../data/services/telegram_service.dart';
import '../../../data/services/backfill_service.dart';  // ✅ ADD
import '../../../data/services/rss_parser_service.dart';

class SettingsViewModel extends ChangeNotifier {
  final StorageService _storageService;
  final GoogleSheetsService _sheetsService;
  final TelegramService _telegramService;
  final RssParserService _rssService;  // ✅ PHẢI CÓ DÒNG NÀY

  SettingsViewModel({
    required StorageService storageService,
    required GoogleSheetsService sheetsService,
    required TelegramService telegramService,
    required RssParserService rssService,  // ✅ PHẢI CÓ DÒNG NÀY
  })  : _storageService = storageService,
        _sheetsService = sheetsService,
        _telegramService = telegramService,
        _rssService = rssService;  // ✅ PHẢI CÓ DÒNG NÀY

  AppConfig _config = AppConfig.defaultConfig();
  bool _isLoading = false;
  String? _errorMessage;
  
  // ✅ THÊM: Trạng thái kết nối
  bool _isGoogleSheetsConnected = false;
  bool _isTelegramConnected = false;

  AppConfig get config => _config;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isGoogleSheetsConnected => _isGoogleSheetsConnected;  // ✅ ADD
  bool get isTelegramConnected => _isTelegramConnected;  // ✅ ADD

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
      await _storageService.saveConfig(newConfig);
      _config = newConfig;
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
    _isLoading = true;
    notifyListeners();

    try {
      await _sheetsService.initialize(_config.googleSheets);
      _isGoogleSheetsConnected = await _sheetsService.testConnection();
      
      if (!_isGoogleSheetsConnected) {
        _errorMessage = 'Không thể kết nối Google Sheets';
      }
      
      _isLoading = false;
      notifyListeners();
      return _isGoogleSheetsConnected;
    } catch (e) {
      _errorMessage = 'Lỗi kết nối Google Sheets: $e';
      _isGoogleSheetsConnected = false;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> testTelegramConnection() async {
    _isLoading = true;
    notifyListeners();

    try {
      _telegramService.initialize(_config.telegram);
      await _telegramService.sendMessage('✅ Test connection thành công!');
      
      _isTelegramConnected = true;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Lỗi gửi Telegram: $e';
      _isTelegramConnected = false;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
  
  // ✅ THÊM: Reset trạng thái kết nối
  void resetConnectionStatus() {
    _isGoogleSheetsConnected = false;
    _isTelegramConnected = false;
    notifyListeners();
  }

  // ✅ THÊM METHOD NÀY vào cuối class SettingsViewModel
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