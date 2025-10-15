// lib/presentation/screens/home/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:async';
import 'home_viewmodel.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

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

      // ✅ FIX: Khởi tạo WebViewController với error handling tốt hơn
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
              
              // ✅ Chỉ show error message, không dùng SnackBar
              print('⚠️ WebView Error: ${error.description}');
              print('   Error code: ${error.errorCode}');
              print('   URL: ${error.url}');
            },
            onNavigationRequest: (NavigationRequest request) {
              // Allow all navigation
              return NavigationDecision.navigate;
            },
          ),
        )
        ..loadRequest(Uri.parse(initialUrl));
    }

  void _startUrlCheckTimer() {
    // Kiểm tra URL mỗi phút
    _urlCheckTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      final viewModel = context.read<HomeViewModel>();
      final newUrl = viewModel.getUrlForCurrentTime();
      
      if (newUrl != viewModel.currentUrl) {
        _webViewController.loadRequest(Uri.parse(newUrl));
        viewModel.updateUrl();
      }
    });
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