// lib/app.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
// ... giữ nguyên các import service/viewmodels
import 'data/services/google_sheets_service.dart';
import 'data/services/analysis_service.dart';
import 'data/services/storage_service.dart';
import 'data/services/telegram_service.dart';
import 'data/services/betting_table_service.dart';
import 'data/services/rss_parser_service.dart';
import 'data/services/backfill_service.dart';
import 'data/services/win_tracking_service.dart';
import 'data/models/app_config.dart';
import 'data/services/cached_data_service.dart';
import 'data/services/service_manager.dart';

import 'presentation/screens/home/home_viewmodel.dart';
import 'presentation/screens/analysis/analysis_viewmodel.dart';
import 'presentation/screens/betting/betting_viewmodel.dart';
import 'presentation/screens/settings/settings_viewmodel.dart';
import 'presentation/screens/win_history/win_history_viewmodel.dart';

import 'presentation/navigation/main_navigation.dart';
import 'core/theme/theme_provider.dart';

final GlobalKey<MainNavigationState> mainNavigationKey = GlobalKey<MainNavigationState>();

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // ... (giữ nguyên logic initState, _initServices, _warmUpCache)
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeServicesInBackground();
    });
  }

  Future<void> _initializeServicesInBackground() async {
    unawaited(_initServices());
  }

  Future<void> _initServices() async {
    try {
      print('🔄 Background: Starting service initialization...');
      final storageService = context.read<StorageService>();
      final sheetsService = context.read<GoogleSheetsService>();
      final telegramService = context.read<TelegramService>();
      
      var config = await storageService.loadConfig();
      if (config == null) {
        config = AppConfig.defaultConfig();
        await storageService.saveConfig(config);
      }
      
      await Future.wait([
        sheetsService.initialize(config!.googleSheets),
        Future(() => telegramService.initialize(config!.telegram)),
      ]);
      
      ServiceManager.markReady();
      print('✅ Background: Core services initialized');
      
      unawaited(_warmUpCache());
    } catch (e) {
      print('⚠️ Background: Error initializing services: $e');
      ServiceManager.markNotReady();
    }
  }

  Future<void> _warmUpCache() async {
    try {
      if (!mounted) return;
      await context.read<CachedDataService>().loadKQXS(minimalMode: true);
    } catch (e) {
      print('⚠️ Cache warming error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MultiProvider(
          providers: [
            // ... (Giữ nguyên toàn bộ block providers như cũ)
            ProxyProvider<GoogleSheetsService, WinTrackingService>(
              update: (_, sheets, __) => WinTrackingService(sheetsService: sheets),
            ),
            
            ProxyProvider2<GoogleSheetsService, RssParserService, BackfillService>(
              update: (_, sheets, rss, __) => BackfillService(
                sheetsService: sheets,
                rssService: rss,
              ),
            ),

            ChangeNotifierProvider(create: (_) => HomeViewModel()),
            
            ChangeNotifierProxyProvider6<CachedDataService, GoogleSheetsService, AnalysisService, StorageService, TelegramService, BettingTableService, AnalysisViewModel>(
              create: (context) => AnalysisViewModel(
                  cachedDataService: context.read<CachedDataService>(),
                  sheetsService: context.read<GoogleSheetsService>(),
                  analysisService: context.read<AnalysisService>(),
                  storageService: context.read<StorageService>(),
                  telegramService: context.read<TelegramService>(),
                  bettingService: context.read<BettingTableService>(),
                  rssService: context.read<RssParserService>(),
              ),
              update: (context, cached, sheets, analysis, storage, telegram, betting, prev) => prev ?? AnalysisViewModel(
                  cachedDataService: cached,
                  sheetsService: sheets,
                  analysisService: analysis,
                  storageService: storage,
                  telegramService: telegram,
                  bettingService: betting,
                  rssService: context.read<RssParserService>(),
              ),
            ),

            ChangeNotifierProxyProvider2<GoogleSheetsService, TelegramService, BettingViewModel>(
              create: (context) => BettingViewModel(
                sheetsService: context.read<GoogleSheetsService>(),
                telegramService: context.read<TelegramService>(),
              ),
              update: (_, sheets, telegram, prev) => prev!,
            ),
            
            ChangeNotifierProxyProvider3<StorageService, GoogleSheetsService, TelegramService, SettingsViewModel>(
              create: (context) => SettingsViewModel(
                storageService: context.read<StorageService>(),
                sheetsService: context.read<GoogleSheetsService>(),
                telegramService: context.read<TelegramService>(),
                rssService: context.read<RssParserService>(),
              ),
               update: (_, storage, sheets, telegram, prev) => prev!,
            ),

            ChangeNotifierProxyProvider<WinTrackingService, WinHistoryViewModel>(
              create: (context) => WinHistoryViewModel(
                trackingService: context.read<WinTrackingService>(),
              ),
              update: (_, tracking, prev) => prev ?? WinHistoryViewModel(
                trackingService: tracking,
              ),
            ),
          ],
          child: MaterialApp(
            title: 'XSKT Bot',
            // ✅ CHỈ DÙNG 1 THEME
            theme: themeProvider.getTheme(),
            // ❌ Đã bỏ darkTheme và themeMode
            home: MainNavigation(key: mainNavigationKey),
            debugShowCheckedModeBanner: false,
          ),
        );
      },
    );
  }
}