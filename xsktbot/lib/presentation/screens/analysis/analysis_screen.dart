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
                  return InkWell(
                    onTap: viewModel.selectedMien == 'Tất cả'
                        ? () => _showNumberDetail(context, viewModel, number)
                        : null,
                    child: Chip(
                      label: Text(
                        number,
                        style: const TextStyle(fontSize: 14),
                      ),
                      backgroundColor: Colors.green.shade100,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              const Text(
                'Phân bổ theo miền:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              // ✅ THAY ĐỔI GIAO DIỆN - BỎ KHUNG
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
                children: ganInfo.pairs.map((pairWithDays) {
                  return Chip(
                    label: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          pairWithDays.pair.display,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '(${pairWithDays.daysGan} ngày)',
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

  // ✅ HIỂN THỊ CHI TIẾT SỐ
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
      builder: (context) => AlertDialog(
        title: Text('Chi tiết số $number'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Thông tin theo từng miền:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              
              if (numberDetail.mienDetails.containsKey('Nam'))
                _buildMienDetailRow(
                  'Miền Nam',
                  numberDetail.mienDetails['Nam']!,
                  Colors.orange,
                ),
              
              if (numberDetail.mienDetails.containsKey('Trung'))
                _buildMienDetailRow(
                  'Miền Trung',
                  numberDetail.mienDetails['Trung']!,
                  Colors.purple,
                ),
              
              if (numberDetail.mienDetails.containsKey('Bắc'))
                _buildMienDetailRow(
                  'Miền Bắc',
                  numberDetail.mienDetails['Bắc']!,
                  Colors.blue,
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _sendNumberDetailToTelegram(context, viewModel, numberDetail);
            },
            icon: const Icon(Icons.send),
            label: const Text('Gửi Telegram'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _createTableForNumber(context, viewModel, number);
            },
            icon: const Icon(Icons.table_chart),
            label: const Text('Tạo bảng'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMienDetailRow(String label, dynamic detail, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text('Gan: ${detail.daysGan} ngày'),
            Text('Lần cuối: ${detail.lastSeenDateStr}'),
          ],
        ),
      ),
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