// lib/app.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/theme_provider.dart';
import 'data/models/app_config.dart';
import 'data/services/analysis_service.dart';
import 'data/services/betting_table_service.dart';
import 'data/services/cached_data_service.dart';
import 'data/services/google_sheets_service.dart';
import 'data/services/storage_service.dart';
import 'data/services/telegram_service.dart';
import 'data/services/win_tracking_service.dart';
import 'presentation/navigation/main_navigation.dart';
import 'presentation/screens/analysis/analysis_viewmodel.dart';
import 'presentation/screens/betting/betting_viewmodel.dart';
import 'presentation/screens/home/home_viewmodel.dart';
import 'presentation/screens/settings/settings_viewmodel.dart';
import 'presentation/screens/win_history/win_history_viewmodel.dart';

final GlobalKey<MainNavigationState> mainNavigationKey =
    GlobalKey<MainNavigationState>();

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // Vẫn gọi khởi tạo nền nhưng không bắt UI phải chờ
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initServices();
    });
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

      // Khởi tạo các service quan trọng
      await Future.wait([
        sheetsService.initialize(config.googleSheets),
        Future(() => telegramService.initialize(config!.telegram)),
      ]);

      print('✅ Background: Core services initialized');

      // Cache warm-up (chạy ngầm)
      _warmUpCache();
    } catch (e) {
      print('⚠️ Background: Error initializing services: $e');
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
            ProxyProvider<GoogleSheetsService, WinTrackingService>(
              update: (_, sheets, __) =>
                  WinTrackingService(sheetsService: sheets),
            ),
            ChangeNotifierProvider(create: (_) => HomeViewModel()),
            ChangeNotifierProxyProvider6<
                CachedDataService,
                GoogleSheetsService,
                AnalysisService,
                StorageService,
                TelegramService,
                BettingTableService,
                AnalysisViewModel>(
              create: (context) => AnalysisViewModel(
                cachedDataService: context.read<CachedDataService>(),
                sheetsService: context.read<GoogleSheetsService>(),
                storageService: context.read<StorageService>(),
                telegramService: context.read<TelegramService>(),
                bettingService: context.read<BettingTableService>(),
              ),
              update: (context, cached, sheets, analysis, storage, telegram,
                      betting, prev) =>
                  prev ??
                  AnalysisViewModel(
                    cachedDataService: cached,
                    sheetsService: sheets,
                    storageService: storage,
                    telegramService: telegram,
                    bettingService: betting,
                  ),
            ),
            ChangeNotifierProxyProvider2<GoogleSheetsService, TelegramService,
                BettingViewModel>(
              create: (context) => BettingViewModel(
                sheetsService: context.read<GoogleSheetsService>(),
                telegramService: context.read<TelegramService>(),
              ),
              update: (_, sheets, telegram, prev) => prev!,
            ),
            ChangeNotifierProxyProvider3<StorageService, GoogleSheetsService,
                TelegramService, SettingsViewModel>(
              create: (context) => SettingsViewModel(
                storageService: context.read<StorageService>(),
                sheetsService: context.read<GoogleSheetsService>(),
                telegramService: context.read<TelegramService>(),
              ),
              update: (_, storage, sheets, telegram, prev) => prev!,
            ),
            ChangeNotifierProxyProvider<WinTrackingService,
                WinHistoryViewModel>(
              create: (context) => WinHistoryViewModel(
                trackingService: context.read<WinTrackingService>(),
              ),
              update: (_, tracking, prev) =>
                  prev ??
                  WinHistoryViewModel(
                    trackingService: tracking,
                  ),
            ),
          ],
          child: MaterialApp(
            title: 'XSKT Bot',
            theme: themeProvider.getTheme(),
            home: MainNavigation(key: mainNavigationKey),
            debugShowCheckedModeBanner: false,
          ),
        );
      },
    );
  }
}
