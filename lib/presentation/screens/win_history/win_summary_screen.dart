// lib/presentation/screens/win_history/win_summary_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'win_history_viewmodel.dart';
import 'win_history_screen.dart';
import '../../../core/utils/number_utils.dart';

class WinSummaryScreen extends StatefulWidget {
  const WinSummaryScreen({Key? key}) : super(key: key);

  @override
  State<WinSummaryScreen> createState() => _WinSummaryScreenState();
}

class _WinSummaryScreenState extends State<WinSummaryScreen> {
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
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Tổng quan trúng số'),
      ),
      body: Consumer<WinHistoryViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.isLoading) {
            return const Center(child: CircularProgressIndicator());
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
              padding: const EdgeInsets.all(16),
              children: [
                _buildCombinedCard(viewModel),
                const SizedBox(height: 16),
                _buildCycleCard(viewModel),
                const SizedBox(height: 16),
                _buildXienCard(viewModel),
              ],
            ),
          );
        },
      ),
    );
  }

  // ✅ 1. Card Tổng hợp
  Widget _buildCombinedCard(WinHistoryViewModel viewModel) {
    final stats = viewModel.getCombinedStats();

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
            Row(
              children: [
                const Text(
                  '📊',
                  style: TextStyle(fontSize: 22),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'TỔNG HỢP TẤT CẢ',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _navigateToDetail(0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Xem chi tiết',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 14,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: Colors.grey.shade400,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24, color: Colors.grey),
            _buildStatsGrid(stats),
          ],
        ),
      ),
    );
  }

  // ✅ 2. Card Chu kỳ (3 phần con)
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
            Row(
              children: [
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: Center(
                    child: Text(
                      'C',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFEE5A5A),
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'CHU KỲ 00-99',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _navigateToDetail(0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Xem chi tiết',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 14,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: Colors.grey.shade400,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24, color: Colors.grey),
            
            // Phần 1: Tất cả
            _buildCycleSubSection(
              icon: Icons.select_all,
              iconColor: const Color(0xFF5A9BD5),
              title: 'TẤT CẢ',
              stats: allCycleStats,
            ),
            const SizedBox(height: 12),
            
            // Phần 2: Miền Trung
            _buildCycleSubSection(
              textIcon: 'T',
              iconColor: const Color(0xFFB6771D),
              title: 'MIỀN TRUNG',
              stats: trungStats,
            ),
            const SizedBox(height: 12),
            
            // Phần 3: Miền Bắc
            _buildCycleSubSection(
              textIcon: 'B',
              iconColor: const Color(0xFF4CAF50),
              title: 'MIỀN BẮC',
              stats: bacStats,
            ),
          ],
        ),
      ),
    );
  }

  // ✅ 3. Card Xiên
  Widget _buildXienCard(WinHistoryViewModel viewModel) {
    final stats = viewModel.getXienStats();

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
            Row(
              children: [
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: Center(
                    child: Text(
                      'X',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF45B7B7),
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'CẶP XIÊN BẮC',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _navigateToDetail(3),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Xem chi tiết',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 14,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: Colors.grey.shade400,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24, color: Colors.grey),
            _buildStatsGrid(stats),
          ],
        ),
      ),
    );
  }

  // ✅ Widget phần con trong Chu kỳ
  Widget _buildCycleSubSection({
    IconData? icon,
    String? textIcon,
    required Color iconColor,
    required String title,
    required WinStats stats,
  }) {
    return Container(
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
              if (textIcon != null)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: Center(
                    child: Text(
                      textIcon,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: iconColor,
                        height: 1.0,
                      ),
                    ),
                  ),
                )
              else if (icon != null)
                Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildStatsGrid(stats),
        ],
      ),
    );
  }

  // ✅ Grid 2x2 hiển thị 4 chỉ số
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
                    ? Colors.green.shade400
                    : Colors.red.shade400,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatItem(
                label: '📈 ROI TB',
                value: '${stats.avgROI.toStringAsFixed(1)}%',
              ),
            ),
            Expanded(
              child: _buildStatItem(
                label: '📅 Lợi/tháng',
                value: NumberUtils.formatCurrency(stats.profitPerMonth),
                valueColor: stats.profitPerMonth > 0
                    ? Colors.green.shade400
                    : Colors.red.shade400,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ✅ Widget hiển thị 1 chỉ số
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

  // ✅ Navigation đến trang chi tiết
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