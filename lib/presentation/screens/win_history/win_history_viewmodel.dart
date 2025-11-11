// lib/presentation/screens/win_history/win_history_viewmodel.dart

import 'package:flutter/material.dart';
import '../../../data/models/cycle_win_history.dart';
import '../../../data/models/xien_win_history.dart';
import '../../../data/services/win_tracking_service.dart';
import '../../../data/services/auto_check_service.dart';

class WinHistoryViewModel extends ChangeNotifier {
  final WinTrackingService _trackingService;
  final AutoCheckService _autoCheckService;

  WinHistoryViewModel({
    required WinTrackingService trackingService,
    required AutoCheckService autoCheckService,
  })  : _trackingService = trackingService,
        _autoCheckService = autoCheckService;

  bool _isLoading = false;
  String? _errorMessage;
  List<CycleWinHistory> _cycleHistory = [];
  List<XienWinHistory> _xienHistory = [];
  List<CycleWinHistory> _trungHistory = [];  // ✅ ADD
  List<CycleWinHistory> _bacHistory = [];    // ✅ ADD
  CheckDailyResult? _lastCheckResult;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<CycleWinHistory> get cycleHistory => _cycleHistory;
  List<XienWinHistory> get xienHistory => _xienHistory;
  List<CycleWinHistory> get trungHistory => _trungHistory;  // ✅ ADD
  List<CycleWinHistory> get bacHistory => _bacHistory;      // ✅ ADD
  CheckDailyResult? get lastCheckResult => _lastCheckResult;

  /// Load lịch sử từ Google Sheets
  Future<void> loadHistory() async {
    print('📚 Loading win history...');
    
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _trackingService.getAllCycleWinHistory(),
        _trackingService.getAllXienWinHistory(),
        _loadTrungHistory(),  // ✅ ADD
        _loadBacHistory(),    // ✅ ADD
      ]);

      _cycleHistory = results[0] as List<CycleWinHistory>;
      _xienHistory = results[1] as List<XienWinHistory>;
      _trungHistory = results[2] as List<CycleWinHistory>;  // ✅ ADD
      _bacHistory = results[3] as List<CycleWinHistory>;    // ✅ ADD

      _cycleHistory.sort((a, b) => b.stt.compareTo(a.stt));
      _xienHistory.sort((a, b) => b.stt.compareTo(a.stt));
      _trungHistory.sort((a, b) => b.stt.compareTo(a.stt));  // ✅ ADD
      _bacHistory.sort((a, b) => b.stt.compareTo(a.stt));    // ✅ ADD

      print('✅ Loaded ${_cycleHistory.length} cycle, ${_xienHistory.length} xien, '
            '${_trungHistory.length} trung, ${_bacHistory.length} bac wins');

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      print('❌ Error loading history: $e');
      _errorMessage = 'Lỗi tải lịch sử: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  // ✅ ADD: Load Trung history from trungWinHistory sheet
  Future<List<CycleWinHistory>> _loadTrungHistory() async {
    try {
      final values = await _trackingService.sheetsService.getAllValues('trungWinHistory');
      
      if (values.length < 2) {
        print('   ⚠️ No trung win history found');
        return [];
      }
      
      final histories = <CycleWinHistory>[];
      for (int i = 1; i < values.length; i++) {
        try {
          histories.add(CycleWinHistory.fromSheetRow(values[i]));
        } catch (e) {
          print('⚠️ Error parsing trung win history row $i: $e');
        }
      }
      
      print('   ✅ Loaded ${histories.length} trung win records');
      return histories;
    } catch (e) {
      print('❌ Error loading trung history: $e');
      return [];
    }
  }

  // ✅ ADD: Load Bac history from bacWinHistory sheet
  Future<List<CycleWinHistory>> _loadBacHistory() async {
    try {
      final values = await _trackingService.sheetsService.getAllValues('bacWinHistory');
      
      if (values.length < 2) {
        print('   ⚠️ No bac win history found');
        return [];
      }
      
      final histories = <CycleWinHistory>[];
      for (int i = 1; i < values.length; i++) {
        try {
          histories.add(CycleWinHistory.fromSheetRow(values[i]));
        } catch (e) {
          print('⚠️ Error parsing bac win history row $i: $e');
        }
      }
      
      print('   ✅ Loaded ${histories.length} bac win records');
      return histories;
    } catch (e) {
      print('❌ Error loading bac history: $e');
      return [];
    }
  }

  /// Kiểm tra kết quả cho ngày cụ thể
  Future<void> checkSpecificDate(String date) async {
    print('🔍 Checking results for $date...');
    
    _isLoading = true;
    _errorMessage = null;
    _lastCheckResult = null;
    notifyListeners();

    try {
      _lastCheckResult = await _autoCheckService.checkDailyResults(
        specificDate: date,
      );

      if (_lastCheckResult!.success) {
        await loadHistory();
      } else {
        _errorMessage = 'Kiểm tra không thành công';
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      print('❌ Error checking date: $e');
      _errorMessage = 'Lỗi kiểm tra: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Kiểm tra tự động (ngày hôm qua)
  Future<void> checkYesterday() async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final dateStr = '${yesterday.day.toString().padLeft(2, '0')}/'
        '${yesterday.month.toString().padLeft(2, '0')}/'
        '${yesterday.year}';
    
    await checkSpecificDate(dateStr);
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

// ✅ TRONG FILE win_history_viewmodel.dart
// THAY THẾ CÁC METHODS (từ dòng getCycleStats đến hết)

  /// Tính tổng thống kê chu kỳ (CHỈ cycleHistory - tab "Tất cả" trong detail)
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
    // ✅ Gộp TẤT CẢ 4 danh sách
    final allHistories = <dynamic>[
      ..._cycleHistory,   // Tab "Tất cả" trong detail
      ..._trungHistory,   // Tab "Trung"
      ..._bacHistory,     // Tab "Bắc"
      ..._xienHistory,    // Tab "Xiên"
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

    // ✅ Lọc các bản ghi trúng
    final wins = allHistories.where((h) {
      if (h is CycleWinHistory) return h.isWin;
      if (h is XienWinHistory) return h.isWin;
      return false;
    }).toList();
    
    // ✅ Tính tổng lợi nhuận
    final totalProfit = wins.fold<double>(0, (sum, h) {
      if (h is CycleWinHistory) return sum + h.loiLo;
      if (h is XienWinHistory) return sum + h.loiLo;
      return sum;
    });
    
    // ✅ Tính tổng tiền cược
    final totalBet = wins.fold<double>(0, (sum, h) {
      if (h is CycleWinHistory) return sum + h.tongTienCuoc;
      if (h is XienWinHistory) return sum + h.tongTienCuoc;
      return sum;
    });
    
    // ✅ Tính ROI trung bình
    final avgROI = wins.isNotEmpty
        ? wins.fold<double>(0, (sum, h) {
            if (h is CycleWinHistory) return sum + h.roi;
            if (h is XienWinHistory) return sum + h.roi;
            return sum;
          }) / wins.length
        : 0.0;

    // ✅ Tính số tháng và lợi/tháng
    final months = _calculateMonths(allHistories);
    final profitPerMonth = months > 0 ? totalProfit / months : 0.0;

    print('📊 getCombinedStats: Cycle=${_cycleHistory.length}, Trung=${_trungHistory.length}, Bắc=${_bacHistory.length}, Xiên=${_xienHistory.length}');
    print('   Total wins: ${wins.length}, Profit: $totalProfit, Months: $months');

    return WinStats(
      totalWins: wins.length,
      totalProfit: totalProfit,
      totalBet: totalBet,
      avgROI: avgROI,
      overallROI: totalBet > 0 ? (totalProfit / totalBet) * 100 : 0,
      profitPerMonth: profitPerMonth,
    );
  }

  /// ✅ "Tất cả" trong Chu kỳ: CHỈ cycleHistory (tab "Tất cả" - không phải Trung/Bắc)
  WinStats getAllCycleStats() {
    // ✅ CHỈ lấy cycleHistory - tab "Tất cả" riêng
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

  // ✅ THÊM vào class WinHistoryViewModel
  List<MonthlyProfit> getProfitByMonth() {
    final allHistories = <dynamic>[
      ..._cycleHistory,
      ..._trungHistory,
      ..._bacHistory,
      ..._xienHistory,
    ];

    if (allHistories.isEmpty) return [];

    // Group by month
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

    // Convert to list and sort
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

// ✅ Class WinStats (GIỮ NGUYÊN)
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

// ✅ THÊM: Method mới để lấy data theo tháng
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