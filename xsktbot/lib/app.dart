// lib/app.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Services
import 'data/services/google_sheets_service.dart';
import 'data/services/analysis_service.dart';
import 'data/services/storage_service.dart';
import 'data/services/telegram_service.dart';
import 'data/services/betting_table_service.dart';
import 'data/services/rss_parser_service.dart';
import 'data/services/backfill_service.dart';
import 'data/services/win_calculation_service.dart';
import 'data/services/win_tracking_service.dart';
import 'data/services/auto_check_service.dart';
import 'data/models/app_config.dart';

// ViewModels
import 'presentation/screens/home/home_viewmodel.dart';
import 'presentation/screens/analysis/analysis_viewmodel.dart';
import 'presentation/screens/betting/betting_viewmodel.dart';
import 'presentation/screens/settings/settings_viewmodel.dart';
import 'presentation/screens/win_history/win_history_viewmodel.dart';

// Screens
import 'presentation/navigation/main_navigation.dart';

// ✅ Global key for navigation
final GlobalKey<MainNavigationState> mainNavigationKey = GlobalKey<MainNavigationState>();

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    
    // ✅ Auto-initialize khi app khởi động
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        print('📱 MyApp: Post-frame callback executing...');
        
        // Get services từ context
        final storageService = context.read<StorageService>();
        final sheetsService = context.read<GoogleSheetsService>();
        final telegramService = context.read<TelegramService>();
        
        // Load config
        var config = await storageService.loadConfig();
        
        if (config == null) {
          print('⚠️ MyApp: No config found, using default');
          config = AppConfig.defaultConfig();
          await storageService.saveConfig(config);
        }
        
        // Reinitialize services (đảm bảo kết nối được thiết lập)
        print('🔄 MyApp: Reinitializing services...');
        await sheetsService.initialize(config.googleSheets);
        telegramService.initialize(config.telegram);
        
        // Test connections
        final sheetsOk = await sheetsService.testConnection();
        final telegramOk = await telegramService.testConnection();
        
        print('✅ MyApp: Services initialized');
        print('   - Google Sheets: ${sheetsOk ? "✓" : "✗"}');
        print('   - Telegram: ${telegramOk ? "✓" : "✗"}');
        
      } catch (e) {
        print('⚠️ MyApp: Error initializing on startup: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Lấy services từ Provider (đã được khởi tạo trong main.dart)
    final googleSheetsService = context.read<GoogleSheetsService>();
    final analysisService = context.read<AnalysisService>();
    final storageService = context.read<StorageService>();
    final telegramService = context.read<TelegramService>();
    final bettingService = context.read<BettingTableService>();
    final rssService = context.read<RssParserService>();
    
    // ✅ Khởi tạo các services mới
    final winCalcService = WinCalculationService();
    final winTrackingService = WinTrackingService(
      sheetsService: googleSheetsService,
    );

    // ✅ Thêm BackfillService
    final backfillService = BackfillService(
      sheetsService: googleSheetsService,
      rssService: rssService,
    );

    final autoCheckService = AutoCheckService(
      winCalcService: winCalcService,
      trackingService: winTrackingService,
      sheetsService: googleSheetsService,
      telegramService: telegramService,
      backfillService: backfillService,  // ✅ THÊM
    );

    return MultiProvider(
      providers: [
        // Existing providers
        ChangeNotifierProvider(
          create: (_) => HomeViewModel(),
        ),
        ChangeNotifierProvider(
          create: (_) => AnalysisViewModel(
            sheetsService: googleSheetsService,
            analysisService: analysisService,
            storageService: storageService,
            telegramService: telegramService,
            bettingService: bettingService,
            rssService: rssService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => BettingViewModel(
            sheetsService: googleSheetsService,
            bettingService: bettingService,
            telegramService: telegramService,
            analysisService: analysisService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => SettingsViewModel(
            storageService: storageService,
            sheetsService: googleSheetsService,
            telegramService: telegramService,
            rssService: rssService,
          ),
        ),
        
        // ✅ Provider cho win history
        ChangeNotifierProvider(
          create: (_) => WinHistoryViewModel(
            trackingService: winTrackingService,
            autoCheckService: autoCheckService,
          ),
        ),
      ],
      child: MaterialApp(
        title: 'XSKT Bot',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        home: MainNavigation(key: mainNavigationKey),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}