// lib/presentation/screens/analysis/analysis_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'analysis_viewmodel.dart';
import '../settings/settings_viewmodel.dart';
import '../betting/betting_viewmodel.dart';
import '../../../core/utils/date_utils.dart' as date_utils;
import '../../../app.dart';
import '../../../data/models/cycle_analysis_result.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({Key? key}) : super(key: key);

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

enum AlertType { xien, tatCa, trung, bac }

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
              
              // 1. Chu kỳ (Tất cả) - GIỮ NGUYÊN Icons.loop
              if (viewModel.tatCaAlertCache == true)
                FutureBuilder<CycleAnalysisResult?>(
                  future: viewModel.analyzeCycleForAllMien(), // ✅ THÊM METHOD MỚI
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox.shrink();
                    final result = snapshot.data!;
                    
                    return _buildClickableAlertItem(
                      context: context,
                      viewModel: viewModel,
                      icon: Icons.text_fields,  // ✅ GIỮ NGUYÊN
                      color: const Color(0xFFEE5A5A),
                      title: 'Chu kỳ (Tất cả)',
                      subtitle: 'Số: ${result.targetNumber}',
                      days: result.maxGanDays,
                      threshold: 3,
                      type: AlertType.tatCa,
                      useTextIcon: 'C',
                    );
                  },
                ),
              // 2. Miền Trung - THAY BẰNG CHỮ T (dùng text icon)
              if (viewModel.trungAlertCache == true)
                FutureBuilder<CycleAnalysisResult?>(
                  future: viewModel.analyzeCycleForMien('Trung'), // ✅ THÊM METHOD MỚI
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox.shrink();
                    final result = snapshot.data!;
                    
                    return _buildClickableAlertItem(
                      context: context,
                      viewModel: viewModel,
                      icon: Icons.text_fields,  // ❌ KHÔNG DÙNG - sẽ dùng custom
                      color: const Color(0xFFBB31E6F),
                      title: 'Miền Trung',
                      subtitle: 'Số: ${result.targetNumber}',
                      days: result.maxGanDays,
                      threshold: 14,
                      type: AlertType.trung,
                      useTextIcon: 'T',  // ✅ THÊM PARAMETER MỚI
                    );
                  },
                ),

              // 3. Miền Bắc - THAY BẰNG CHỮ B
              if (viewModel.bacAlertCache == true)
                FutureBuilder<CycleAnalysisResult?>(
                  future: viewModel.analyzeCycleForMien('Bắc'), // ✅ THÊM METHOD MỚI
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox.shrink();
                    final result = snapshot.data!;
                    
                    return _buildClickableAlertItem(
                      context: context,
                      viewModel: viewModel,
                      icon: Icons.text_fields,  // ❌ KHÔNG DÙNG
                      color: const Color(0xFFB6771D),
                      title: 'Miền Bắc',
                      subtitle: 'Số: ${result.targetNumber}',
                      days: result.maxGanDays,
                      threshold: 16,
                      type: AlertType.bac,
                      useTextIcon: 'B',  // ✅ THÊM PARAMETER MỚI
                    );
                  },
                ),

              // 4. Xiên - THAY BẰNG GẠCH CHÉO
              if (viewModel.ganPairInfo != null && viewModel.ganPairInfo!.daysGan > 152)
                _buildClickableAlertItem(
                  context: context,
                  viewModel: viewModel,
                  icon: Icons.text_fields,  // ✅ GẠCH CHÉO - hoặc dùng custom
                  color: const Color(0xFF45B7B7),
                  title: 'Cặp số gan (Xiên)',
                  subtitle: 'Cặp: ${viewModel.ganPairInfo!.randomPair.display}',
                  days: viewModel.ganPairInfo!.daysGan,
                  threshold: 152,
                  type: AlertType.xien,
                  useTextIcon: 'X',
                ),
              
              // Thông báo nếu không có alert
              if ((viewModel.ganPairInfo?.daysGan ?? 0) <= 152 &&
                  viewModel.tatCaAlertCache != true &&
                  viewModel.trungAlertCache != true &&
                  viewModel.bacAlertCache != true)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.grey.shade600),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Hiện chưa có số nào thỏa điều kiện',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          // ✅ CHỈ CÒN NÚT ĐÓNG
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }


  // ✅ SỬA _buildAlertItem() THÀNH CLICKABLE
  Widget _buildClickableAlertItem({
    required BuildContext context,
    required AnalysisViewModel viewModel,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required int days,
    required int threshold,
    required AlertType type,
    String? useTextIcon,  // ✅ THÊM: Dùng chữ thay vì icon
  }) {
    return InkWell(
      onTap: () {
        Navigator.pop(context); // Đóng dialog
        _handleAlertItemClick(context, viewModel, type);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            // ✅ THAY ĐỔI: Hiển thị text hoặc icon
            if (useTextIcon != null)
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                child: Text(
                  useTextIcon,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              )
            else
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
                    '$days ngày (>$threshold)',
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
      ),
    );
  }

  // ✅ THÊM HANDLER KHI CLICK VÀO TỪNG ITEM
  void _handleAlertItemClick(
    BuildContext context,
    AnalysisViewModel viewModel,
    AlertType type,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tạo bảng cược'),
        content: Text(_getCreateTableMessage(type, viewModel)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _createTableForAlertType(context, viewModel, type);
            },
            child: const Text('Tạo bảng'),
          ),
        ],
      ),
    );
  }

  // ✅ LẤY MESSAGE CHO DIALOG XÁC NHẬN
  String _getCreateTableMessage(AlertType type, AnalysisViewModel viewModel) {
    switch (type) {
      case AlertType.xien:
        return 'Tạo bảng cược Xiên cho cặp ${viewModel.ganPairInfo!.randomPair.display}?\n\n'
            'Bảng hiện tại sẽ bị thay thế.';
      case AlertType.tatCa:
        return 'Tạo bảng cược Chu kỳ (Tất cả) cho số ${viewModel.cycleResult!.targetNumber}?\n\n'
            'Bảng hiện tại sẽ bị thay thế.';
      case AlertType.trung:
        return 'Tạo bảng cược Miền Trung cho số ${viewModel.cycleResult!.targetNumber}?\n\n'
            'Bảng hiện tại sẽ bị thay thế.';
      case AlertType.bac:
        return 'Tạo bảng cược Miền Bắc cho số ${viewModel.cycleResult!.targetNumber}?\n\n'
            'Bảng hiện tại sẽ bị thay thế.';
    }
  }

  // ✅ TẠO BẢNG THEO LOẠI
  Future<void> _createTableForAlertType(
    BuildContext context,
    AnalysisViewModel viewModel,
    AlertType type,
  ) async {
    final config = context.read<SettingsViewModel>().config;

    switch (type) {
      case AlertType.xien:
        await viewModel.createXienBettingTable();
        break;
      case AlertType.tatCa:
        await viewModel.createCycleBettingTable(config);
        break;
      case AlertType.trung:
        final number = viewModel.cycleResult!.targetNumber;
        await viewModel.createTrungGanBettingTable(number, config);
        break;
      case AlertType.bac:
        final number = viewModel.cycleResult!.targetNumber;
        await viewModel.createBacGanBettingTable(number, config);
        break;
    }

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
                    // ✅ THAY ICON BẰNG CHỮ C
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Center(
                        child: const Text(
                          'C',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFBEE5A5A),
                            height: 1.0,
                          ),
                        ),
                      ),
                    ),
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
                // ✅ 3. ĐỔI VỊ TRÍ: TẠO BẢNG TRƯỚC, GỬI TELEGRAM SAU
                if (viewModel.selectedMien != 'Nam')
                IconButton(
                  icon: const Icon(Icons.table_chart, color: Colors.orange),
                  tooltip: 'Tạo bảng cược',
                  onPressed: cycleResult != null
                      ? () {
                          if (viewModel.selectedMien == 'Bắc') {
                            _showCreateBacGanTableDialog(
                              context, 
                              viewModel, 
                              cycleResult.targetNumber,
                            );
                          } else if (viewModel.selectedMien == 'Trung') {
                            _showCreateTrungGanTableDialog(
                              context, 
                              viewModel, 
                              cycleResult.targetNumber,
                            );
                          } else {
                            _createCycleBettingTable(context, viewModel);
                          }
                        }
                      : null,
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blue),
                  tooltip: 'Gửi Telegram',
                  onPressed: cycleResult != null
                      ? () => _sendCycleToTelegram(context, viewModel)
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
              if (viewModel.selectedMien != 'Nam')
              _buildInfoRow('Số mục tiêu:', cycleResult.targetNumber),
              
              // ✅ 2. THÊM NHÓM SỐ GAN NHẤT (HIỂN THỊ CHO TẤT CẢ FILTER)
              const SizedBox(height: 8),
              const Text(
                'Nhóm số gan nhất:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              
              // ✅ HIỂN THỊ DẠNG CHIP ĐỂ CHỌN
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: cycleResult.ganNumbers.map((number) {
                  // ✅ HIGHLIGHT NẾU LÀ TARGET NUMBER
                  final isTarget = number == cycleResult.targetNumber;

                  // ✅ NẾU FILTER = NAM → DÙNG CHIP (KHÔNG CLICK)
                  if (viewModel.selectedMien == 'Nam') {
                    return Chip(
                      label: Text(
                        number,
                        style: TextStyle(
                          fontWeight: FontWeight.normal,
                          color: null,
                        ),
                      ),
                      backgroundColor: Colors.grey.shade100,
                      side: BorderSide(color: Colors.grey.shade300),
                    );
                  }
                  
                  return ActionChip(
                    label: Text(
                      number,
                      style: TextStyle(
                        fontWeight: isTarget ? FontWeight.bold : FontWeight.normal,
                        color: isTarget ? Colors.orange.shade700 : null,
                      ),
                    ),
                    backgroundColor: isTarget 
                        ? Colors.orange.shade50 
                        : Colors.grey.shade100,
                    side: BorderSide(
                      color: isTarget 
                          ? Colors.orange.shade300 
                          : Colors.grey.shade300,
                    ),
                    onPressed: () => _showNumberDetail(context, viewModel, number),
                  );
                }).toList(),
              ),
              
              // ✅ 1. BỎ PHÂN BỔ THEO MIỀN CHO NAM, TRUNG, BẮC
              // CHỈ HIỂN THỊ KHI FILTER = "TẤT CẢ"
              if (viewModel.selectedMien == 'Tất cả') ...[
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
                    // ✅ THAY ICON BẰNG CHỮ X
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Center(
                        child: Text(
                          'X',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF45B7B7),
                            height: 1.0,
                          ),
                        ),
                      ),
                    ),
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
                // ✅ ĐỔI VỊ TRÍ: TẠO BẢNG TRƯỚC, GỬI TELEGRAM SAU
                IconButton(
                  icon: const Icon(Icons.table_chart, color: Colors.orange),
                  tooltip: 'Tạo bảng cược',
                  onPressed: ganInfo != null
                      ? () => _createXienBettingTable(context, viewModel)
                      : null,
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blue),
                  tooltip: 'Gửi Telegram',
                  onPressed: ganInfo != null
                      ? () => _sendGanPairToTelegram(context, viewModel)
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
              // Hiển thị dạng text thường
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
        
        // ✅ CHECK alert từ cache (LUÔN HIỆN dù đang chọn filter khác)
        bool hasAlert = false;
        if (mien== 'Tất cả') {
          hasAlert = viewModel.tatCaAlertCache ?? false;
        } else if (mien == 'Trung') {
          hasAlert = viewModel.trungAlertCache ?? false;
        } else if (mien == 'Bắc') {
          hasAlert = viewModel.bacAlertCache ?? false;
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
                    // Tạo bảng (bên trái)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _createTableForNumber(context, viewModel, number);
                        },
                        icon: const Icon(Icons.table_chart, size: 20),
                        label: const Text('Tạo bảng'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Gửi Telegram (bên phải)
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