// lib/presentation/navigation/main_navigation.dart

import 'package:flutter/material.dart';
import '../screens/home/home_screen.dart';
import '../screens/analysis/analysis_screen.dart';
import '../screens/betting/betting_screen.dart';
import '../screens/win_history/win_history_screen.dart';  // ✅ ADD
import '../screens/settings/settings_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({Key? key}) : super(key: key);

  @override
  State<MainNavigation> createState() => MainNavigationState();
}

class MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  // ✅ ADD: WinHistoryScreen
  final _screens = [
    const HomeScreen(),
    const AnalysisScreen(),
    const BettingScreen(),
    WinHistoryScreen(),  // ✅ ADD (no const because it uses Provider)
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Trang chủ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Phân tích',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.table_chart),
            label: 'Bảng cược',
          ),
          // ✅ ADD
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Lịch sử',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Cài đặt',
          ),
        ],
      ),
    );
  }

  // ✅ ADD: Method to switch tab from outside
  void switchToTab(int index) {
    if (index >= 0 && index < _screens.length) {
      setState(() => _currentIndex = index);
    }
  }
}