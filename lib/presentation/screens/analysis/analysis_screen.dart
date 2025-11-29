// lib/presentation/screens/analysis/analysis_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'analysis_viewmodel.dart';
import '../settings/settings_viewmodel.dart';
import '../betting/betting_viewmodel.dart';
import '../../../core/utils/date_utils.dart' as date_utils;
import '../../../app.dart';
import '../../widgets/shimmer_loading.dart';
import '../../../data/models/number_detail.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> 
    with SingleTickerProviderStateMixin {

  String? _selectedNumber;
  NumberDetail? _currentNumberDetail;
  bool _isLoadingDetail = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AnalysisViewModel>().loadAnalysis();
      }
    });
  }

  Future<void> _onNumberSelected(String number) async {
    final viewModel = context.read<AnalysisViewModel>();

    // Nếu bấm lại số đang chọn -> đóng
    if (_selectedNumber == number) {
      setState(() {
        _selectedNumber = null;
        _currentNumberDetail = null;
      });
      return;
    }

    // Reset và bắt đầu load số mới
    setState(() {
      _selectedNumber = number;
      _isLoadingDetail = true;
      _currentNumberDetail = null;
    });

    viewModel.setTargetNumber(number);

    // Load chi tiết số
    final detail = await viewModel.analyzeNumberDetail(number);

    if (mounted) {
      setState(() {
        _currentNumberDetail = detail;
        _isLoadingDetail = false;
      });
    }
  }

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
            onRefresh: ()  async {
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
            // --- HEADER ---
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        'Chu kỳ 00-99',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (viewModel.tatCaAlertCache == true || 
                          viewModel.trungAlertCache == true || 
                          viewModel.bacAlertCache == true)
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 15),
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
                      const Spacer(),
                    ],
                  ),
                ),
                if (viewModel.selectedMien != 'Nam')
                IconButton(
                  icon: Icon(Icons.table_chart, color: Theme.of(context).primaryColor.withOpacity(0.9)),
                  tooltip: 'Tạo bảng cược (cho số mục tiêu)',
                  onPressed: cycleResult != null
                      ? () {
                          if (viewModel.selectedMien == 'Bắc') {
                            _showCreateBacGanTableDialog(context, viewModel, cycleResult.targetNumber);
                          } else if (viewModel.selectedMien == 'Trung') {
                            _showCreateTrungGanTableDialog(context, viewModel, cycleResult.targetNumber);
                          } else {
                            _createCycleBettingTable(context, viewModel, cycleResult.targetNumber);
                          }
                        }
                      : null,
                ),
                IconButton(
                  icon: Icon(Icons.send, color: Theme.of(context).primaryColor.withOpacity(0.9)),
                  tooltip: 'Gửi Telegram (cho số mục tiêu)',
                  onPressed: cycleResult != null
                      ? () => _sendCycleToTelegram(context, viewModel)
                      : null,
                ),
              ],
            ),
            const Divider(color: Colors.grey),
            
            // --- FILTER ---
            _buildMienFilter(viewModel),
            const SizedBox(height: 16),
            
            if (cycleResult == null)
              const Text('Chưa có dữ liệu phân tích') 
            else ...[
              // --- THÔNG TIN CHUNG ---
              _buildInfoRow(
                'Số ngày gan:', 
                AnalysisThresholds.formatWithThreshold(
                  cycleResult.maxGanDays, 
                  viewModel.selectedMien,
                ),
              ),
              _buildInfoRow(
                'Lần cuối về:',
                date_utils.DateUtils.formatDate(cycleResult.lastSeenDate),
              ),
              if (viewModel.selectedMien != 'Nam')
              // Số mục tiêu hiển thị ở đây sẽ thay đổi khi click chọn số khác
              _buildInfoRow('Số mục tiêu:', cycleResult.targetNumber),
              
              // --- NHÓM SỐ GAN NHẤT ---
              const SizedBox(height: 8),
              const Text(
                'Nhóm số gan nhất:',
                style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: cycleResult.ganNumbers.map((number) {
                  final isTarget = number == cycleResult.targetNumber;
                  final isSelected = number == _selectedNumber; 

                  if (viewModel.selectedMien == 'Nam') {
                    return Chip(
                      label: Text(number, style: TextStyle(color: Colors.grey.shade400)),
                      backgroundColor: Colors.grey.shade100,
                      side: BorderSide(color: Colors.grey.shade300),
                    );
                  }
                  
                  return ActionChip(
                    label: Text(
                      number,
                      style: TextStyle(
                        fontWeight: isTarget || isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isTarget || isSelected ? Theme.of(context).primaryColor.withOpacity(0.9) : Colors.grey.shade500,
                      ),
                    ),
                    backgroundColor: isSelected
                        ? Theme.of(context).primaryColor.withOpacity(0.5) 
                        : (isTarget ? Theme.of(context).primaryColor.withOpacity(0.3) : const Color(0xFF2C2C2C)),
                    side: BorderSide(
                      color: isTarget || isSelected
                          ? Theme.of(context).primaryColor.withOpacity(0.8) 
                          : Colors.grey.shade600,
                    ),
                    onPressed: () => _onNumberSelected(number),
                  );
                }).toList(),
              ),
              
              // --- PHÂN BỔ THEO MIỀN ---
              if (viewModel.selectedMien == 'Tất cả') ...[
                const SizedBox(height: 16),
                const Text(
                  'Phân bổ theo miền:',
                  style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
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
                              color: Colors.grey,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            cycleResult.mienGroups[mien]!.join(', '),
                            style: const TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],

              // ✅ HIỂN THỊ CHI TIẾT SỐ (Đã bỏ các nút bấm)
              if (_selectedNumber != null) ...[
                const SizedBox(height: 20),
                const Divider(color: Colors.grey),
                const SizedBox(height: 8),
                _buildInlineNumberDetail(viewModel),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInlineNumberDetail(AnalysisViewModel viewModel) {
    if (_isLoadingDetail) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(16.0),
        child: CircularProgressIndicator(),
      ));
    }

    if (_currentNumberDetail == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF252525), 
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Chi tiết số ${_selectedNumber}:',
                style: const TextStyle(
                  fontSize: 16, 
                  fontWeight: FontWeight.bold,
                  color: Colors.white
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Hiển thị thông tin từng miền
          if (_currentNumberDetail!.mienDetails.containsKey('Nam'))
            _buildInlineMienRow('Miền Nam', _currentNumberDetail!.mienDetails['Nam']!, Colors.orange),
          
          if (_currentNumberDetail!.mienDetails.containsKey('Trung'))
            _buildInlineMienRow('Miền Trung', _currentNumberDetail!.mienDetails['Trung']!, Colors.purple),
          
          if (_currentNumberDetail!.mienDetails.containsKey('Bắc'))
            _buildInlineMienRow('Miền Bắc', _currentNumberDetail!.mienDetails['Bắc']!, Colors.blue),
        ],
      ),
    );
  }

  Widget _buildInlineMienRow(String title, dynamic detail, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              title,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              '${detail.daysGan} ngày, từ ${detail.lastSeenDateStr}',
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
        ],
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
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        'Cặp xiên Bắc',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (viewModel.hasXienAlert)
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 15),
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
                      const Spacer(),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.table_chart, color: Theme.of(context).primaryColor.withOpacity(0.9)),
                  tooltip: 'Tạo bảng cược',
                  onPressed: ganInfo != null
                      ? () => _createXienBettingTable(context, viewModel)
                      : null,
                ),
                IconButton(
                  icon: Icon(Icons.send, color: Theme.of(context).primaryColor.withOpacity(0.9)),
                  tooltip: 'Gửi Telegram',
                  onPressed: ganInfo != null
                      ? () => _sendGanPairToTelegram(context, viewModel)
                      : null,
                ),
              ],
            ),
            const Divider(color: Colors.grey),
            if (ganInfo == null)
              const Text('Chưa có dữ liệu phân tích')
            else ...[
              _buildInfoRow('Số ngày gan:', '${ganInfo.daysGan} ngày/${AnalysisThresholds.xien} ngày'),
              _buildInfoRow(
                'Lần cuối về:',
                date_utils.DateUtils.formatDate(ganInfo.lastSeen),
              ),
              const SizedBox(height: 8),
              const Text(
                'Các cặp gan nhất:',
                style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...ganInfo.pairs.asMap().entries.map((entry) {
                final index = entry.key;
                final pairWithDays = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${index + 1}. ${pairWithDays.pair.display} (${pairWithDays.daysGan} ngày)',
                    style: const TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMienFilter(AnalysisViewModel viewModel) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: ['Tất cả', 'Nam', 'Trung', 'Bắc'].map((mien) {
          final isSelected = viewModel.selectedMien == mien;
          
          bool hasAlert = false;
          if (mien== 'Tất cả') {
            hasAlert = viewModel.tatCaAlertCache ?? false;
          } else if (mien == 'Trung') {
            hasAlert = viewModel.trungAlertCache ?? false;
          } else if (mien == 'Bắc') {
            hasAlert = viewModel.bacAlertCache ?? false;
          }
          
          return Padding(
            padding: const EdgeInsets.only(right: 7),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                FilterChip(
                  label: SizedBox(
                    width: 45,
                    child: Text(
                      mien,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
                      setState(() {
                        _selectedNumber = null;
                        _currentNumberDetail = null;
                      });
                      viewModel.setSelectedMien(mien);
                      viewModel.loadAnalysis(useCache: true);
                    }
                  },
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 0),
                  labelPadding: EdgeInsets.zero,
                ),
                if (hasAlert)
                  Positioned(
                    right: 1,
                    top: 1,
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
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
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

  void _createCycleBettingTable(BuildContext context, AnalysisViewModel viewModel, String number) {
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
                      content: Text('Tạo bảng cược thành công!'),
                      backgroundColor: Colors.green,
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

  void _createXienBettingTable(BuildContext context, AnalysisViewModel viewModel) {
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
                      backgroundColor: Colors.green,
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

  Future<void> _createTableForNumberWithMien(
    BuildContext context,
    AnalysisViewModel viewModel,
    String number,
  ) async {
     // ... (Giữ nguyên logic của hàm này) ...
     // Code đã được cung cấp trong phản hồi trước
     print('🎯 Creating table for number: $number');
     final selectedMien = viewModel.selectedMien;
     String tableDisplayName;
     if (selectedMien == 'Bắc') {
      tableDisplayName = 'Miền Bắc';
    } else if (selectedMien == 'Trung') {
      tableDisplayName = 'Miền Trung';
    } else {
      tableDisplayName = 'Chu kỳ (Tất cả)';
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xác nhận'),
        content: Text(
          'Tạo bảng cược $tableDisplayName cho số $number?\n\n'
          'Bảng cược hiện tại sẽ bị xóa và thay thế.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Tạo'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final config = context.read<SettingsViewModel>().config;
      if (selectedMien == 'Bắc') {
        await viewModel.createBacGanBettingTable(number, config);
      } else if (selectedMien == 'Trung') {
        await viewModel.createTrungGanBettingTable(number, config);
      } else {
        await viewModel.createCycleBettingTable(number, config);
      }
      if (context.mounted) {
        Navigator.pop(context);
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
            mainNavigationKey.currentState?.switchToTab(1);
          }
        }
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      print('❌ Error: $e');
    }
  }
}