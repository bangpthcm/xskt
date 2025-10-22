// lib/presentation/screens/analysis/analysis_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'analysis_viewmodel.dart';
import '../settings/settings_viewmodel.dart';
import '../betting/betting_viewmodel.dart';
import '../../../core/utils/date_utils.dart' as date_utils;
import '../../../app.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({Key? key}) : super(key: key);

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AnalysisViewModel>().loadAnalysis();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Phân tích'),
        actions: [
          // ✅ THÊM: Nút thông báo
          Consumer<AnalysisViewModel>(
            builder: (context, viewModel, child) {
              if (viewModel.hasAnyAlert) {
                return Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications),
                      tooltip: 'Thông báo',
                      onPressed: () => _showAlertDialog(context, viewModel),
                    ),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Đồng bộ RSS và phân tích lại',
            onPressed: () {
              context.read<AnalysisViewModel>().loadAnalysis(useCache: false);
            },
          ),
        ],
      ),
      body: Consumer<AnalysisViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.isLoading) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Đang đồng bộ dữ liệu và phân tích...',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            );
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
                      viewModel.loadAnalysis(useCache: false);
                    },
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => viewModel.loadAnalysis(useCache: false),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ✅ THÊM: Alert banner nếu có
                if (viewModel.hasAnyAlert)
                  _buildAlertBanner(viewModel),
                
                _buildCycleSection(viewModel),
                const SizedBox(height: 24),
                _buildGanPairSection(viewModel),
              ],
            ),
          );
        },
      ),
    );
  }

  // ✅ THÊM: Alert banner
  Widget _buildAlertBanner(AnalysisViewModel viewModel) {
    return Card(
      color: Colors.orange.shade50,
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _showAlertDialog(context, viewModel),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Có số gan thỏa điều kiện!',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Nhấn để xem chi tiết',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.orange.shade700),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ THÊM: Dialog hiển thị chi tiết alert
  void _showAlertDialog(BuildContext context, AnalysisViewModel viewModel) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700),
            const SizedBox(width: 8),
            const Text('Thông báo số gan'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Các số sau đã thỏa điều kiện gan:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              
              // Xiên
              if (viewModel.hasXienAlert)
                _buildAlertItem(
                  icon: Icons.trending_up,
                  color: Colors.blue,
                  title: 'Cặp số gan (Xiên)',
                  subtitle: 'Cặp: ${viewModel.ganPairInfo!.randomPair.display}',
                  days: viewModel.ganPairInfo!.daysGan,
                  threshold: 155,
                ),
              
              // Chu kỳ Tất cả
              if (viewModel.hasCycleAlert)
                _buildAlertItem(
                  icon: Icons.loop,
                  color: Colors.green,
                  title: 'Chu kỳ (Tất cả)',
                  subtitle: 'Số: ${viewModel.cycleResult!.targetNumber}',
                  days: viewModel.cycleResult!.maxGanDays,
                  threshold: 3,
                ),
              
              // Trung
              if (viewModel.hasTrungAlert)
                _buildAlertItem(
                  icon: Icons.filter_2,
                  color: Colors.purple,
                  title: 'Miền Trung',
                  subtitle: 'Số: ${viewModel.cycleResult!.targetNumber}',
                  days: viewModel.cycleResult!.maxGanDays,
                  threshold: 15,
                ),
              
              // Bắc
              if (viewModel.hasBacAlert)
                _buildAlertItem(
                  icon: Icons.filter_3,
                  color: Colors.indigo,
                  title: 'Miền Bắc',
                  subtitle: 'Số: ${viewModel.cycleResult!.targetNumber}',
                  days: viewModel.cycleResult!.maxGanDays,
                  threshold: 17,
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Có thể chuyển sang tab Bảng cược
            },
            child: const Text('Tạo bảng cược'),
          ),
        ],
      ),
    );
  }

  // Helper: Item trong alert dialog
  Widget _buildAlertItem({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required int days,
    required int threshold,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  '$days ngày (>${threshold})',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: color),
        ],
      ),
    );
  }

  Widget _buildCycleSection(AnalysisViewModel viewModel) {
    final cycleResult = viewModel.cycleResult;

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
                    const Icon(Icons.loop, color: Colors.green),
                    if (viewModel.hasCycleAlert)
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Chu kỳ 00-99',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.green),
                  tooltip: 'Gửi Telegram',
                  onPressed: cycleResult != null
                      ? () => _sendCycleToTelegram(context, viewModel)
                      : null,
                ),
                IconButton(
                  icon: const Icon(Icons.table_chart, color: Colors.orange),
                  tooltip: 'Tạo bảng cược',
                  onPressed: cycleResult != null
                      ? () => _createCycleBettingTable(context, viewModel)
                      : null,
                ),
              ],
            ),
            const Divider(),
            
            _buildMienFilter(viewModel),
            const SizedBox(height: 16),
            
            if (cycleResult == null)
              const Text('Chưa có dữ liệu phân tích')
            else ...[
              _buildInfoRow('Số ngày gan:', '${cycleResult.maxGanDays} ngày'),
              _buildInfoRow(
                'Lần cuối về:',
                date_utils.DateUtils.formatDate(cycleResult.lastSeenDate),
              ),
              _buildInfoRow('Số mục tiêu:', cycleResult.targetNumber),
              
              // ✅ CHỈ HIỂN thị "Nhóm số gan nhất" khi filter = Tất cả, Trung, Bắc
              if (viewModel.selectedMien != 'Nam') ...[
                const SizedBox(height: 8),
                const Text(
                  'Nhóm số gan nhất:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                // ✅ BỎ KHUNG: Hiển thị dạng text thường, không có Chip
                Text(
                  cycleResult.ganNumbers.join(', '),
                  style: const TextStyle(fontSize: 16),
                ),
              ],
              
              const SizedBox(height: 16),
              const Text(
                'Phân bổ theo miền:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              ...['Nam', 'Trung', 'Bắc'].map((mien) {
                if (!cycleResult.mienGroups.containsKey(mien) || 
                    cycleResult.mienGroups[mien]!.isEmpty) {
                  return const SizedBox.shrink();
                }
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 100,
                        child: Text(
                          'Miền $mien:',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          cycleResult.mienGroups[mien]!.join(', '),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ],
        ),
      ),
    );
  }

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
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.trending_up, color: Colors.blue),
                    if (viewModel.hasXienAlert)
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Cặp số gan Miền Bắc',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blue),
                  tooltip: 'Gửi Telegram',
                  onPressed: ganInfo != null
                      ? () => _sendGanPairToTelegram(context, viewModel)
                      : null,
                ),
                IconButton(
                  icon: const Icon(Icons.table_chart, color: Colors.orange),
                  tooltip: 'Tạo bảng cược',
                  onPressed: ganInfo != null
                      ? () => _createXienBettingTable(context, viewModel)
                      : null,
                ),
              ],
            ),
            const Divider(),
            if (ganInfo == null)
              const Text('Chưa có dữ liệu phân tích')
            else ...[
              _buildInfoRow('Số ngày gan:', '${ganInfo.daysGan} ngày/185 ngày'),
              _buildInfoRow(
                'Lần cuối về:',
                date_utils.DateUtils.formatDate(ganInfo.lastSeen),
              ),
              const SizedBox(height: 8),
              const Text(
                'Các cặp gan nhất:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              // ✅ BỎ KHUNG: Hiển thị dạng text thường
              ...ganInfo.pairs.asMap().entries.map((entry) {
                final index = entry.key;
                final pairWithDays = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${index + 1}. ${pairWithDays.pair.display} (${pairWithDays.daysGan} ngày)',
                    style: const TextStyle(fontSize: 16),
                  ),
                );
              }).toList(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMienFilter(AnalysisViewModel viewModel) {
    return Wrap(
      spacing: 8,
      children: ['Tất cả', 'Nam', 'Trung', 'Bắc'].map((mien) {
        final isSelected = viewModel.selectedMien == mien;
        
        // ✅ Check alert cho từng filter
        bool hasAlert = false;
        if (mien == 'Tất cả' && viewModel.cycleResult != null) {
          hasAlert = viewModel.cycleResult!.maxGanDays > 3;
        } else if (mien == 'Trung' && viewModel.cycleResult != null && viewModel.selectedMien == 'Trung') {
          hasAlert = viewModel.cycleResult!.maxGanDays > 15;
        } else if (mien == 'Bắc' && viewModel.cycleResult != null && viewModel.selectedMien == 'Bắc') {
          hasAlert = viewModel.cycleResult!.maxGanDays > 17;
        }
        
        return Stack(
          clipBehavior: Clip.none,
          children: [
            FilterChip(
              label: Text(mien),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  viewModel.setSelectedMien(mien);
                  viewModel.loadAnalysis(useCache: true);
                }
              },
            ),
            if (hasAlert)
              Positioned(
                right: 4,
                top: 4,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                ),
              ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Color _getMienColor(String mien) {
    switch (mien) {
      case 'Nam':
        return Colors.orange.shade100;
      case 'Trung':
        return Colors.purple.shade100;
      case 'Bắc':
        return Colors.blue.shade100;
      default:
        return Colors.grey.shade100;
    }
  }

  void _createCycleBettingTable(BuildContext context, AnalysisViewModel viewModel) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận'),
        content: const Text(
          'Tạo bảng cược Chu kỳ dựa trên kết quả phân tích?\n\n'
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
              
              final config = context.read<SettingsViewModel>().config;
              await viewModel.createCycleBettingTable(config);
              
              if (context.mounted) {
                if (viewModel.errorMessage == null) {
                  await context.read<BettingViewModel>().loadBettingTables();
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Tạo bảng cược thành công!'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2),
                    ),
                  );
                  
                  await Future.delayed(const Duration(milliseconds: 300));
                  
                  if (context.mounted) {
                    mainNavigationKey.currentState?.switchToTab(2);
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(viewModel.errorMessage!),
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

  void _createXienBettingTable(BuildContext context, AnalysisViewModel viewModel) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận'),
        content: const Text(
          'Tạo bảng cược Xiên dựa trên kết quả phân tích?\n\n'
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
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2),
                    ),
                  );
                  
                  await Future.delayed(const Duration(milliseconds: 300));
                  
                  if (context.mounted) {
                    mainNavigationKey.currentState?.switchToTab(2);
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(viewModel.errorMessage!),
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
                        ? Colors.red
                        : Colors.green,
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

  void _sendGanPairToTelegram(BuildContext context, AnalysisViewModel viewModel) {
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
                        ? Colors.red
                        : Colors.green,
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

  // ✅ ADD: Method mới cho Trung
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
              '• Số lượt: 30 lượt\n'
              '• Thời gian: ~35 ngày\n'
              '• Ăn: 98 lần\n'
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
                      content: Text('Tạo bảng cược Trung gan thành công!'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2),
                    ),
                  );
                  
                  await Future.delayed(const Duration(milliseconds: 300));
                  
                  if (context.mounted) {
                    mainNavigationKey.currentState?.switchToTab(2);
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(viewModel.errorMessage!),
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

  // ✅ ADD: Method mới để show dialog
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
              '• Thời gian: 35 ngày\n'
              '• Ăn: 99 lần\n'
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
                      content: Text('Tạo bảng cược Bắc gan thành công!'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2),
                    ),
                  );
                  
                  await Future.delayed(const Duration(milliseconds: 300));
                  
                  if (context.mounted) {
                    mainNavigationKey.currentState?.switchToTab(2);
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(viewModel.errorMessage!),
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

  // ✅ HIỂN THỊ CHI TIẾT SỐ
  // Thay thế method _showNumberDetail trong analysis_screen.dart
  Future<void> _showNumberDetail(
    BuildContext context,
    AnalysisViewModel viewModel,
    String number,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    final numberDetail = await viewModel.analyzeNumberDetail(number);

    if (!context.mounted) return;
    
    Navigator.pop(context);

    if (numberDetail == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không tìm thấy dữ liệu')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ✅ Header với nút X góc phải trên
              Container(
                padding: const EdgeInsets.fromLTRB(24, 16, 16, 16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Chi tiết số $number',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    // ✅ 2. NÚT X THAY VÌ NÚT "ĐÓNG"
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      tooltip: 'Đóng',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Thông tin theo từng miền:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ✅ 1. CÁC Ô MIỀN CÂN ĐỐI VỚI POPUP
                    if (numberDetail.mienDetails.containsKey('Nam'))
                      _buildMienCard(
                        'Miền Nam',
                        numberDetail.mienDetails['Nam']!,
                        Colors.orange,
                      ),

                    const SizedBox(height: 12),

                    if (numberDetail.mienDetails.containsKey('Trung'))
                      _buildMienCard(
                        'Miền Trung',
                        numberDetail.mienDetails['Trung']!,
                        Colors.purple,
                      ),

                    const SizedBox(height: 12),

                    if (numberDetail.mienDetails.containsKey('Bắc'))
                      _buildMienCard(
                        'Miền Bắc',
                        numberDetail.mienDetails['Bắc']!,
                        Colors.blue,
                      ),
                  ],
                ),
              ),

              // ✅ 3. ACTION BUTTONS: GỬI TELEGRAM BÊN TRÁI, TẠO BẢNG BÊN PHẢI
              Container(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Row(
                  children: [
                    // Gửi Telegram (bên trái)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _sendNumberDetailToTelegram(context, viewModel, numberDetail);
                        },
                        icon: const Icon(Icons.send, size: 20),
                        label: const Text('Gửi Telegram'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Tạo bảng (bên phải)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _createTableForNumber(context, viewModel, number);
                        },
                        icon: const Icon(Icons.table_chart, size: 20),
                        label: const Text('Tạo bảng'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ HELPER METHOD ĐỂ BUILD CARD MIỀN
  Widget _buildMienCard(String title, dynamic detail, Color color) {
    return Container(
      width: double.infinity,  // ✅ Full width để cân đối
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildInfoRowInCard('Gan:', '${detail.daysGan} ngày'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: _buildInfoRowInCard('Lần cuối:', detail.lastSeenDateStr),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRowInCard(String label, String value) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _sendNumberDetailToTelegram(
    BuildContext context,
    AnalysisViewModel viewModel,
    dynamic numberDetail,
  ) async {
    await viewModel.sendNumberDetailToTelegram(numberDetail);
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            viewModel.errorMessage ?? 'Gửi thành công!',
          ),
          backgroundColor: viewModel.errorMessage != null
              ? Colors.red
              : Colors.green,
        ),
      );
    }
  }

  Future<void> _createTableForNumber(
    BuildContext context,
    AnalysisViewModel viewModel,
    String number,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận'),
        content: Text(
          'Tạo bảng cược cho số $number?\n\n'
          'Bảng cược chu kỳ hiện tại sẽ bị xóa và thay thế.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Tạo'),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    final config = context.read<SettingsViewModel>().config;
    await viewModel.createCycleBettingTableForNumber(number, config);

    if (context.mounted) {
      if (viewModel.errorMessage == null) {
        await context.read<BettingViewModel>().loadBettingTables();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tạo bảng cược thành công!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        
        await Future.delayed(const Duration(milliseconds: 300));
        
        if (context.mounted) {
          mainNavigationKey.currentState?.switchToTab(2);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(viewModel.errorMessage!),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}