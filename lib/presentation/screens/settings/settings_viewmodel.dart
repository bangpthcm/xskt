// lib/presentation/screens/settings/settings_viewmodel.dart
import 'package:flutter/material.dart';

import '../../../data/models/api_account.dart';
import '../../../data/models/app_config.dart';
import '../../../data/services/betting_api_service.dart';
import '../../../data/services/google_sheets_service.dart';
import '../../../data/services/storage_service.dart';
import '../../../data/services/telegram_service.dart';

class SettingsViewModel extends ChangeNotifier {
  final StorageService _storageService;
  final GoogleSheetsService _sheetsService;
  final TelegramService _telegramService;

  SettingsViewModel({
    required StorageService storageService,
    required GoogleSheetsService sheetsService,
    required TelegramService telegramService,
  })  : _storageService = storageService,
        _sheetsService = sheetsService,
        _telegramService = telegramService;

  AppConfig _config = AppConfig.defaultConfig();
  bool _isLoading = false;
  String? _errorMessage;

  final List<bool?> _apiAccountStatus = [null, null, null];

  AppConfig get config => _config;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<bool?> get apiAccountStatus => _apiAccountStatus;

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

      await _sheetsService.initialize(newConfig.googleSheets);
      _telegramService.initialize(newConfig.telegram);

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

  Future<void> testAllApiAccounts(
      List<ApiAccount> accounts, String domain) async {
    for (int i = 0; i < 3; i++) {
      _apiAccountStatus[i] = null;
    }
    notifyListeners();

    for (int i = 0; i < accounts.length && i < 3; i++) {
      final account = accounts[i];
      if (account.username.isEmpty || account.password.isEmpty) {
        _apiAccountStatus[i] = null;
        continue;
      }

      try {
        final apiService = BettingApiService();
        final token = await apiService.authenticateAndGetToken(account, domain);
        _apiAccountStatus[i] = (token != null && token.isNotEmpty);
        apiService.clearCache();
      } catch (e) {
        _apiAccountStatus[i] = false;
      }

      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
