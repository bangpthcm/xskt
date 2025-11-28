// lib/presentation/screens/home/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:async';
import 'home_viewmodel.dart';
import '../betting/betting_viewmodel.dart';
import '../../../data/models/betting_row.dart';
import '../../../core/utils/number_utils.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late WebViewController _webViewController;
  Timer? _urlCheckTimer;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
    _startUrlCheckTimer();
  }

  void _initializeWebView() {
    final viewModel = context.read<HomeViewModel>();
    final initialUrl = viewModel.getUrlForCurrentTime();

    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            setState(() {
              _isLoading = false;
            });
            
            print('⚠️ WebView Error: ${error.description}');
            print('   Error code: ${error.errorCode}');
            print('   URL: ${error.url}');
          },
          onNavigationRequest: (NavigationRequest request) {
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(initialUrl));
  }

  void _startUrlCheckTimer() {
    _urlCheckTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      final viewModel = context.read<HomeViewModel>();
      final newUrl = viewModel.getUrlForCurrentTime();
      
      if (newUrl != viewModel.currentUrl) {
        _webViewController.loadRequest(Uri.parse(newUrl));
        viewModel.updateUrl();
      }
    });
  }

  void _showSummaryTable(BuildContext context, BettingViewModel viewModel) {
    final now = DateTime.now();
    final today = '${now.day.toString().padLeft(2, '0')}/${now.month}/${now.year}';
    
    final todayCycleRows = _getTodayCycleRows(viewModel, today);
    final todayXienRows = viewModel.xienTable
        ?.where((r) => r.ngay == today)
        .toList() ?? [];

    final allRows = <BettingRow>[...todayCycleRows, ...todayXienRows];

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
            color: Color(0xFF1E1E1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 40,
                height: 3,
                decoration: BoxDecoration(
                  color: Colors.grey.shade600,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              Expanded(
                child: allRows.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inbox_outlined,
                                size: 64,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Chưa có bảng cược cho ngày hôm nay',
                                style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.all(12),
                        children: [
                          _buildUnifiedTable(allRows),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<BettingRow> _getTodayCycleRows(BettingViewModel viewModel, String today) {
    final todayCycleRows = <BettingRow>[
      ...viewModel.cycleTable?.where((r) => r.ngay == today) ?? [],
      ...viewModel.trungTable?.where((r) => r.ngay == today) ?? [],
      ...viewModel.bacTable?.where((r) => r.ngay == today) ?? [],
    ];

    todayCycleRows.sort((a, b) {
      const mienOrder = {'Nam': 1, 'Trung': 2, 'Bắc': 3};
      final mienCompare = (mienOrder[a.mien] ?? 0).compareTo(mienOrder[b.mien] ?? 0);
      return mienCompare;
    });

    return todayCycleRows;
  }

  Widget _buildUnifiedTable(List<BettingRow> rows) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade800),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF2C2C2C),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Text(
                    'Ngày',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Miền',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Text(
                    'Số',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Text(
                    'Cược/số',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
          
          ...rows.asMap().entries.map((entry) {
            final index = entry.key;
            final row = entry.value;
            final isEven = index % 2 == 0;
            
            final isCycleRow = row.cuocSo > 0;
            final cuocValue = isCycleRow ? row.cuocSo : row.cuocMien;

            return Container(
              padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 12),
              color: isEven ? const Color(0xFF1E1E1E) : const Color(0xFF252525),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Text(
                      row.ngay,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      row.mien,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Text(
                      row.so,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Text(
                      NumberUtils.formatCurrency(cuocValue),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _urlCheckTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kết quả XS'),
        actions: [
          // ✅ NÚT XEM BẢNG TÓM TẮT
          Consumer<BettingViewModel>(
            builder: (context, viewModel, child) {
              final now = DateTime.now();
              final today = '${now.day.toString().padLeft(2, '0')}/${now.month}/${now.year}';
              
              final todayCycleRows = _getTodayCycleRows(viewModel, today);
              final todayXienRows = viewModel.xienTable
                  ?.where((r) => r.ngay == today)
                  .toList() ?? [];
              
              final totalRows = todayCycleRows.length + todayXienRows.length;
              
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.table_chart),
                    tooltip: 'Xem bảng tóm tắt',
                    onPressed: totalRows > 0 
                        ? () => _showSummaryTable(context, viewModel)
                        : null,
                  ),
                  if (totalRows > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Text(
                          totalRows.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
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
            onPressed: () {
              _webViewController.reload();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _webViewController),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}