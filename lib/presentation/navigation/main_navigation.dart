// lib/presentation/navigation/main_navigation.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../screens/betting/betting_screen.dart';
import '../screens/analysis/analysis_screen.dart';
import '../screens/analysis/analysis_viewmodel.dart';
import '../screens/win_history/win_summary_screen.dart';
import '../screens/settings/settings_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => MainNavigationState();
}

class MainNavigationState extends State<MainNavigation>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: 1, // ✅ MỞ APP VÀO BẢNG CƯỢC (index 0)
    );
    _tabController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: TabBarView(
        controller: _tabController,
        physics: const BouncingScrollPhysics(),
        children: const [
          AnalysisScreen(),     // ✅ Index 0: Phân tích
          BettingScreen(),      // ✅ Index 1: Bảng cược
          WinSummaryScreen(),   // ✅ Index 2: Kết quả
          SettingsScreen(),     // ✅ Index 3: Cài đặt
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabController.index,
        onTap: (index) {
          _tabController.animateTo(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
          );
        },
        type: BottomNavigationBarType.fixed,
        items: [
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
            icon: Icon(Icons.assessment),
            label: 'Kết quả',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Cài đặt',
          ),
        ],
      ),
    );
  }

  void switchToTab(int index) {
    if (index >= 0 && index < 4) {
      _tabController.animateTo(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
      );
    }
  }
}