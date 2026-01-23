// lib/presentation/screens/win_history/win_summary_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/number_utils.dart';
import '../../widgets/profit_chart.dart';
import '../../widgets/shimmer_loading.dart';
import 'win_history_screen.dart';
import 'win_history_viewmodel.dart';

class WinSummaryScreen extends StatefulWidget {
  const WinSummaryScreen({super.key});

  @override
  State<WinSummaryScreen> createState() => _WinSummaryScreenState();
}

class _WinSummaryScreenState extends State<WinSummaryScreen>
    with AutomaticKeepAliveClientMixin {
  // ✅ 2. Biến trạng thái để ẩn/hiện chi tiết
  bool _isExpanded = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialLogic();
    });
  }

  Future<void> _initialLogic() async {
    final vm = context.read<WinHistoryViewModel>();

    // 🚀 CHIẾN THUẬT:
    // 1. Load dữ liệu cũ ngay (mất ~1s) -> Chart và Card sẽ hiện ngay lập tức
    await vm.loadHistory();

    // 2. Sau đó mới kích hoạt cập nhật server (chạy ngầm 200s)
    // Nếu dữ liệu trống hoặc người dùng vừa vào app, ta mới tự động trigger
    if (vm.cycleHistory.isEmpty || !vm.isUpdating) {
      _triggerUpdateWithNotify();
    }
  }

  Future<void> _triggerUpdateWithNotify() async {
    final vm = context.read<WinHistoryViewModel>();
    try {
      await vm.updateDataFromServer();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Đã cập nhật kết quả mới nhất'),
          backgroundColor: ThemeProvider.profit,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('❌ Lỗi cập nhật: $e'),
          backgroundColor: ThemeProvider.loss,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
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

                const SizedBox(height: 12),

                // 🚀 KHU VỰC NÚT KIỂM TRA KẾT QUẢ VÀ LOADING
                Column(
                  children: [
                    if (viewModel.isUpdating) ...[
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          'Hệ thống đang kiểm tra kết quả... (Có thể mất 1 phút)',
                          style:
                              TextStyle(color: Color(0xFFFFD700), fontSize: 12),
                        ),
                      ),
                      const LinearProgressIndicator(
                        color: Color(0xFFFFD700), // Màu vàng gold đồng bộ
                        backgroundColor: Colors.white10,
                      ),
                      const SizedBox(height: 12),
                    ],
                    ElevatedButton.icon(
                      onPressed: viewModel.isUpdating
                          ? null
                          : () async {
                              try {
                                // 1. Gọi hàm cập nhật
                                await viewModel.updateDataFromServer();

                                // 2. Hiển thị thông báo thành công (Màu xanh - profit)
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content:
                                          Text('✅ Cập nhật kết quả thành công'),
                                      backgroundColor: ThemeProvider
                                          .profit, // Đồng bộ màu Settings
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              } catch (e) {
                                // 3. Hiển thị thông báo thất bại (Màu đỏ - loss)
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('❌ Lỗi: ${e.toString()}'),
                                      backgroundColor: ThemeProvider
                                          .loss, // Đồng bộ màu Settings
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              }
                            },
                      icon: viewModel.isUpdating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.grey))
                          : const Icon(Icons.sync_alt),
                      label: Text(viewModel.isUpdating
                          ? 'Đang thực thi...'
                          : 'Kiểm tra kết quả'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ThemeProvider.surface, // kSurfaceColor
                        foregroundColor:
                            ThemeProvider.accent, // Đồng bộ kAccentColor
                        disabledBackgroundColor: Colors.grey.shade900,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Colors.white10),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
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
                    _isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
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
    final namStats = viewModel.getNamStats(); // Lấy stats miền nam
    final trungStats = viewModel.getTrungStats();
    final bacStats = viewModel.getBacStats();

    return Card(
      color: const Color(0xFF1E1E1E),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('CHU KỲ 00-99',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(height: 24, color: Colors.grey),

            _buildCycleSubSection(
              iconColor: ThemeProvider.accent,
              title: 'TẤT CẢ',
              stats: allCycleStats,
              onTap: () => _navigateToDetail(0),
            ),
            const SizedBox(height: 12),

            // ✅ THÊM THẺ MIỀN NAM TẠI ĐÂY
            _buildCycleSubSection(
              iconColor: ThemeProvider.accent,
              title: 'MIỀN NAM',
              stats: namStats,
              onTap: () =>
                  _navigateToDetail(1), // Tab Index 1 trong WinHistoryScreen
            ),
            const SizedBox(height: 12),

            _buildCycleSubSection(
              iconColor: ThemeProvider.accent,
              title: 'MIỀN TRUNG',
              stats: trungStats,
              onTap: () => _navigateToDetail(2), // Tăng index lên 2
            ),
            const SizedBox(height: 12),

            _buildCycleSubSection(
              iconColor: ThemeProvider.accent,
              title: 'MIỀN BẮC',
              stats: bacStats,
              onTap: () => _navigateToDetail(3), // Tăng index lên 3
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
        onTap: () => _navigateToDetail(4), // Tab Xiên
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
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
                valueColor:
                    stats.totalProfit > 0 ? ThemeProvider.profit : Colors.white,
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
                valueColor:
                    stats.maxBet > 0 ? ThemeProvider.loss : Colors.white,
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
