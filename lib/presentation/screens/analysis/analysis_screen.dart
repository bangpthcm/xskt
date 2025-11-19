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

enum AlertType { xien, tatCa, trung, bac }

class _AnalysisScreenState extends State<AnalysisScreen> 
    with SingleTickerProviderStateMixin {

  late AnimationController _pulseController;  // ✅ THÊM
  late Animation<double> _pulseAnimation; 

  @override
  void initState() {
    super.initState();

    // ✅ Setup animation
    _pulseController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
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
  void dispose() {
    _pulseController.dispose();  // ✅ THÊM
    super.dispose();
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

  // ✅ SỬA: _buildAlertBanner method
  Widget _buildAlertBanner(AnalysisViewModel viewModel) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      child: viewModel.hasAnyAlert ? Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: InkWell(
          onTap: () => _showAlertDialog(context, viewModel),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: Theme.of(context).primaryColor,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Có số gan thỏa điều kiện!',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Nhấn để xem chi tiết',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).primaryColor.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _getAlertCount(viewModel).toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, color: Theme.of(context).primaryColor),
              ],
            ),
          ),
        ),
      ) : const SizedBox.shrink(),
    );
  }

  // ✅ THÊM: Dialog hiển thị chi tiết alert
  void _showAlertDialog(BuildContext context, AnalysisViewModel viewModel) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.white),
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
                      color: Colors.grey,
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
                      threshold: 9,
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
                      threshold: 15,
                      type: AlertType.bac,
                      useTextIcon: 'B',  // ✅ THÊM PARAMETER MỚI
                    );
                  },
                ),

              // 4. Xiên - THAY BẰNG GẠCH CHÉO
              if (viewModel.ganPairInfo != null && viewModel.ganPairInfo!.daysGan > 150)
                _buildClickableAlertItem(
                  context: context,
                  viewModel: viewModel,
                  icon: Icons.text_fields,  // ✅ GẠCH CHÉO - hoặc dùng custom
                  color: Colors.grey,
                  title: 'Cặp số gan (Xiên)',
                  subtitle: 'Cặp: ${viewModel.ganPairInfo!.randomPair.display}',
                  days: viewModel.ganPairInfo!.daysGan,
                  threshold: 150,
                  type: AlertType.xien,
                  useTextIcon: 'X',
                ),
              
              // Thông báo nếu không có alert
              if ((viewModel.ganPairInfo?.daysGan ?? 0) <= 150 &&
                  viewModel.tatCaAlertCache != true &&
                  viewModel.trungAlertCache != true &&
                  viewModel.bacAlertCache != true)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Theme.of(context).primaryColor),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Hiện chưa có số nào thỏa điều kiện',
                          style: TextStyle(color: Theme.of(context).primaryColor),
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
    print('📘 Alert item clicked: $type');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tạo bảng cược'),
        content: Text(_getCreateTableMessage(type, viewModel)),
        actions: [
          TextButton(
            onPressed: () {
              print('❌ User cancelled');
              Navigator.pop(context);
            },
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              print('✅ User confirmed, creating table...');
              Navigator.pop(context); // ✅ Đóng dialog xác nhận
              
              // ❌ BỎ LOADING Ở ĐÂY - Các hàm bên trong đã có loading riêng
              
              try {
                await _createTableForAlertType(context, viewModel, type);
                // ✅ Không cần đóng loading ở đây nữa
              } catch (e) {
                print('❌ Error in _handleAlertItemClick: $e');
                
                // ✅ HIỂN THỊ LỖI
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Lỗi: $e'),
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
    print('🎯 _createTableForAlertType called: $type'); // ✅ ADD LOG
    
    final config = context.read<SettingsViewModel>().config;

    try {
      switch (type) {
        case AlertType.xien:
          print('   Creating Xiên table...'); // ✅ ADD LOG
          await viewModel.createXienBettingTable();
          break;
          
        case AlertType.tatCa:
          print('   Creating Tất cả table...'); // ✅ ADD LOG
          await viewModel.createCycleBettingTable(config);
          break;
          
        case AlertType.trung:
          print('   Analyzing Trung...'); // ✅ ADD LOG
          final trungResult = await viewModel.analyzeCycleForMien('Trung');
          if (trungResult == null) {
            throw Exception('Không thể phân tích Miền Trung');
          }
          print('   Creating Trung table for number: ${trungResult.targetNumber}'); // ✅ ADD LOG
          await viewModel.createTrungGanBettingTable(trungResult.targetNumber, config);
          break;
          
        case AlertType.bac:
          print('   Analyzing Bắc...'); // ✅ ADD LOG
          final bacResult = await viewModel.analyzeCycleForMien('Bắc');
          if (bacResult == null) {
            throw Exception('Không thể phân tích Miền Bắc');
          }
          print('   Creating Bắc table for number: ${bacResult.targetNumber}'); // ✅ ADD LOG
          await viewModel.createBacGanBettingTable(bacResult.targetNumber, config);
          break;
      }

      print('   ✅ Table created successfully'); // ✅ ADD LOG

      // ✅ XỬ LÝ SAU KHI TẠO BẢNG
      if (context.mounted) {
        if (viewModel.errorMessage == null) {
          print('   Reloading betting tables...'); // ✅ ADD LOG
          await context.read<BettingViewModel>().loadBettingTables();
          
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Tạo bảng cược thành công!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
            
            await Future.delayed(const Duration(milliseconds: 300));
            
            if (context.mounted) {
              print('   Switching to betting tab...'); // ✅ ADD LOG
              mainNavigationKey.currentState?.switchToTab(1);
            }
          }
        } else {
          print('   ❌ ViewModel error: ${viewModel.errorMessage}'); // ✅ ADD LOG
        }
      }
    } catch (e, stackTrace) {
      print('❌ Error in _createTableForAlertType: $e'); // ✅ ADD LOG
      print('   Stack trace: $stackTrace'); // ✅ ADD LOG
      rethrow; // ✅ Throw lại để _handleAlertItemClick bắt được
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
                Expanded(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Text(
                        'Chu kỳ 00-99',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      // ✅ THAY ĐỔI: Hiển thị chấm đỏ nếu CÓ BẤT KỲ alert nào (từ cache)
                      if (viewModel.tatCaAlertCache == true || 
                          viewModel.trungAlertCache == true || 
                          viewModel.bacAlertCache == true)
                        Positioned(
                          left: 127,
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
                            _createCycleBettingTable(context, viewModel);
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
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Text(
                        'Cặp xiên Bắc',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      // ✅ FIX: Đổi từ hasCycleAlert thành hasXienAlert
                      if (viewModel.hasXienAlert)
                        Positioned(
                          left: 127,
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
              _buildInfoRow('Số ngày gan:', '${ganInfo.daysGan} ngày'),
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
    print('🎯 _createTableForNumberWithMien called');
    print('   Number: $number');
    
    final selectedMien = viewModel.selectedMien;
    print('   Selected mien: $selectedMien');
    
    // ✅ XÁC ĐỊNH LOẠI BẢNG DỰA TRÊN FILTER
    String tableType;
    if (selectedMien == 'Bắc') {
      tableType = 'Miền Bắc';
    } else if (selectedMien == 'Trung') {
      tableType = 'Miền Trung';
    } else {
      tableType = 'Chu kỳ (Tất cả)';
    }
    
    print('   Table type: $tableType');
    
    // ✅ LƯU TẤT CẢ REFERENCES TRƯỚC KHI HIỂN THỊ DIALOG
    final settingsViewModel = context.read<SettingsViewModel>();
    final bettingViewModel = context.read<BettingViewModel>();
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xác nhận'),
        content: Text(
          'Tạo bảng cược $tableType cho số $number?\n\n'
          'Bảng cược hiện tại sẽ bị xóa và thay thế.',
          style: TextStyle(color: Theme.of(context).primaryColor.withOpacity(0.9)),
        ),
        actions: [
          TextButton(
            onPressed: () {
              print('   ❌ User cancelled');
              Navigator.pop(dialogContext, false);
            },
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              print('   ✅ User confirmed');
              Navigator.pop(dialogContext, true);
            },
            child: const Text('Tạo'),
          ),
        ],
      ),
    );

    print('   Confirm result: $confirm');

    if (confirm != true) {
      print('   ⚠️ User cancelled');
      return;
    }

    print('   💰 Config loaded');

    // ✅ HIỂN THỊ LOADING (DÙNG NAVIGATOR ĐÃ LƯU)
    print('   📊 Showing loading dialog');
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
      
      // ✅ GỌI HÀM ĐÚNG THEO MIỀN
      if (selectedMien == 'Bắc') {
        print('   🎯 Creating Bắc table...');
        await viewModel.createBacGanBettingTable(number, config);
      } else if (selectedMien == 'Trung') {
        print('   🎯 Creating Trung table...');
        await viewModel.createTrungGanBettingTable(number, config);
      } else {
        print('   🎯 Creating Cycle table...');
        await viewModel.createCycleBettingTableForNumber(number, config);
      }

      print('   ✅ Table creation completed');

      // ✅ ĐÓNG LOADING
      print('   🔄 Closing loading dialog');
      navigator.pop();

      if (viewModel.errorMessage == null) {
        print('   ✅ No errors, reloading betting tables');
        await bettingViewModel.loadBettingTables();
        
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Tạo bảng cược thành công!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        
        await Future.delayed(const Duration(milliseconds: 300));
        
        print('   🔀 Switching to betting tab');
        mainNavigationKey.currentState?.switchToTab(1);
      }
    } catch (e, stackTrace) {
      print('   ❌ Exception caught: $e');
      print('   Stack trace: $stackTrace');
      
      // ✅ ĐÓNG LOADING
      navigator.pop();
    }
  }
  // ✅ THÊM: Helper method
  int _getAlertCount(AnalysisViewModel viewModel) {
    int count = 0;
    if (viewModel.hasXienAlert) count++;
    if (viewModel.tatCaAlertCache == true) count++;
    if (viewModel.trungAlertCache == true) count++;
    if (viewModel.bacAlertCache == true) count++;
    return count;
  }
}

// ✅ THÊM: Custom painter cho ripple effect
class RipplePainter extends CustomPainter {
  final double progress;
  final Color color;

  RipplePainter(this.progress, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity((1 - progress) * 0.3)
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width * 0.8) * progress;

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(RipplePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}