import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:async';
import 'home_viewmodel.dart';
import '../betting/betting_viewmodel.dart';
import '../../../data/models/betting_row.dart';
import '../../../core/utils/number_utils.dart';
import '../../../core/theme/theme_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

// ✅ Thêm WidgetsBindingObserver để tự động tắt Timer khi ẩn app
class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late WebViewController _webViewController;
  Timer? _urlCheckTimer;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Đăng ký observer
    _initializeWebView();
    _startUrlCheckTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // Hủy observer
    _stopUrlCheckTimer(); // Hủy timer
    super.dispose();
  }

  // ✅ Tự động Dừng/Chạy Timer để tiết kiệm pin
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startUrlCheckTimer();
      _webViewController.reload();
    } else if (state == AppLifecycleState.paused) {
      _stopUrlCheckTimer();
    }
  }

  void _startUrlCheckTimer() {
    _stopUrlCheckTimer();
    _urlCheckTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (!mounted) return;
      final viewModel = context.read<HomeViewModel>();
      final newUrl = viewModel.getUrlForCurrentTime();
      
      if (newUrl != viewModel.currentUrl) {
        _webViewController.loadRequest(Uri.parse(newUrl));
        viewModel.updateUrl();
      }
    });
  }

  void _stopUrlCheckTimer() {
    _urlCheckTimer?.cancel();
    _urlCheckTimer = null;
  }

  void _initializeWebView() {
    final viewModel = context.read<HomeViewModel>();
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _isLoading = true),
          onPageFinished: (_) => setState(() => _isLoading = false),
          onNavigationRequest: (request) => NavigationDecision.navigate,
        ),
      )
      ..loadRequest(Uri.parse(viewModel.getUrlForCurrentTime()));
  }

  void _showSummaryTable(BuildContext context, BettingViewModel viewModel) {
    // ✅ Logic lấy dữ liệu sạch sẽ từ ViewModel
    final allRows = [...viewModel.todayCycleRows, ...viewModel.todayXienRows];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.3,
        minChildSize: 0.25,
        maxChildSize: 0.8,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: ThemeProvider.surface, // ✅ Dùng màu từ ThemeProvider
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 40,
                height: 3,
                decoration: BoxDecoration(
                  color: ThemeProvider.textSecondary, // ✅ Dùng màu từ ThemeProvider
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: allRows.isEmpty
                    ? const Center(
                        child: Text(
                          'Chưa có bảng cược cho ngày hôm nay',
                          style: TextStyle(color: ThemeProvider.textSecondary, fontSize: 16),
                        ),
                      )
                    : ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.all(12),
                        children: [_buildUnifiedTable(allRows)],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUnifiedTable(List<BettingRow> rows) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: ThemeProvider.borderColor), // ✅ Dùng màu viền
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 12),
            decoration: const BoxDecoration(
              color: ThemeProvider.tableHeader, // ✅ Dùng màu Header mới thêm
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: const Row(
              children: [
                Expanded(flex: 4, child: Text('Ngày', style: TextStyle(fontWeight: FontWeight.bold, color: ThemeProvider.textPrimary))),
                Expanded(flex: 3, child: Text('Miền', style: TextStyle(fontWeight: FontWeight.bold, color: ThemeProvider.textPrimary))),
                Expanded(flex: 4, child: Text('Số', style: TextStyle(fontWeight: FontWeight.bold, color: ThemeProvider.textPrimary))),
                Expanded(flex: 4, child: Text('Cược/số', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, color: ThemeProvider.textPrimary))),
              ],
            ),
          ),
          
          // Rows
          ...rows.asMap().entries.map((entry) {
            final index = entry.key;
            final row = entry.value;
            final isEven = index % 2 == 0;
            
            final isCycleRow = row.cuocSo > 0;
            final cuocValue = isCycleRow ? row.cuocSo : row.cuocMien;

            return Container(
              padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 12),
              // ✅ Logic màu chẵn/lẻ dùng ThemeProvider
              color: isEven ? ThemeProvider.surface : ThemeProvider.tableRowOdd,
              child: Row(
                children: [
                  Expanded(flex: 4, child: Text(row.ngay, style: const TextStyle(fontSize: 13, color: ThemeProvider.textPrimary))),
                  Expanded(flex: 3, child: Text(row.mien, style: const TextStyle(fontSize: 13, color: ThemeProvider.textPrimary))),
                  Expanded(flex: 4, child: Text(row.so, style: const TextStyle(fontSize: 13, color: ThemeProvider.textPrimary, fontWeight: FontWeight.w500))),
                  Expanded(flex: 4, child: Text(NumberUtils.formatCurrency(cuocValue), textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ThemeProvider.textPrimary))),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kết quả XS', style: TextStyle(color: Colors.white)),
        actions: [
          Consumer<BettingViewModel>(
            builder: (context, viewModel, child) {
              final totalRows = viewModel.todayCycleRows.length + viewModel.todayXienRows.length;
              return Stack(
                children: [
                  IconButton(
                    icon: Icon(Icons.table_chart, color: totalRows > 0 ? Theme.of(context).primaryColor.withOpacity(0.5) : Theme.of(context).primaryColor.withOpacity(0.1)),
                    tooltip: 'Xem bảng tóm tắt',
                    onPressed: totalRows > 0 ? () => _showSummaryTable(context, viewModel) : null,
                  ),
                  if (totalRows > 0)
                    Positioned(
                      right: 8, top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                        child: Text(
                          totalRows.toString(),
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _webViewController.reload(),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _webViewController),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}