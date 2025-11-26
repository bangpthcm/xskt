// lib/presentation/screens/betting/betting_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'betting_viewmodel.dart';
import 'select_account_screen.dart';
import 'betting_detail_screen.dart';
import '../../../core/utils/number_utils.dart';
import '../../../data/models/betting_row.dart';
import '../../widgets/empty_state_widget.dart';
import '../../navigation/main_navigation.dart';
import '../../widgets/shimmer_loading.dart';
import '../../../app.dart';
import '../settings/settings_viewmodel.dart';
import 'select_account_screen.dart';
import '../../../data/models/app_config.dart';
import '../home/home_screen.dart';
import '../../../data/services/service_manager.dart'; 

class BettingScreen extends StatefulWidget {
  const BettingScreen({Key? key}) : super(key: key);

  @override
  State<BettingScreen> createState() => _BettingScreenState();
}

class _BettingScreenState extends State<BettingScreen> {
  @override
  void initState() {
    super.initState();
    
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        print('📊 BettingScreen: Waiting for services...');
        await ServiceManager.waitForReady();
        print('📊 BettingScreen: Services ready, loading tables...');
        
        if (mounted) {
          await context.read<BettingViewModel>().loadBettingTables();
        }
        
      } catch (e) {
        print('❌ BettingScreen: Error loading: $e');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Không thể kết nối. Vui lòng pull-to-refresh'),
              action: SnackBarAction(
                label: 'Thử lại',
                onPressed: () {
                  context.read<BettingViewModel>().loadBettingTables();
                },
              ),
            ),
          );
        }
      }
    });
  }

  void _showBettingOptionsDialog(BuildContext context) {
    try {
      final settingsVM = context.read<SettingsViewModel>();
      final config = settingsVM.config;
      
      final validAccounts = config.apiAccounts
          .where((a) => a.username.isNotEmpty && a.password.isNotEmpty)
          .toList();

      if (validAccounts.isEmpty) {
        showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Chưa có tài khoản'),
            content: const Text(
              'Vui lòng cấu hình tài khoản Betting trong Settings → Tài khoản API',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('OK'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  mainNavigationKey.currentState?.switchToTab(3);
                },
                child: const Text('Đi đến Settings'),
              ),
            ],
          ),
        );
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SelectAccountScreen(
            accounts: validAccounts,
          ),
        ),
      );
    } catch (e) {
      print('❌ Error opening betting: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ✅ SHOW BẢNG TÓM TẮT TRONG BOTTOM SHEET (KẾT HỢP CHU KỲ + XIÊN)
  void _showSummaryTable(BuildContext context, BettingViewModel viewModel) {
    final now = DateTime.now();
    final today = '${now.day.toString().padLeft(2, '0')}/${now.month}/${now.year}';
    
    // Lấy dữ liệu chu kỳ + xiên hôm nay
    final todayCycleRows = _getTodayCycleRows(viewModel, today);
    final todayXienRows = viewModel.xienTable
        ?.where((r) => r.ngay == today)
        .toList() ?? [];

    // ✅ KẾT HỢP 2 BẢNG THÀNH 1
    final allRows = <BettingRow>[...todayCycleRows, ...todayXienRows];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.3,
        minChildSize: 0.25,
        maxChildSize: 0.8,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade600,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Content - BẢNG KẾT HỢP
              Expanded(
                child: allRows.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inbox_outlined,
                                size: 64,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Chưa có bảng cược cho ngày hôm nay',
                                style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.all(12),
                        children: [
                          _buildUnifiedTable(allRows),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ✅ APPBAR VỚI NÚT XEM BẢNG TÓM TẮT
      appBar: AppBar(
        title: const Text('Bảng cược'),
        centerTitle: false,
        actions: [
          Consumer<BettingViewModel>(
            builder: (context, viewModel, child) {
              final now = DateTime.now();
              final today = '${now.day.toString().padLeft(2, '0')}/${now.month}/${now.year}';
              
              final todayCycleRows = _getTodayCycleRows(viewModel, today);
              final todayXienRows = viewModel.xienTable
                  ?.where((r) => r.ngay == today)
                  .toList() ?? [];
              
              final totalRows = todayCycleRows.length + todayXienRows.length;
              
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.table_chart),
                    tooltip: 'Xem bảng tóm tắt',
                    onPressed: totalRows > 0 
                        ? () => _showSummaryTable(context, viewModel)
                        : null,
                  ),
                  if (totalRows > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Text(
                          totalRows.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      
      body: Consumer<BettingViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.isLoading) {
            return const ShimmerLoading(type: ShimmerType.card);
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
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                        'Nhấn đề xem chi tiết',
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
            const SizedBox(height: 16),
            const Divider(color: Colors.grey),
            const SizedBox(height: 16),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showBettingOptionsDialog(context),
                icon: const Icon(Icons.open_in_browser),
                label: const Text('Mở Betting'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

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

    final now = DateTime.now();
    final today = '${now.day.toString().padLeft(2, '0')}/${now.month}/${now.year}';
    final todayCycleRows = _getTodayCycleRows(viewModel, today);
    
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
            
            if (!hasAnyTable)
              EmptyStateWidget(
                title: 'Chưa có bảng cược',
                message: 'Hãy phân tích và tạo bảng cược chu kỳ đầu tiên',
                onAction: () {
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

              const SizedBox(height: 8),
              Text(
                'Bảng cược hôm nay ($today):',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 12),
              
              if (todayCycleRows.isNotEmpty)
                _buildMiniTable(todayCycleRows, isCycle: true)
              else
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

  Widget _buildXienCard(BuildContext context, BettingViewModel viewModel) {
    final tongTienXien = viewModel.xienTable?.isNotEmpty == true
        ? viewModel.xienTable!.last.tongTien
        : 0.0;

    final today = DateFormat('dd/MM/yyyy').format(DateTime.now());
    final todayXienRows = viewModel.xienTable
        ?.where((r) => r.ngay == today)
        .toList() ?? [];
    
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

              const SizedBox(height: 8),
              Text(
                'Bảng cược hôm nay ($today):',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 12),
              
              if (todayXienRows.isNotEmpty)
                _buildMiniTable(todayXienRows, isCycle: false)
              else
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

  // ✅ BẢNG THỐNG NHẤT (KẾT HỢP CHU KỲ + XIÊN)
  Widget _buildUnifiedTable(List<BettingRow> rows) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade800),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF2C2C2C),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: const [
                Expanded(
                  flex: 4,
                  child: Text(
                    'Ngày',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Miền',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Text(
                    'Số',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Text(
                    'Cược/số',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
          
          // Rows
          ...rows.asMap().entries.map((entry) {
            final index = entry.key;
            final row = entry.value;
            final isEven = index % 2 == 0;
            
            // ✅ Xác định loại cược: Chu kỳ (có cuocSo và > 0) hoặc Xiên (cuocSo null hoặc = 0)
            final isCycleRow = row.cuocSo != null && row.cuocSo! > 0;
            final cuocValue = isCycleRow ? row.cuocSo! : row.cuocMien;

            return Container(
              padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 12),
              color: isEven ? const Color(0xFF1E1E1E) : const Color(0xFF252525),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Text(
                      row.ngay,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      row.mien,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Text(
                      row.so,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Text(
                      NumberUtils.formatCurrency(cuocValue),
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

  Widget _buildMiniTable(List<BettingRow> rows, {required bool isCycle}) {
    return Container(
      decoration: BoxDecoration(
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
                    child: Text(row.so, style: const TextStyle(fontSize: 13, color: Colors.white)),
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