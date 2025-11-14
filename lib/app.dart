// lib/app.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';

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
import 'data/services/cached_data_service.dart';

// ✅ ADD: Import ServiceManager
import 'data/services/service_manager.dart';

// ViewModels
import 'presentation/screens/home/home_viewmodel.dart';
import 'presentation/screens/analysis/analysis_viewmodel.dart';
import 'presentation/screens/betting/betting_viewmodel.dart';
import 'presentation/screens/settings/settings_viewmodel.dart';
import 'presentation/screens/win_history/win_history_viewmodel.dart';

// Screens
import 'presentation/navigation/main_navigation.dart';
import 'core/theme/theme_provider.dart';

// ✅ Global key for navigation
final GlobalKey<MainNavigationState> mainNavigationKey = GlobalKey<MainNavigationState>();

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // ✅ REMOVE: Local _servicesInitialized flag (dùng ServiceManager thay thế)
  
  @override
  void initState() {
    super.initState();
    
    // ✅ OPTIMIZATION: Initialize services AFTER first frame
    // Không block UI rendering
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeServicesInBackground();
    });
  }

  /// ✅ OPTIMIZATION: Background initialization (không block UI)
  Future<void> _initializeServicesInBackground() async {
    // Không await, không block
    unawaited(_initServices());
  }

  /// ✅ Initialize services với error handling
  Future<void> _initServices() async {
    try {
      print('🔄 Background: Starting service initialization...');
      
      final storageService = context.read<StorageService>();
      final sheetsService = context.read<GoogleSheetsService>();
      final telegramService = context.read<TelegramService>();
      
      // ✅ STEP 1: Load config (fast - from SharedPreferences)
      var config = await storageService.loadConfig();
      
      if (config == null) {
        print('⚠️ Background: No config found, using default');
        config = AppConfig.defaultConfig();
        await storageService.saveConfig(config);
      }
      
      // ✅ STEP 2: Initialize services in parallel (fast)
      print('🔄 Background: Initializing services in parallel...');
      await Future.wait([
        sheetsService.initialize(config!.googleSheets),
        Future(() => telegramService.initialize(config!.telegram)),
      ], eagerError: false);
      
      // ✅ CHANGE: Use ServiceManager
      ServiceManager.markReady();
      print('✅ Background: Core services initialized');
      
      // ✅ THÊM: Warm up cache
      unawaited(_warmUpCache());
      
    } catch (e) {
      print('⚠️ Background: Error initializing services: $e');
      ServiceManager.markNotReady();
    }
  }

  /// ✅ Test connections sau khi init (non-blocking)
  Future<void> _testConnections(
    GoogleSheetsService sheetsService,
    TelegramService telegramService,
  ) async {
    try {
      print('🔄 Background: Testing connections...');
      
      final results = await Future.wait([
        sheetsService.testConnection(),
        telegramService.testConnection(),
      ], eagerError: false);
      
      print('✅ Background: Connection test complete');
      print('   - Google Sheets: ${results[0] ? "✓" : "✗"}');
      print('   - Telegram: ${results[1] ? "✓" : "✗"}');
      
    } catch (e) {
      print('⚠️ Background: Error testing connections: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Lấy services từ Provider
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

    final backfillService = BackfillService(
      sheetsService: googleSheetsService,
      rssService: rssService,
    );

    final autoCheckService = AutoCheckService(
      winCalcService: winCalcService,
      trackingService: winTrackingService,
      sheetsService: googleSheetsService,
      telegramService: telegramService,
      backfillService: backfillService,
    );

    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => HomeViewModel(),
            ),
            ChangeNotifierProvider(
              create: (_) {
                final cachedService = context.read<CachedDataService>();
                
                return AnalysisViewModel(
                  cachedDataService: cachedService,
                  sheetsService: googleSheetsService,
                  analysisService: analysisService,
                  storageService: storageService,
                  telegramService: telegramService,
                  bettingService: bettingService,
                  rssService: rssService,
                );
              },
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
            ChangeNotifierProvider(
              create: (_) => WinHistoryViewModel(
                trackingService: winTrackingService,
                autoCheckService: autoCheckService,
              ),
            ),
          ],
          child: MaterialApp(
            title: 'XSKT Bot',
            theme: themeProvider.getLightTheme(),
            darkTheme: themeProvider.getDarkTheme(),
            themeMode: themeProvider.themeMode,
            home: MainNavigation(key: mainNavigationKey),
            debugShowCheckedModeBanner: false,
          ),
        );
      },
    );
  }
  
  Future<void> _warmUpCache() async {
    print('🔥 Warming up cache...');
    
    try {
      final cachedService = context.read<CachedDataService>();
      
      // Preload minimal data
      await cachedService.loadKQXS(
        forceRefresh: false,
        minimalMode: true,
      );
      
      print('✅ Cache warmed up');
    } catch (e) {
      print('⚠️ Cache warming error: $e');
    }
  }
}