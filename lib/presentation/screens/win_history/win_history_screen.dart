// lib/presentation/screens/win_history/win_history_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/number_utils.dart';
import '../../../data/models/cycle_win_history.dart';
import '../../../data/models/xien_win_history.dart';
import 'win_history_viewmodel.dart';
import '../../widgets/empty_state_widget.dart';

class WinHistoryScreen extends StatefulWidget {
  final int initialTab;

  const WinHistoryScreen({
    super.key,
    this.initialTab = 0,
  });

  @override
  State<WinHistoryScreen> createState() => _WinHistoryScreenState();
}

class _WinHistoryScreenState extends State<WinHistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ✅ Định nghĩa bảng màu (Dark Theme)
  static const Color kBackgroundColor = Color(0xFF121212);
  static const Color kSurfaceColor = Color(0xFF1E1E1E);
  static const Color kAccentColor = Color(0xFFFFD700);
  static const Color kPrimaryTextColor = Color(0xFFE0E0E0);
  static const Color kSecondaryTextColor = Color(0xFFA0A0A0);
  static const Color kGrowthColor = Color(0xFF00897B);
  static const Color kLossColor = Color(0xFFD32F2F);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTab,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WinHistoryViewModel>().loadHistory();
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
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: kSurfaceColor,
        title: const Text(
          'Lịch sử chi tiết',
          style: TextStyle(color: kPrimaryTextColor),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: kPrimaryTextColor),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: kAccentColor,
          unselectedLabelColor: kSecondaryTextColor,
          indicatorColor: kAccentColor,
          dividerColor: Colors.transparent,
          tabs: const [
            Tab(text: 'Ba miền'),
            Tab(text: 'Miền Trung'),
            Tab(text: 'Miền Bắc'),
            Tab(text: 'Xiên Bắc'),
          ],
        ),
      ),
      body: Consumer<WinHistoryViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.isLoading && viewModel.cycleHistory.isEmpty) {
            return const Center(child: CircularProgressIndicator(color: kAccentColor));
          }

          if (viewModel.errorMessage != null && viewModel.cycleHistory.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: kLossColor),
                  const SizedBox(height: 16),
                  Text(
                    viewModel.errorMessage!,
                    style: const TextStyle(color: kSecondaryTextColor),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => viewModel.loadHistory(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kSurfaceColor,
                      foregroundColor: kAccentColor,
                    ),
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            );
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _buildHistoryList(
                context,
                viewModel.cycleHistory,
                onLoadMore: viewModel.loadMoreCycle,
                hasMore: viewModel.hasMoreCycle,
              ),
              _buildHistoryList(
                context,
                viewModel.trungHistory,
                onLoadMore: viewModel.loadMoreTrung,
                hasMore: viewModel.hasMoreTrung,
              ),
              _buildHistoryList(
                context,
                viewModel.bacHistory,
                onLoadMore: viewModel.loadMoreBac,
                hasMore: viewModel.hasMoreBac,
              ),
              _buildHistoryList(
                context,
                viewModel.xienHistory,
                onLoadMore: viewModel.loadMoreXien,
                hasMore: viewModel.hasMoreXien,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHistoryList(
    BuildContext context,
    List<dynamic> history, {
    required VoidCallback onLoadMore,
    required bool hasMore,
  }) {
    if (history.isEmpty) {
      return const EmptyStateWidget(
        title: 'Chưa có dữ liệu',
        message: 'Lịch sử sẽ hiển thị tại đây',
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification scrollInfo) {
        if (!scrollInfo.metrics.atEdge && scrollInfo.metrics.pixels > 0) {
          if (scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
            if (hasMore) {
              onLoadMore();
            }
          }
        }
        return false;
      },
      child: RefreshIndicator(
        color: kAccentColor,
        backgroundColor: kSurfaceColor,
        onRefresh: () async {
          await context.read<WinHistoryViewModel>().loadHistory();
        },
        child: ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: history.length + (hasMore ? 1 : 0),
          separatorBuilder: (ctx, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (index == history.length) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: kAccentColor,
                  ),
                ),
              );
            }

            final item = history[index];
            return _buildHistoryItem(item);
          },
        ),
      ),
    );
  }

  Widget _buildHistoryItem(dynamic item) {
    // 1. Chuẩn bị dữ liệu
    String ngayTrung = '';
    double loiLo = 0.0;
    double tongTienCuoc = 0.0;
    String soDanh = '';
    int soLanTrung = 0;

    if (item is CycleWinHistory) {
      ngayTrung = item.ngayTrung;
      loiLo = item.loiLo;
      tongTienCuoc = item.tongTienCuoc;
      soDanh = item.soMucTieu;
      soLanTrung = item.soLanTrung;
    } else if (item is XienWinHistory) {
      ngayTrung = item.ngayTrung;
      loiLo = item.loiLo;
      tongTienCuoc = item.tongTienCuoc;
      soDanh = item.capSoMucTieu;
      soLanTrung = item.soLanTrungCap;
    }

    final String profitText = NumberUtils.formatCurrency(loiLo);
    final String betText = NumberUtils.formatCurrency(tongTienCuoc);

    // Màu sắc theo logic Tăng trưởng / Thua lỗ
    final Color profitColor = loiLo >= 0 ? kGrowthColor : kLossColor;
    final String profitPrefix = loiLo > 0 ? '+' : '';

    return Card(
      color: kSurfaceColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white.withOpacity(0.05)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ Dòng 1: Ngày (Trái) - Số đánh (Phải)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Ngày: $ngayTrung',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: kPrimaryTextColor,
                    fontSize: 15,
                  ),
                ),
                // Số đánh nổi bật ở góc phải
                Text(
                  'Số: $soDanh',
                  style: const TextStyle(
                    color: kPrimaryTextColor, // Màu vàng
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1, color: Colors.white10),
            const SizedBox(height: 12),

            // ✅ Dòng 2: Số lần trúng (Đã bỏ border, hiển thị text thường)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Số lần trúng:',
                  style: TextStyle(color: kSecondaryTextColor),
                ),
                Text(
                  '$soLanTrung lần',
                  style: const TextStyle(
                    color: kSecondaryTextColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Dòng 3: Lợi nhuận
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Lợi nhuận:',
                  style: TextStyle(color: kSecondaryTextColor),
                ),
                Text(
                  '$profitPrefix$profitText',
                  style: TextStyle(
                    color: profitColor, // Màu xanh/đỏ
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Dòng 4: Tổng tiền bỏ ra
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Tổng tiền bỏ ra:',
                  style: TextStyle(color: kSecondaryTextColor),
                ),
                Text(
                  betText,
                  style: const TextStyle(
                    color: kLossColor, // Màu đỏ cho chi phí
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}