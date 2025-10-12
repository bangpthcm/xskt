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

  // Load config and initialize services
  final config = await storageService.loadConfig();
  if (config != null) {
    try {
      await sheetsService.initialize(config.googleSheets);
      telegramService.initialize(config.telegram);
    } catch (e) {
      print('Error initializing services: $e');
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