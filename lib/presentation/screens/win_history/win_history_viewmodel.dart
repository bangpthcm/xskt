// lib/presentation/screens/win_history/win_history_viewmodel.dart

import 'package:flutter/material.dart';
import '../../../data/models/cycle_win_history.dart';
import '../../../data/models/xien_win_history.dart';
import '../../../data/services/win_tracking_service.dart';

class WinHistoryViewModel extends ChangeNotifier {
  final WinTrackingService _trackingService;

  // Đã xóa AutoCheckService khỏi constructor
  WinHistoryViewModel({
    required WinTrackingService trackingService,
  }) : _trackingService = trackingService;

  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _errorMessage;
  List<CycleWinHistory> _cycleHistory = [];
  List<XienWinHistory> _xienHistory = [];
  List<CycleWinHistory> _trungHistory = [];
  List<CycleWinHistory> _bacHistory = [];
  
  // Đã xóa biến _lastCheckResult

  static const int _pageSize = 50;
  bool _hasMoreCycle = true;
  bool _hasMoreXien = true;
  bool _hasMoreTrung = true;
  bool _hasMoreBac = true;

  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  String? get errorMessage => _errorMessage;
  List<CycleWinHistory> get cycleHistory => _cycleHistory;
  List<XienWinHistory> get xienHistory => _xienHistory;
  List<CycleWinHistory> get trungHistory => _trungHistory;
  List<CycleWinHistory> get bacHistory => _bacHistory;
  
  bool get hasMoreCycle => _hasMoreCycle;
  bool get hasMoreXien => _hasMoreXien;
  bool get hasMoreTrung => _hasMoreTrung;
  bool get hasMoreBac => _hasMoreBac;

  /// ✅ LAZY: Load initial data (chỉ page đầu)
  Future<void> loadHistory() async {
    print('📚 Loading win history (initial page)...');
    
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _loadCyclePage(0),
        _loadXienPage(0),
        _loadTrungPage(0),
        _loadBacPage(0),
      ]);

      _cycleHistory = results[0] as List<CycleWinHistory>;
      _xienHistory = results[1] as List<XienWinHistory>;
      _trungHistory = results[2] as List<CycleWinHistory>;
      _bacHistory = results[3] as List<CycleWinHistory>;

      _hasMoreCycle = _cycleHistory.length >= _pageSize;
      _hasMoreXien = _xienHistory.length >= _pageSize;
      _hasMoreTrung = _trungHistory.length >= _pageSize;
      _hasMoreBac = _bacHistory.length >= _pageSize;

      print('✅ Loaded initial: Cycle=${_cycleHistory.length}, Xien=${_xienHistory.length}, '
            'Trung=${_trungHistory.length}, Bac=${_bacHistory.length}');

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      print('❌ Error loading history: $e');
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
      final values = await _trackingService.sheetsService.getAllValues('cycleWinHistory');
      
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
      final values = await _trackingService.sheetsService.getAllValues('xienWinHistory');
      
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

  /// Helper: Load một page của trung history
  Future<List<CycleWinHistory>> _loadTrungPage(int page) async {
    try {
      final values = await _trackingService.sheetsService.getAllValues('trungWinHistory');
      
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
      final values = await _trackingService.sheetsService.getAllValues('bacWinHistory');
      
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

  // ĐÃ XÓA checkSpecificDate()
  // ĐÃ XÓA checkYesterday()

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Tính tổng thống kê chu kỳ
  WinStats getCycleStats() {
    final wins = _cycleHistory.where((h) => h.isWin).toList();
    final totalProfit = wins.fold<double>(0, (sum, h) => sum + h.loiLo);
    final totalBet = wins.fold<double>(0, (sum, h) => sum + h.tongTienCuoc);
    final avgROI = wins.isNotEmpty
        ? wins.fold<double>(0, (sum, h) => sum + h.roi) / wins.length
        : 0.0;
    
    final months = _calculateMonths(_cycleHistory.cast<dynamic>());
    final profitPerMonth = months > 0 ? totalProfit / months : 0.0;

    return WinStats(
      totalWins: wins.length,
      totalProfit: totalProfit,
      totalBet: totalBet,
      avgROI: avgROI,
      overallROI: totalBet > 0 ? (totalProfit / totalBet) * 100 : 0,
      profitPerMonth: profitPerMonth,
    );
  }

  /// Tính tổng thống kê xiên
  WinStats getXienStats() {
    final wins = _xienHistory.where((h) => h.isWin).toList();
    final totalProfit = wins.fold<double>(0, (sum, h) => sum + h.loiLo);
    final totalBet = wins.fold<double>(0, (sum, h) => sum + h.tongTienCuoc);
    final avgROI = wins.isNotEmpty
        ? wins.fold<double>(0, (sum, h) => sum + h.roi) / wins.length
        : 0.0;

    final months = _calculateMonths(_xienHistory.cast<dynamic>());
    final profitPerMonth = months > 0 ? totalProfit / months : 0.0;

    return WinStats(
      totalWins: wins.length,
      totalProfit: totalProfit,
      totalBet: totalBet,
      avgROI: avgROI,
      overallROI: totalBet > 0 ? (totalProfit / totalBet) * 100 : 0,
      profitPerMonth: profitPerMonth,
    );
  }

  /// Tính thống kê Trung
  WinStats getTrungStats() {
    final wins = _trungHistory.where((h) => h.isWin).toList();
    final totalProfit = wins.fold<double>(0, (sum, h) => sum + h.loiLo);
    final totalBet = wins.fold<double>(0, (sum, h) => sum + h.tongTienCuoc);
    final avgROI = wins.isNotEmpty
        ? wins.fold<double>(0, (sum, h) => sum + h.roi) / wins.length
        : 0.0;

    final months = _calculateMonths(_trungHistory.cast<dynamic>());
    final profitPerMonth = months > 0 ? totalProfit / months : 0.0;

    return WinStats(
      totalWins: wins.length,
      totalProfit: totalProfit,
      totalBet: totalBet,
      avgROI: avgROI,
      overallROI: totalBet > 0 ? (totalProfit / totalBet) * 100 : 0,
      profitPerMonth: profitPerMonth,
    );
  }

  /// Tính thống kê Bắc
  WinStats getBacStats() {
    final wins = _bacHistory.where((h) => h.isWin).toList();
    final totalProfit = wins.fold<double>(0, (sum, h) => sum + h.loiLo);
    final totalBet = wins.fold<double>(0, (sum, h) => sum + h.tongTienCuoc);
    final avgROI = wins.isNotEmpty
        ? wins.fold<double>(0, (sum, h) => sum + h.roi) / wins.length
        : 0.0;

    final months = _calculateMonths(_bacHistory.cast<dynamic>());
    final profitPerMonth = months > 0 ? totalProfit / months : 0.0;

    return WinStats(
      totalWins: wins.length,
      totalProfit: totalProfit,
      totalBet: totalBet,
      avgROI: avgROI,
      overallROI: totalBet > 0 ? (totalProfit / totalBet) * 100 : 0,
      profitPerMonth: profitPerMonth,
    );
  }

  /// ✅ TỔNG HỢP THỰC SỰ: Cycle + Trung + Bắc + Xiên
  WinStats getCombinedStats() {
    final allHistories = <dynamic>[
      ..._cycleHistory,
      ..._trungHistory,
      ..._bacHistory,
      ..._xienHistory,
    ];

    if (allHistories.isEmpty) {
      return WinStats(
        totalWins: 0,
        totalProfit: 0,
        totalBet: 0,
        avgROI: 0,
        overallROI: 0,
        profitPerMonth: 0,
      );
    }

    final wins = allHistories.where((h) {
      if (h is CycleWinHistory) return h.isWin;
      if (h is XienWinHistory) return h.isWin;
      return false;
    }).toList();
    
    final totalProfit = wins.fold<double>(0, (sum, h) {
      if (h is CycleWinHistory) return sum + h.loiLo;
      if (h is XienWinHistory) return sum + h.loiLo;
      return sum;
    });
    
    final totalBet = wins.fold<double>(0, (sum, h) {
      if (h is CycleWinHistory) return sum + h.tongTienCuoc;
      if (h is XienWinHistory) return sum + h.tongTienCuoc;
      return sum;
    });
    
    final avgROI = wins.isNotEmpty
        ? wins.fold<double>(0, (sum, h) {
            if (h is CycleWinHistory) return sum + h.roi;
            if (h is XienWinHistory) return sum + h.roi;
            return sum;
          }) / wins.length
        : 0.0;

    final months = _calculateMonths(allHistories);
    final profitPerMonth = months > 0 ? totalProfit / months : 0.0;

    return WinStats(
      totalWins: wins.length,
      totalProfit: totalProfit,
      totalBet: totalBet,
      avgROI: avgROI,
      overallROI: totalBet > 0 ? (totalProfit / totalBet) * 100 : 0,
      profitPerMonth: profitPerMonth,
    );
  }

  /// ✅ "Tất cả" trong Chu kỳ
  WinStats getAllCycleStats() {
    final wins = _cycleHistory.where((h) => h.isWin).toList();
    final totalProfit = wins.fold<double>(0, (sum, h) => sum + h.loiLo);
    final totalBet = wins.fold<double>(0, (sum, h) => sum + h.tongTienCuoc);
    final avgROI = wins.isNotEmpty
        ? wins.fold<double>(0, (sum, h) => sum + h.roi) / wins.length
        : 0.0;

    final months = _calculateMonths(_cycleHistory.cast<dynamic>());
    final profitPerMonth = months > 0 ? totalProfit / months : 0.0;

    return WinStats(
      totalWins: wins.length,
      totalProfit: totalProfit,
      totalBet: totalBet,
      avgROI: avgROI,
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
          (lastDate.month - firstDate.month) + 1;

      return months > 0 ? months : 1;
    } catch (e) {
      print('⚠️ Error calculating months: $e');
      return 1;
    }
  }

  /// Lấy profit theo tháng
  List<MonthlyProfit> getProfitByMonth() {
    final allHistories = <dynamic>[
      ..._cycleHistory,
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
}

class WinStats {
  final int totalWins;
  final double totalProfit;
  final double totalBet;
  final double avgROI;
  final double overallROI;
  final double profitPerMonth;

  WinStats({
    required this.totalWins,
    required this.totalProfit,
    required this.totalBet,
    required this.avgROI,
    required this.overallROI,
    required this.profitPerMonth,
  });

  @override
  String toString() {
    return 'WinStats(wins: $totalWins, profit: $totalProfit, avgROI: $avgROI%, profitPerMonth: $profitPerMonth)';
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