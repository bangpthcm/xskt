import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
// Import các service của bạn
import 'core/theme/theme_provider.dart';
import 'data/services/storage_service.dart';
import 'data/services/google_sheets_service.dart';
import 'data/services/analysis_service.dart';
import 'data/services/betting_table_service.dart';
import 'data/services/telegram_service.dart';
import 'data/services/cached_data_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Không gọi await ServiceManager.waitForReady() ở đây nữa!

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        
        // Dùng create: (_) => Service() để kích hoạt Lazy Loading
        Provider(create: (_) => StorageService()),
        Provider(create: (_) => GoogleSheetsService()),
        Provider(create: (_) => AnalysisService()),
        Provider(create: (_) => BettingTableService()),
        Provider(create: (_) => TelegramService()),

        // CachedDataService phụ thuộc vào GoogleSheetsService, dùng ProxyProvider
        ProxyProvider<GoogleSheetsService, CachedDataService>(
          update: (_, sheetsService, __) => CachedDataService(sheetsService: sheetsService),
        ),
      ],
      child: const MyApp(),
    ),
  );
}