// lib/presentation/screens/win_history/win_history_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/cycle_win_history.dart';
import '../../../data/models/xien_win_history.dart';
import '../../../core/utils/number_utils.dart';
import 'win_history_viewmodel.dart';
import '../../widgets/empty_state_widget.dart';

class WinHistoryScreen extends StatefulWidget {
  final int initialTab;

  const WinHistoryScreen({
    Key? key,
    this.initialTab = 0,
  }) : super(key: key);

  @override
  State<WinHistoryScreen> createState() => _WinHistoryScreenState();
}

class _WinHistoryScreenState extends State<WinHistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WinHistoryViewModel>().loadHistory();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử thắng/thua'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.deepPurple,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.deepPurple,
          tabs: const [
            Tab(text: 'Ba miền'),
            Tab(text: 'Miền Trung'),
            Tab(text: 'Miền Bắc'),
            Tab(text: 'Xiên Bắc'),
          ],
        ),
      ),
      body: Consumer<WinHistoryViewModel>(
        builder: (context, viewModel, child) {
          // Hiển thị loading khi chưa có dữ liệu
          if (viewModel.isLoading && viewModel.cycleHistory.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          // Hiển thị lỗi nếu có
          if (viewModel.errorMessage != null && viewModel.cycleHistory.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(viewModel.errorMessage!),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => viewModel.loadHistory(),
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            );
          }

          return TabBarView(
            controller: _tabController,
            children: [
              // Tab 1: Ba miền (CycleWinHistory)
              _buildHistoryList(
                context, 
                viewModel.cycleHistory, 
                onLoadMore: viewModel.loadMoreCycle,
                hasMore: viewModel.hasMoreCycle,
              ),
              // Tab 2: Miền Trung (CycleWinHistory)
              _buildHistoryList(
                context, 
                viewModel.trungHistory, 
                onLoadMore: viewModel.loadMoreTrung,
                hasMore: viewModel.hasMoreTrung,
              ),
              // Tab 3: Miền Bắc (CycleWinHistory)
              _buildHistoryList(
                context, 
                viewModel.bacHistory, 
                onLoadMore: viewModel.loadMoreBac,
                hasMore: viewModel.hasMoreBac,
              ),
              // Tab 4: Xiên Bắc (XienWinHistory)
              _buildHistoryList(
                context, 
                viewModel.xienHistory, 
                onLoadMore: viewModel.loadMoreXien,
                hasMore: viewModel.hasMoreXien,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHistoryList(
    BuildContext context, 
    List<dynamic> history, 
    {
      required VoidCallback onLoadMore,
      required bool hasMore,
    }
  ) {
    if (history.isEmpty) {
      return const EmptyStateWidget(
        title: 'Chưa có dữ liệu',
        message: 'Lịch sử sẽ hiển thị tại đây',
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification scrollInfo) {
        if (!scrollInfo.metrics.atEdge && scrollInfo.metrics.pixels > 0) {
           if (scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
             if (hasMore) {
               onLoadMore();
             }
           }
        }
        return false;
      },
      child: RefreshIndicator(
        onRefresh: () async {
          await context.read<WinHistoryViewModel>().loadHistory();
        },
        child: ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: history.length + (hasMore ? 1 : 0),
          separatorBuilder: (ctx, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            if (index == history.length) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            }

            final item = history[index];
            return _buildHistoryItem(item);
          },
        ),
      ),
    );
  }

  Widget _buildHistoryItem(dynamic item) {
    // Khai báo biến mặc định
    String ngayTrung = '';
    double loiLo = 0.0;
    double tongTienCuoc = 0.0;
    String soDanh = '';
    int soLanTrung = 0;

    // ✅ KIỂM TRA KIỂU DỮ LIỆU ĐỂ LẤY ĐÚNG TRƯỜNG
    if (item is CycleWinHistory) {
      ngayTrung = item.ngayTrung;
      loiLo = item.loiLo;
      tongTienCuoc = item.tongTienCuoc;
      soDanh = item.soMucTieu; // Trường đúng trong model Cycle
      soLanTrung = item.soLanTrung; // Trường đúng trong model Cycle
    } else if (item is XienWinHistory) {
      ngayTrung = item.ngayTrung;
      loiLo = item.loiLo;
      tongTienCuoc = item.tongTienCuoc;
      soDanh = item.capSoMucTieu; // Trường đúng trong model Xien
      soLanTrung = item.soLanTrungCap; // Trường đúng trong model Xien
    }

    // Format tiền tệ
    final String profitText = NumberUtils.formatCurrency(loiLo);
    final String betText = NumberUtils.formatCurrency(tongTienCuoc);
    
    // Màu sắc (Chỉ dựa trên Lời/Lỗ)
    final Color profitColor = loiLo >= 0 ? Colors.green : Colors.red;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dòng 1: Ngày và Số lần trúng
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Ngày: $ngayTrung',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.blue),
                  ),
                  child: Text(
                    'Trúng: $soLanTrung lần',
                    style: const TextStyle(
                      color: Colors.blue, 
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            
            const Divider(height: 16),

            // Dòng 2: Số đánh
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Số đánh: ', style: TextStyle(color: Colors.grey)),
                Expanded(
                  child: Text(
                    soDanh,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Dòng 3: Lợi nhuận
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Lợi nhuận:'),
                Text(
                  profitText,
                  style: TextStyle(
                    color: profitColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 4),

            // Dòng 4: Tổng cược
             Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Tổng tiền cược:', style: TextStyle(color: Colors.grey)),
                Text(betText, style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}