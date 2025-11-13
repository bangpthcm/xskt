// lib/presentation/screens/betting/betting_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'betting_viewmodel.dart';
import 'betting_detail_screen.dart';
import '../../../core/utils/number_utils.dart';
import '../../../data/models/betting_row.dart';
import '../../widgets/empty_state_widget.dart';
import '../../navigation/main_navigation.dart';
import '../../widgets/shimmer_loading.dart';
import '../home/home_screen.dart'; 

class BettingScreen extends StatefulWidget {
  const BettingScreen({Key? key}) : super(key: key);

  @override
  State<BettingScreen> createState() => _BettingScreenState();
}

class _BettingScreenState extends State<BettingScreen> {
  @override
  void initState() {
    super.initState();
    
    // ✅ FIX: Đợi services init xong rồi mới load
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final viewModel = context.read<BettingViewModel>();
      
      // ✅ Đợi 500ms cho services init (từ app.dart)
      await Future.delayed(const Duration(milliseconds: 800));
      
      // ✅ Check xem services đã init chưa
      try {
        await viewModel.loadBettingTables();
      } catch (e) {
        print('⚠️ First load failed (services not ready), retrying...');
        
        // ✅ Retry sau 1s nữa
        await Future.delayed(const Duration(seconds: 1));
        
        if (mounted) {
          viewModel.loadBettingTables();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<BettingViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.isLoading) {
            return const ShimmerLoading(type: ShimmerType.card);  // ✅ ĐỔI từ CircularProgressIndicator
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

          return RefreshIndicator(
            onRefresh: () async {
              HapticFeedback.mediumImpact();
              await viewModel.loadBettingTables();
              if (viewModel.errorMessage == null) {
                HapticFeedback.lightImpact();
              }
            },

            color: Colors.grey.shade200,
            backgroundColor: const Color(0xFF1E1E1E),
            strokeWidth: 3.0,
            displacement: 40,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 45, 16, 16),
              children: [
                _buildWarningCard(context, viewModel),
                const SizedBox(height: 16),
                _buildCycleCard(context, viewModel),
                const SizedBox(height: 16),
                _buildXienCard(context, viewModel),
              ],
            ),
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
              Icon(Icons.warning_amber_rounded, color: Theme.of(context).primaryColor, size: 32),
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
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Nhấn để xem chi tiết',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).primaryColor.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Theme.of(context).primaryColor),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ THẺ CHU KỲ (CÓ BẢNG RÚT GỌN)
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

    // ✅ FIX: Format ngày KHÔNG có số 0 đứng trước (khớp với Google Sheets)
    final now = DateTime.now();
    final today = '${now.day.toString().padLeft(2, '0')}/${now.month}/${now.year}';
    final todayCycleRows = _getTodayCycleRows(viewModel, today);
    
    // ✅ DEBUG LOG
    print('🔍 Today: $today');
    print('🔍 Cycle rows today: ${todayCycleRows.length}');
    if (viewModel.cycleTable != null && viewModel.cycleTable!.isNotEmpty) {
      print('🔍 Sample dates from cycleTable: ${viewModel.cycleTable!.take(3).map((r) => r.ngay).join(", ")}');
    }

    // ✅ CHECK: NẾU KHÔNG CÓ BẢNG NÀO THÌ HIỂN THỊ MESSAGE
    final hasAnyTable = viewModel.cycleTable != null || 
                        viewModel.trungTable != null || 
                        viewModel.bacTable != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Chu kỳ 00-99',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HomeScreen(),
                      ),
                    );
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.live_tv,
                        color: Theme.of(context).primaryColor.withOpacity(0.8),
                        size: 33,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(color: Colors.grey),
            
            // ✅ NẾU KHÔNG CÓ BẢNG
            if (!hasAnyTable)
              EmptyStateWidget(  // ✅ ĐỔI từ Center(child: Text(...))
                title: 'Chưa có bảng cược',
                message: 'Hãy phân tích và tạo bảng cược chu kỳ đầu tiên',
                onAction: () {
                  // Navigate to analysis tab
                  final mainNav = context.findAncestorStateOfType<MainNavigationState>();
                  mainNav?.switchToTab(0);
                },
                actionLabel: 'Đi đến Phân tích',
              )
            else ...[
              _buildInfoRow(
                icon: Icons.monetization_on,
                label: 'Tổng tiền Chu kỳ',
                value: NumberUtils.formatCurrency(tongTienChuKy),
                valueColor: Colors.grey,
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 36),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• Tất cả: ${NumberUtils.formatCurrency(tongTienTatCa)}',
                        style: const TextStyle(color: Colors.grey, fontSize: 14)),
                    Text('• Miền Trung: ${NumberUtils.formatCurrency(tongTienTrung)}',
                        style: const TextStyle(color: Colors.grey, fontSize: 14)),
                    Text('• Miền Bắc: ${NumberUtils.formatCurrency(tongTienBac)}',
                        style: const TextStyle(color: Colors.grey, fontSize: 14)),
                  ],
                ),
              ),

              // ✅ HIỂN THỊ BẢNG HÔM NAY (LUÔN HIỂN THỊ, KHÔNG CẦN CHECK isEmpty)
              const SizedBox(height: 16),
              const Divider(color: Colors.grey),
              const SizedBox(height: 8),
              Text(
                'Bảng cược hôm nay ($today):',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 12),
              
              // ✅ NẾU CÓ DỮ LIỆU → HIỂN THỊ BẢNG
              if (todayCycleRows.isNotEmpty)
                _buildMiniTable(todayCycleRows, isCycle: true)
              else
                // ✅ NẾU KHÔNG CÓ DỮ LIỆU HÔM NAY → MESSAGE
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    border: Border.all(color: Colors.grey.shade800),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      'Chưa có bảng cược cho ngày hôm nay',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),

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
          ],
        ),
      ),
    );
  }

  // ✅ THẺ XIÊN (CÓ BẢNG RÚT GỌN)
  Widget _buildXienCard(BuildContext context, BettingViewModel viewModel) {
    final tongTienXien = viewModel.xienTable?.isNotEmpty == true
        ? viewModel.xienTable!.last.tongTien
        : 0.0;

    final today = DateFormat('dd/MM/yyyy').format(DateTime.now());
    final todayXienRows = viewModel.xienTable
        ?.where((r) => r.ngay == today)
        .toList() ?? [];
    
    // ✅ DEBUG LOG
    print('🔍 Xien rows today: ${todayXienRows.length}');
    if (viewModel.xienTable != null && viewModel.xienTable!.isNotEmpty) {
      print('🔍 Sample dates from xienTable: ${viewModel.xienTable!.take(3).map((r) => r.ngay).join(", ")}');
    }

    // ✅ CHECK: NẾU KHÔNG CÓ BẢNG XIÊN
    final hasXienTable = viewModel.xienTable != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Cặp xiên Bắc',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const Divider(color: Colors.grey),
            
            // ✅ NẾU KHÔNG CÓ BẢNG
            if (!hasXienTable)
              EmptyStateWidget(
                title: 'Chưa có bảng xiên',
                message: 'Hãy phân tích và tạo bảng cược xiên đầu tiên',
                onAction: () {
                  final mainNav = context.findAncestorStateOfType<MainNavigationState>();
                  mainNav?.switchToTab(0);
                },
                actionLabel: 'Đi đến Phân tích',
              )
            else ...[
              _buildInfoRow(
                icon: Icons.monetization_on,
                label: 'Tổng tiền Xiên',
                value: NumberUtils.formatCurrency(tongTienXien),
                valueColor: Colors.grey,
              ),

              // ✅ HIỂN THỊ BẢNG HÔM NAY (LUÔN HIỂN THỊ)
              const SizedBox(height: 16),
              const Divider(color: Colors.grey),
              const SizedBox(height: 8),
              Text(
                'Bảng cược hôm nay ($today):',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 12),
              
              // ✅ NẾU CÓ DỮ LIỆU → HIỂN THỊ BẢNG
              if (todayXienRows.isNotEmpty)
                _buildMiniTable(todayXienRows, isCycle: false)
              else
                // ✅ NẾU KHÔNG CÓ DỮ LIỆU HÔM NAY → MESSAGE
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    border: Border.all(color: Colors.grey.shade800),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      'Chưa có bảng cược cho ngày hôm nay',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),

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

  // ✅ BẢNG RÚT GỌN (MINI TABLE)
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
                  flex: 4,
                  child: Text('Ngày', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
                const Expanded(
                  flex: 3,
                  child: Text('Miền', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
                const Expanded(
                  flex: 3,
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
                    flex: 4,
                    child: Text(row.ngay, style: const TextStyle(fontSize: 13, color: Colors.white)),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(row.mien, style: const TextStyle(fontSize: 13, color: Colors.white)),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(row.so, style: TextStyle(fontSize: 13, color: Colors.white)),
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
                        color: Colors.white,
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