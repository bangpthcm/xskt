// lib/presentation/screens/betting/betting_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:data_table_2/data_table_2.dart';
import 'betting_viewmodel.dart';
import '../settings/settings_viewmodel.dart';
import '../../../core/utils/number_utils.dart';
import '../../../data/models/betting_row.dart';

class BettingDetailScreen extends StatefulWidget {
  final int initialTab;

  const BettingDetailScreen({
    Key? key,
    this.initialTab = 0,
  }) : super(key: key);

  @override
  State<BettingDetailScreen> createState() => _BettingDetailScreenState();
}

class _BettingDetailScreenState extends State<BettingDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTab,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết bảng cược'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Tất cả'),
            Tab(text: 'Trung'),
            Tab(text: 'Bắc'),
            Tab(text: 'Xiên'),
          ],
        ),
      ),
      body: Consumer<BettingViewModel>(
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
                ],
              ),
            );
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _buildCycleTab(viewModel),
              _buildTrungTab(viewModel),
              _buildBacTab(viewModel),
              _buildXienTab(viewModel),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCycleTab(BettingViewModel viewModel) {
    if (viewModel.cycleTable == null) {
      return const Center(child: Text('Chưa có bảng cược chu kỳ'));
    }
    return Column(
      children: [
        _buildMetadataCard(viewModel.cycleMetadata!),
        Expanded(child: _buildCycleDataTable(viewModel.cycleTable!)),
        _buildActionButtons(viewModel, BettingTableType.cycle),
      ],
    );
  }

  Widget _buildTrungTab(BettingViewModel viewModel) {
    if (viewModel.trungTable == null) {
      return const Center(child: Text('Chưa có bảng cược Miền Trung'));
    }
    return Column(
      children: [
        _buildMetadataCard(viewModel.trungMetadata!),
        Expanded(child: _buildCycleDataTable(viewModel.trungTable!)),
        _buildActionButtons(viewModel, BettingTableType.trung),
      ],
    );
  }

  Widget _buildBacTab(BettingViewModel viewModel) {
    if (viewModel.bacTable == null) {
      return const Center(child: Text('Chưa có bảng cược Miền Bắc'));
    }
    return Column(
      children: [
        _buildMetadataCard(viewModel.bacMetadata!),
        Expanded(child: _buildCycleDataTable(viewModel.bacTable!)),
        _buildActionButtons(viewModel, BettingTableType.bac),
      ],
    );
  }

  Widget _buildXienTab(BettingViewModel viewModel) {
    if (viewModel.xienTable == null) {
      return const Center(child: Text('Chưa có bảng cược xiên'));
    }
    return Column(
      children: [
        _buildMetadataCard(viewModel.xienMetadata!),
        Expanded(child: _buildXienDataTable(viewModel.xienTable!)),
        _buildActionButtons(viewModel, BettingTableType.xien),
      ],
    );
  }

  Widget _buildMetadataCard(Map<String, dynamic> metadata) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMetadataRow('Số ngày gan:', metadata['so_ngay_gan']?.toString() ?? '-'),
            _buildMetadataRow('Lần cuối về:', metadata['lan_cuoi_ve']?.toString() ?? '-'),
            if (metadata.containsKey('cap_so_muc_tieu'))
              _buildMetadataRow('Cặp số:', metadata['cap_so_muc_tieu']?.toString() ?? '-'),
            if (metadata.containsKey('so_muc_tieu'))
              _buildMetadataRow('Số mục tiêu:', metadata['so_muc_tieu']?.toString() ?? '-'),
          ],
        ),
      ),
    );
  }

  Widget _buildMetadataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 16))),
        ],
      ),
    );
  }

  Widget _buildCycleDataTable(List<BettingRow> table) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: const Color(0xFF1E1E1E),
      child: DataTable2(
        columnSpacing: 12,
        horizontalMargin: 12,
        minWidth: 600,
        headingTextStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
          color: Colors.white,
        ),
        dataTextStyle: const TextStyle(
          fontSize: 13,
          color: Colors.white,
        ),
        headingRowColor: MaterialStateProperty.all(const Color(0xFF2C2C2C)),
        dataRowColor: MaterialStateProperty.resolveWith<Color?>(
          (Set<MaterialState> states) {
            if (states.contains(MaterialState.selected)) {
              return const Color(0xFF2C2C2C);
            }
            return null;
          },
        ),
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
        ),
        columns: [
          DataColumn2(label: Center(child: Text('STT')), size: ColumnSize.S, fixedWidth: 30),
          DataColumn2(label: Center(child: Text('Ngày')), size: ColumnSize.M, fixedWidth: 90),
          DataColumn2(label: Center(child: Text('Miền')), size: ColumnSize.S, fixedWidth: 60),
          DataColumn2(label: Center(child: Text('Số')), size: ColumnSize.S, fixedWidth: 50),
          DataColumn2(label: Center(child: Text('Cược/Số')), size: ColumnSize.S, fixedWidth: 65),
          DataColumn2(label: Align(alignment: Alignment.centerRight, child: Text('Cược/miền')), size: ColumnSize.M),
          DataColumn2(label: Align(alignment: Alignment.centerRight, child: Text('Tổng tiền')), size: ColumnSize.M),
          DataColumn2(label: Align(alignment: Alignment.centerRight, child: Text('Lời (1 số)')), size: ColumnSize.M),
          DataColumn2(label: Align(alignment: Alignment.centerRight, child: Text('Lời (2 số)')), size: ColumnSize.M),
        ],
        rows: table.asMap().entries.map((entry) {
          final index = entry.key;
          final row = entry.value;
          final isEven = index % 2 == 0;
          
          return DataRow2(
            color: MaterialStateProperty.all(
              isEven ? const Color(0xFF1E1E1E) : const Color(0xFF252525),
            ),
            cells: [
              DataCell(Center(child: Text(row.stt.toString()))),
              DataCell(Center(child: Text(row.ngay))),
              DataCell(Center(child: Text(row.mien))),
              DataCell(Center(child: Text(row.so,style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)))),
              DataCell(Align(alignment: Alignment.centerRight, child: Text(NumberUtils.formatCurrency(row.cuocSo), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)))),
              DataCell(Align(alignment: Alignment.centerRight, child: Text(NumberUtils.formatCurrency(row.cuocMien)))),
              DataCell(Align(alignment: Alignment.centerRight, child: Text(NumberUtils.formatCurrency(row.tongTien)))),
              DataCell(Align(alignment: Alignment.centerRight, child: Text(NumberUtils.formatCurrency(row.loi1So), style: TextStyle(color: row.loi1So > 0 ? Colors.green : Colors.red, fontWeight: FontWeight.bold)))),
              DataCell(Align(alignment: Alignment.centerRight, child: Text(NumberUtils.formatCurrency(row.loi2So ?? 0), style: TextStyle(color: (row.loi2So ?? 0) > 0 ? Colors.green : Colors.red, fontWeight: FontWeight.bold)))),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildXienDataTable(List<BettingRow> table) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: const Color(0xFF1E1E1E),
      child: DataTable2(
        columnSpacing: 12,
        horizontalMargin: 12,
        minWidth: 600,
        headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
        dataTextStyle: const TextStyle(fontSize: 13, color: Colors.white),
        headingRowColor: MaterialStateProperty.all(const Color(0xFF2C2C2C)),
        dataRowColor: MaterialStateProperty.resolveWith<Color?>((Set<MaterialState> states) {
          if (states.contains(MaterialState.selected)) return const Color(0xFF2C2C2C);
          return null;
        }),
        decoration: const BoxDecoration(color: Color(0xFF1E1E1E)),
        columns: [
          DataColumn2(label: Center(child: Text('STT')), size: ColumnSize.S, fixedWidth: 30),
          DataColumn2(label: Center(child: Text('Ngày')), size: ColumnSize.M, fixedWidth: 90),
          DataColumn2(label: Center(child: Text('Miền')), size: ColumnSize.S, fixedWidth: 60),
          DataColumn2(label: Center(child: Text('Số')), size: ColumnSize.S, fixedWidth: 50),
          DataColumn2(label: Align(alignment: Alignment.centerRight, child: Text('Cược')), size: ColumnSize.M, fixedWidth: 70),
          DataColumn2(label: Align(alignment: Alignment.centerRight, child: Text('Tổng tiền')), size: ColumnSize.M),
          DataColumn2(label: Align(alignment: Alignment.centerRight, child: Text('Lời')), size: ColumnSize.M),
        ],
        rows: table.asMap().entries.map((entry) {
          final index = entry.key;
          final row = entry.value;
          final isEven = index % 2 == 0;

          return DataRow2(
            color: MaterialStateProperty.all(isEven ? const Color(0xFF1E1E1E) : const Color(0xFF252525)),
            cells: [
              DataCell(Center(child: Text(row.stt.toString()))),
              DataCell(Center(child: Text(row.ngay))),
              DataCell(Center(child: Text(row.mien))),
              DataCell(Center(child: Text(row.so,style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)))),
              DataCell(Align(alignment: Alignment.centerRight, child: Text(NumberUtils.formatCurrency(row.cuocMien), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)))),
              DataCell(Align(alignment: Alignment.centerRight, child: Text(NumberUtils.formatCurrency(row.tongTien)))),
              DataCell(Align(alignment: Alignment.centerRight, child: Text(NumberUtils.formatCurrency(row.loi1So), style: TextStyle(color: row.loi1So > 0 ? Colors.green : Colors.red, fontWeight: FontWeight.bold)))),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActionButtons(BettingViewModel viewModel, BettingTableType type) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF121212),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, -2))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showRegenerateDialog(context, viewModel, type),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tạo lại', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Colors.orange),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showSendTelegramDialog(context, viewModel, type),
                  icon: const Icon(Icons.send),
                  label: const Text('Gửi Telegram', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Colors.blue),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showDeleteDialog(context, viewModel, type),
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              label: const Text('Xóa bảng cược', style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), side: const BorderSide(color: Colors.red)),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, BettingViewModel viewModel, BettingTableType type) {
    String tableName = type == BettingTableType.xien ? 'xiên' : type == BettingTableType.cycle ? 'chu kỳ' : type == BettingTableType.trung ? 'Miền Trung' : 'Miền Bắc';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc muốn xóa bảng cược $tableName?\n\nDữ liệu sẽ bị xóa khỏi Google Sheet và không thể khôi phục.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await viewModel.deleteTable(type);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(viewModel.errorMessage ?? 'Xóa bảng thành công!'), backgroundColor: viewModel.errorMessage != null ? Colors.red : Colors.green),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }

  void _showRegenerateDialog(BuildContext context, BettingViewModel viewModel, BettingTableType type) {
    String tableName = type == BettingTableType.xien ? 'xiên' : type == BettingTableType.cycle ? 'chu kỳ' : type == BettingTableType.trung ? 'Miền Trung' : 'Miền Bắc';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận'),
        content: Text('Bạn có chắc muốn tạo lại bảng cược $tableName? Bảng hiện tại sẽ bị ghi đè.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final config = context.read<SettingsViewModel>().config;
              await viewModel.regenerateTable(type, config);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(viewModel.errorMessage ?? 'Tạo bảng thành công!'), backgroundColor: viewModel.errorMessage != null ? Colors.red : Colors.green),
                );
              }
            },
            child: const Text('Tạo lại'),
          ),
        ],
      ),
    );
  }

  void _showSendTelegramDialog(BuildContext context, BettingViewModel viewModel, BettingTableType type) {
    String tableName = type == BettingTableType.xien ? 'xiên' : type == BettingTableType.cycle ? 'chu kỳ' : type == BettingTableType.trung ? 'Miền Trung' : 'Miền Bắc';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận'),
        content: Text('Gửi bảng cược $tableName qua Telegram?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await viewModel.sendToTelegram(type);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(viewModel.errorMessage ?? 'Gửi thành công!'), backgroundColor: viewModel.errorMessage != null ? Colors.red : Colors.green),
                );
              }
            },
            child: const Text('Gửi'),
          ),
        ],
      ),
    );
  }
}