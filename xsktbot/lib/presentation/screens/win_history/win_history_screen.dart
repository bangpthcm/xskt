// lib/presentation/screens/win_history/win_history_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:data_table_2/data_table_2.dart';
import 'win_history_viewmodel.dart';
import '../../../core/utils/number_utils.dart';
import '../../../data/models/cycle_win_history.dart';
import '../../../data/models/xien_win_history.dart';

class WinHistoryScreen extends StatefulWidget {
  const WinHistoryScreen({Key? key}) : super(key: key);

  @override
  State<WinHistoryScreen> createState() => _WinHistoryScreenState();
}

class _WinHistoryScreenState extends State<WinHistoryScreen>
    with TickerProviderStateMixin {
  late TabController _mainTabController;
  late TabController _cycleSubTabController;

  @override
  void initState() {
    super.initState();
    _mainTabController = TabController(length: 2, vsync: this);
    _cycleSubTabController = TabController(length: 4, vsync: this);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WinHistoryViewModel>().loadHistory();
    });
  }

  @override
  void dispose() {
    _mainTabController.dispose();
    _cycleSubTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử trúng số'),
        bottom: TabBar(
          controller: _mainTabController,
          tabs: const [
            Tab(text: 'Xiên'),
            Tab(text: 'Chu kỳ'),
          ],
        ),
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

          return TabBarView(
            controller: _mainTabController,
            children: [
              _buildXienTab(viewModel),
              _buildCycleMainTab(viewModel),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCycleMainTab(WinHistoryViewModel viewModel) {
    return Column(
      children: [
        Container(
          color: Colors.grey.shade100,
          child: TabBar(
            controller: _cycleSubTabController,
            isScrollable: true,
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blue,
            tabs: const [
              Tab(text: 'Tất cả'),
              Tab(text: 'Nam'),
              Tab(text: 'Trung'),
              Tab(text: 'Bắc'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _cycleSubTabController,
            children: [
              _buildCycleTab(viewModel),
              _buildNamWarningTab(),
              _buildTrungTab(viewModel),
              _buildBacTab(viewModel),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNamWarningTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 80,
            color: Colors.orange.shade400,
          ),
          const SizedBox(height: 24),
          Text(
            '⚠️ Tránh rủi ro Bến Tre',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.orange.shade700,
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Miền Nam có nguy cơ trúng tại Bến Tre.\n'
              'Vui lòng sử dụng bảng "Tất cả" hoặc các miền khác.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade700,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.symmetric(horizontal: 32),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.info_outline, color: Colors.orange.shade700),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    'Bảng "Tất cả" đã loại trừ Bến Tre',
                    style: TextStyle(
                      color: Colors.orange.shade900,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCycleTab(WinHistoryViewModel viewModel) {
    if (viewModel.cycleHistory.isEmpty) {
      return const Center(child: Text('Chưa có lịch sử trúng số chu kỳ'));
    }

    final stats = viewModel.getCycleStats();
    return Column(
      children: [
        _buildStatsCard(
          wins: stats.totalWins,
          totalProfit: stats.totalProfit,
          avgROI: stats.avgROI,
        ),
        Expanded(child: _buildCycleDataTable(viewModel.cycleHistory)),
      ],
    );
  }

  Widget _buildXienTab(WinHistoryViewModel viewModel) {
    if (viewModel.xienHistory.isEmpty) {
      return const Center(child: Text('Chưa có lịch sử trúng số xiên'));
    }

    final stats = viewModel.getXienStats();
    return Column(
      children: [
        _buildStatsCard(
          wins: stats.totalWins,
          totalProfit: stats.totalProfit,
          avgROI: stats.avgROI,
        ),
        Expanded(child: _buildXienDataTable(viewModel.xienHistory)),
      ],
    );
  }

  // ✅ ADD: Trung tab
  Widget _buildTrungTab(WinHistoryViewModel viewModel) {
    if (viewModel.trungHistory.isEmpty) {
      return const Center(child: Text('Chưa có lịch sử trúng số Miền Trung'));
    }

    final stats = viewModel.getTrungStats();
    return Column(
      children: [
        _buildStatsCard(
          wins: stats.totalWins,
          totalProfit: stats.totalProfit,
          avgROI: stats.avgROI,
        ),
        Expanded(child: _buildCycleDataTable(viewModel.trungHistory)),
      ],
    );
  }

  // ✅ ADD: Bac tab
  Widget _buildBacTab(WinHistoryViewModel viewModel) {
    if (viewModel.bacHistory.isEmpty) {
      return const Center(child: Text('Chưa có lịch sử trúng số Miền Bắc'));
    }

    final stats = viewModel.getBacStats();
    return Column(
      children: [
        _buildStatsCard(
          wins: stats.totalWins,
          totalProfit: stats.totalProfit,
          avgROI: stats.avgROI,
        ),
        Expanded(child: _buildCycleDataTable(viewModel.bacHistory)),
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
              label: 'Tổng lời',
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

  Widget _buildCycleDataTable(List<CycleWinHistory> history) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
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
    );
  }

  Widget _buildXienDataTable(List<XienWinHistory> history) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
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
    );
  }

  void _showCheckDialog(BuildContext context) {
    final dateController = TextEditingController();
    
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final yesterdayStr = '${yesterday.day.toString().padLeft(2, '0')}/'
        '${yesterday.month.toString().padLeft(2, '0')}/'
        '${yesterday.year}';
    dateController.text = yesterdayStr;

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