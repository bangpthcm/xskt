// lib/presentation/screens/betting/betting_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/models/betting_row.dart';
import '../../widgets/responsive_data_table.dart';
import 'betting_viewmodel.dart';

class BettingDetailScreen extends StatefulWidget {
  final int initialTab;

  const BettingDetailScreen({
    super.key,
    this.initialTab = 0,
  });

  @override
  State<BettingDetailScreen> createState() => _BettingDetailScreenState();
}

class _BettingDetailScreenState extends State<BettingDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // ✅ TĂNG LENGTH LÊN 5
    _tabController = TabController(
      length: 5,
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
        title: const Text('Bảng cược chi tiết'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Tất cả'),
            Tab(text: 'Nam'), // ✅ THÊM TAB NAM
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
              _buildNamTab(viewModel), // ✅ THÊM VIEW NAM
              _buildTrungTab(viewModel),
              _buildBacTab(viewModel),
              _buildXienTab(viewModel),
            ],
          );
        },
      ),
    );
  }

  // ... (Giữ nguyên _buildCycleTab)
  Widget _buildCycleTab(BettingViewModel viewModel) {
    if (viewModel.cycleTable == null) {
      return RefreshIndicator(
        onRefresh: () async {
          await viewModel.loadBettingTables();
        },
        child: ListView(
          children: const [
            Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: Text('Chưa có bảng cược chu kỳ')),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async {
        await viewModel.loadBettingTables();
      },
      child: ListView(
        children: [
          _buildMetadataCard(viewModel.cycleMetadata!),
          _buildCycleDataTable(viewModel.cycleTable!),
          _buildActionButtons(viewModel, BettingTableType.cycle),
        ],
      ),
    );
  }

  // ✅ THÊM HÀM BUILD TAB NAM
  Widget _buildNamTab(BettingViewModel viewModel) {
    if (viewModel.namTable == null) {
      return RefreshIndicator(
        onRefresh: () async {
          await viewModel.loadBettingTables();
        },
        child: ListView(
          children: const [
            Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: Text('Chưa có bảng cược Miền Nam')),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async {
        await viewModel.loadBettingTables();
      },
      child: ListView(
        children: [
          // Lưu ý: Cần đảm bảo namMetadata không null khi namTable không null (Logic ViewModel đã lo việc này)
          _buildMetadataCard(viewModel.namMetadata!),
          _buildCycleDataTable(viewModel.namTable!),
          _buildActionButtons(viewModel, BettingTableType.nam),
        ],
      ),
    );
  }

  Widget _buildTrungTab(BettingViewModel viewModel) {
    if (viewModel.trungTable == null) {
      return RefreshIndicator(
        onRefresh: () async {
          await viewModel.loadBettingTables();
        },
        child: ListView(
          children: const [
            Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: Text('Chưa có bảng cược Miền Trung')),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async {
        await viewModel.loadBettingTables();
      },
      child: ListView(
        children: [
          _buildMetadataCard(viewModel.trungMetadata!),
          _buildCycleDataTable(viewModel.trungTable!),
          _buildActionButtons(viewModel, BettingTableType.trung),
        ],
      ),
    );
  }

  Widget _buildBacTab(BettingViewModel viewModel) {
    if (viewModel.bacTable == null) {
      return RefreshIndicator(
        onRefresh: () async {
          await viewModel.loadBettingTables();
        },
        child: ListView(
          children: const [
            Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: Text('Chưa có bảng cược Miền Bắc')),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async {
        await viewModel.loadBettingTables();
      },
      child: ListView(
        children: [
          _buildMetadataCard(viewModel.bacMetadata!),
          _buildCycleDataTable(viewModel.bacTable!),
          _buildActionButtons(viewModel, BettingTableType.bac),
        ],
      ),
    );
  }

  Widget _buildXienTab(BettingViewModel viewModel) {
    if (viewModel.xienTable == null) {
      return RefreshIndicator(
        onRefresh: () async {
          await viewModel.loadBettingTables();
        },
        child: ListView(
          children: const [
            Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: Text('Chưa có bảng cược xiên')),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async {
        await viewModel.loadBettingTables();
      },
      child: ListView(
        children: [
          _buildMetadataCard(viewModel.xienMetadata!),
          _buildXienDataTable(viewModel.xienTable!),
          _buildActionButtons(viewModel, BettingTableType.xien),
        ],
      ),
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
            _buildMetadataRow(
                'Số ngày gan:', metadata['so_ngay_gan']?.toString() ?? '-'),
            _buildMetadataRow(
                'Lần cuối về:', metadata['lan_cuoi_ve']?.toString() ?? '-'),
            if (metadata.containsKey('cap_so_muc_tieu'))
              _buildMetadataRow(
                  'Cặp số:', metadata['cap_so_muc_tieu']?.toString() ?? '-'),
            if (metadata.containsKey('so_muc_tieu'))
              _buildMetadataRow(
                  'Số mục tiêu:', metadata['so_muc_tieu']?.toString() ?? '-'),
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
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 16))),
        ],
      ),
    );
  }

  Widget _buildCycleDataTable(List<BettingRow> table) {
    return ResponsiveDataTable(
      rows: table,
      isCycleTable: true,
    );
  }

  Widget _buildXienDataTable(List<BettingRow> table) {
    return ResponsiveDataTable(
      rows: table,
      isCycleTable: false,
    );
  }

  Widget _buildActionButtons(
      BettingViewModel viewModel, BettingTableType type) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _showDeleteDialog(context, viewModel, type),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Xóa bảng cược'),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    Theme.of(context).primaryColor.withOpacity(0.1),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () =>
                  _showSendTelegramDialog(context, viewModel, type),
              icon: const Icon(Icons.send),
              label: const Text('Gửi Telegram'),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    Theme.of(context).primaryColor.withOpacity(0.1),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ CẬP NHẬT LOGIC TÊN BẢNG (THÊM NAM)
  void _showDeleteDialog(
      BuildContext context, BettingViewModel viewModel, BettingTableType type) {
    String tableName = '';
    switch (type) {
      case BettingTableType.xien:
        tableName = 'xiên';
        break;
      case BettingTableType.cycle:
        tableName = 'chu kỳ (Tất cả)';
        break;
      case BettingTableType.nam:
        tableName = 'Miền Nam';
        break;
      case BettingTableType.trung:
        tableName = 'Miền Trung';
        break;
      case BettingTableType.bac:
        tableName = 'Miền Bắc';
        break;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text(
            'Bạn có chắc muốn xóa bảng cược $tableName?\n\nDữ liệu sẽ bị xóa khỏi Google Sheet và không thể khôi phục.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await viewModel.deleteTable(type);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(
                          viewModel.errorMessage ?? 'Xóa bảng thành công!'),
                      backgroundColor: viewModel.errorMessage != null
                          ? Colors.red
                          : Colors.green),
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

  // ✅ CẬP NHẬT LOGIC TÊN BẢNG (THÊM NAM)
  void _showSendTelegramDialog(
      BuildContext context, BettingViewModel viewModel, BettingTableType type) {
    String tableName = '';
    switch (type) {
      case BettingTableType.xien:
        tableName = 'xiên';
        break;
      case BettingTableType.cycle:
        tableName = 'chu kỳ (Tất cả)';
        break;
      case BettingTableType.nam:
        tableName = 'Miền Nam';
        break;
      case BettingTableType.trung:
        tableName = 'Miền Trung';
        break;
      case BettingTableType.bac:
        tableName = 'Miền Bắc';
        break;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận'),
        content: Text('Gửi bảng cược $tableName qua Telegram?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await viewModel.sendToTelegram(type);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content:
                          Text(viewModel.errorMessage ?? 'Gửi thành công!'),
                      backgroundColor: viewModel.errorMessage != null
                          ? Colors.red
                          : Colors.green),
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
