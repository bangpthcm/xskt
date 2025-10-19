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

  /// Tính tổng thống kê chu kỳ
  WinStats getCycleStats() {
    final wins = _cycleHistory.where((h) => h.isWin).toList();
    final totalProfit = wins.fold<double>(0, (sum, h) => sum + h.loiLo);
    final totalBet = wins.fold<double>(0, (sum, h) => sum + h.tongTienCuoc);
    final avgROI = wins.isNotEmpty
        ? wins.fold<double>(0, (sum, h) => sum + h.roi) / wins.length
        : 0.0;

    return WinStats(
      totalWins: wins.length,
      totalProfit: totalProfit,
      totalBet: totalBet,
      avgROI: avgROI,
      overallROI: totalBet > 0 ? (totalProfit / totalBet) * 100 : 0,
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

    return WinStats(
      totalWins: wins.length,
      totalProfit: totalProfit,
      totalBet: totalBet,
      avgROI: avgROI,
      overallROI: totalBet > 0 ? (totalProfit / totalBet) * 100 : 0,
    );
  }

  // ✅ ADD: Tính thống kê Trung
  WinStats getTrungStats() {
    final wins = _trungHistory.where((h) => h.isWin).toList();
    final totalProfit = wins.fold<double>(0, (sum, h) => sum + h.loiLo);
    final totalBet = wins.fold<double>(0, (sum, h) => sum + h.tongTienCuoc);
    final avgROI = wins.isNotEmpty
        ? wins.fold<double>(0, (sum, h) => sum + h.roi) / wins.length
        : 0.0;

    return WinStats(
      totalWins: wins.length,
      totalProfit: totalProfit,
      totalBet: totalBet,
      avgROI: avgROI,
      overallROI: totalBet > 0 ? (totalProfit / totalBet) * 100 : 0,
    );
  }

  // ✅ ADD: Tính thống kê Bắc
  WinStats getBacStats() {
    final wins = _bacHistory.where((h) => h.isWin).toList();
    final totalProfit = wins.fold<double>(0, (sum, h) => sum + h.loiLo);
    final totalBet = wins.fold<double>(0, (sum, h) => sum + h.tongTienCuoc);
    final avgROI = wins.isNotEmpty
        ? wins.fold<double>(0, (sum, h) => sum + h.roi) / wins.length
        : 0.0;

    return WinStats(
      totalWins: wins.length,
      totalProfit: totalProfit,
      totalBet: totalBet,
      avgROI: avgROI,
      overallROI: totalBet > 0 ? (totalProfit / totalBet) * 100 : 0,
    );
  }
}

class WinStats {
  final int totalWins;
  final double totalProfit;
  final double totalBet;
  final double avgROI;
  final double overallROI;

  WinStats({
    required this.totalWins,
    required this.totalProfit,
    required this.totalBet,
    required this.avgROI,
    required this.overallROI,
  });

  @override
  String toString() {
    return 'WinStats(wins: $totalWins, profit: $totalProfit, avgROI: $avgROI%)';
  }
}