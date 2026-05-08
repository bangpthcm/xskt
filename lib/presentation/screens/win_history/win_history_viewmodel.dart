// lib/presentation/screens/win_history/win_history_viewmodel.dart

import 'dart:math'; // Import để dùng hàm max

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../data/models/cycle_win_history.dart';
import '../../../data/models/xien_win_history.dart';
import '../../../data/services/win_tracking_service.dart';

class WinHistoryViewModel extends ChangeNotifier {
  final WinTrackingService _trackingService;

  WinHistoryViewModel({
    required WinTrackingService trackingService,
  }) : _trackingService = trackingService;

  bool _isUpdating = false;
  bool get isUpdating => _isUpdating;

  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _errorMessage;
  List<CycleWinHistory> _cycleHistory = [];
  List<XienWinHistory> _xienHistory = [];
  List<CycleWinHistory> _namHistory = [];
  List<CycleWinHistory> _trungHistory = [];
  List<CycleWinHistory> _bacHistory = [];

  static const int _pageSize = 50;
  bool _hasMoreCycle = true;
  bool _hasMoreXien = true;
  bool _hasMoreNam = true;
  bool _hasMoreTrung = true;
  bool _hasMoreBac = true;

  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  String? get errorMessage => _errorMessage;
  List<CycleWinHistory> get cycleHistory => _cycleHistory;
  List<XienWinHistory> get xienHistory => _xienHistory;
  List<CycleWinHistory> get namHistory => _namHistory;
  List<CycleWinHistory> get trungHistory => _trungHistory;
  List<CycleWinHistory> get bacHistory => _bacHistory;

  bool get hasMoreCycle => _hasMoreCycle;
  bool get hasMoreXien => _hasMoreXien;
  bool get hasMoreNam => _hasMoreNam;
  bool get hasMoreTrung => _hasMoreTrung;
  bool get hasMoreBac => _hasMoreBac;

  /// ✅ LAZY: Load initial data (chỉ page đầu)
  Future<void> loadHistory() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _loadCyclePage(0),
        _loadXienPage(0),
        _loadTrungPage(0),
        _loadBacPage(0),
        _loadNamPage(0),
      ]);

      _cycleHistory = results[0] as List<CycleWinHistory>;
      _xienHistory = results[1] as List<XienWinHistory>;
      _trungHistory = results[2] as List<CycleWinHistory>;
      _bacHistory = results[3] as List<CycleWinHistory>;
      _namHistory = results[4] as List<CycleWinHistory>;

      _hasMoreCycle = _cycleHistory.length >= _pageSize;
      _hasMoreXien = _xienHistory.length >= _pageSize;
      _hasMoreTrung = _trungHistory.length >= _pageSize;
      _hasMoreBac = _bacHistory.length >= _pageSize;
      _hasMoreNam = _namHistory.length >= _pageSize;

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Lỗi tải lịch sử: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// ✅ Load more cycle history
  Future<void> loadMoreCycle() async {
    if (!_hasMoreCycle || _isLoadingMore) return;

    print('🔄 Loading more cycle history...');
    _isLoadingMore = true;
    notifyListeners();

    try {
      final currentPage = (_cycleHistory.length / _pageSize).floor();
      final newData = await _loadCyclePage(currentPage);

      _cycleHistory.addAll(newData);
      _hasMoreCycle = newData.length >= _pageSize;

      print('✅ Loaded ${newData.length} more cycle records');
    } catch (e) {
      print('❌ Error loading more cycle: $e');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// ✅ Load more xien history
  Future<void> loadMoreXien() async {
    if (!_hasMoreXien || _isLoadingMore) return;

    print('🔄 Loading more xien history...');
    _isLoadingMore = true;
    notifyListeners();

    try {
      final currentPage = (_xienHistory.length / _pageSize).floor();
      final newData = await _loadXienPage(currentPage);

      _xienHistory.addAll(newData);
      _hasMoreXien = newData.length >= _pageSize;

      print('✅ Loaded ${newData.length} more xien records');
    } catch (e) {
      print('❌ Error loading more xien: $e');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreNam() async {
    if (!_hasMoreNam || _isLoadingMore) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final currentPage = (_namHistory.length / _pageSize).floor();
      final newData = await _loadNamPage(currentPage);

      _namHistory.addAll(newData);
      _hasMoreNam = newData.length >= _pageSize;
    } catch (e) {
      print('❌ Error loading more nam: $e');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// ✅ Load more trung history
  Future<void> loadMoreTrung() async {
    if (!_hasMoreTrung || _isLoadingMore) return;

    print('🔄 Loading more trung history...');
    _isLoadingMore = true;
    notifyListeners();

    try {
      final currentPage = (_trungHistory.length / _pageSize).floor();
      final newData = await _loadTrungPage(currentPage);

      _trungHistory.addAll(newData);
      _hasMoreTrung = newData.length >= _pageSize;

      print('✅ Loaded ${newData.length} more trung records');
    } catch (e) {
      print('❌ Error loading more trung: $e');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// ✅ Load more bac history
  Future<void> loadMoreBac() async {
    if (!_hasMoreBac || _isLoadingMore) return;

    print('🔄 Loading more bac history...');
    _isLoadingMore = true;
    notifyListeners();

    try {
      final currentPage = (_bacHistory.length / _pageSize).floor();
      final newData = await _loadBacPage(currentPage);

      _bacHistory.addAll(newData);
      _hasMoreBac = newData.length >= _pageSize;

      print('✅ Loaded ${newData.length} more bac records');
    } catch (e) {
      print('❌ Error loading more bac: $e');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Helper: Load một page của cycle history
  Future<List<CycleWinHistory>> _loadCyclePage(int page) async {
    try {
      final values =
          await _trackingService.sheetsService.getAllValues('cycleWinHistory');

      if (values.length < 2) return [];

      final startIndex = 1 + (page * _pageSize);
      final endIndex = (startIndex + _pageSize).clamp(0, values.length);

      if (startIndex >= values.length) return [];

      final histories = <CycleWinHistory>[];
      for (int i = startIndex; i < endIndex; i++) {
        try {
          histories.add(CycleWinHistory.fromSheetRow(values[i]));
        } catch (e) {
          print('⚠️ Error parsing cycle row $i: $e');
        }
      }

      histories.sort((a, b) => b.stt.compareTo(a.stt));
      return histories;
    } catch (e) {
      print('❌ Error loading cycle page: $e');
      return [];
    }
  }

  /// Helper: Load một page của xien history
  Future<List<XienWinHistory>> _loadXienPage(int page) async {
    try {
      final values =
          await _trackingService.sheetsService.getAllValues('xienWinHistory');

      if (values.length < 2) return [];

      final startIndex = 1 + (page * _pageSize);
      final endIndex = (startIndex + _pageSize).clamp(0, values.length);

      if (startIndex >= values.length) return [];

      final histories = <XienWinHistory>[];
      for (int i = startIndex; i < endIndex; i++) {
        try {
          histories.add(XienWinHistory.fromSheetRow(values[i]));
        } catch (e) {
          print('⚠️ Error parsing xien row $i: $e');
        }
      }

      histories.sort((a, b) => b.stt.compareTo(a.stt));
      return histories;
    } catch (e) {
      print('❌ Error loading xien page: $e');
      return [];
    }
  }

  Future<List<CycleWinHistory>> _loadNamPage(int page) async {
    try {
      final values = await _trackingService.sheetsService
          .getAllValues('namWinHistory'); // Gọi sheet namWinHistory

      if (values.length < 2) return [];

      final startIndex = 1 + (page * _pageSize);
      final endIndex = (startIndex + _pageSize).clamp(0, values.length);

      if (startIndex >= values.length) return [];

      final histories = <CycleWinHistory>[];
      for (int i = startIndex; i < endIndex; i++) {
        try {
          histories.add(CycleWinHistory.fromSheetRow(values[i]));
        } catch (e) {
          print('⚠️ Error parsing nam row $i: $e');
        }
      }
      histories.sort((a, b) => b.stt.compareTo(a.stt));
      return histories;
    } catch (e) {
      print('❌ Error loading nam page: $e');
      return [];
    }
  }

  /// Helper: Load một page của trung history
  Future<List<CycleWinHistory>> _loadTrungPage(int page) async {
    try {
      final values =
          await _trackingService.sheetsService.getAllValues('trungWinHistory');

      if (values.length < 2) return [];

      final startIndex = 1 + (page * _pageSize);
      final endIndex = (startIndex + _pageSize).clamp(0, values.length);

      if (startIndex >= values.length) return [];

      final histories = <CycleWinHistory>[];
      for (int i = startIndex; i < endIndex; i++) {
        try {
          histories.add(CycleWinHistory.fromSheetRow(values[i]));
        } catch (e) {
          print('⚠️ Error parsing trung row $i: $e');
        }
      }

      histories.sort((a, b) => b.stt.compareTo(a.stt));
      return histories;
    } catch (e) {
      print('❌ Error loading trung page: $e');
      return [];
    }
  }

  /// Helper: Load một page của bac history
  Future<List<CycleWinHistory>> _loadBacPage(int page) async {
    try {
      final values =
          await _trackingService.sheetsService.getAllValues('bacWinHistory');

      if (values.length < 2) return [];

      final startIndex = 1 + (page * _pageSize);
      final endIndex = (startIndex + _pageSize).clamp(0, values.length);

      if (startIndex >= values.length) return [];

      final histories = <CycleWinHistory>[];
      for (int i = startIndex; i < endIndex; i++) {
        try {
          histories.add(CycleWinHistory.fromSheetRow(values[i]));
        } catch (e) {
          print('⚠️ Error parsing bac row $i: $e');
        }
      }

      histories.sort((a, b) => b.stt.compareTo(a.stt));
      return histories;
    } catch (e) {
      print('❌ Error loading bac page: $e');
      return [];
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ===================== LOGIC THỐNG KÊ (ĐÃ CẬP NHẬT MAX BET) =====================

  /// Tính tổng thống kê chu kỳ
  WinStats getCycleStats() {
    return _calculateStats(_cycleHistory.cast<dynamic>());
  }

  /// Tính tổng thống kê xiên
  WinStats getXienStats() {
    return _calculateStats(_xienHistory.cast<dynamic>());
  }

  WinStats getNamStats() {
    return _calculateStats(_namHistory.cast<dynamic>());
  }

  /// Tính thống kê Trung
  WinStats getTrungStats() {
    return _calculateStats(_trungHistory.cast<dynamic>());
  }

  /// Tính thống kê Bắc
  WinStats getBacStats() {
    return _calculateStats(_bacHistory.cast<dynamic>());
  }

  /// ✅ "Tất cả" trong Chu kỳ (chính là getCycleStats, nhưng tách biệt tên gọi cho rõ)
  WinStats getAllCycleStats() {
    return _calculateStats(_cycleHistory.cast<dynamic>());
  }

  /// ✅ TỔNG HỢP THỰC SỰ: Cycle + Trung + Bắc + Xiên
  WinStats getCombinedStats() {
    final allHistories = <dynamic>[
      ..._cycleHistory,
      ..._namHistory, // Bổ sung Nam vào tổng hợp
      ..._trungHistory,
      ..._bacHistory,
      ..._xienHistory,
    ];
    return _calculateStats(allHistories);
  }

  /// Hàm chung để tính toán WinStats
  /// Thay avgROI bằng maxBet (Tổng tiền bỏ ra lớn nhất trong các lần thắng)
  WinStats _calculateStats(List<dynamic> histories) {
    if (histories.isEmpty) {
      return WinStats(
        totalWins: 0,
        totalProfit: 0,
        totalBet: 0,
        maxBet: 0,
        overallROI: 0,
        profitPerMonth: 0,
      );
    }

    // Lọc ra danh sách các lần thắng
    final wins = histories.where((h) {
      if (h is CycleWinHistory) return h.isWin;
      if (h is XienWinHistory) return h.isWin;
      return false;
    }).toList();

    // Tính tổng lợi nhuận
    final totalProfit = wins.fold<double>(0, (sum, h) {
      if (h is CycleWinHistory) return sum + h.loiLo;
      if (h is XienWinHistory) return sum + h.loiLo;
      return sum;
    });

    // Tính tổng tiền cược (của các ván thắng)
    final totalBet = wins.fold<double>(0, (sum, h) {
      if (h is CycleWinHistory) return sum + h.tongTienCuoc;
      if (h is XienWinHistory) return sum + h.tongTienCuoc;
      return sum;
    });

    // ✅ Logic mới: Tìm tổng tiền bỏ ra lớn nhất (Max Bet)
    // Lấy danh sách tiền cược của các ván thắng
    final betAmounts = wins.map((h) {
      if (h is CycleWinHistory) return h.tongTienCuoc;
      if (h is XienWinHistory) return h.tongTienCuoc;
      return 0.0;
    });

    // Tìm giá trị lớn nhất (nếu danh sách không rỗng)
    final maxBet = betAmounts.isEmpty ? 0.0 : betAmounts.reduce(max);

    // Tính số tháng hoạt động để tính Lợi/tháng
    final months = _calculateMonths(histories);
    final profitPerMonth = months > 0 ? totalProfit / months : 0.0;

    return WinStats(
      totalWins: wins.length,
      totalProfit: totalProfit,
      totalBet: totalBet,
      maxBet: maxBet, // Field mới
      overallROI: totalBet > 0 ? (totalProfit / totalBet) * 100 : 0,
      profitPerMonth: profitPerMonth,
    );
  }

  /// ✅ Tính số tháng hoạt động
  int _calculateMonths(List<dynamic> histories) {
    if (histories.isEmpty) return 1;

    try {
      final dates = <DateTime>[];

      for (var h in histories) {
        String dateStr;
        if (h is CycleWinHistory) {
          dateStr = h.ngayTrung;
        } else if (h is XienWinHistory) {
          dateStr = h.ngayTrung;
        } else {
          continue;
        }

        final parts = dateStr.split('/');
        if (parts.length == 3) {
          dates.add(DateTime(
            int.parse(parts[2]),
            int.parse(parts[1]),
            int.parse(parts[0]),
          ));
        }
      }

      if (dates.isEmpty) return 1;

      dates.sort();
      final firstDate = dates.first;
      final lastDate = dates.last;

      final months = (lastDate.year - firstDate.year) * 12 +
          (lastDate.month - firstDate.month) +
          1;

      return months > 0 ? months : 1;
    } catch (e) {
      print('⚠️ Error calculating months: $e');
      return 1;
    }
  }

  /// Lấy profit theo tháng cho biểu đồ
  List<MonthlyProfit> getProfitByMonth() {
    final allHistories = <dynamic>[
      ..._cycleHistory,
      ..._namHistory, // Bổ sung Nam để vẽ chart
      ..._trungHistory,
      ..._bacHistory,
      ..._xienHistory,
    ];

    if (allHistories.isEmpty) return [];

    final monthlyData = <String, Map<String, dynamic>>{};

    for (var history in allHistories) {
      String dateStr;
      double profit;

      if (history is CycleWinHistory) {
        if (!history.isWin) continue;
        dateStr = history.ngayTrung;
        profit = history.loiLo;
      } else if (history is XienWinHistory) {
        if (!history.isWin) continue;
        dateStr = history.ngayTrung;
        profit = history.loiLo;
      } else {
        continue;
      }

      try {
        final parts = dateStr.split('/');
        if (parts.length != 3) continue;

        final month = int.parse(parts[1]);
        final year = int.parse(parts[2]);
        final key = '$month/$year';

        if (!monthlyData.containsKey(key)) {
          monthlyData[key] = {
            'month': month,
            'year': year,
            'profit': 0.0,
            'wins': 0,
          };
        }

        monthlyData[key]!['profit'] = monthlyData[key]!['profit'] + profit;
        monthlyData[key]!['wins'] = monthlyData[key]!['wins'] + 1;
      } catch (e) {
        continue;
      }
    }

    final result = monthlyData.entries.map((entry) {
      return MonthlyProfit(
        month: entry.value['month'],
        year: entry.value['year'],
        profit: entry.value['profit'],
        wins: entry.value['wins'],
      );
    }).toList();

    result.sort((a, b) {
      final dateA = DateTime(a.year, a.month);
      final dateB = DateTime(b.year, b.month);
      return dateA.compareTo(dateB);
    });

    return result;
  }

  Future<void> updateDataFromServer() async {
    if (_isUpdating) return;
    _isUpdating = true;
    notifyListeners();

    try {
      const String webAppUrl =
          "https://script.google.com/macros/s/AKfycbyjJViGK_f6nR5jO152flYaZbPky-82_ErywHkFY3-3lZMDAerfCbXXtKZyygmV9wD9/exec?action=dailyLotteryCheck";

      // Gọi script với timeout 210 giây
      await http.get(Uri.parse(webAppUrl)).timeout(const Duration(seconds: 70));
    } catch (e) {
      if (e.toString().contains('Failed to fetch')) {
        await loadHistory();
      } else {
        rethrow; // Đẩy lỗi ra ngoài để UI hiện SnackBar đỏ
      }
    } finally {
      _isUpdating = false;
      notifyListeners();
    }
  }
}

// ✅ Class WinStats đã cập nhật
class WinStats {
  final int totalWins;
  final double totalProfit;
  final double totalBet;
  final double maxBet; // Thay thế avgROI bằng maxBet
  final double overallROI;
  final double profitPerMonth;

  WinStats({
    required this.totalWins,
    required this.totalProfit,
    required this.totalBet,
    required this.maxBet, // Field mới
    required this.overallROI,
    required this.profitPerMonth,
  });

  @override
  String toString() {
    return 'WinStats(wins: $totalWins, profit: $totalProfit, maxBet: $maxBet, profitPerMonth: $profitPerMonth)';
  }
}

class MonthlyProfit {
  final int month;
  final int year;
  final double profit;
  final int wins;

  MonthlyProfit({
    required this.month,
    required this.year,
    required this.profit,
    required this.wins,
  });

  String get monthLabel => '$month/$year';
}
