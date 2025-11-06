// lib/presentation/navigation/main_navigation.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../screens/betting/betting_screen.dart';
import '../screens/analysis/analysis_screen.dart';
import '../screens/analysis/analysis_viewmodel.dart';
import '../screens/home/home_screen.dart';
import '../screens/win_history/win_history_screen.dart';
import '../screens/settings/settings_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({Key? key}) : super(key: key);

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
      length: 5,
      vsync: this,
      initialIndex: 0, // ✅ MỞ APP VÀO BẢNG CƯỢC (index 0)
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
          BettingScreen(),      // ✅ Index 0: Bảng cược
          AnalysisScreen(),     // ✅ Index 1: Phân tích
          HomeScreen(),         // ✅ Index 2: Live (Trang chủ)
          WinHistoryScreen(),   // ✅ Index 3: Lịch sử
          SettingsScreen(),     // ✅ Index 4: Cài đặt
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabController.index,
        onTap: (index) {
          // ✅ NẾU CLICK VÀO LIVE, MỞ FULL-SCREEN WEBVIEW
          if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const HomeScreen(),
              ),
            );
            return;
          }
          
          _tabController.animateTo(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
          );
        },
        type: BottomNavigationBarType.fixed,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.table_chart),
            label: 'Bảng cược',
          ),
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
          // ✅ LIVE Ở GIỮA
          const BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Live',
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

  void switchToTab(int index) {
    if (index >= 0 && index < 5) {
      _tabController.animateTo(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
      );
    }
  }
}