// lib/presentation/screens/betting/betting_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'betting_viewmodel.dart';
import 'betting_detail_screen.dart';
import '../../../core/utils/number_utils.dart';
import '../../../data/models/betting_row.dart';

class BettingScreen extends StatefulWidget {
  const BettingScreen({Key? key}) : super(key: key);

  @override
  State<BettingScreen> createState() => _BettingScreenState();
}

class _BettingScreenState extends State<BettingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BettingViewModel>().loadBettingTables();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bảng cược'),
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

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildWarningCard(context, viewModel),
              const SizedBox(height: 16),
              _buildCycleCard(context, viewModel),
              const SizedBox(height: 16),
              _buildXienCard(context, viewModel),
            ],
          );
        },
      ),
    );
  }

  // ✅ THẺ CẢNH BÁO
  Widget _buildWarningCard(BuildContext context, BettingViewModel viewModel) {
    final tongTienTatCa = viewModel.cycleTable?.isNotEmpty == true 
        ? viewModel.cycleTable!.last.tongTien 
        : 0.0;
    final tongTienTrung = viewModel.trungTable?.isNotEmpty == true
        ? viewModel.trungTable!.last.tongTien
        : 0.0;
    final tongTienBac = viewModel.bacTable?.isNotEmpty == true
        ? viewModel.bacTable!.last.tongTien
        : 0.0;
    final tongTienXien = viewModel.xienTable?.isNotEmpty == true
        ? viewModel.xienTable!.last.tongTien
        : 0.0;

    final tongTienChuKy = tongTienTatCa + tongTienTrung + tongTienBac;
    final tongTienTongQuat = tongTienChuKy + tongTienXien;

    return Card(
      color: const Color(0xFF2C2C2C),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const BettingDetailScreen(initialTab: 0),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange.shade400, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tổng tiền: ${NumberUtils.formatCurrency(tongTienTongQuat)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade400,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Nhấn để xem chi tiết',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.orange.shade400,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.orange.shade400),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ THẺ CHU KỲ
  Widget _buildCycleCard(BuildContext context, BettingViewModel viewModel) {
    final tongTienTatCa = viewModel.cycleTable?.isNotEmpty == true 
        ? viewModel.cycleTable!.last.tongTien 
        : 0.0;
    final tongTienTrung = viewModel.trungTable?.isNotEmpty == true
        ? viewModel.trungTable!.last.tongTien
        : 0.0;
    final tongTienBac = viewModel.bacTable?.isNotEmpty == true
        ? viewModel.bacTable!.last.tongTien
        : 0.0;
    final tongTienChuKy = tongTienTatCa + tongTienTrung + tongTienBac;

    final today = DateFormat('dd/MM/yyyy').format(DateTime.now());
    final todayCycleRows = _getTodayCycleRows(viewModel, today);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
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
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Chu kỳ 00-99',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const Divider(),
            
            _buildInfoRow(
              icon: Icons.monetization_on,
              label: 'Tổng tiền Chu kỳ',
              value: NumberUtils.formatCurrency(tongTienChuKy),
              valueColor: Colors.white,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• Tất cả: ${NumberUtils.formatCurrency(tongTienTatCa)}',
                      style: const TextStyle(fontSize: 14)),
                  Text('• Miền Trung: ${NumberUtils.formatCurrency(tongTienTrung)}',
                      style: const TextStyle(fontSize: 14)),
                  Text('• Miền Bắc: ${NumberUtils.formatCurrency(tongTienBac)}',
                      style: const TextStyle(fontSize: 14)),
                ],
              ),
            ),

            if (todayCycleRows.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Bảng cược hôm nay ($today):',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 12),
              _buildMiniTable(todayCycleRows, isCycle: true),
            ],

            const SizedBox(height: 16),
            Center(
              child: TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const BettingDetailScreen(initialTab: 0),
                    ),
                  );
                },
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Xem chi tiết'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ THẺ XIÊN
  Widget _buildXienCard(BuildContext context, BettingViewModel viewModel) {
    final tongTienXien = viewModel.xienTable?.isNotEmpty == true
        ? viewModel.xienTable!.last.tongTien
        : 0.0;

    final today = DateFormat('dd/MM/yyyy').format(DateTime.now());
    final todayXienRows = viewModel.xienTable
        ?.where((r) => r.ngay == today)
        .toList() ?? [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // ✅ THAY ICON BẰNG CHỮ X
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Center(
                        child: Text(
                          'X',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF45B7B7),
                            height: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Cặp xiên Bắc',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const Divider(),
            
            _buildInfoRow(
              icon: Icons.monetization_on,
              label: 'Tổng tiền Xiên',
              value: NumberUtils.formatCurrency(tongTienXien),
              valueColor: Colors.white,
            ),

            if (todayXienRows.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Bảng cược hôm nay ($today):',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 12),
              _buildMiniTable(todayXienRows, isCycle: false),
            ],

            const SizedBox(height: 16),
            Center(
              child: TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const BettingDetailScreen(initialTab: 3),
                    ),
                  );
                },
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Xem chi tiết'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<BettingRow> _getTodayCycleRows(BettingViewModel viewModel, String today) {
    final todayCycleRows = <BettingRow>[
      ...viewModel.cycleTable?.where((r) => r.ngay == today) ?? [],
      ...viewModel.trungTable?.where((r) => r.ngay == today) ?? [],
      ...viewModel.bacTable?.where((r) => r.ngay == today) ?? [],
    ];

    todayCycleRows.sort((a, b) {
      const mienOrder = {'Nam': 1, 'Trung': 2, 'Bắc': 3};
      final mienCompare = (mienOrder[a.mien] ?? 0).compareTo(mienOrder[b.mien] ?? 0);
      return mienCompare;
    });

    return todayCycleRows;
  }

  Widget _buildMiniTable(List<BettingRow> rows, {required bool isCycle}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        border: Border.all(color: Colors.grey.shade800),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF2C2C2C),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                const Expanded(
                  flex: 2,
                  child: Text('Ngày', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
                const Expanded(
                  flex: 2,
                  child: Text('Miền', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
                const Expanded(
                  flex: 2,
                  child: Text('Số', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    isCycle ? 'Cược/số' : 'Cược',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
          ...rows.asMap().entries.map((entry) {
            final index = entry.key;
            final row = entry.value;
            final isEven = index % 2 == 0;

            return Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              color: isEven ? const Color(0xFF1E1E1E) : const Color(0xFF252525),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(row.ngay, style: const TextStyle(fontSize: 13, color: Colors.white)),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(row.mien, style: const TextStyle(fontSize: 13, color: Colors.white)),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(row.so, style: const TextStyle(fontSize: 13, color: Colors.orange)),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      isCycle 
                          ? NumberUtils.formatCurrency(row.cuocSo ?? 0)
                          : NumberUtils.formatCurrency(row.cuocMien),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: valueColor ?? Colors.black,
          ),
        ),
      ],
    );
  }
}