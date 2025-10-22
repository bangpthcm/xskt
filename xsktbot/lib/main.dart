// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'app.dart';
import 'data/services/storage_service.dart';
import 'data/services/google_sheets_service.dart';
import 'data/services/rss_parser_service.dart';
import 'data/services/analysis_service.dart';
import 'data/services/betting_table_service.dart';
import 'data/services/telegram_service.dart';
import 'data/models/app_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // ✅ Khởi tạo WebView Platform
  //if (WebViewPlatform.instance == null) {
  //  WebViewPlatform.instance = AndroidWebViewController.platform;
  //}
  
  // Initialize services
  final storageService = StorageService();
  final sheetsService = GoogleSheetsService();
  final rssService = RssParserService();
  final analysisService = AnalysisService();
  final bettingService = BettingTableService();
  final telegramService = TelegramService();

  // ✅ Load config và khởi tạo services TỰ ĐỘNG
  try {
    print('🚀 Starting app initialization...');
    
    // Load config từ storage
    var config = await storageService.loadConfig();
    
    // ✅ Nếu chưa có config, tạo default config
    if (config == null) {
      print('⚠️ No config found, creating default config...');
      config = AppConfig.defaultConfig();
      await storageService.saveConfig(config);
      print('✅ Default config saved');
    } else {
      print('✅ Config loaded from storage');
    }
    
    // ✅ Khởi tạo Google Sheets
    print('🔄 Initializing Google Sheets...');
    await sheetsService.initialize(config.googleSheets);
    final isConnected = await sheetsService.testConnection();
    
    if (isConnected) {
      print('✅ Google Sheets connected successfully');
    } else {
      print('❌ Google Sheets connection failed');
    }
    
    // ✅ Khởi tạo và test Telegram
    print('🔄 Initializing Telegram...');
    telegramService.initialize(config.telegram);
    final isTelegramConnected = await telegramService.testConnection();

    if (isTelegramConnected) {
      print('✅ Telegram connected successfully');
    } else {
      print('⚠️ Telegram connection failed (check bot token)');
    }
    
    print('✅ App initialization completed');
    
  } catch (e) {
    print('❌ Error initializing services: $e');
    // ✅ Nếu lỗi, vẫn chạy app nhưng với default config
    final defaultConfig = AppConfig.defaultConfig();
    try {
      await sheetsService.initialize(defaultConfig.googleSheets);
      telegramService.initialize(defaultConfig.telegram);
      print('⚠️ Using default config due to initialization error');
    } catch (e2) {
      print('❌ Failed to initialize with default config: $e2');
    }
  }

  runApp(
    MultiProvider(
      providers: [
        Provider.value(value: storageService),
        Provider.value(value: sheetsService),
        Provider.value(value: rssService),
        Provider.value(value: analysisService),
        Provider.value(value: bettingService),
        Provider.value(value: telegramService),
      ],
      child: const MyApp(),
    ),
  );
}