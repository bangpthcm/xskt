// lib/presentation/screens/analysis/analysis_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'analysis_viewmodel.dart';
import '../settings/settings_viewmodel.dart';
import '../betting/betting_viewmodel.dart';
import '../../../core/utils/date_utils.dart' as date_utils;
import '../../../app.dart';
import '../../../data/models/cycle_analysis_result.dart';
import '../../widgets/shimmer_loading.dart';
import '../../../data/services/service_manager.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({Key? key}) : super(key: key);

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}


class _AnalysisScreenState extends State<AnalysisScreen> 
    with SingleTickerProviderStateMixin {

  @override
  void initState() {
    super.initState();
    // ✅ FIX: Use ServiceManager
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        print('📊 AnalysisScreen: Waiting for services...');
        
        // ✅ Use ServiceManager.waitForReady()
        await ServiceManager.waitForReady();
        
        if (mounted) {
          context.read<AnalysisViewModel>().loadAnalysis();
        }
      } catch (e) {
        print('❌ AnalysisScreen: Error: $e');
      }
    });
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
              // ✅ THÊM: Haptic feedback
              HapticFeedback.mediumImpact();
              
              await viewModel.loadAnalysis(useCache: false);
              
              // ✅ THÊM: Success feedback
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
            Row(
              children: [
                Expanded(
                  child: // ✅ THAY ĐỔI: Từ Stack với left cố định sang Row với flexible positioning
                  Row(
                    children: [
                      Text(
                        'Chu kỳ 00-99',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      // ✅ Dấu chấm đỏ sát ngay bên phải text
                      if (viewModel.tatCaAlertCache == true || 
                          viewModel.trungAlertCache == true || 
                          viewModel.bacAlertCache == true)
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 15), // Điều chỉnh vị trí
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
                      const Spacer(), // Đẩy các icon sang phải
                    ],
                  ),
                ),
                // ✅ 3. ĐỔI VỊ TRÍ: TẠO BẢNG TRƯỚC, GỬI TELEGRAM SAU
                if (viewModel.selectedMien != 'Nam')
                IconButton(
                  icon: Icon(Icons.table_chart, color: Theme.of(context).primaryColor.withOpacity(0.9)),
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
                            _createCycleBettingTable(
                              context, 
                              viewModel, 
                              cycleResult.targetNumber,
                            );
                          }
                        }
                      : null,
                ),
                IconButton(
                  icon: Icon(Icons.send, color: Theme.of(context).primaryColor.withOpacity(0.9)),
                  tooltip: 'Gửi Telegram',
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
              _buildInfoRow('Số mục tiêu:', cycleResult.targetNumber),
              
              // ✅ 2. THÊM NHÓM SỐ GAN NHẤT (HIỂN THỊ CHO TẤT CẢ FILTER)
              const SizedBox(height: 8),
              const Text(
                'Nhóm số gan nhất:',
                style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
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
                          color: Colors.grey.shade400,
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
                        color: isTarget ? Theme.of(context).primaryColor.withOpacity(0.9) : Colors.grey.shade500,
                      ),
                    ),
                    backgroundColor: isTarget 
                        ? Theme.of(context).primaryColor.withOpacity(0.3) 
                        : const Color(0xFF2C2C2C),
                    side: BorderSide(
                      color: isTarget 
                          ? Theme.of(context).primaryColor.withOpacity(0.8) 
                          : Colors.grey.shade600,
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
                // ✅ ĐỔI VỊ TRÍ: TẠO BẢNG TRƯỚC, GỬI TELEGRAM SAU
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
              // Hiển thị dạng text thường
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
              }).toList(),
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
          
          // ✅ CHECK alert từ cache
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
                            ? Theme.of(context).primaryColor.withOpacity(0.9)  // ✅ Text trắng khi selected
                            : Colors.grey.shade500,  // ✅ Text xám tối khi chưa selected
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  selected: isSelected,
                  backgroundColor: const Color(0xFF2C2C2C),  // ✅ Nền xám rất tối khi chưa selected
                  selectedColor: Theme.of(context).primaryColor.withOpacity(0.3),  // ✅ Nền xanh dương khi selected
                  side: BorderSide(
                    color: isSelected 
                        ? Theme.of(context).primaryColor.withOpacity(0.8)   // ✅ Viền xanh khi selected
                        : Colors.grey.shade600,  // ✅ Viền xám tối khi chưa selected
                    width: 1,
                  ),
                  checkmarkColor: Colors.transparent,
                  showCheckmark: false,
                  onSelected: (selected) {
                    if (selected) {
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

  void _createCycleBettingTable(
    BuildContext context,
    AnalysisViewModel viewModel,
    String number,
  ) {
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

  Future<void> _showNumberDetail(
    BuildContext context,
    AnalysisViewModel viewModel,
    String number,
  ) async {
    print('🔍 _showNumberDetail called for number: $number'); // ✅ ADD LOG
    print('   Selected mien: ${viewModel.selectedMien}'); // ✅ ADD LOG
    
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

    print('✅ Number detail loaded'); // ✅ ADD LOG

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.95,
          constraints: const BoxConstraints(maxWidth: 500),
          decoration: BoxDecoration(
            color: Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Content
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Thông tin $number theo từng miền:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),

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

              // 2 NÚT TRÊN
              Container(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: Row(
                  children: [
                    // Tạo bảng - ✅ THÊM LOG
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          print('📊 Create table button clicked'); // ✅ ADD LOG
                          Navigator.pop(context);
                          _createTableForNumberWithMien(context, viewModel, number);
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

                    // Gửi Telegram
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          print('📤 Send telegram button clicked'); // ✅ ADD LOG
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

              // NÚT ĐÓNG Ở DƯỚI
              Container(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      print('❌ Close button clicked'); // ✅ ADD LOG
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.close, size: 20),
                    label: const Text('Đóng'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ THAY ĐỔI 3: Sửa _buildMienCard() - Dùng màu tối như header
  Widget _buildMienCard(String title, dynamic detail, Color accentColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // ✅ MÀU TỐI GIỐNG HEADER
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accentColor.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: accentColor, // Giữ màu accent cho title
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

  // ✅ HÀM MỚI: Tạo bảng theo miền đang chọn (FIXED V2)
  Future<void> _createTableForNumberWithMien(
    BuildContext context,
    AnalysisViewModel viewModel,
    String number,
  ) async {
    print('🎯 Creating table for number: $number');

    final selectedMien = viewModel.selectedMien;
    print('   Selected mien: $selectedMien');

    // ✅ Xác định table type
    final BettingTableTypeEnum tableType;
    String tableDisplayName;

    if (selectedMien == 'Bắc') {
      tableType = BettingTableTypeEnum.bac;
      tableDisplayName = 'Miền Bắc';
    } else if (selectedMien == 'Trung') {
      tableType = BettingTableTypeEnum.trung;
      tableDisplayName = 'Miền Trung';
    } else {
      tableType = BettingTableTypeEnum.tatca;
      tableDisplayName = 'Chu kỳ (Tất cả)';
    }

    // ✅ Lưu references
    final settingsViewModel = context.read<SettingsViewModel>();
    final bettingViewModel = context.read<BettingViewModel>();
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // ✅ Xác nhận
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

    // ✅ Show loading
    navigator.push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: false,
        pageBuilder: (_, __, ___) => const Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );

    try {
      final config = settingsViewModel.config;

      // ✅ GỌI wrapper (chọn tùy theo type)
      if (selectedMien == 'Bắc') {
        await viewModel.createBacGanBettingTable(number, config);
      } else if (selectedMien == 'Trung') {
        await viewModel.createTrungGanBettingTable(number, config);
      } else {
        // ✅ Gọi createCycleBettingTableForNumber (giữ nguyên từ code cũ)
        await viewModel.createCycleBettingTable(number, config);
      }

      // ✅ Close loading
      navigator.pop();

      if (viewModel.errorMessage == null) {
        await bettingViewModel.loadBettingTables();

        scaffoldMessenger.showSnackBar(
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
    } catch (e) {
      print('❌ Error: $e');
      navigator.pop();
    }
  }
}