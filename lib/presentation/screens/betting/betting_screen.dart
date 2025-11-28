// lib/presentation/screens/betting/betting_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'betting_viewmodel.dart';
import 'select_account_screen.dart';
import 'betting_detail_screen.dart';
import '../../../core/utils/number_utils.dart';
import '../../../data/models/betting_row.dart';
import '../../widgets/shimmer_loading.dart';
import '../../../app.dart';
import '../settings/settings_viewmodel.dart';
import '../../../data/models/api_account.dart';
import '../../../data/services/betting_api_service.dart';
import '../home/home_screen.dart';
import '../../../data/services/service_manager.dart'; 

class BettingScreen extends StatefulWidget {
  const BettingScreen({super.key});

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
          // ✅ Load config từ Settings trước
          await context.read<SettingsViewModel>().loadConfig();
          
          // ✅ Sau đó load betting tables
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

  // ✅ ĐỔI: Đọc tài khoản từ SettingsViewModel
  // ✅ THÊM: Nếu chỉ 1 tài khoản, tự động vào không cần chọn
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

      // ✅ THÊM: Nếu chỉ có 1 tài khoản, tự động vào
      if (validAccounts.length == 1) {
        print('✅ Chỉ có 1 tài khoản, tự động vào: ${validAccounts[0].username}');
        _navigateToBettingWebView(context, validAccounts[0], config.betting.domain);
        return;
      }

      // ✅ Nếu > 1 tài khoản, hiển thị dialog chọn
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SelectAccountScreen(
            accounts: validAccounts,
            domain: config.betting.domain,
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

  // ✅ THÊM: Hàm xử lý xác thực và vào WebView
  Future<void> _navigateToBettingWebView(
    BuildContext context,
    ApiAccount account,
    String domain,
  ) async {
    try {
      print('🔐 Authenticating: ${account.username}');
      
      final apiService = BettingApiService();
      final token = await apiService.authenticateAndGetToken(account, domain);

      if (!mounted) return;

      if (token != null && token.isNotEmpty) {
        print('✅ Token received, opening WebView...');

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BettingWebViewScreen(
                token: token,
                accountUsername: account.username,
                domain: domain,
              ),
            ),
          );
        }
      } else {
        print('❌ Failed to get token');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Xác thực thất bại. Vui lòng thử lại.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showSummaryTable(BuildContext context, BettingViewModel viewModel) {
    final now = DateTime.now();
    final today = '${now.day.toString().padLeft(2, '0')}/${now.month}/${now.year}';
    
    final todayCycleRows = _getTodayCycleRows(viewModel, today);
    final todayXienRows = viewModel.xienTable
        ?.where((r) => r.ngay == today)
        .toList() ?? [];

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
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 40,
                height: 3,
                decoration: BoxDecoration(
                  color: Colors.grey.shade600,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
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
      body: Consumer<BettingViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.isLoading) {
            return const ShimmerLoading(type: ShimmerType.card);
          }

          if (viewModel.errorMessage != null) {
            return RefreshIndicator(
              onRefresh: () async {
                HapticFeedback.mediumImpact();
                await viewModel.loadBettingTables();
              },
              child: ListView(
                children: [
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 100),
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
                _buildStatisticsSection(context, viewModel),
                const SizedBox(height: 16),
                _buildActionButtons(context),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatisticsSection(BuildContext context, BettingViewModel viewModel) {
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

    final now = DateTime.now();
    final today = '${now.day.toString().padLeft(2, '0')}/${now.month}/${now.year}';
    final todayCycleRows = _getTodayCycleRows(viewModel, today);
    final todayXienRows = viewModel.xienTable
        ?.where((r) => r.ngay == today)
        .toList() ?? [];
    final allRows = <BettingRow>[...todayCycleRows, ...todayXienRows];

    final hasAnyTable = viewModel.cycleTable != null || 
                        viewModel.trungTable != null || 
                        viewModel.bacTable != null ||
                        viewModel.xienTable != null;

    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Tổng tiền: ${NumberUtils.formatCurrency(tongTienTongQuat)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.grey),
                const SizedBox(height: 16),

                if (!hasAnyTable)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(
                            Icons.inbox_outlined,
                            size: 64,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Chưa có bảng cược',
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Hãy phân tích và tạo bảng cược đầu tiên',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Chu kỳ: ${NumberUtils.formatCurrency(tongTienChuKy)}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.only(left: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '• Tất cả: ${NumberUtils.formatCurrency(tongTienTatCa)}',
                                style: const TextStyle(color: Colors.grey, fontSize: 14),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '• Miền Trung: ${NumberUtils.formatCurrency(tongTienTrung)}',
                                style: const TextStyle(color: Colors.grey, fontSize: 14),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '• Miền Bắc: ${NumberUtils.formatCurrency(tongTienBac)}',
                                style: const TextStyle(color: Colors.grey, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Text(
                      'Xiên: ${NumberUtils.formatCurrency(tongTienXien)}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),

                  if (hasAnyTable) ...[
                    Divider(color: Colors.grey.shade600),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Bảng cược hôm nay ($today)',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    if (allRows.isEmpty)
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
                              fontSize: 14,
                            ),
                          ),
                        ),
                      )
                    else
                      _buildUnifiedTable(allRows),

                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const BettingDetailScreen(initialTab: 0),
                            ),
                          );
                        },
                        icon: Icon(Icons.arrow_forward, color: Theme.of(context).primaryColor),
                        label: Text(
                          'Xem chi tiết',
                          style: TextStyle(color: Theme.of(context).primaryColor),
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
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
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              print('🔴 Xem Live button pressed');
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const HomeScreen(),
                ),
              );
            },
            icon: const Icon(Icons.live_tv),
            label: const Text('Xem Live'),
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

  Widget _buildUnifiedTable(List<BettingRow> rows) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade800),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF2C2C2C),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: const Row(
              children: [
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
          
          ...rows.asMap().entries.map((entry) {
            final index = entry.key;
            final row = entry.value;
            final isEven = index % 2 == 0;
            
            final isCycleRow = row.cuocSo > 0;
            final cuocValue = isCycleRow ? row.cuocSo : row.cuocMien;

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
          }),
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
            decoration: const BoxDecoration(
              color: Color(0xFF2C2C2C),
              borderRadius: BorderRadius.only(
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
          }),
        ],
      ),
    );
  }
}