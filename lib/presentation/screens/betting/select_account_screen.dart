// lib/presentation/screens/betting/select_account_screen.dart
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../data/models/app_config.dart';
import '../../../data/models/api_account.dart';
import '../../../data/services/betting_api_service.dart';

class SelectAccountScreen extends StatefulWidget {
  final List<ApiAccount> accounts;

  const SelectAccountScreen({
    Key? key,
    required this.accounts,
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

  Future<void> _handleAccountSelect(int index) async {
    final account = widget.accounts[index];

    setState(() {
      _selectedAccountIndex = index;
      _isAuthenticating = true;
    });

    try {
      print('🔐 Authenticating account: ${account.username}');

      // ✅ Xác thực và lấy token
      final token = await _apiService.authenticateAndGetToken(account);

      if (!mounted) return;

      if (token != null && token.isNotEmpty) {
        print('✅ Token received, opening WebView...');

        // ✅ Mở WebView với token
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BettingWebViewScreen(
              token: token,
              accountUsername: account.username,
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

  const BettingWebViewScreen({
    Key? key,
    required this.token,
    required this.accountUsername,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Betting - ${widget.accountUsername}'),
        actions: [
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