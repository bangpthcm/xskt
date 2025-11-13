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
import 'core/theme/theme_provider.dart';
import 'data/services/cached_data_service.dart';

// lib/main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize services
  final storageService = StorageService();
  final sheetsService = GoogleSheetsService();
  final rssService = RssParserService();
  final analysisService = AnalysisService();
  final bettingService = BettingTableService();
  final telegramService = TelegramService();
  final themeProvider = ThemeProvider();
  final cachedDataService = CachedDataService(
    sheetsService: sheetsService,
  );

  // ✅ KHÔNG INITIALIZE GÌ CẢ - ĐỂ CHO LAZY LOADING
  print('🚀 Starting app (lazy initialization mode)...');
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        Provider.value(value: storageService),
        Provider.value(value: sheetsService),
        Provider.value(value: rssService),
        Provider.value(value: analysisService),
        Provider.value(value: bettingService),
        Provider.value(value: telegramService),
        Provider.value(value: cachedDataService),
      ],
      child: const MyApp(),
    ),
  );
}