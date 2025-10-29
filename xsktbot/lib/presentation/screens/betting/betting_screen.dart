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
    with TickerProviderStateMixin {
  late TabController _mainTabController;
  late TabController _cycleSubTabController;

  @override
  void initState() {
    super.initState();
    _mainTabController = TabController(length: 2, vsync: this);
    _cycleSubTabController = TabController(length: 4, vsync: this);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BettingViewModel>().loadBettingTables();
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
        title: const Text('Bảng cược'),
        bottom: TabBar(
          controller: _mainTabController,
          tabs: const [
            Tab(text: 'Xiên'),
            Tab(text: 'Chu kỳ'),
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

  Widget _buildCycleMainTab(BettingViewModel viewModel) {
    return Column(
      children: [
        Container(
          color: Color(0xFF1E1E1E),
          child: TabBar(
            controller: _cycleSubTabController,
            isScrollable: true,
            labelColor: Colors.deepPurple.shade100,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.deepPurple.shade100,
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
      color: const Color(0xFF1E1E1E),
      child: DataTable2(
        columnSpacing: 12,
        horizontalMargin: 12,
        minWidth: 600,
        headingTextStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
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
            return null; // Sử dụng màu mặc định
          },
        ),
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E), // ✅ Dark table background
        ),
        columns: [
          DataColumn2(
            label: Center(child: Text('STT')),
            size: ColumnSize.S,
            fixedWidth: 30,
          ),
          DataColumn2(
            label: Center(child: Text('Ngày')),
            size: ColumnSize.M,
            fixedWidth: 100,
          ),
          DataColumn2(
            label: Center(child: Text('Miền')),
            size: ColumnSize.S,
            fixedWidth: 60,
          ),
          DataColumn2(
            label: Center(child: Text('Số')),
            size: ColumnSize.S,
            fixedWidth: 50,
          ),
          DataColumn2(
            label: Align(
              alignment: Alignment.centerRight,
              child: Text('Cược'),
            ),
            size: ColumnSize.M,
              fixedWidth: 70,
          ),
          DataColumn2(
            label: Align(
              alignment: Alignment.centerRight,
              child: Text('Tổng tiền'),
            ),
            size: ColumnSize.M,
          ),
          DataColumn2(
            label: Align(
              alignment: Alignment.centerRight,
              child: Text('Lời'),
            ),
            size: ColumnSize.M,
          ),
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
              DataCell(
                Center(child: Text(row.stt.toString()))),
              DataCell(
                Center(child: Text(row.ngay))),
              DataCell(
                Center(child: Text(row.mien))),
              DataCell(
                Center(child: Text(row.so))),
              DataCell(
                Align(
                  alignment: Alignment.centerRight,
                  child:Text(
                    NumberUtils.formatCurrency(row.cuocMien),
                    style: TextStyle(  
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              DataCell(
                Align(
                  alignment: Alignment.centerRight,
                  child:Text(NumberUtils.formatCurrency(row.tongTien)),
                ),
              ),
              DataCell(
                Align(
                  alignment: Alignment.centerRight,
                  child:Text(
                    NumberUtils.formatCurrency(row.loi1So),
                    style: TextStyle(
                      color: row.loi1So > 0 ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
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
      color: const Color(0xFF1E1E1E),
      child: DataTable2(
        columnSpacing: 12,
        horizontalMargin: 12,
        minWidth: 600,
        headingTextStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
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
            return null; // Sử dụng màu mặc định
          },
        ),
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E), // ✅ Dark table background
        ),
        columns: [
          DataColumn2(
            label: Center(child: Text('STT')),
            size: ColumnSize.S,
            fixedWidth: 30,
          ),
          DataColumn2(
            label: Center(child: Text('Ngày')),
            size: ColumnSize.M,
            fixedWidth: 100,
          ),
          DataColumn2(
            label: Center(child: Text('Miền')),
            size: ColumnSize.S,
            fixedWidth: 60,
          ),
          DataColumn2(
            label: Center(child: Text('Số')),
            size: ColumnSize.S,
            fixedWidth: 50,
          ),
          DataColumn2(
            label: Center(child: Text('Cược/Số')),
            size: ColumnSize.S,
            fixedWidth: 70,
            ),
          DataColumn2(
            label: Align(
              alignment: Alignment.centerRight,
              child: Text('Cược/miền'),
            ),
            size: ColumnSize.M,
          ),
          DataColumn2(
            label: Align(
              alignment: Alignment.centerRight,
              child: Text('Tổng tiền'),
            ),
            size: ColumnSize.M,
          ),
          DataColumn2(
            label: Align(
              alignment: Alignment.centerRight,
              child: Text('Lời (1 số)'),
            ),
            size: ColumnSize.M,
          ),
          DataColumn2(
            label: Align(
              alignment: Alignment.centerRight,
              child: Text('Lời (2 số)'),
            ),
            size: ColumnSize.M,
          ),
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
              DataCell(
                Center(child: Text(row.stt.toString())),
              ),
              DataCell(
                Center(child: Text(row.ngay)),
              ),
              DataCell(
                Center(child: Text(row.mien)),
              ),
              DataCell(
                Center(child: Text(row.so)),
              ),
              DataCell(
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    NumberUtils.formatCurrency(row.cuocSo),
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              DataCell(
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(NumberUtils.formatCurrency(row.cuocMien)),
                ),
              ),
              DataCell(
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(NumberUtils.formatCurrency(row.tongTien)),
                ),
              ),
              DataCell(
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    NumberUtils.formatCurrency(row.loi1So),
                    style: TextStyle(
                      color: row.loi1So > 0 ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              DataCell(
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    NumberUtils.formatCurrency(row.loi2So ?? 0),
                    style: TextStyle(
                      color: (row.loi2So ?? 0) > 0 ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
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
        color: Color(0xFF121212),
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
                  label: const Text('Tạo lại',style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.orange,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showSendTelegramDialog(context, viewModel, type),
                  icon: const Icon(Icons.send),
                  label: const Text('Gửi Telegram',style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blue,
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