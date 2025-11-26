// lib/presentation/screens/betting/select_account_screen.dart
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:provider/provider.dart';
import '../../../data/models/app_config.dart';
import '../../../data/models/api_account.dart';
import '../../../data/models/betting_row.dart';
import '../../../data/services/betting_api_service.dart';
import 'betting_viewmodel.dart';
import '../../../core/utils/number_utils.dart';

class SelectAccountScreen extends StatefulWidget {
  final List<ApiAccount> accounts;
  final String domain;

  const SelectAccountScreen({
    Key? key,
    required this.accounts,
    required this.domain,
  }) : super(key: key);

  @override
  State<SelectAccountScreen> createState() => _SelectAccountScreenState();
}

class _SelectAccountScreenState extends State<SelectAccountScreen> {
  late BettingApiService _apiService;
  int? _selectedAccountIndex;
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    _apiService = BettingApiService();
  }

  @override
  void dispose() {
    _apiService.clearCache();
    super.dispose();
  }

  Future<void> _handleAccountSelect(int index) async {  // ✅ REMOVE parameter domain
    final account = widget.accounts[index];

    setState(() {
      _selectedAccountIndex = index;
      _isAuthenticating = true;
    });

    try {
      print('🔐 Authenticating account: ${account.username}');
      print('   Domain: ${widget.domain}');  // ✅ Dùng widget.domain

      final token = await _apiService.authenticateAndGetToken(account, widget.domain);  // ✅ Truyền domain

      if (!mounted) return;

      if (token != null && token.isNotEmpty) {
        print('✅ Token received, opening WebView...');

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BettingWebViewScreen(
              token: token,
              accountUsername: account.username,
              domain: widget.domain,  // ✅ Truyền domain
            ),
          ),
        );
      } else {
        print('❌ Failed to get token');
        _showErrorDialog('Xác thực thất bại', 'Không thể lấy token. Vui lòng thử lại.');
      }
    } catch (e) {
      print('❌ Error: $e');
      if (mounted) {
        _showErrorDialog('Lỗi xác thực', '$e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
          _selectedAccountIndex = null;
        });
      }
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.accounts.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chọn tài khoản')),
        body: const Center(
          child: Text('Chưa có tài khoản được cấu hình trong Settings'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chọn tài khoản Betting'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text(
              'Chọn tài khoản để đăng nhập vào Betting:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ...List.generate(widget.accounts.length, (index) {
            final account = widget.accounts[index];
            final isSelected = _selectedAccountIndex == index;
            final isLoading = _isAuthenticating && isSelected;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              color: isSelected
                  ? Theme.of(context).primaryColor.withOpacity(0.1)
                  : const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isSelected
                      ? Theme.of(context).primaryColor
                      : Colors.grey.shade800,
                  width: 2,
                ),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isLoading
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Theme.of(context).primaryColor,
                              ),
                            ),
                          )
                        : Icon(
                            Icons.person,
                            color: Theme.of(context).primaryColor,
                          ),
                  ),
                ),
                title: Text(
                  account.username,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                subtitle: Text(
                  'Tài khoản Betting #${index + 1}',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 13,
                  ),
                ),
                trailing: isSelected
                    ? Icon(
                        Icons.check_circle,
                        color: Theme.of(context).primaryColor,
                        size: 24,
                      )
                    : Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.grey.shade600,
                        size: 18,
                      ),
                onTap: _isAuthenticating ? null : () => _handleAccountSelect(index),
              ),
            );
          }),
          const SizedBox(height: 24),
          Text(
            '💡 Mẹo: Tài khoản được cấu hình trong Settings → Tài khoản API',
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 13,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

/// ✅ WebView Screen
class BettingWebViewScreen extends StatefulWidget {
  final String token;
  final String accountUsername;
  final String domain;  // ✅ THÊM

  const BettingWebViewScreen({
    Key? key,
    required this.token,
    required this.accountUsername,
    required this.domain,  // ✅ THÊM
  }) : super(key: key);

  @override
  State<BettingWebViewScreen> createState() => _BettingWebViewScreenState();
}

class _BettingWebViewScreenState extends State<BettingWebViewScreen> {
  late WebViewController _webViewController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    final url = 'https://m-web-sg.quayso.live/?style=blue&token=${widget.token}';
    
    print('🌐 Loading WebView: $url');

    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF121212))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            print('📍 Page started: $url');
            setState(() => _isLoading = true);
          },
          onPageFinished: (String url) {
            print('✅ Page finished: $url');
            setState(() => _isLoading = false);
          },
          onWebResourceError: (WebResourceError error) {
            print('❌ WebResource error: ${error.description}');
            setState(() => _isLoading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(url));
  }

  void _showSummaryTable(BuildContext context, BettingViewModel viewModel) {
    final now = DateTime.now();
    final today = '${now.day.toString().padLeft(2, '0')}/${now.month}/${now.year}';
    
    // Lấy dữ liệu chu kỳ + xiên hôm nay
    final todayCycleRows = _getTodayCycleRows(viewModel, today);
    final todayXienRows = viewModel.xienTable
        ?.where((r) => r.ngay == today)
        .toList() ?? [];

    // ✅ KẾT HỢP 2 BẢNG THÀNH 1
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
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 40,
                height: 3,
                decoration: BoxDecoration(
                  color: Colors.grey.shade600,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Content - BẢNG KẾT HỢP
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
          // Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF2C2C2C),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: const [
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
          
          // Rows
          ...rows.asMap().entries.map((entry) {
            final index = entry.key;
            final row = entry.value;
            final isEven = index % 2 == 0;
            
            // ✅ Xác định loại cược: Chu kỳ (có cuocSo và > 0) hoặc Xiên (cuocSo null hoặc = 0)
            final isCycleRow = row.cuocSo != null && row.cuocSo! > 0;
            final cuocValue = isCycleRow ? row.cuocSo! : row.cuocMien;

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
          }).toList(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Betting - ${widget.accountUsername}'),
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
            onPressed: () => _webViewController.reload(),
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