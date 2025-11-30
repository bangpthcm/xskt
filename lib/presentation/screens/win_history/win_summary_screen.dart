// lib/presentation/screens/win_history/win_summary_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'win_history_viewmodel.dart';
import 'win_history_screen.dart';
import '../../../core/utils/number_utils.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/profit_chart.dart';
import '../../../core/theme/theme_provider.dart';

class WinSummaryScreen extends StatefulWidget {
  const WinSummaryScreen({super.key});

  @override
  State<WinSummaryScreen> createState() => _WinSummaryScreenState();
}

class _WinSummaryScreenState extends State<WinSummaryScreen> {
  // ✅ 2. Biến trạng thái để ẩn/hiện chi tiết
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WinHistoryViewModel>().loadHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Consumer<WinHistoryViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.isLoading) {
            return const ShimmerLoading(type: ShimmerType.stats);
          }

          if (viewModel.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    viewModel.errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      viewModel.clearError();
                      viewModel.loadHistory();
                    },
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => viewModel.loadHistory(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 45, 16, 16),
              children: [
                ProfitChart(data: viewModel.getProfitByMonth()),
                const SizedBox(height: 16),
                
                // ✅ Card Tổng hợp (Tương tác để mở rộng)
                _buildCombinedCard(viewModel),
                
                const SizedBox(height: 16),
                
                // ✅ Chỉ hiện các card dưới khi _isExpanded = true
                if (_isExpanded) ...[
                  _buildCycleCard(viewModel),
                  const SizedBox(height: 16),
                  _buildXienCard(viewModel),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  // ✅ 1 & 2. Card Tổng hợp có chức năng Expand
  Widget _buildCombinedCard(WinHistoryViewModel viewModel) {
    final stats = viewModel.getCombinedStats();

    return Card(
      color: const Color(0xFF1E1E1E),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          // Toggle trạng thái mở rộng
          setState(() {
            _isExpanded = !_isExpanded;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'TỔNG HỢP TẤT CẢ',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: ThemeProvider.accent,
                      ),
                    ),
                  ),
                  // Icon chỉ thị trạng thái mở/đóng
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: ThemeProvider.accent,
                  ),
                ],
              ),
              const Divider(height: 24, color: Colors.grey),
              _buildStatsGrid(stats),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ 3. Card Chu kỳ (Bỏ nút Xem chi tiết, thêm onTap cho sub-section)
  Widget _buildCycleCard(WinHistoryViewModel viewModel) {
    final allCycleStats = viewModel.getAllCycleStats();
    final trungStats = viewModel.getTrungStats();
    final bacStats = viewModel.getBacStats();

    return Card(
      color: const Color(0xFF1E1E1E),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'CHU KỲ 00-99',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 24, color: Colors.grey),
            
            // Phần 1: Tất cả -> Tab 0 (Ba miền)
            _buildCycleSubSection(
              iconColor: ThemeProvider.accent,
              title: 'TẤT CẢ',
              stats: allCycleStats,
              onTap: () => _navigateToDetail(0), // Tab Ba miền
            ),
            const SizedBox(height: 12),
            
            // Phần 2: Miền Trung -> Tab 1
            _buildCycleSubSection(
              iconColor: ThemeProvider.accent,
              title: 'MIỀN TRUNG',
              stats: trungStats,
              onTap: () => _navigateToDetail(1), // Tab Trung
            ),
            const SizedBox(height: 12),
            
            // Phần 3: Miền Bắc -> Tab 2
            _buildCycleSubSection(
              iconColor: ThemeProvider.accent,
              title: 'MIỀN BẮC',
              stats: bacStats,
              onTap: () => _navigateToDetail(2), // Tab Bắc
            ),
          ],
        ),
      ),
    );
  }

  // ✅ 3. Card Xiên (Bỏ nút header, tap vào nội dung -> Tab Xiên)
  Widget _buildXienCard(WinHistoryViewModel viewModel) {
    final stats = viewModel.getXienStats();

    return Card(
      color: const Color(0xFF1E1E1E),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _navigateToDetail(3), // Tab Xiên
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Expanded(
                    child: Text(
                      'CẶP XIÊN BẮC',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: ThemeProvider.accent,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right, color: ThemeProvider.accent),
                ],
              ),
              const Divider(height: 24, color: Colors.grey),
              _buildStatsGrid(stats),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ Widget phần con trong Chu kỳ (Thêm InkWell để bấm)
  Widget _buildCycleSubSection({
    IconData? icon,
    String? textIcon,
    required Color iconColor,
    required String title,
    required WinStats stats,
    required VoidCallback onTap, // Thêm callback
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: iconColor.withOpacity(0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
              ],
            ),
            const SizedBox(height: 12),
            _buildStatsGrid(stats),
          ],
        ),
      ),
    );
  }

  // ✅ 1. Grid hiển thị (Thay đổi ROI -> Tiền lớn nhất)
  Widget _buildStatsGrid(WinStats stats) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatItem(
                label: '✓ Trúng',
                value: stats.totalWins.toString(),
              ),
            ),
            Expanded(
              child: _buildStatItem(
                label: '💰 Lợi nhuận',
                value: NumberUtils.formatCurrency(stats.totalProfit),
                valueColor: stats.totalProfit > 0
                    ? ThemeProvider.profit
                    : Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              // Thay đổi: ROI TB -> Tiền lớn nhất
              child: _buildStatItem(
                label: '💎 Tổng vốn đã dùng', 
                value: NumberUtils.formatCurrency(stats.maxBet),
                valueColor: stats.maxBet > 0
                    ? ThemeProvider.loss
                    : Colors.white,
              ),
            ),
            Expanded(
              child: _buildStatItem(
                label: '📅 Lợi/tháng',
                value: NumberUtils.formatCurrency(stats.profitPerMonth),
                valueColor: stats.profitPerMonth > 0
                    ? ThemeProvider.profit
                    : Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade400,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: valueColor ?? Colors.white,
          ),
        ),
      ],
    );
  }

  void _navigateToDetail(int initialTab) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WinHistoryScreen(
          initialTab: initialTab,
        ),
      ),
    );
  }
}