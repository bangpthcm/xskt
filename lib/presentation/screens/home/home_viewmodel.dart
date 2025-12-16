import 'package:flutter/material.dart';

class HomeViewModel extends ChangeNotifier {
  String _currentUrl = '';
  String get currentUrl => _currentUrl;

  String getUrlForCurrentTime() {
    final now = DateTime.now();
    final minutes = now.hour * 60 + now.minute;

    if (minutes < 1030) {
      // < 17:10
      _currentUrl = 'https://xoso.com.vn/xo-so-mien-nam/xsmn-p1.html';
    } else if (minutes < 1090) {
      // 17:10 - 18:10
      _currentUrl = 'https://xoso.com.vn/xo-so-mien-trung/xsmt-p1.html';
    } else {
      // > 18:10
      _currentUrl = 'https://xoso.com.vn/xo-so-mien-bac/xsmb-p1.html';
    }
    return _currentUrl;
  }

  void updateUrl() {
    getUrlForCurrentTime();
    notifyListeners();
  }
}
