// lib/app.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'presentation/screens/home/home_screen.dart';
import 'presentation/screens/home/home_viewmodel.dart';
import 'presentation/screens/analysis/analysis_screen.dart';
import 'presentation/screens/analysis/analysis_viewmodel.dart';
import 'presentation/screens/betting/betting_screen.dart';
import 'presentation/screens/betting/betting_viewmodel.dart';
import 'presentation/screens/settings/settings_screen.dart';
import 'presentation/screens/settings/settings_viewmodel.dart';
import 'data/services/storage_service.dart';
import 'data/services/google_sheets_service.dart';
import 'data/services/analysis_service.dart';
import 'data/services/betting_table_service.dart';
import 'data/services/telegram_service.dart';

// ✅ QUAN TRỌNG: Phải có dòng này
final GlobalKey<_MainNavigationScreenState> mainNavigationKey = 
    GlobalKey<_MainNavigationScreenState>();

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => HomeViewModel()),
        ChangeNotifierProvider(
          create: (context) => AnalysisViewModel(
            sheetsService: context.read<GoogleSheetsService>(),
            analysisService: context.read<AnalysisService>(),
            storageService: context.read<StorageService>(),
            telegramService: context.read<TelegramService>(),
            bettingService: context.read<BettingTableService>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => BettingViewModel(
            sheetsService: context.read<GoogleSheetsService>(),
            bettingService: context.read<BettingTableService>(),
            telegramService: context.read<TelegramService>(),
            analysisService: context.read<AnalysisService>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => SettingsViewModel(
            storageService: context.read<StorageService>(),
            sheetsService: context.read<GoogleSheetsService>(),
            telegramService: context.read<TelegramService>(),
          ),
        ),
      ],
      child: MaterialApp(
        title: 'XS Kiến Thiết',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 2,
          ),
          cardTheme: CardThemeData(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        home: MainNavigationScreen(key: mainNavigationKey),  // ✅ Dùng key
      ),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({Key? key}) : super(key: key);

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    AnalysisScreen(),
    BettingScreen(),
    SettingsScreen(),
  ];

  void switchToTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          switchToTab(index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Trang chủ',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics),
            label: 'Phân tích',
          ),
          NavigationDestination(
            icon: Icon(Icons.table_chart_outlined),
            selectedIcon: Icon(Icons.table_chart),
            label: 'Bảng cược',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Cài đặt',
          ),
        ],
      ),
    );
  }
}