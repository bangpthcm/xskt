// lib/presentation/navigation/main_navigation.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../screens/home/home_screen.dart';
import '../screens/analysis/analysis_screen.dart';
import '../screens/analysis/analysis_viewmodel.dart';
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

  final _screens = [
    const HomeScreen(),
    const AnalysisScreen(),
    const BettingScreen(),
    WinHistoryScreen(),
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
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Trang chủ',
          ),
          // ✅ THÊM: Badge cho tab Phân tích
          BottomNavigationBarItem(
            icon: Consumer<AnalysisViewModel>(
              builder: (context, viewModel, child) {
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.analytics),
                    if (viewModel.hasAnyAlert)
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            label: 'Phân tích',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.table_chart),
            label: 'Bảng cược',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Lịch sử',
          ),
          const BottomNavigationBarItem(
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