import 'package:flutter/material.dart';

class HomeViewModel extends ChangeNotifier {
  String _currentUrl = '';

  String get currentUrl => _currentUrl;

  String getUrlForCurrentTime() {
    final now = DateTime.now();
    final hour = now.hour;
    final minute = now.minute;
    final timeInMinutes = hour * 60 + minute;

    // ✅ Thử dùng domain khác nếu xsmn.mobi bị chặn
    // Trước 17:10 (1030 phút)
    if (timeInMinutes < 1030) {
      _currentUrl = 'https://xoso.com.vn/xo-so-mien-nam/xsmn-p1.html';  // ✅ Thay đổi
    }
    // 17:10 đến 18:10 (1030-1090 phút)
    else if (timeInMinutes >= 1030 && timeInMinutes < 1090) {
      _currentUrl = 'https://xoso.com.vn/xo-so-mien-trung/xsmt-p1.html';  // ✅ Thay đổi
    }
    // Sau 18:10
    else {
      _currentUrl = 'https://xoso.com.vn/xo-so-mien-bac/xsmb-p1.html';  // ✅ Thay đổi
    }

    return _currentUrl;
  }

  void updateUrl() {
    getUrlForCurrentTime();
    notifyListeners();
  }
}