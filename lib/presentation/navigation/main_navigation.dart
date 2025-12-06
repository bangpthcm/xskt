import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../screens/betting/betting_screen.dart';
import '../screens/analysis/analysis_screen.dart';
import '../screens/analysis/analysis_viewmodel.dart';
import '../screens/win_history/win_summary_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../../core/theme/theme_provider.dart'; // ✅ Import ThemeProvider

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
      if (mounted) setState(() {});
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
      // ✅ Sử dụng Custom Bottom Bar thay vì widget mặc định
      bottomNavigationBar: _buildCustomBottomBar(context),
    );
  }

  // ✅ Widget thanh điều hướng tùy chỉnh
  Widget _buildCustomBottomBar(BuildContext context) {
    // Tăng chiều cao để chứa dòng ghi chú (56 chuẩn + ~20 text)
    const double barHeight = 76.0;

    return Container(
      height: barHeight,
      decoration: const BoxDecoration(
        color: ThemeProvider.surface,
        border: Border(
          top: BorderSide(color: Color(0xFF2C2C2C), width: 1),
        ),
      ),
      child: Consumer<AnalysisViewModel>(
        builder: (context, viewModel, child) {
          return Stack(
            children: [
              // 1. Dòng ghi chú (Nằm ở layer dưới cùng hoặc trên cùng đều được, 
              // nhưng InkWell ở layer trên sẽ phủ lên để nhận gợn sóng)
              Positioned(
                top: 6,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    viewModel.latestDataInfo,
                    style: TextStyle(
                      fontSize: 11,
                      color: ThemeProvider.textSecondary.withOpacity(0.7),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),

              // 2. Các nút điều hướng (Row chứa các InkWell full chiều cao)
              Row(
                children: [
                  _buildNavItem(0, Icons.analytics, 'Phân tích', viewModel),
                  _buildNavItem(1, Icons.table_chart, 'Bảng cược', viewModel),
                  _buildNavItem(2, Icons.assessment, 'Kết quả', viewModel),
                  _buildNavItem(3, Icons.settings, 'Cài đặt', viewModel),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, AnalysisViewModel vm) {
    final isSelected = _tabController.index == index;
    // Màu active là Accent (Vàng), inactive là TextSecondary (Xám)
    final color = isSelected ? ThemeProvider.accent : ThemeProvider.textSecondary;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => switchToTab(index),
          // ✅ InkWell bao trùm toàn bộ chiều cao cột, ripple sẽ lan lên cả vùng text
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Spacer đẩy icon xuống dưới, chừa chỗ cho text ở trên
              const SizedBox(height: 20), 
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, color: color, size: 24),
                  // Dấu chấm đỏ báo hiệu (chỉ cho tab Phân tích)
                  if (index == 0 && vm.hasAnyAlert)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: ThemeProvider.loss, 
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              const SizedBox(height: 8), // Padding dưới cùng
            ],
          ),
        ),
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