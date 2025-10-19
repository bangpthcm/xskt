// lib/presentation/screens/betting/betting_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:data_table_2/data_table_2.dart';
import 'betting_viewmodel.dart';
import '../settings/settings_viewmodel.dart';
import '../../../core/utils/number_utils.dart';
import '../../../data/models/betting_row.dart';

class BettingScreen extends StatefulWidget {
  const BettingScreen({Key? key}) : super(key: key);

  @override
  State<BettingScreen> createState() => _BettingScreenState();
}

class _BettingScreenState extends State<BettingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);  // ✅ 2 → 4 tabs
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BettingViewModel>().loadBettingTables();
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
      appBar: AppBar(
        title: const Text('Bảng cược'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,  // ✅ Enable scroll for 4 tabs
          tabs: const [
            Tab(text: 'Xiên'),
            Tab(text: 'Chu kỳ'),
            Tab(text: 'Trung'),  // ✅ ADD
            Tab(text: 'Bắc'),    // ✅ ADD
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<BettingViewModel>().loadBettingTables();
            },
          ),
        ],
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
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      viewModel.clearError();
                      viewModel.loadBettingTables();
                    },
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            );
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _buildXienTab(viewModel),
              _buildCycleTab(viewModel),
              _buildTrungTab(viewModel),  // ✅ ADD
              _buildBacTab(viewModel),    // ✅ ADD
            ],
          );
        },
      ),
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

  // ✅ ADD: Trung tab
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

  // ✅ ADD: Bac tab
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
            if (metadata.containsKey('nhom_so_gan'))
              _buildMetadataRow('Nhóm gan:', metadata['nhom_so_gan']?.toString() ?? '-'),
            if (metadata.containsKey('nhom_cap_so'))
              _buildMetadataRow('Nhóm cặp:', metadata['nhom_cap_so']?.toString() ?? '-'),
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

  Widget _buildXienDataTable(List<BettingRow> table) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: DataTable2(
        columnSpacing: 12,
        horizontalMargin: 12,
        minWidth: 600,
        columns: const [
          DataColumn2(label: Text('STT'), size: ColumnSize.S),
          DataColumn2(label: Text('Ngày'), size: ColumnSize.M),
          DataColumn2(label: Text('Miền'), size: ColumnSize.S),
          DataColumn2(label: Text('Số'), size: ColumnSize.S),
          DataColumn2(label: Text('Cược/miền'), size: ColumnSize.M),
          DataColumn2(label: Text('Tổng tiền'), size: ColumnSize.M),
          DataColumn2(label: Text('Lời'), size: ColumnSize.M),
        ],
        rows: table.map((row) {
          return DataRow2(
            cells: [
              DataCell(Text(row.stt.toString())),
              DataCell(Text(row.ngay)),
              DataCell(Text(row.mien)),
              DataCell(Text(row.so)),
              DataCell(Text(NumberUtils.formatCurrency(row.cuocMien))),
              DataCell(Text(NumberUtils.formatCurrency(row.tongTien))),
              DataCell(
                Text(
                  NumberUtils.formatCurrency(row.loi1So),
                  style: TextStyle(
                    color: row.loi1So > 0 ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCycleDataTable(List<BettingRow> table) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: DataTable2(
        columnSpacing: 8,
        horizontalMargin: 8,
        minWidth: 800,
        columns: const [
          DataColumn2(label: Text('STT'), size: ColumnSize.S),
          DataColumn2(label: Text('Ngày'), size: ColumnSize.M),
          DataColumn2(label: Text('Miền'), size: ColumnSize.S),
          DataColumn2(label: Text('Số'), size: ColumnSize.S),
          DataColumn2(label: Text('Số lô'), size: ColumnSize.S),
          DataColumn2(label: Text('Cược/số'), size: ColumnSize.M),
          DataColumn2(label: Text('Cược/miền'), size: ColumnSize.M),
          DataColumn2(label: Text('Tổng tiền'), size: ColumnSize.M),
          DataColumn2(label: Text('Lời (1 số)'), size: ColumnSize.M),
          DataColumn2(label: Text('Lời (2 số)'), size: ColumnSize.M),
        ],
        rows: table.map((row) {
          return DataRow2(
            cells: [
              DataCell(Text(row.stt.toString())),
              DataCell(Text(row.ngay)),
              DataCell(Text(row.mien)),
              DataCell(Text(row.so)),
              DataCell(Text(row.soLo?.toString() ?? '-')),
              DataCell(Text(NumberUtils.formatCurrency(row.cuocSo))),
              DataCell(Text(NumberUtils.formatCurrency(row.cuocMien))),
              DataCell(Text(NumberUtils.formatCurrency(row.tongTien))),
              DataCell(
                Text(
                  NumberUtils.formatCurrency(row.loi1So),
                  style: TextStyle(
                    color: row.loi1So > 0 ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              DataCell(
                Text(
                  NumberUtils.formatCurrency(row.loi2So ?? 0),
                  style: TextStyle(
                    color: (row.loi2So ?? 0) > 0 ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
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
        color: Colors.grey.shade100,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
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
                  label: const Text('Tạo lại'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showSendTelegramDialog(context, viewModel, type),
                  icon: const Icon(Icons.send),
                  label: const Text('Gửi Telegram'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.green,
                  ),
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
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: Colors.red),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, BettingViewModel viewModel, BettingTableType type) {
    String tableName = '';
    if (type == BettingTableType.xien) tableName = 'xiên';
    else if (type == BettingTableType.cycle) tableName = 'chu kỳ';
    else if (type == BettingTableType.trung) tableName = 'Miền Trung';
    else if (type == BettingTableType.bac) tableName = 'Miền Bắc';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text(
          'Bạn có chắc muốn xóa bảng cược $tableName?\n\n'
          'Dữ liệu sẽ bị xóa khỏi Google Sheet và không thể khôi phục.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await viewModel.deleteTable(type);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(viewModel.errorMessage ?? 'Xóa bảng thành công!'),
                    backgroundColor: viewModel.errorMessage != null ? Colors.red : Colors.green,
                  ),
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
    String tableName = '';
    if (type == BettingTableType.xien) tableName = 'xiên';
    else if (type == BettingTableType.cycle) tableName = 'chu kỳ';
    else if (type == BettingTableType.trung) tableName = 'Miền Trung';
    else if (type == BettingTableType.bac) tableName = 'Miền Bắc';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận'),
        content: Text(
          'Bạn có chắc muốn tạo lại bảng cược $tableName? '
          'Bảng hiện tại sẽ bị ghi đè.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final config = context.read<SettingsViewModel>().config;
              await viewModel.regenerateTable(type, config);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(viewModel.errorMessage ?? 'Tạo bảng thành công!'),
                    backgroundColor: viewModel.errorMessage != null ? Colors.red : Colors.green,
                  ),
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
    String tableName = '';
    if (type == BettingTableType.xien) tableName = 'xiên';
    else if (type == BettingTableType.cycle) tableName = 'chu kỳ';
    else if (type == BettingTableType.trung) tableName = 'Miền Trung';
    else if (type == BettingTableType.bac) tableName = 'Miền Bắc';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận'),
        content: Text('Gửi bảng cược $tableName qua Telegram?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await viewModel.sendToTelegram(type);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(viewModel.errorMessage ?? 'Gửi thành công!'),
                    backgroundColor: viewModel.errorMessage != null ? Colors.red : Colors.green,
                  ),
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