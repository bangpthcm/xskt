// lib/presentation/screens/analysis/analysis_viewmodel.dart
import 'package:flutter/material.dart';
import '../../../data/models/gan_pair_info.dart';
import '../../../data/models/cycle_analysis_result.dart';
import '../../../data/models/lottery_result.dart';
import '../../../data/models/app_config.dart';
import '../../../data/models/number_detail.dart';
import '../../../data/models/betting_row.dart';
import '../../../data/services/google_sheets_service.dart';
import '../../../data/services/analysis_service.dart';
import '../../../data/services/storage_service.dart';
import '../../../data/services/telegram_service.dart';
import '../../../data/services/betting_table_service.dart';
import '../../../core/utils/date_utils.dart' as date_utils;
import '../../../data/services/budget_calculation_service.dart';
import '../../../core/utils/number_utils.dart';
import '../../../data/services/cached_data_service.dart';
import '../../../core/constants/app_constants.dart';

// --- ENUMS & CONSTANTS ---
class AnalysisThresholds {
  static const int tatca = 4;
  static const int nam = 0;
  static const int trung = 13;
  static const int bac = 19;
  static const int xien = 155;

  static String formatWithThreshold(int currentDays, String mien) {
    final threshold = {
      'Tất cả': tatca, 'Nam': nam, 'Trung': trung, 'Bắc': bac
    }[mien] ?? 0;
    return threshold == 0 ? '$currentDays ngày' : '$currentDays ngày/$threshold ngày';
  }
}

enum BettingTableTypeEnum { tatca, trung, bac }

extension BettingTableTypeExtension on BettingTableTypeEnum {
  String get sheetName => switch (this) {
    BettingTableTypeEnum.tatca => 'xsktBot1',
    BettingTableTypeEnum.trung => 'trungBot',
    BettingTableTypeEnum.bac => 'bacBot',
  };

  String get displayName => switch (this) {
    BettingTableTypeEnum.tatca => 'Tất cả',
    BettingTableTypeEnum.trung => 'Miền Trung',
    BettingTableTypeEnum.bac => 'Miền Bắc',
  };

  String get budgetTableName => switch (this) {
    BettingTableTypeEnum.tatca => 'tatca',
    BettingTableTypeEnum.trung => 'trung',
    BettingTableTypeEnum.bac => 'bac',
  };

  double? getBudgetConfig(AppConfig config) => switch (this) {
    BettingTableTypeEnum.tatca => null,
    BettingTableTypeEnum.trung => config.budget.trungBudget,
    BettingTableTypeEnum.bac => config.budget.bacBudget,
  };

  Future<List<BettingRow>> generateTable({
    required BettingTableService service,
    required CycleAnalysisResult result,
    required DateTime start,
    required DateTime end,
    required int startIdx,
    required double min,
    required double max,
    required List<LotteryResult> results,
    required int maxCount,
  }) async {
    return switch (this) {
      BettingTableTypeEnum.tatca => await service.generateCycleTable(
          cycleResult: result, startDate: start, endDate: end, startMienIndex: startIdx,
          budgetMin: min, budgetMax: max, allResults: results, maxMienCount: maxCount),
      BettingTableTypeEnum.trung => await service.generateTrungGanTable(
          cycleResult: result, startDate: start, endDate: end, budgetMin: min, budgetMax: max),
      BettingTableTypeEnum.bac => await service.generateBacGanTable(
          cycleResult: result, startDate: start, endDate: end, budgetMin: min, budgetMax: max),
    };
  }
}

// --- VIEWMODEL ---
class AnalysisViewModel extends ChangeNotifier {
  final CachedDataService _cachedDataService;
  final GoogleSheetsService _sheetsService;
  final AnalysisService _analysisService;
  final StorageService _storageService;
  final TelegramService _telegramService;
  final BettingTableService _bettingService;

  AnalysisViewModel({
    required CachedDataService cachedDataService,
    required GoogleSheetsService sheetsService,
    required AnalysisService analysisService,
    required StorageService storageService,
    required TelegramService telegramService,
    required BettingTableService bettingService,
  })  : _cachedDataService = cachedDataService,
        _sheetsService = sheetsService,
        _analysisService = analysisService,
        _storageService = storageService,
        _telegramService = telegramService,
        _bettingService = bettingService;

  // State
  bool _isLoading = false;
  String? _errorMessage;
  GanPairInfo? _ganPairInfo;
  CycleAnalysisResult? _cycleResult;
  String _selectedMien = 'Tất cả';
  List<LotteryResult> _allResults = [];
  
  // Cache Alerts
  String? _lastDataHash;
  bool? _tatCaAlertCache;
  bool? _trungAlertCache;
  bool? _bacAlertCache;

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  GanPairInfo? get ganPairInfo => _ganPairInfo;
  CycleAnalysisResult? get cycleResult => _cycleResult;
  String get selectedMien => _selectedMien;
  bool? get tatCaAlertCache => _tatCaAlertCache;
  bool? get trungAlertCache => _trungAlertCache;
  bool? get bacAlertCache => _bacAlertCache;

  bool get hasCycleAlert => _cycleResult != null && _selectedMien == 'Tất cả' && _cycleResult!.maxGanDays > AnalysisThresholds.tatca;
  bool get hasTrungAlert => _cycleResult != null && _selectedMien == 'Trung' && _cycleResult!.maxGanDays > AnalysisThresholds.trung;
  bool get hasBacAlert => _cycleResult != null && _selectedMien == 'Bắc' && _cycleResult!.maxGanDays > AnalysisThresholds.bac;
  bool get hasXienAlert => _ganPairInfo != null && _ganPairInfo!.daysGan > AnalysisThresholds.xien;
  bool get hasAnyAlert => hasXienAlert || (_tatCaAlertCache ?? false) || (_trungAlertCache ?? false) || (_bacAlertCache ?? false);

  // --- ACTIONS ---

  void setSelectedMien(String mien) {
    _selectedMien = mien;
    notifyListeners();
  }

  void setTargetNumber(String number) {
    if (_cycleResult != null) {
      _cycleResult = CycleAnalysisResult(
        ganNumbers: _cycleResult!.ganNumbers,
        maxGanDays: _cycleResult!.maxGanDays,
        lastSeenDate: _cycleResult!.lastSeenDate,
        mienGroups: _cycleResult!.mienGroups,
        targetNumber: number,
      );
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> loadAnalysis({bool useCache = true}) async {
    _isLoading = true; _errorMessage = null; notifyListeners();
    try {
      _allResults = await _cachedDataService.loadKQXS(forceRefresh: !useCache, incrementalOnly: useCache);
      _analyzeInBackground();
      _isLoading = false; notifyListeners();
    } catch (e) {
      _errorMessage = 'Lỗi phân tích: $e';
      _isLoading = false; notifyListeners();
    }
  }

  Future<void> _analyzeInBackground() async {
    _ganPairInfo = await _analysisService.findGanPairsMienBac(_allResults);
    
    if (_selectedMien == 'Tất cả') {
      _cycleResult = await _analysisService.analyzeCycle(_allResults);
    } else {
      _cycleResult = await _analysisService.analyzeCycle(_allResults.where((r) => r.mien == _selectedMien).toList());
    }
    notifyListeners();
    await _cacheAllAlerts();
    notifyListeners();
  }

  Future<void> _cacheAllAlerts() async {
    try {
      final currentHash = '${_allResults.length}_${_allResults.last.ngay}';
      if (_lastDataHash == currentHash && _tatCaAlertCache != null) return;

      final results = await Future.wait([
        _analysisService.analyzeCycle(_allResults),
        _analysisService.analyzeCycle(_allResults.where((r) => r.mien == 'Trung').toList()),
        _analysisService.analyzeCycle(_allResults.where((r) => r.mien == 'Bắc').toList()),
      ]);

      _tatCaAlertCache = results[0] != null && results[0]!.maxGanDays > AnalysisThresholds.tatca;
      _trungAlertCache = results[1] != null && results[1]!.maxGanDays > AnalysisThresholds.trung;
      _bacAlertCache = results[2] != null && results[2]!.maxGanDays > AnalysisThresholds.bac;
      _lastDataHash = currentHash;
    } catch (_) {
      _tatCaAlertCache = _trungAlertCache = _bacAlertCache = false;
    }
  }

  Future<NumberDetail?> analyzeNumberDetail(String number) async {
    return await _analysisService.analyzeNumberDetail(_allResults, number);
  }

  // --- TABLE CREATION LOGIC (REFACTORED) ---

  Future<void> createCycleBettingTable(String number, AppConfig config) => 
      _createBettingTableGeneric(BettingTableTypeEnum.tatca, number, config);

  Future<void> createTrungGanBettingTable(String number, AppConfig config) => 
      _createBettingTableGeneric(BettingTableTypeEnum.trung, number, config);

  Future<void> createBacGanBettingTable(String number, AppConfig config) => 
      _createBettingTableGeneric(BettingTableTypeEnum.bac, number, config);

  Future<void> _createBettingTableGeneric(
    BettingTableTypeEnum type, String number, AppConfig config
  ) async {
    _isLoading = true; _errorMessage = null; notifyListeners();
    try {
      final result = await _prepareCycleResult(type, number);
      final dates = _calculateDateParameters(type, result);

      final budgetService = BudgetCalculationService(sheetsService: _sheetsService);
      final budgetResult = await budgetService.calculateAvailableBudgetByEndDate(
        totalCapital: config.budget.totalCapital,
        targetTable: type.budgetTableName,
        configBudget: type.getBudgetConfig(config),
        endDate: dates.endDate,
      );

      final table = await _generateTableWithOptimization(
        type: type,
        result: result,
        dates: dates,
        budgetMax: budgetResult.budgetMax,
        budgetResult: budgetResult,
      );

      await _saveTableToSheet(type, table, result);

      _isLoading = false; notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false; notifyListeners();
    }
  }

  // --- HELPER METHODS FOR TABLE CREATION ---

  Future<CycleAnalysisResult> _prepareCycleResult(BettingTableTypeEnum type, String number) async {
    if (type == BettingTableTypeEnum.tatca) {
      if (_cycleResult == null) throw Exception('Chưa có dữ liệu chu kỳ');
      return _cycleResult!;
    }
    
    final detail = await _analysisService.analyzeNumberDetail(_allResults, number);
    final mien = type == BettingTableTypeEnum.trung ? 'Trung' : 'Bắc';
    final mienDetail = detail?.mienDetails[mien];
    
    if (mienDetail == null) throw Exception('Không tìm thấy thông tin số $number cho $mien');
    
    return CycleAnalysisResult(
      ganNumbers: {number},
      maxGanDays: mienDetail.daysGan,
      lastSeenDate: mienDetail.lastSeenDate,
      mienGroups: {mien: [number]},
      targetNumber: number,
    );
  }

  ({DateTime startDate, DateTime endDate, int startMienIndex, int targetCount}) 
  _calculateDateParameters(BettingTableTypeEnum type, CycleAnalysisResult result) {
    final lastInfo = _getLastResultInfo();
    final startDate = lastInfo.isLastBac ? lastInfo.date.add(const Duration(days: 1)) : lastInfo.date;
    final startIdx = lastInfo.isLastBac ? 0 : lastInfo.mienIndex + 1;

    if (type == BettingTableTypeEnum.tatca) {
      String targetMien = 'Nam';
      result.mienGroups.forEach((k, v) { if (v.contains(result.targetNumber)) targetMien = k; });

      final initialCount = _countMienOccurrences(result.lastSeenDate, startDate, targetMien);
      var targetCount = AppConstants.cycleGanDays;
      
      final rows = _simulateTableRows(startDate, startIdx, targetMien, targetCount, initialCount);
      if (_checkIfExtraTurnNeeded(rows)) targetCount++;

      return (
        startDate: startDate, 
        endDate: result.lastSeenDate.add(const Duration(days: AppConstants.cycleGanDays)), 
        startMienIndex: startIdx, 
        targetCount: targetCount
      );
    } else {
      final daysToAdd = type == BettingTableTypeEnum.trung ? AppConstants.trungGanDays : AppConstants.bacGanDays;
      return (
        startDate: startDate, 
        endDate: result.lastSeenDate.add(Duration(days: daysToAdd)), 
        startMienIndex: startIdx, 
        targetCount: 0
      );
    }
  }

  Future<List<BettingRow>> _generateTableWithOptimization({
    required BettingTableTypeEnum type,
    required CycleAnalysisResult result,
    required ({DateTime startDate, DateTime endDate, int startMienIndex, int targetCount}) dates,
    required double budgetMax,
    required AvailableBudgetResult budgetResult,
  }) async {
    try {
      return await type.generateTable(
        service: _bettingService, result: result, start: dates.startDate, end: dates.endDate,
        startIdx: dates.startMienIndex, min: budgetMax * 0.9, max: budgetMax,
        results: _allResults, maxCount: dates.targetCount,
      );
    } catch (_) {
      try {
        final hugeTable = await type.generateTable(
          service: _bettingService, result: result, start: dates.startDate, end: dates.endDate,
          startIdx: dates.startMienIndex, min: budgetMax, max: budgetMax * 100,
          results: _allResults, maxCount: dates.targetCount,
        );
        
        final minRequired = await _findMinimumBudget(type, result, dates, hugeTable.last.tongTien);
        
        if (minRequired <= budgetMax) {
          return await type.generateTable(
            service: _bettingService, result: result, start: dates.startDate, end: dates.endDate,
            startIdx: dates.startMienIndex, min: minRequired * 0.95, max: minRequired,
            results: _allResults, maxCount: dates.targetCount,
          );
        }
        throw Exception('Cần tối thiểu ${NumberUtils.formatCurrency(minRequired)}');
      } catch (e) {
        if (e is BudgetInsufficientException) rethrow;
        throw BudgetInsufficientException(tableName: type.displayName, budgetResult: budgetResult, minimumRequired: 0);
      }
    }
  }

  Future<double> _findMinimumBudget(
    BettingTableTypeEnum type, CycleAnalysisResult result, dynamic dates, double maxEstimate
  ) async {
    double low = 1.0, high = maxEstimate, minFound = maxEstimate;
    
    for (int i = 0; i < 20; i++) {
      final mid = (low + high) / 2;
      try {
        final t = await type.generateTable(
          service: _bettingService, result: result, start: dates.startDate, end: dates.endDate,
          startIdx: dates.startMienIndex, min: mid * 0.95, max: mid,
          results: _allResults, maxCount: dates.targetCount,
        );
        if (t.isNotEmpty) { minFound = t.last.tongTien; high = mid - 1; } 
        else { low = mid + 1; }
      } catch (_) { low = mid + 1; }
      if (high < low) break;
    }
    return minFound;
  }

  Future<void> _saveTableToSheet(BettingTableTypeEnum type, List<BettingRow> table, CycleAnalysisResult result) async {
    await _sheetsService.clearSheet(type.sheetName);
    await _sheetsService.updateRange(type.sheetName, 'A1:D1', [[
      result.maxGanDays.toString(),
      date_utils.DateUtils.formatDate(result.lastSeenDate),
      result.ganNumbersDisplay,
      result.targetNumber,
    ]]);
    await _sheetsService.updateRange(type.sheetName, 'A3:J3', [['STT', 'Ngày', 'Miền', 'Số', 'Số lô', 'Cược/số', 'Cược/miền', 'Tổng tiền', 'Lời (1 số)', 'Lời (2 số)']]);
    await _sheetsService.updateRange(type.sheetName, 'A4', table.map((e) => e.toSheetRow()).toList().cast<List<String>>());
  }

  // --- UTILS FOR CALCULATION ---

  ({DateTime date, String mien, int mienIndex, bool isLastBac}) _getLastResultInfo() {
    DateTime? latest; String? mien;
    for (final r in _allResults) {
      final d = date_utils.DateUtils.parseDate(r.ngay);
      if (d != null && (latest == null || d.isAfter(latest) || (d.isAtSameMomentAs(latest) && _isMienLater(r.mien, mien!)))) {
        latest = d; mien = r.mien;
      }
    }
    if (latest == null) throw Exception('No data');
    final mienOrder = ['Nam', 'Trung', 'Bắc'];
    final idx = mienOrder.indexOf(mien!);
    return (date: latest, mien: mien, mienIndex: idx, isLastBac: idx == 2);
  }

  bool _isMienLater(String newMien, String oldMien) {
    final p = {'Nam': 1, 'Trung': 2, 'Bắc': 3};
    return (p[newMien] ?? 0) > (p[oldMien] ?? 0);
  }

  int _countMienOccurrences(DateTime start, DateTime end, String mien) {
    final dates = <String>{};
    for (final r in _allResults) {
      final d = date_utils.DateUtils.parseDate(r.ngay);
      if (d != null && d.isAfter(start) && (d.isBefore(end) || d.isAtSameMomentAs(end)) && r.mien == mien) {
        dates.add(r.ngay);
      }
    }
    return dates.length;
  }

  List<Map<String, dynamic>> _simulateTableRows(DateTime start, int startIdx, String targetMien, int count, int initCount) {
    final rows = <Map<String, dynamic>>[];
    var curr = start; var total = initCount; var firstDay = true;
    final order = ['Nam', 'Trung', 'Bắc'];

    while (total < count) {
      for (int i = firstDay ? startIdx : 0; i < 3; i++) {
        rows.add({'date': curr, 'mien': order[i]});
        if (order[i] == targetMien) {
          total++; if (total >= count) break;
        }
      }
      firstDay = false; curr = curr.add(const Duration(days: 1));
    }
    return rows;
  }

  bool _checkIfExtraTurnNeeded(List<Map<String, dynamic>> rows) {
    if (rows.length < 2) return false;
    final dates = rows.map((e) => e['date'] as DateTime).toSet().toList()..sort();
    if (dates.length < 2) return false;

    bool hasNam(DateTime d) => rows.any((r) => (r['date'] as DateTime).isAtSameMomentAs(d) && r['mien'] == 'Nam');

    final last = dates.last;
    final secondLast = dates[dates.length - 2];

    if (hasNam(last) && last.weekday == 2) return true;
    if (hasNam(secondLast) && secondLast.weekday == 2) return true;

    return false;
  }

  // --- XIEN TABLE ---
  Future<void> createXienBettingTable() async {
    if (_ganPairInfo == null) return;
    _isLoading = true; _errorMessage = null; notifyListeners();
    try {
      final lastInfo = _getLastResultInfo();
      final start = lastInfo.date.add(const Duration(days: 1));
      final end = lastInfo.date.add(const Duration(days: AppConstants.durationBase));
      final config = await _storageService.loadConfig();
      
      final budgetRes = await BudgetCalculationService(sheetsService: _sheetsService)
          .calculateAvailableBudgetByEndDate(
              totalCapital: config!.budget.totalCapital, targetTable: 'xien',
              configBudget: config.budget.xienBudget, endDate: end);

      List<BettingRow> table;
      try {
        final rawTable = await _bettingService.generateXienTable(ganInfo: _ganPairInfo!, startDate: start, xienBudget: budgetRes.budgetMax);
        
        // ✅ FIX: Dùng factory method forXien() thay vì constructor trực tiếp
        table = rawTable.map<BettingRow>((row) {
          return BettingRow.forXien(
            stt: row.stt,
            ngay: row.ngay,
            mien: 'Bắc',  // ✅ Xiên luôn là Bắc
            so: row.so,
            cuocMien: row.cuocMien,
            tongTien: row.tongTien,
            loi: row.loi1So,
          );
        }).toList();

      } catch (e) {
        print('❌ Error generating xien table: $e');
        rethrow; 
      }
      
      await _saveXienTable(table);
      _isLoading = false; notifyListeners();
    } catch (e) {
      _errorMessage = e.toString(); _isLoading = false; notifyListeners();
    }
  }

  Future<void> _saveXienTable(List<BettingRow> table) async {
    await _sheetsService.clearSheet('xienBot');
    await _sheetsService.updateRange('xienBot', 'A1:D1', [[_ganPairInfo!.daysGan.toString(), date_utils.DateUtils.formatDate(_ganPairInfo!.lastSeen), _ganPairInfo!.pairsDisplay, table.first.so]]);
    // Header có cột Miền
    await _sheetsService.updateRange('xienBot', 'A3:G3', [['STT', 'Ngày', 'Miền', 'Số', 'Cược/miền', 'Tổng tiền', 'Lời']]);
    // Dữ liệu (toSheetRow() tự động map cột mien vào vị trí index 2)
    await _sheetsService.updateRange('xienBot', 'A4', table.map((e) => e.toSheetRow()).toList().cast<List<String>>());
  }

  // --- TELEGRAM ---

  Future<void> sendCycleAnalysisToTelegram() async {
    if (_cycleResult == null) return;
    await _sendTelegram(_buildCycleMessage());
  }

  Future<void> sendGanPairAnalysisToTelegram() async {
    if (_ganPairInfo == null) return;
    await _sendTelegram(_buildGanPairMessage());
  }

  Future<void> sendNumberDetailToTelegram(NumberDetail detail) async {
    await _sendTelegram(_buildNumberDetailMessage(detail));
  }

  Future<void> _sendTelegram(String msg) async {
    _isLoading = true; _errorMessage = null; notifyListeners();
    try {
      await _telegramService.sendMessage(msg);
      _isLoading = false; notifyListeners();
    } catch (e) {
      _errorMessage = 'Lỗi gửi Telegram: $e';
      _isLoading = false; notifyListeners();
    }
  }

  String _buildCycleMessage() {
    final buffer = StringBuffer();
    final title = switch(_selectedMien) {
      'Nam' => '🌴 PHÂN TÍCH CHU KỲ MIỀN NAM 🌴',
      'Trung' => '🔍 PHÂN TÍCH MIỀN TRUNG 🔍',
      'Bắc' => '🎯 PHÂN TÍCH MIỀN BẮC 🎯',
      _ => '📊 PHÂN TÍCH CHU KỲ (TẤT CẢ) 📊'
    };
    buffer.writeln('<b>$title</b>\n');
    buffer.writeln('<b>Miền:</b> $_selectedMien\n');
    buffer.writeln('<b>Số ngày gan:</b> ${_cycleResult!.maxGanDays} ngày');
    buffer.writeln('<b>Lần cuối về:</b> ${date_utils.DateUtils.formatDate(_cycleResult!.lastSeenDate)}');
    buffer.writeln('<b>Số mục tiêu:</b> ${_cycleResult!.targetNumber}\n');
    buffer.writeln('<b>Nhóm số gan nhất:</b>\n${_cycleResult!.ganNumbersDisplay}\n');
    
    if (_selectedMien == 'Tất cả') {
      buffer.writeln('<b>Phân bổ theo miền:</b>');
      for (var m in ['Nam', 'Trung', 'Bắc']) {
        if (_cycleResult!.mienGroups.containsKey(m)) {
          buffer.writeln('- Miền $m: ${_cycleResult!.mienGroups[m]!.join(", ")}');
        }
      }
    }
    return buffer.toString();
  }

  String _buildGanPairMessage() {
    final buffer = StringBuffer();
    buffer.writeln('<b>📈 PHÂN TÍCH CẶP XIÊN 📈</b>\n');
    
    buffer.writeln('Đây là 2 cặp số đã lâu nhất chưa xuất hiện cùng nhau:\n');
    for (int i = 0; i < _ganPairInfo!.pairs.length && i < 2; i++) {
      final p = _ganPairInfo!.pairs[i];
      // ✅ Hiển thị kiểu cột: "1. Miền Bắc | Cặp 01-02 (15 ngày)"
      buffer.writeln('${i + 1}. Miền Bắc | Cặp <b>${p.display}</b> (${p.daysGan} ngày)');
    }
    buffer.writeln('\n<b>Cặp gan nhất:</b> ${_ganPairInfo!.pairs[0].display}');
    buffer.writeln('<b>Số ngày gan:</b> ${_ganPairInfo!.daysGan} ngày');
    buffer.writeln('<b>Lần cuối về:</b> ${date_utils.DateUtils.formatDate(_ganPairInfo!.lastSeen)}');
    return buffer.toString();
  }

  String _buildNumberDetailMessage(NumberDetail detail) {
    final buffer = StringBuffer();
    buffer.writeln('<b>📊 CHI TIẾT SỐ ${detail.number} 📊</b>\n');
    for (var m in ['Nam', 'Trung', 'Bắc']) {
      if (detail.mienDetails.containsKey(m)) {
        final d = detail.mienDetails[m]!;
        buffer.writeln('<b>Miền $m:</b> ${d.daysGan} ngày - Lần cuối: ${d.lastSeenDateStr}');
      }
    }
    return buffer.toString();
  }
}