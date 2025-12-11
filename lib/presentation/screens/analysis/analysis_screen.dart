// lib/presentation/screens/analysis/analysis_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../app.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/date_utils.dart' as date_utils;
import '../../../data/models/number_detail.dart';
import '../../../data/models/rebetting_summary.dart';
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
  String? _selectedNumber;
  NumberDetail? _currentNumberDetail;
  bool _isLoadingDetail = false;
  bool _isRebettingMode = false;

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
          _isRebettingMode = viewModel.isRebettingMode;

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
                // ✨ THÊM: Toggle buttons
                _buildToggleButtons(viewModel),
                const SizedBox(height: 16),

                // ✨ Hiển thị Rebetting hoặc Farming
                if (_isRebettingMode) ...[
                  _buildRebettingSummaryCards(viewModel),
                  const SizedBox(height: 16),
                  _buildRebettingCycleSection(viewModel),
                ] else ...[
                  _buildOptimalSummaryCard(viewModel),
                  const SizedBox(height: 16),
                  _buildCycleSection(viewModel),
                  const SizedBox(height: 16),
                  _buildGanPairSection(viewModel),
                ],
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
            // ✅ HEADER: Tiêu đề + Ngày hôm nay
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween, // Đẩy 2 đầu
              children: [
                // Bên trái: Icon + Label
                Row(
                  children: [
                    Text(
                      'Ngày có thể bắt đầu',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                // Bên phải: Ngày hôm nay
                Text(
                  date_utils.DateUtils.formatDate(DateTime.now()),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const Divider(color: Colors.grey),

            // Nội dung
            _buildSummaryRow('Tất cả', viewModel.optimalTatCa,
                date: viewModel.dateTatCa),
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
    // Logic check highlight: Ngày >= Hôm nay
    bool isHighlight = false;
    if (date != null) {
      final now = DateTime.now();
      // Reset về 00:00:00 để so sánh chính xác theo ngày
      final today = DateTime(now.year, now.month, now.day);
      final targetDate = DateTime(date.year, date.month, date.day);

      // Nếu ngày dự kiến >= ngày hiện tại thì highlight
      if (targetDate.compareTo(today) >= 0) {
        isHighlight = true;
      }
    }

    // Nếu giá trị là "Đang tính..." hoặc Lỗi/Thiếu vốn thì không highlight
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
                  // ✅ Đổi màu xanh (hoặc màu nổi bật) nếu thỏa điều kiện
                  color: isHighlight ? Colors.grey : Colors.white,
                  fontWeight: isHighlight ? FontWeight.normal : FontWeight.bold,
                  fontSize: 16)),
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
            // --- HEADER (Đã xóa chấm đỏ alert) ---
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
                if (viewModel.selectedMien != 'Nam')
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
                  tooltip: 'Gửi Telegram',
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
              // 2. Hiển thị số ngày gan (Thuần túy)
              _buildInfoRow('Số ngày gan:', '${cycleResult.maxGanDays} ngày'),

              _buildInfoRow(
                'Lần cuối về:',
                date_utils.DateUtils.formatDate(cycleResult.lastSeenDate),
              ),
              if (viewModel.selectedMien != 'Nam')
                _buildInfoRow('Số mục tiêu:', cycleResult.targetNumber),

              // --- NHÓM SỐ GAN NHẤT ---
              const SizedBox(height: 8),
              const Text(
                'Nhóm số gan nhất:',
                style:
                    TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
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
                      label: Text(number,
                          style: TextStyle(color: Colors.grey.shade400)),
                      backgroundColor: Colors.grey.shade100,
                      side: BorderSide(color: Colors.grey.shade300),
                    );
                  }

                  return ActionChip(
                    label: Text(
                      number,
                      style: TextStyle(
                        fontWeight: isTarget || isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isTarget || isSelected
                            ? Theme.of(context).primaryColor.withOpacity(0.9)
                            : Colors.grey.shade500,
                      ),
                    ),
                    backgroundColor: isSelected
                        ? Theme.of(context).primaryColor.withOpacity(0.5)
                        : (isTarget
                            ? Theme.of(context).primaryColor.withOpacity(0.3)
                            : const Color(0xFF2C2C2C)),
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
                  style: TextStyle(
                      color: Colors.grey, fontWeight: FontWeight.bold),
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
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 14),
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
      return const Center(
          child: Padding(
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
                'Chi tiết số $_selectedNumber:',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Hiển thị thông tin từng miền
          if (_currentNumberDetail!.mienDetails.containsKey('Nam'))
            _buildInlineMienRow('Miền Nam',
                _currentNumberDetail!.mienDetails['Nam']!, Colors.orange),

          if (_currentNumberDetail!.mienDetails.containsKey('Trung'))
            _buildInlineMienRow('Miền Trung',
                _currentNumberDetail!.mienDetails['Trung']!, Colors.purple),

          if (_currentNumberDetail!.mienDetails.containsKey('Bắc'))
            _buildInlineMienRow('Miền Bắc',
                _currentNumberDetail!.mienDetails['Bắc']!, Colors.blue),
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
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 13),
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
                      const Spacer(),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.table_chart,
                      color: Theme.of(context).primaryColor.withOpacity(0.9)),
                  onPressed: ganInfo != null
                      ? () => _createXienBettingTable(context, viewModel)
                      : null,
                ),
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
                style:
                    TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
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
                  setState(() {
                    _selectedNumber = null;
                    _currentNumberDetail = null;
                  });
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

  Widget _buildInfoRow(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
                color: Colors.grey, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
                color: isHighlight ? Colors.white : null,
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

// ✨ NEW: REBETTING UI METHODS

  /// Build toggle buttons
  Widget _buildToggleButtons(AnalysisViewModel viewModel) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: _buildToggleButton(
              label: '🌾 FARMING',
              isSelected: !_isRebettingMode,
              onPressed: () {
                setState(() => _isRebettingMode = false);
                viewModel.toggleRebettingMode(false);
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildToggleButton(
              label: '♻️ REBETTING',
              isSelected: _isRebettingMode,
              onPressed: () {
                setState(() => _isRebettingMode = true);
                viewModel.toggleRebettingMode(true);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton({
    required String label,
    required bool isSelected,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected
            ? Theme.of(context).primaryColor.withOpacity(0.3)
            : Colors.grey.withOpacity(0.2),
        foregroundColor:
            isSelected ? Theme.of(context).primaryColor : Colors.grey,
        side: BorderSide(
          color: isSelected
              ? Theme.of(context).primaryColor
              : Colors.grey.withOpacity(0.5),
        ),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }

  /// Build Rebetting summary cards
  Widget _buildRebettingSummaryCards(AnalysisViewModel viewModel) {
    final result = viewModel.rebettingResult;
    if (result == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ngày hôm nay: ${date_utils.DateUtils.formatDate(DateTime.now())}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const Divider(),
            _buildRebettingSummaryRow('Tất cả', result.summaries['tatCa']),
            _buildRebettingSummaryRow('Nam', result.summaries['nam']),
            _buildRebettingSummaryRow('Trung', result.summaries['trung']),
            _buildRebettingSummaryRow('Bắc', result.summaries['bac']),
          ],
        ),
      ),
    );
  }

  Widget _buildRebettingSummaryRow(String mien, RebettingSummary? summary) {
    final text = summary == null ? 'Không có' : summary.ngayCoTheVao;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(mien),
          Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  /// Build Rebetting Chu kỳ section
  Widget _buildRebettingCycleSection(AnalysisViewModel viewModel) {
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
                IconButton(
                  icon: const Icon(Icons.table_chart),
                  onPressed: () => _createRebettingTable(context, viewModel),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () => _sendRebettingToTelegram(context, viewModel),
                ),
              ],
            ),
            const Divider(),
            _buildRebettingMienFilter(viewModel),
            const SizedBox(height: 16),
            _buildRebettingDetail(viewModel),
          ],
        ),
      ),
    );
  }

  Widget _buildRebettingMienFilter(AnalysisViewModel viewModel) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: ['Tất cả', 'Nam', 'Trung', 'Bắc'].map((mien) {
          final isSelected = viewModel.selectedRebettingMien == mien;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(mien),
              selected: isSelected,
              onSelected: (selected) {
                viewModel.setSelectedRebettingMien(mien);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRebettingDetail(AnalysisViewModel viewModel) {
    final mienKey = _getMienKey(viewModel.selectedRebettingMien);
    final candidate = viewModel.rebettingResult?.selected[mienKey];

    if (candidate == null) {
      return const Center(child: Text('Không có ứng viên'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetailSection('📅 Lịch sử cũ:', [
          '• Bắt đầu cũ: ${candidate.ngayBatDauCu}',
          '• Trúng cũ: ${candidate.ngayTrungCu}',
        ]),
        const SizedBox(height: 12),
        _buildDetailSection('📊 Thông tin Gan:', [
          '• Gan cũ: ${candidate.soNgayGanCu} ngày',
          '• Gan mới: ${candidate.soNgayGanMoi} ngày',
          '• Duration: ${candidate.rebettingDuration} ngày',
        ]),
        const SizedBox(height: 12),
        Row(
          children: [
            const Text('Số mục tiêu: '),
            Chip(
              label: Text(candidate.soMucTieu),
              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.3),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Text('Ngày vào: '),
            Chip(
              label: Text(candidate.ngayCoTheVao),
              backgroundColor: Colors.green.withOpacity(0.3),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailSection(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        ...items
            .map((item) => Text(item, style: const TextStyle(fontSize: 14))),
      ],
    );
  }

  void _createRebettingTable(
      BuildContext context, AnalysisViewModel viewModel) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận'),
        content: const Text('Tạo bảng cược Rebetting?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              // TODO: Implement create rebetting table
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Tính năng sắp có!'),
                    backgroundColor: Colors.orange),
              );
            },
            child: const Text('Tạo bảng'),
          ),
        ],
      ),
    );
  }

  void _sendRebettingToTelegram(
      BuildContext context, AnalysisViewModel viewModel) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận'),
        content: const Text('Gửi kết quả Rebetting qua Telegram?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement send to telegram
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Tính năng sắp có!'),
                    backgroundColor: Colors.orange),
              );
            },
            child: const Text('Gửi'),
          ),
        ],
      ),
    );
  }

  String _getMienKey(String mien) {
    switch (mien) {
      case 'Tất cả':
        return 'tatCa';
      case 'Nam':
        return 'nam';
      case 'Trung':
        return 'trung';
      case 'Bắc':
        return 'bac';
      default:
        return 'tatCa';
    }
  }
}
