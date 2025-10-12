import 'package:flutter/material.dart';

class HomeViewModel extends ChangeNotifier {
  String _currentUrl = '';

  String get currentUrl => _currentUrl;

  String getUrlForCurrentTime() {
    final now = DateTime.now();
    final hour = now.hour;
    final minute = now.minute;
    final timeInMinutes = hour * 60 + minute;

    // Trước 17:10 (1030 phút)
    if (timeInMinutes < 1030) {
      _currentUrl = 'https://xsmn.mobi/';
    }
    // 17:10 đến 18:10 (1030-1090 phút)
    else if (timeInMinutes >= 1030 && timeInMinutes < 1090) {
      _currentUrl = 'https://xsmn.mobi/xsmt-xo-so-mien-trung.html';
    }
    // Sau 18:10
    else {
      _currentUrl = 'https://xsmn.mobi/xsmb-xo-so-mien-bac.html';
    }

    return _currentUrl;
  }

  void updateUrl() {
    getUrlForCurrentTime();
    notifyListeners();
  }
}