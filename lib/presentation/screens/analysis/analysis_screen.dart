// lib/presentation/screens/analysis/analysis_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../app.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/date_utils.dart' as date_utils;
// Đã xóa import number_detail.dart vì không còn dùng tới
import '../../widgets/shimmer_loading.dart';
import '../betting/betting_viewmodel.dart';
import '../settings/settings_viewmodel.dart';
import 'analysis_viewmodel.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen>
    with SingleTickerProviderStateMixin {
  // Đã xóa các biến state _selectedNumber, _currentNumberDetail, _isLoadingDetail thừa thãi

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final viewModel = context.read<AnalysisViewModel>();
        if (viewModel.cycleResult == null) {
          viewModel.loadAnalysis();
        }
      }
    });
  }

  // Đã xóa hàm _onNumberSelected

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<AnalysisViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.isLoading) {
            return const ShimmerLoading(type: ShimmerType.card);
          }

          if (viewModel.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline,
                      size: 64, color: ThemeProvider.loss),
                  const SizedBox(height: 16),
                  Text(
                    viewModel.errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: ThemeProvider.loss),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      viewModel.clearError();
                      viewModel.loadAnalysis(useCache: false);
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
              await viewModel.loadAnalysis(useCache: false);
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
                _buildOptimalSummaryCard(viewModel),
                const SizedBox(height: 16),
                _buildCycleSection(viewModel),
                const SizedBox(height: 16),
                _buildGanPairSection(viewModel),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOptimalSummaryCard(AnalysisViewModel viewModel) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ... (Header giữ nguyên)
            const Divider(color: Colors.grey),
            _buildSummaryRow('Tất cả', viewModel.optimalTatCa,
                date: viewModel.dateTatCa),

            // ✅ THÊM DÒNG NÀY
            _buildSummaryRow(
                'Nam', viewModel.optimalNam, // Cần thêm field này vào ViewModel
                date: viewModel.dateNam), // Cần thêm field này vào ViewModel

            _buildSummaryRow('Trung', viewModel.optimalTrung,
                date: viewModel.dateTrung),
            _buildSummaryRow('Bắc', viewModel.optimalBac,
                date: viewModel.dateBac),
            _buildSummaryRow('Xiên', viewModel.optimalXien,
                date: viewModel.dateXien),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {DateTime? date}) {
    bool isHighlight = false;
    if (date != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final targetDate = DateTime(date.year, date.month, date.day);
      if (targetDate.compareTo(today) >= 0) {
        isHighlight = true;
      }
    }
    if (value.contains("Đang tính") ||
        value.contains("Thiếu vốn") ||
        value.contains("Lỗi")) {
      isHighlight = false;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$label:',
              style: const TextStyle(color: Colors.grey, fontSize: 16)),
          Text(value,
              style: TextStyle(
                  color: isHighlight ? Colors.grey : Colors.white,
                  fontWeight: isHighlight ? FontWeight.normal : FontWeight.bold,
                  fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildCycleSection(AnalysisViewModel viewModel) {
    final cycleResult = viewModel.cycleResult;

    // ✅ Lấy end date tương ứng với miền đang chọn
    DateTime? currentEndDate;
    if (viewModel.selectedMien == 'Tất cả') {
      currentEndDate = viewModel.endDateTatCa;
    } else if (viewModel.selectedMien == 'Nam') {
      currentEndDate = viewModel.endDateNam;
    } else if (viewModel.selectedMien == 'Trung') {
      currentEndDate = viewModel.endDateTrung;
    } else if (viewModel.selectedMien == 'Bắc') {
      currentEndDate = viewModel.endDateBac;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        'Chu kỳ 00-99',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.table_chart,
                      color: Theme.of(context).primaryColor.withOpacity(0.9)),
                  tooltip: 'Tạo bảng cược',
                  onPressed: cycleResult != null
                      ? () {
                          if (viewModel.selectedMien == 'Bắc') {
                            _showCreateBacGanTableDialog(
                                context, viewModel, cycleResult.targetNumber);
                          } else if (viewModel.selectedMien == 'Trung') {
                            _showCreateTrungGanTableDialog(
                                context, viewModel, cycleResult.targetNumber);
                          } else if (viewModel.selectedMien == 'Nam') {
                            _showCreateNamGanTableDialog(
                                context, viewModel, cycleResult.targetNumber);
                          } else {
                            _createCycleBettingTable(
                                context, viewModel, cycleResult.targetNumber);
                          }
                        }
                      : null,
                ),
                IconButton(
                  icon: Icon(Icons.send,
                      color: Theme.of(context).primaryColor.withOpacity(0.9)),
                  onPressed: cycleResult != null
                      ? () => _sendCycleToTelegram(context, viewModel)
                      : null,
                ),
              ],
            ),
            const Divider(color: Colors.grey),
            _buildMienFilter(viewModel),
            const SizedBox(height: 16),
            if (cycleResult == null)
              const Text('Chưa có dữ liệu phân tích')
            else ...[
              _buildInfoRow(
                'Số mục tiêu:',
                cycleResult.targetNumber,
                isHighlight: true,
              ),

              // ✅ HIỂN THỊ END DATE với highlight màu đỏ
              if (currentEndDate != null)
                _buildInfoRow(
                  'Kết thúc dự kiến:',
                  date_utils.DateUtils.formatDate(currentEndDate),
                  textColor: const Color(0xFFFF5252),
                )
              else ...[
                _buildInfoRow(
                  'Kết thúc dự kiến:',
                  'Đang tính ...',
                  textColor: const Color(0xFFFF5252),
                )
              ],
              // Lần cuối về
              _buildInfoRow(
                'Lần cuối về:',
                date_utils.DateUtils.formatDate(cycleResult.lastSeenDate),
              ),

              // Ngày gan hiện tại (Cột E)
              _buildInfoRow('Ngày gan hiện tại:',
                  '${cycleResult.maxGanDays} ngày (Slots: ${cycleResult.ganCurrentSlots})'),

              // Ngày gan cũ (Cột H)
              _buildInfoRow('Ngày gan CK trước:',
                  '${cycleResult.ganCKTruocDays} ngày (Slots: ${cycleResult.ganCKTruocSlots})'),

              // Ngày gan kìa (Cột J)
              _buildInfoRow('Ngày gan CK kìa:',
                  '${cycleResult.ganCKKiaDays} ngày (Slots: ${cycleResult.ganCKKiaSlots})'),
            ],
          ],
        ),
      ),
    );
  }

  // Đã xóa widget _buildInlineNumberDetail và _buildInlineMienRow

  // ... (Giữ nguyên _buildGanPairSection)
  Widget _buildGanPairSection(AnalysisViewModel viewModel) {
    final ganInfo = viewModel.ganPairInfo;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        'Cặp xiên Bắc',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
                // Nút tạo bảng
                IconButton(
                  icon: Icon(Icons.table_chart,
                      color: Theme.of(context).primaryColor.withOpacity(0.9)),
                  onPressed: ganInfo != null
                      ? () => _createXienBettingTable(context, viewModel)
                      : null,
                ),
                // Nút gửi Telegram
                IconButton(
                  icon: Icon(Icons.send,
                      color: Theme.of(context).primaryColor.withOpacity(0.9)),
                  onPressed: ganInfo != null
                      ? () => _sendGanPairToTelegram(context, viewModel)
                      : null,
                ),
              ],
            ),
            const Divider(color: Colors.grey),

            // ✅ HIỂN THỊ KHI CÓ DỮ LIỆU
            if (ganInfo == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text('Chưa có dữ liệu phân tích Xiên',
                    style: TextStyle(color: Colors.grey)),
              )
            else ...[
              if (ganInfo.pairs.isNotEmpty)
                ...ganInfo.pairs.asMap().entries.map((entry) {
                  final pairWithDays = entry.value;
                  return _buildInfoRow(
                    'Cặp số mục tiêu:',
                    pairWithDays.display,
                    textColor: Colors.white,
                  );
                }),
              if (viewModel.endDateXien != null)
                _buildInfoRow(
                  'Kết thúc (dự kiến):',
                  date_utils.DateUtils.formatDate(viewModel.endDateXien!),
                  textColor: const Color(0xFFFF5252),
                ),
              _buildInfoRow(
                'Lần cuối về:',
                date_utils.DateUtils.formatDate(ganInfo.lastSeen),
              ),
              _buildInfoRow('Số ngày gan:', '${ganInfo.daysGan} ngày/151 ngày'),
            ],
          ],
        ),
      ),
    );
  }

  // ... (Giữ nguyên _buildMienFilter)
  Widget _buildMienFilter(AnalysisViewModel viewModel) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: ['Tất cả', 'Nam', 'Trung', 'Bắc'].map((mien) {
          final isSelected = viewModel.selectedMien == mien;
          return Padding(
            padding: const EdgeInsets.only(right: 7),
            child: FilterChip(
              label: SizedBox(
                width: 45,
                child: Text(
                  mien,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected
                        ? Theme.of(context).primaryColor.withOpacity(0.9)
                        : Colors.grey.shade500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              selected: isSelected,
              backgroundColor: const Color(0xFF2C2C2C),
              selectedColor: Theme.of(context).primaryColor.withOpacity(0.3),
              side: BorderSide(
                color: isSelected
                    ? Theme.of(context).primaryColor.withOpacity(0.8)
                    : Colors.grey.shade600,
                width: 1,
              ),
              checkmarkColor: Colors.transparent,
              showCheckmark: false,
              onSelected: (selected) {
                if (selected) {
                  // Đã xóa reset state _selectedNumber
                  viewModel.setSelectedMien(mien);
                }
              },
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 0),
              labelPadding: EdgeInsets.zero,
            ),
          );
        }).toList(),
      ),
    );
  }

  // Cập nhật helper _buildInfoRow để hỗ trợ custom màu text
  Widget _buildInfoRow(String label, String value,
      {bool isHighlight = false, Color? textColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140, // Cố định độ rộng label cho thẳng hàng
            child: Text(
              label,
              style: const TextStyle(
                  color: Colors.grey, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
                color: textColor ?? (isHighlight ? Colors.white : null),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _createCycleBettingTable(
      BuildContext context, AnalysisViewModel viewModel, String number) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Số: $number'),
            const SizedBox(height: 8),
            const Text(
              'Tạo bảng cược Chu kỳ dựa trên kết quả phân tích?\n'
              'Bảng cược sẽ được tạo trong tab "Bảng cược".',
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

              final config = context.read<SettingsViewModel>().config;
              await viewModel.createCycleBettingTable(number, config);

              if (context.mounted) {
                if (viewModel.errorMessage == null) {
                  await context.read<BettingViewModel>().loadBettingTables();

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Tạo bảng cược thành công!'),
                      backgroundColor: ThemeProvider.profit,
                      duration: Duration(seconds: 2),
                    ),
                  );

                  await Future.delayed(const Duration(milliseconds: 300));

                  if (context.mounted) {
                    mainNavigationKey.currentState?.switchToTab(1);
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('❌ ${viewModel.errorMessage}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Tạo bảng'),
          ),
        ],
      ),
    );
  }

  void _createXienBettingTable(
      BuildContext context, AnalysisViewModel viewModel) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận'),
        content: const Text(
          'Tạo bảng cược Xiên dựa trên kết quả phân tích?\n'
          'Bảng cược sẽ được tạo trong tab "Bảng cược".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              await viewModel.createXienBettingTable();

              if (context.mounted) {
                if (viewModel.errorMessage == null) {
                  await context.read<BettingViewModel>().loadBettingTables();

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Tạo bảng cược thành công!'),
                      backgroundColor: ThemeProvider.profit,
                      duration: Duration(seconds: 2),
                    ),
                  );

                  await Future.delayed(const Duration(milliseconds: 300));

                  if (context.mounted) {
                    mainNavigationKey.currentState?.switchToTab(1);
                  }
                }
              }
            },
            child: const Text('Tạo bảng'),
          ),
        ],
      ),
    );
  }

  void _sendCycleToTelegram(BuildContext context, AnalysisViewModel viewModel) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận'),
        content: const Text('Gửi kết quả phân tích Chu kỳ 00-99 qua Telegram?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await viewModel.sendCycleAnalysisToTelegram();

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      viewModel.errorMessage ?? 'Gửi thành công!',
                    ),
                    backgroundColor: viewModel.errorMessage != null
                        ? ThemeProvider.loss
                        : ThemeProvider.profit,
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

  void _sendGanPairToTelegram(
      BuildContext context, AnalysisViewModel viewModel) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận'),
        content: const Text('Gửi kết quả phân tích Cặp số gan qua Telegram?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await viewModel.sendGanPairAnalysisToTelegram();

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      viewModel.errorMessage ?? 'Gửi thành công!',
                    ),
                    backgroundColor: viewModel.errorMessage != null
                        ? ThemeProvider.loss
                        : ThemeProvider.profit,
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

  void _showCreateTrungGanTableDialog(
    BuildContext context,
    AnalysisViewModel viewModel,
    String number,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tạo bảng cược Miền Trung'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Số: $number'),
            const SizedBox(height: 8),
            const Text(
              'Tạo bảng cược cho số gan Miền Trung?\n\n'
              '• Chỉ cược Miền Trung\n'
              '• Dựa trên kết quả phân tích\n'
              '• Bảng hiện tại sẽ bị thay thế',
              style: TextStyle(fontSize: 13),
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

              final config = context.read<SettingsViewModel>().config;
              await viewModel.createTrungGanBettingTable(number, config);

              if (context.mounted) {
                if (viewModel.errorMessage == null) {
                  await context.read<BettingViewModel>().loadBettingTables();

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Tạo bảng cược Miền Trung thành công!'),
                      backgroundColor: ThemeProvider.profit,
                      duration: Duration(seconds: 2),
                    ),
                  );

                  await Future.delayed(const Duration(milliseconds: 300));

                  if (context.mounted) {
                    mainNavigationKey.currentState?.switchToTab(1);
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('❌ ${viewModel.errorMessage}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Tạo bảng'),
          ),
        ],
      ),
    );
  }

  void _showCreateNamGanTableDialog(
    BuildContext context,
    AnalysisViewModel viewModel,
    String number,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tạo bảng cược Miền Nam'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Số: $number'),
            const SizedBox(height: 8),
            const Text(
              'Tạo bảng cược cho số gan Miền Nam?\n\n'
              '• Chỉ cược Miền Nam\n'
              '• Dựa trên kết quả phân tích\n'
              '• Bảng hiện tại sẽ bị thay thế',
              style: TextStyle(fontSize: 13),
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

              final config = context.read<SettingsViewModel>().config;

              // ⚠️ LƯU Ý: Trò cần thêm hàm createNamGanBettingTable vào AnalysisViewModel
              await viewModel.createNamGanBettingTable(number, config);

              if (context.mounted) {
                if (viewModel.errorMessage == null) {
                  await context.read<BettingViewModel>().loadBettingTables();

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Tạo bảng cược Miền Nam thành công!'),
                      backgroundColor: ThemeProvider.profit,
                      duration: Duration(seconds: 2),
                    ),
                  );

                  await Future.delayed(const Duration(milliseconds: 300));

                  if (context.mounted) {
                    mainNavigationKey.currentState
                        ?.switchToTab(1); // Chuyển sang tab Bảng cược
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('❌ ${viewModel.errorMessage}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Tạo bảng'),
          ),
        ],
      ),
    );
  }

  void _showCreateBacGanTableDialog(
    BuildContext context,
    AnalysisViewModel viewModel,
    String number,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tạo bảng cược Miền Bắc'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Số: $number'),
            const SizedBox(height: 8),
            const Text(
              'Tạo bảng cược cho số gan Miền Bắc?\n\n'
              '• Chỉ cược Miền Bắc\n'
              '• Dựa trên kết quả phân tích\n'
              '• Bảng hiện tại sẽ bị thay thế',
              style: TextStyle(fontSize: 13),
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

              final config = context.read<SettingsViewModel>().config;
              await viewModel.createBacGanBettingTable(number, config);

              if (context.mounted) {
                if (viewModel.errorMessage == null) {
                  await context.read<BettingViewModel>().loadBettingTables();

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Tạo bảng cược Miền Bắc thành công!'),
                      backgroundColor: ThemeProvider.profit,
                      duration: Duration(seconds: 2),
                    ),
                  );

                  await Future.delayed(const Duration(milliseconds: 300));

                  if (context.mounted) {
                    mainNavigationKey.currentState?.switchToTab(1);
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('❌ ${viewModel.errorMessage}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Tạo bảng'),
          ),
        ],
      ),
    );
  }
}
