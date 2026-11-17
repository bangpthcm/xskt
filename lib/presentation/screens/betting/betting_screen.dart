// lib/presentation/screens/betting/betting_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../app.dart';
import '../../../core/utils/number_utils.dart';
import '../../../data/models/api_account.dart';
import '../../../data/models/betting_row.dart';
import '../../../data/services/betting_api_service.dart';
import '../../../data/services/google_sheets_service.dart';
import '../../widgets/shimmer_loading.dart';
import '../home/home_screen.dart';
import '../settings/settings_viewmodel.dart';
import 'betting_detail_screen.dart';
import 'betting_viewmodel.dart';
import 'select_account_screen.dart';

class BettingScreen extends StatefulWidget {
  const BettingScreen({super.key});

  @override
  State<BettingScreen> createState() => _BettingScreenState();
}

class _BettingScreenState extends State<BettingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final settingsVM = context.read<SettingsViewModel>();
        final bettingVM = context.read<BettingViewModel>();
        final sheetsService = context.read<GoogleSheetsService>();

        settingsVM.loadConfig().then((_) async {
          await sheetsService.initialize(settingsVM.config.googleSheets);
          if (mounted) {
            bettingVM.loadBettingTables();
          }
        });
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

      if (validAccounts.length == 1) {
        _navigateToBettingWebView(
            context, validAccounts[0], config.betting.domain);
        return;
      }

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
        SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
      );
    }
  }

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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    }
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
                        const Icon(Icons.error_outline,
                            size: 64, color: Colors.red),
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

  Widget _buildStatisticsSection(
      BuildContext context, BettingViewModel viewModel) {
    final tongTienTatCa = viewModel.cycleTable?.isNotEmpty == true
        ? viewModel.cycleTable!.last.tongTien
        : 0.0;

    // ✅ Lấy tổng tiền Miền Nam
    final tongTienNam = viewModel.namTable?.isNotEmpty == true
        ? viewModel.namTable!.last.tongTien
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

    // ✅ Thêm Nam vào tổng chu kỳ
    final tongTienChuKy =
        tongTienTatCa + tongTienNam + tongTienTrung + tongTienBac;
    final tongTienTongQuat = tongTienChuKy + tongTienXien;

    final now = DateTime.now();
    final today =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    final todayCycleRows = _getTodayCycleRows(viewModel, today);
    final todayXienRows =
        viewModel.xienTable?.where((r) => r.ngay == today).toList() ?? [];
    final allRows = <BettingRow>[...todayCycleRows, ...todayXienRows];

    // ✅ Kiểm tra có bảng nào không (bao gồm Nam)
    final hasAnyTable = viewModel.cycleTable != null ||
        viewModel.namTable != null ||
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
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 14),
                              ),
                              const SizedBox(height: 4),
                              // ✅ Thêm hiển thị Miền Nam
                              Text(
                                '• Miền Nam: ${NumberUtils.formatCurrency(tongTienNam)}',
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 14),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '• Miền Trung: ${NumberUtils.formatCurrency(tongTienTrung)}',
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 14),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '• Miền Bắc: ${NumberUtils.formatCurrency(tongTienBac)}',
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 14),
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
                              builder: (context) =>
                                  const BettingDetailScreen(initialTab: 0),
                            ),
                          );
                        },
                        icon: Icon(Icons.arrow_forward,
                            color: Theme.of(context).primaryColor),
                        label: Text(
                          'Xem chi tiết',
                          style:
                              TextStyle(color: Theme.of(context).primaryColor),
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
              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
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
              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  List<BettingRow> _getTodayCycleRows(
      BettingViewModel viewModel, String today) {
    // ✅ Bổ sung bảng Miền Nam vào danh sách
    final todayCycleRows = <BettingRow>[
      ...viewModel.cycleTable?.where((r) => r.ngay == today) ?? [],
      ...viewModel.namTable?.where((r) => r.ngay == today) ?? [], // ✅ MỚI
      ...viewModel.trungTable?.where((r) => r.ngay == today) ?? [],
      ...viewModel.bacTable?.where((r) => r.ngay == today) ?? [],
    ];

    todayCycleRows.sort((a, b) {
      const mienOrder = {'Nam': 1, 'Trung': 2, 'Bắc': 3};
      final mienCompare =
          (mienOrder[a.mien] ?? 0).compareTo(mienOrder[b.mien] ?? 0);
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
                  flex: 5,
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
                  flex: 3,
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
                    flex: 5,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        row.ngay,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white,
                        ),
                        maxLines: 1,
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
                    flex: 3,
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
}
