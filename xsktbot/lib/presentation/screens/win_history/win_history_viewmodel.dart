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
  CheckDailyResult? _lastCheckResult;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<CycleWinHistory> get cycleHistory => _cycleHistory;
  List<XienWinHistory> get xienHistory => _xienHistory;
  CheckDailyResult? get lastCheckResult => _lastCheckResult;

  /// Load lịch sử từ Google Sheets
  Future<void> loadHistory() async {
    print('📚 Loading win history...');
    
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Load cả 2 loại lịch sử song song
      final results = await Future.wait([
        _trackingService.getAllCycleWinHistory(),
        _trackingService.getAllXienWinHistory(),
      ]);

      _cycleHistory = results[0] as List<CycleWinHistory>;
      _xienHistory = results[1] as List<XienWinHistory>;

      // Sắp xếp theo STT giảm dần (mới nhất lên trước)
      _cycleHistory.sort((a, b) => b.stt.compareTo(a.stt));
      _xienHistory.sort((a, b) => b.stt.compareTo(a.stt));

      print('✅ Loaded ${_cycleHistory.length} cycle wins, ${_xienHistory.length} xien wins');

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      print('❌ Error loading history: $e');
      _errorMessage = 'Lỗi tải lịch sử: $e';
      _isLoading = false;
      notifyListeners();
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
        // Reload history để hiển thị kết quả mới
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

  /// Lấy lịch sử theo khoảng thời gian
  List<CycleWinHistory> getCycleHistoryByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) {
    return _cycleHistory.where((h) {
      final dateStr = h.ngayTrung;
      if (dateStr.isEmpty) return false;
      
      try {
        final parts = dateStr.split('/');
        if (parts.length != 3) return false;
        
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = int.parse(parts[2]);
        final date = DateTime(year, month, day);
        
        return date.isAfter(startDate.subtract(const Duration(days: 1))) &&
               date.isBefore(endDate.add(const Duration(days: 1)));
      } catch (e) {
        return false;
      }
    }).toList();
  }

  List<XienWinHistory> getXienHistoryByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) {
    return _xienHistory.where((h) {
      final dateStr = h.ngayTrung;
      if (dateStr.isEmpty) return false;
      
      try {
        final parts = dateStr.split('/');
        if (parts.length != 3) return false;
        
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = int.parse(parts[2]);
        final date = DateTime(year, month, day);
        
        return date.isAfter(startDate.subtract(const Duration(days: 1))) &&
               date.isBefore(endDate.add(const Duration(days: 1)));
      } catch (e) {
        return false;
      }
    }).toList();
  }

  /// Tìm kiếm theo số
  List<CycleWinHistory> searchCycleByNumber(String number) {
    return _cycleHistory.where((h) => h.soMucTieu == number).toList();
  }

  /// Tìm kiếm theo cặp số
  List<XienWinHistory> searchXienByPair(String pair) {
    return _xienHistory.where((h) => h.capSoMucTieu == pair).toList();
  }

  /// Lấy top N số thắng nhiều nhất
  List<MapEntry<String, int>> getTopWinningNumbers(int top) {
    final numberCounts = <String, int>{};
    
    for (final h in _cycleHistory.where((h) => h.isWin)) {
      numberCounts[h.soMucTieu] = (numberCounts[h.soMucTieu] ?? 0) + 1;
    }
    
    final sorted = numberCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sorted.take(top).toList();
  }

  /// Lấy top N cặp số thắng nhiều nhất
  List<MapEntry<String, int>> getTopWinningPairs(int top) {
    final pairCounts = <String, int>{};
    
    for (final h in _xienHistory.where((h) => h.isWin)) {
      pairCounts[h.capSoMucTieu] = (pairCounts[h.capSoMucTieu] ?? 0) + 1;
    }
    
    final sorted = pairCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sorted.take(top).toList();
  }

  /// Tính win rate theo miền
  Map<String, double> getCycleWinRateByMien() {
    final mienStats = <String, Map<String, int>>{
      'Nam': {'wins': 0, 'total': 0},
      'Trung': {'wins': 0, 'total': 0},
      'Bắc': {'wins': 0, 'total': 0},
    };
    
    for (final h in _cycleHistory) {
      if (h.mienTrung != null && mienStats.containsKey(h.mienTrung)) {
        mienStats[h.mienTrung]!['total'] = 
            (mienStats[h.mienTrung]!['total'] ?? 0) + 1;
        
        if (h.isWin) {
          mienStats[h.mienTrung]!['wins'] = 
              (mienStats[h.mienTrung]!['wins'] ?? 0) + 1;
        }
      }
    }
    
    final winRates = <String, double>{};
    for (final entry in mienStats.entries) {
      final total = entry.value['total'] ?? 0;
      final wins = entry.value['wins'] ?? 0;
      winRates[entry.key] = total > 0 ? (wins / total) * 100 : 0;
    }
    
    return winRates;
  }

  /// Export data to CSV format
  String exportToCsv({required bool isCycle}) {
    final buffer = StringBuffer();
    
    if (isCycle) {
      // Header
      buffer.writeln('STT,Ngày trúng,Số,Miền,Lần,Tỉnh,Tổng cược,Lời/Lỗ,ROI,Số ngày');
      
      // Data
      for (final h in _cycleHistory) {
        buffer.writeln(
          '${h.stt},${h.ngayTrung},${h.soMucTieu},${h.mienTrung ?? ""},'
          '${h.soLanTrung},"${h.cacTinhTrung}",${h.tongTienCuoc},'
          '${h.loiLo},${h.roi},${h.soNgayCuoc}'
        );
      }
    } else {
      // Header
      buffer.writeln('STT,Ngày trúng,Cặp,Lần,Chi tiết,Tổng cược,Lời/Lỗ,ROI,Số ngày');
      
      // Data
      for (final h in _xienHistory) {
        buffer.writeln(
          '${h.stt},${h.ngayTrung},${h.capSoMucTieu},${h.soLanTrungCap},'
          '"${h.chiTietTrung}",${h.tongTienCuoc},${h.loiLo},${h.roi},'
          '${h.soNgayCuoc}'
        );
      }
    }
    
    return buffer.toString();
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