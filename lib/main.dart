// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'data/services/storage_service.dart';
import 'data/services/google_sheets_service.dart';
import 'data/services/analysis_service.dart';
import 'data/services/betting_table_service.dart';
import 'data/services/telegram_service.dart';
import 'core/theme/theme_provider.dart';
import 'data/services/cached_data_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize services
  final storageService = StorageService();
  final sheetsService = GoogleSheetsService();
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
        Provider.value(value: analysisService),
        Provider.value(value: bettingService),
        Provider.value(value: telegramService),
        Provider.value(value: cachedDataService),
      ],
      child: const MyApp(),
    ),
  );
}