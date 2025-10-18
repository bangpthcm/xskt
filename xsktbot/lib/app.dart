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
import 'data/services/win_calculation_service.dart';  // ✅ ADD
import 'data/services/win_tracking_service.dart';      // ✅ ADD
import 'data/services/auto_check_service.dart';        // ✅ ADD

// ViewModels
import 'presentation/screens/home/home_viewmodel.dart';
import 'presentation/screens/analysis/analysis_viewmodel.dart';
import 'presentation/screens/betting/betting_viewmodel.dart';
import 'presentation/screens/settings/settings_viewmodel.dart';
import 'presentation/screens/win_history/win_history_viewmodel.dart';  // ✅ ADD

// Screens
import 'presentation/navigation/main_navigation.dart';

// ✅ ADD: Global key for navigation
final GlobalKey<MainNavigationState> mainNavigationKey = GlobalKey<MainNavigationState>();

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // ✅ Initialize all services
    final googleSheetsService = GoogleSheetsService();
    final analysisService = AnalysisService();
    final storageService = StorageService();
    final telegramService = TelegramService();
    final bettingService = BettingTableService();
    final rssService = RssParserService();
    
    // ✅ ADD: Initialize new services
    final winCalcService = WinCalculationService();
    final winTrackingService = WinTrackingService(
      sheetsService: googleSheetsService,
    );
    final autoCheckService = AutoCheckService(
      winCalcService: winCalcService,
      trackingService: winTrackingService,
      sheetsService: googleSheetsService,
      telegramService: telegramService,
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
        
        // ✅ ADD: New provider for win history
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
        home: MainNavigation(key: mainNavigationKey),  // ✅ ADD key
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}