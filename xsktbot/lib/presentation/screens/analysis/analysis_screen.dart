// lib/presentation/screens/analysis/analysis_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'analysis_viewmodel.dart';
import '../settings/settings_viewmodel.dart';
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
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<AnalysisViewModel>().loadAnalysis(useCache: false);
            },
          ),
        ],
      ),
      body: Consumer<AnalysisViewModel>(
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
                const Icon(Icons.loop, color: Colors.green),
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
                  // ✅ FIX: Bỏ điều kiện maxGanDays > 3
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
              const SizedBox(height: 8),
              const Text(
                'Nhóm số gan nhất:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: cycleResult.ganNumbers.map((number) {
                  return Chip(
                    label: Text(
                      number,
                      style: const TextStyle(fontSize: 14),
                    ),
                    backgroundColor: Colors.green.shade100,
                  );
                }).toList(),
              ),
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
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Miền $mien:',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: cycleResult.mienGroups[mien]!.map((number) {
                          return Chip(
                            label: Text(number),
                            backgroundColor: _getMienColor(mien),
                          );
                        }).toList(),
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
                const Icon(Icons.trending_up, color: Colors.blue),
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
                  // ✅ FIX: Bỏ điều kiện daysGan > 155
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
              _buildInfoRow('Số ngày gan:', '${ganInfo.daysGan} ngày'),
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
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ganInfo.pairs.map((pairWithDays) {  // ✅ pairWithDays là PairWithDays
                  return Chip(
                    label: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          pairWithDays.pair.display,  // ✅ Đúng
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '(${pairWithDays.daysGan} ngày)',  // ✅ Đúng
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    backgroundColor: Colors.blue.shade100,
                  );
                }).toList(),
              ),
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
        return FilterChip(
          label: Text(mien),
          selected: isSelected,
          onSelected: (selected) {
            if (selected) {
              viewModel.setSelectedMien(mien);
              viewModel.loadAnalysis(useCache: false);
            }
          },
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

  // ✅ DIALOG TẠO BẢNG CƯỢC CHU KỲ
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
                  // ✅ RELOAD bảng cược SAU KHI tạo thành công
                  await context.read<BettingViewModel>().loadBettingTables();
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Tạo bảng cược thành công!'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2),
                    ),
                  );
                  
                  // Delay một chút trước khi chuyển tab
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
                  // ✅ RELOAD bảng cược SAU KHI tạo thành công
                  await context.read<BettingViewModel>().loadBettingTables();
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Tạo bảng cược thành công!'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2),
                    ),
                  );
                  
                  // Delay một chút trước khi chuyển tab
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
}