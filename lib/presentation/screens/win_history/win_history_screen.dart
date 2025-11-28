// lib/presentation/screens/win_history/win_history_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:data_table_2/data_table_2.dart';
import 'win_history_viewmodel.dart';
import '../../../core/utils/number_utils.dart';
import '../../../data/models/cycle_win_history.dart';
import '../../../data/models/xien_win_history.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/shimmer_loading.dart';

class WinHistoryScreen extends StatefulWidget {
  final int initialTab;
  
  const WinHistoryScreen({
    super.key,
    this.initialTab = 0,
  });

  @override
  State<WinHistoryScreen> createState() => _WinHistoryScreenState();
}

class _WinHistoryScreenState extends State<WinHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // ✅ ScrollControllers cho từng tab
  final _cycleScrollController = ScrollController();
  final _trungScrollController = ScrollController();
  final _bacScrollController = ScrollController();
  final _xienScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    
    // ✅ Setup scroll listeners
    _setupScrollListeners();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WinHistoryViewModel>().loadHistory();
    });
  }

  // ✅ Setup scroll listeners cho tất cả tabs
  void _setupScrollListeners() {
    _cycleScrollController.addListener(() => _onScroll(
      _cycleScrollController,
      () => context.read<WinHistoryViewModel>().loadMoreCycle(),
    ));
    
    _trungScrollController.addListener(() => _onScroll(
      _trungScrollController,
      () => context.read<WinHistoryViewModel>().loadMoreTrung(),
    ));
    
    _bacScrollController.addListener(() => _onScroll(
      _bacScrollController,
      () => context.read<WinHistoryViewModel>().loadMoreBac(),
    ));
    
    _xienScrollController.addListener(() => _onScroll(
      _xienScrollController,
      () => context.read<WinHistoryViewModel>().loadMoreXien(),
    ));
  }

  // ✅ Detect khi scroll gần đến cuối (còn 200px)
  void _onScroll(ScrollController controller, VoidCallback loadMore) {
    if (controller.position.pixels >= controller.position.maxScrollExtent - 200) {
      loadMore();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _cycleScrollController.dispose();
    _trungScrollController.dispose();
    _bacScrollController.dispose();
    _xienScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử trúng số'),
        actions: [
          IconButton(
            icon: const Icon(Icons.play_arrow),
            tooltip: 'Kiểm tra ngay',
            onPressed: () => _showCheckDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<WinHistoryViewModel>().loadHistory();
            },
          ),
        ],
      ),
      body: Consumer<WinHistoryViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.isLoading && viewModel.cycleHistory.isEmpty) {
            return const ShimmerLoading(type: ShimmerType.table);
          }

          if (viewModel.errorMessage != null && viewModel.cycleHistory.isEmpty) {
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

          return Column(
            children: [
              Container(
                color: const Color(0xFF1E1E1E),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  labelColor: Colors.deepPurple.shade100,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Colors.deepPurple.shade100,
                  tabs: const [
                    Tab(text: 'Tất cả'),
                    Tab(text: 'Trung'),
                    Tab(text: 'Bắc'),
                    Tab(text: 'Xiên'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildCycleTab(viewModel),
                    _buildTrungTab(viewModel),
                    _buildBacTab(viewModel),
                    _buildXienTab(viewModel),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ✅ Cycle Tab với ScrollController
  Widget _buildCycleTab(WinHistoryViewModel viewModel) {
    if (viewModel.cycleHistory.isEmpty && !viewModel.isLoading) {
      return const EmptyStateWidget(
        title: 'Chưa có lịch sử',
        message: 'Lịch sử trúng số sẽ hiển thị ở đây sau khi bạn có kết quả trúng',
      );
    }

    final stats = viewModel.getCycleStats();
    return ListView(
      controller: _cycleScrollController,
      children: [
        _buildStatsCard(
          wins: stats.totalWins,
          totalProfit: stats.totalProfit,
          avgROI: stats.avgROI,
        ),
        _buildCycleDataTable(viewModel.cycleHistory),
        _buildLoadingFooter(
          hasMore: viewModel.hasMoreCycle,
          isLoading: viewModel.isLoadingMore,
        ),
      ],
    );
  }

  // ✅ Trung Tab với ScrollController
  Widget _buildTrungTab(WinHistoryViewModel viewModel) {
    if (viewModel.trungHistory.isEmpty && !viewModel.isLoading) {
      return const Center(child: Text('Chưa có lịch sử trúng số Miền Trung'));
    }

    final stats = viewModel.getTrungStats();
    return ListView(
      controller: _trungScrollController,
      children: [
        _buildStatsCard(
          wins: stats.totalWins,
          totalProfit: stats.totalProfit,
          avgROI: stats.avgROI,
        ),
        _buildCycleDataTable(viewModel.trungHistory),
        _buildLoadingFooter(
          hasMore: viewModel.hasMoreTrung,
          isLoading: viewModel.isLoadingMore,
        ),
      ],
    );
  }

  // ✅ Bac Tab với ScrollController
  Widget _buildBacTab(WinHistoryViewModel viewModel) {
    if (viewModel.bacHistory.isEmpty && !viewModel.isLoading) {
      return const Center(child: Text('Chưa có lịch sử trúng số Miền Bắc'));
    }

    final stats = viewModel.getBacStats();
    return ListView(
      controller: _bacScrollController,
      children: [
        _buildStatsCard(
          wins: stats.totalWins,
          totalProfit: stats.totalProfit,
          avgROI: stats.avgROI,
        ),
        _buildCycleDataTable(viewModel.bacHistory),
        _buildLoadingFooter(
          hasMore: viewModel.hasMoreBac,
          isLoading: viewModel.isLoadingMore,
        ),
      ],
    );
  }

  // ✅ Xien Tab với ScrollController
  Widget _buildXienTab(WinHistoryViewModel viewModel) {
    if (viewModel.xienHistory.isEmpty && !viewModel.isLoading) {
      return const Center(child: Text('Chưa có lịch sử trúng số xiên'));
    }

    final stats = viewModel.getXienStats();
    return ListView(
      controller: _xienScrollController,
      children: [
        _buildStatsCard(
          wins: stats.totalWins,
          totalProfit: stats.totalProfit,
          avgROI: stats.avgROI,
        ),
        _buildXienDataTable(viewModel.xienHistory),
        _buildLoadingFooter(
          hasMore: viewModel.hasMoreXien,
          isLoading: viewModel.isLoadingMore,
        ),
      ],
    );
  }

  Widget _buildStatsCard({
    required int wins,
    required double totalProfit,
    required double avgROI,
  }) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(
              icon: Icons.check_circle,
              label: 'Số lần trúng',
              value: wins.toString(),
              color: Colors.green,
            ),
            _buildStatItem(
              icon: Icons.monetization_on,
              label: 'Tổng lợi',
              value: NumberUtils.formatCurrency(totalProfit),
              color: totalProfit > 0 ? Colors.green : Colors.red,
            ),
            _buildStatItem(
              icon: Icons.trending_up,
              label: 'ROI TB',
              value: '${avgROI.toStringAsFixed(2)}%',
              color: Colors.blue,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  // ✅ Loading footer widget
  Widget _buildLoadingFooter({
    required bool hasMore,
    required bool isLoading,
  }) {
    if (hasMore && isLoading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    if (hasMore && !isLoading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: Text(
            'Kéo xuống để tải thêm...',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }
    
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(
        child: Text(
          'Đã hiển thị tất cả',
          style: TextStyle(color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildCycleDataTable(List<CycleWinHistory> history) {
    // ✅ Tính chiều cao dựa trên số dòng (tối đa 10 dòng mỗi lần)
    const rowHeight = 52.0;
    const headerHeight = 56.0;
    final visibleRows = history.length.clamp(0, 10);
    final tableHeight = headerHeight + (rowHeight * visibleRows);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: tableHeight,
        child: DataTable2(
          columnSpacing: 8,
          horizontalMargin: 8,
          minWidth: 800,
          columns: const [
            DataColumn2(label: Text('STT'), size: ColumnSize.S),
            DataColumn2(label: Text('Ngày trúng'), size: ColumnSize.M),
            DataColumn2(label: Text('Số'), size: ColumnSize.S),
            DataColumn2(label: Text('Miền'), size: ColumnSize.S),
            DataColumn2(label: Text('Lần'), size: ColumnSize.S),
            DataColumn2(label: Text('Tổng cược'), size: ColumnSize.M),
            DataColumn2(label: Text('Lời/Lỗ'), size: ColumnSize.M),
            DataColumn2(label: Text('ROI'), size: ColumnSize.S),
            DataColumn2(label: Text('Số ngày'), size: ColumnSize.S),
          ],
          rows: history.map((h) {
            return DataRow2(
              cells: [
                DataCell(Text(h.stt.toString())),
                DataCell(Text(h.ngayTrung)),
                DataCell(Text(h.soMucTieu)),
                DataCell(Text(h.mienTrung ?? '-')),
                DataCell(Text(h.soLanTrung.toString())),
                DataCell(Text(NumberUtils.formatCurrency(h.tongTienCuoc))),
                DataCell(
                  Text(
                    NumberUtils.formatCurrency(h.loiLo),
                    style: TextStyle(
                      color: h.loiLo > 0 ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    '${h.roi.toStringAsFixed(2)}%',
                    style: TextStyle(
                      color: h.roi > 0 ? Colors.green : Colors.red,
                    ),
                  ),
                ),
                DataCell(Text(h.soNgayCuoc.toString())),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildXienDataTable(List<XienWinHistory> history) {
    // ✅ Tính chiều cao dựa trên số dòng
    const rowHeight = 52.0;
    const headerHeight = 56.0;
    final visibleRows = history.length.clamp(0, 10);
    final tableHeight = headerHeight + (rowHeight * visibleRows);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: tableHeight,
        child: DataTable2(
          columnSpacing: 8,
          horizontalMargin: 12,
          minWidth: 1000,
          columns: const [
            DataColumn2(label: Text('STT'), size: ColumnSize.S),
            DataColumn2(label: Text('Ngày trúng'), size: ColumnSize.M),
            DataColumn2(label: Text('Cặp số'), size: ColumnSize.M),
            DataColumn2(label: Text('Lần'), size: ColumnSize.S),
            DataColumn2(label: Text('Chi tiết'), size: ColumnSize.L),
            DataColumn2(label: Text('Tổng cược'), size: ColumnSize.M),
            DataColumn2(label: Text('Lời/Lỗ'), size: ColumnSize.M),
            DataColumn2(label: Text('ROI'), size: ColumnSize.S),
            DataColumn2(label: Text('Số ngày'), size: ColumnSize.S),
          ],
          rows: history.map((h) {
            return DataRow2(
              cells: [
                DataCell(Text(h.stt.toString())),
                DataCell(Text(h.ngayTrung)),
                DataCell(Text(h.capSoMucTieu)),
                DataCell(Text(h.soLanTrungCap.toString())),
                DataCell(Text(h.chiTietTrung, overflow: TextOverflow.ellipsis)),
                DataCell(Text(NumberUtils.formatCurrency(h.tongTienCuoc))),
                DataCell(
                  Text(
                    NumberUtils.formatCurrency(h.loiLo),
                    style: TextStyle(
                      color: h.loiLo > 0 ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    '${h.roi.toStringAsFixed(2)}%',
                    style: TextStyle(
                      color: h.roi > 0 ? Colors.green : Colors.red,
                    ),
                  ),
                ),
                DataCell(Text(h.soNgayCuoc.toString())),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showCheckDialog(BuildContext context) {
    final dateController = TextEditingController();
    
    final today = DateTime.now();
    final todayStr = '${today.day.toString().padLeft(2, '0')}/'
        '${today.month.toString().padLeft(2, '0')}'
        '/${today.year}';
    dateController.text = todayStr;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kiểm tra kết quả'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Nhập ngày cần kiểm tra:'),
            const SizedBox(height: 16),
            TextField(
              controller: dateController,
              decoration: const InputDecoration(
                labelText: 'Ngày (dd/MM/yyyy)',
                hintText: '15/01/2025',
                prefixIcon: Icon(Icons.calendar_today),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Lưu ý: Chỉ kiểm tra các ngày chưa được đánh dấu',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              
              final date = dateController.text.trim();
              if (date.isEmpty) return;
              
              final viewModel = context.read<WinHistoryViewModel>();
              await viewModel.checkSpecificDate(date);
              
              if (context.mounted) {
                if (viewModel.errorMessage != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(viewModel.errorMessage!),
                      backgroundColor: Colors.red,
                    ),
                  );
                } else {
                  final result = viewModel.lastCheckResult;
                  if (result != null) {
                    final totalWins = result.cycleWins + result.xienWins;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          totalWins > 0
                              ? '🎉 Tìm thấy $totalWins lần trúng!\n'
                                'Chu kỳ: ${result.cycleWins}, Xiên: ${result.xienWins}'
                              : 'Không có kết quả trúng cho ngày $date',
                        ),
                        backgroundColor: totalWins > 0 ? Colors.green : Colors.orange,
                        duration: const Duration(seconds: 4),
                      ),
                    );
                  }
                }
              }
            },
            child: const Text('Kiểm tra'),
          ),
        ],
      ),
    );
  }
}