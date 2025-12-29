// lib/presentation/screens/analysis/analysis_viewmodel.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/date_utils.dart' as date_utils;
import '../../../data/models/app_config.dart';
import '../../../data/models/betting_row.dart';
import '../../../data/models/cycle_analysis_result.dart';
import '../../../data/models/gan_pair_info.dart';
import '../../../data/models/lottery_result.dart';
import '../../../data/models/number_detail.dart';
import '../../../data/services/analysis_service.dart';
import '../../../data/services/betting_table_service.dart';
import '../../../data/services/budget_calculation_service.dart';
import '../../../data/services/cached_data_service.dart';
import '../../../data/services/google_sheets_service.dart';
import '../../../data/services/storage_service.dart';
import '../../../data/services/telegram_service.dart';

// --- ENUM & EXTENSION ---
enum BettingTableTypeEnum { tatca, nam, trung, bac }

extension BettingTableTypeExtension on BettingTableTypeEnum {
  String get sheetName => switch (this) {
        BettingTableTypeEnum.tatca => 'xsktBot1',
        BettingTableTypeEnum.nam => 'namBot',
        BettingTableTypeEnum.trung => 'trungBot',
        BettingTableTypeEnum.bac => 'bacBot',
      };

  String get displayName => switch (this) {
        BettingTableTypeEnum.tatca => 'Tất cả',
        BettingTableTypeEnum.nam => 'Miền Nam',
        BettingTableTypeEnum.trung => 'Miền Trung',
        BettingTableTypeEnum.bac => 'Miền Bắc',
      };

  String get budgetTableName => switch (this) {
        BettingTableTypeEnum.tatca => 'tatca',
        BettingTableTypeEnum.nam => 'nam',
        BettingTableTypeEnum.trung => 'trung',
        BettingTableTypeEnum.bac => 'bac',
      };

  double? getBudgetConfig(AppConfig config) => switch (this) {
        BettingTableTypeEnum.tatca => null,
        BettingTableTypeEnum.nam => config.budget.namBudget,
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
    required int durationLimit,
  }) async {
    return switch (this) {
      BettingTableTypeEnum.tatca => await service.generateCycleTable(
          cycleResult: result,
          startDate: start,
          endDate: end,
          startMienIndex: startIdx,
          budgetMin: min,
          budgetMax: max,
          allResults: results,
          maxMienCount: maxCount,
          durationLimit: durationLimit,
        ),
      BettingTableTypeEnum.nam => await service.generateNamGanTable(
          cycleResult: result,
          startDate: start,
          endDate: end,
          budgetMin: min,
          budgetMax: max,
          durationLimit: durationLimit,
        ),
      BettingTableTypeEnum.trung => await service.generateTrungGanTable(
          cycleResult: result,
          startDate: start,
          endDate: end,
          budgetMin: min,
          budgetMax: max,
          durationLimit: durationLimit,
        ),
      BettingTableTypeEnum.bac => await service.generateBacGanTable(
          cycleResult: result,
          startDate: start,
          endDate: end,
          budgetMin: min,
          budgetMax: max,
          durationLimit: durationLimit,
        ),
    };
  }
}

class BettingTableParams {
  final BettingTableTypeEnum type;
  final String targetNumber;
  final DateTime startDate;
  final DateTime endDate;
  final int startMienIndex;
  final int durationLimit;
  final int soNgayGan;
  final CycleAnalysisResult cycleResult;
  final List<LotteryResult> allResults;

  BettingTableParams({
    required this.type,
    required this.targetNumber,
    required this.startDate,
    required this.endDate,
    required this.startMienIndex,
    required this.durationLimit,
    required this.soNgayGan,
    required this.cycleResult,
    required this.allResults,
  });
}

// --- VIEW MODEL ---
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

  // Dữ liệu
  GanPairInfo? _ganPairInfo;
  CycleAnalysisResult? _cycleResult;
  String _selectedMien = 'Tất cả';
  List<LotteryResult> _allResults = [];

  // Cache data từ Sheet
  final List<CycleAnalysisResult> _cachedSheetResults = [];

  // Header Info
  String _sheetHeaderDate = "";
  String _sheetHeaderRegion = "";

  // State Optimal Plan (START INFO - hiển thị ở Summary)
  String _optimalTatCa = "Đang tính ...";
  String _optimalNam = "Đang tính ...";
  String _optimalTrung = "Đang tính ...";
  String _optimalBac = "Đang tính ...";
  String _optimalXien = "Đang tính ...";

  // State End Plan (END INFO - hiển thị ở Detail Tab)
  String _endPlanTatCa = "...";
  String _endPlanNam = "...";
  String _endPlanTrung = "...";
  String _endPlanBac = "...";
  String _endPlanXien = "...";

  DateTime? _dateTatCa;
  DateTime? _dateNam;
  DateTime? _dateTrung;
  DateTime? _dateBac;
  DateTime? _dateXien;

  DateTime? _endDateTatCa;
  DateTime? _endDateNam;
  DateTime? _endDateTrung;
  DateTime? _endDateBac;
  DateTime? _endDateXien;

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  GanPairInfo? get ganPairInfo => _ganPairInfo;
  CycleAnalysisResult? get cycleResult => _cycleResult;
  String get selectedMien => _selectedMien;

  // Getters for Start Info (Summary)
  String get optimalTatCa => _optimalTatCa;
  String get optimalNam => _optimalNam;
  String get optimalTrung => _optimalTrung;
  String get optimalBac => _optimalBac;
  String get optimalXien => _optimalXien;

  // Getters for End Info (Detail)
  String get endPlanTatCa => _endPlanTatCa;
  String get endPlanNam => _endPlanNam;
  String get endPlanTrung => _endPlanTrung;
  String get endPlanBac => _endPlanBac;
  String get endPlanXien => _endPlanXien;

  DateTime? get dateTatCa => _dateTatCa;
  DateTime? get dateNam => _dateNam;
  DateTime? get dateTrung => _dateTrung;
  DateTime? get dateBac => _dateBac;
  DateTime? get dateXien => _dateXien;

  DateTime? get endDateTatCa => _endDateTatCa;
  DateTime? get endDateNam => _endDateNam;
  DateTime? get endDateTrung => _endDateTrung;
  DateTime? get endDateBac => _endDateBac;
  DateTime? get endDateXien => _endDateXien;

  String get latestDataInfo {
    if (_sheetHeaderDate.isNotEmpty && _sheetHeaderRegion.isNotEmpty) {
      return "$_sheetHeaderRegion ngày $_sheetHeaderDate";
    }
    return "Đang tải dữ liệu...";
  }

  // --- ACTIONS ---

  void setSelectedMien(String mien) {
    if (_selectedMien == mien) return;
    _selectedMien = mien;
    _updateCurrentCycleResult();
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ✅ HÀM LOAD CHÍNH
  Future<void> loadAnalysis({bool useCache = true}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Load Config (Fallback mặc định)
      var config = await _storageService.loadConfig();
      if (config == null) {
        config = AppConfig.defaultConfig();
        await _storageService.saveConfig(config);
      }

      // 2. Init Service
      await _sheetsService.initialize(config.googleSheets);

      // ✅ Load KQXS nền TRƯỚC để có dữ liệu tính toán Plan
      if (_allResults.isEmpty || !useCache) {
        print('🔄 [ViewModel] Fetching KQXS data first...');
        _allResults = await _cachedDataService.loadKQXS(
          forceRefresh: !useCache,
          incrementalOnly: useCache,
        );
      }

      print('🔄 [ViewModel] Fetching Analysis Data...');

      // 3. Get Data (Service đã được update range lên 30 dòng)
      final rawData = await _sheetsService.getAnalysisCycleData();

      if (rawData.isEmpty) {
        print('⚠️ Data analysis_cycle trống');
        _isLoading = false;
        notifyListeners();
        return;
      }

      // 4. Parse Header (Dòng 1 trong Sheet)
      if (rawData.isNotEmpty) {
        final headerRow = rawData[0];
        if (headerRow.length > 3) {
          _sheetHeaderDate = headerRow[1];
          _sheetHeaderRegion = headerRow[3];
        }
      }

      // 5. Parse Data Loop
      _cachedSheetResults.clear();
      _ganPairInfo = null;

      print('📊 Danh sách các miền tìm thấy trong Sheet:');

      for (int i = 1; i < rawData.length; i++) {
        try {
          final row = rawData[i];
          if (row.isEmpty) continue;

          final rawMien = row[0];
          final mienName = rawMien.trim().toLowerCase();

          // ✅ BỎ QUA DÒNG HEADER PHỤ
          if (mienName.contains('miền xét') || mienName.contains('mien xet')) {
            continue;
          }

          // ✅ BẮT XIÊN
          if (mienName.contains('xiên') || mienName.contains('xien')) {
            print('      ✅ ĐÃ TÌM THẤY XIÊN -> Parsing...');
            _parseXienRow(row, config);
            continue;
          }

          // Xử lý các miền khác
          final result = _parseRowToResult(row);
          _cachedSheetResults.add(result);

          await _calculatePlanForRegion(result, rawMien, config);
        } catch (e) {
          print('⚠️ Lỗi parse dòng ${i + 1}: $e');
        }
      }

      _updateCurrentCycleResult();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Lỗi tải dữ liệu: $e';
      print('❌ Fatal Error: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  CycleAnalysisResult _parseRowToResult(List<String> row) {
    String getVal(int idx) => (idx < row.length) ? row[idx] : "";
    int parseInt(String s) =>
        int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

    DateTime parseDate(String s) {
      try {
        if (s.contains('/')) return DateFormat('dd/MM/yyyy').parse(s);
        if (s.contains('-')) return DateTime.parse(s);
        return DateTime.now();
      } catch (e) {
        return DateTime.now();
      }
    }

    final mien = getVal(0);
    final targetNumber = getVal(1);
    final ganCurDays = parseInt(getVal(4));
    final lastSeen = parseDate(getVal(5));
    final ganPrevDays = parseInt(getVal(7));
    final ganPrevPrevDays = parseInt(getVal(9));

    final maxHistorical =
        (ganPrevDays > ganPrevPrevDays) ? ganPrevDays : ganPrevPrevDays;

    return CycleAnalysisResult(
      ganNumbers: {targetNumber},
      maxGanDays: ganCurDays,
      lastSeenDate: lastSeen,
      mienGroups: {
        mien: [targetNumber]
      },
      targetNumber: targetNumber,
      ganCurrentSlots: parseInt(getVal(3)),
      ganCKTruocSlots: parseInt(getVal(6)),
      ganCKTruocDays: ganPrevDays,
      ganCKKiaSlots: parseInt(getVal(8)),
      ganCKKiaDays: ganPrevPrevDays,
      historicalGan: maxHistorical,
    );
  }

  void _parseXienRow(List<String> row, AppConfig? config) {
    try {
      String getVal(int idx) => (idx < row.length) ? row[idx] : "";
      int parseInt(String s) =>
          int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

      final pairStr = getVal(1);
      final ganCurDays = parseInt(getVal(4));
      final lastSeenStr = getVal(5);

      if (pairStr.isEmpty) return;

      DateTime lastSeen;
      try {
        if (lastSeenStr.contains('/'))
          lastSeen = DateFormat('dd/MM/yyyy').parse(lastSeenStr);
        else if (lastSeenStr.contains('-'))
          lastSeen = DateTime.parse(lastSeenStr);
        else
          lastSeen = DateTime.now();
      } catch (_) {
        lastSeen = DateTime.now();
      }

      final parts =
          pairStr.split(RegExp(r'[-,\s]+')).where((e) => e.isNotEmpty).toList();
      String first = parts.isNotEmpty ? parts[0] : '00';
      String second = parts.length > 1 ? parts[1] : '00';

      final pairObj = PairWithDays(
          pair: NumberPair(first, second),
          daysGan: ganCurDays,
          lastSeen: lastSeen);

      _ganPairInfo = GanPairInfo(
        pairs: [pairObj],
        daysGan: ganCurDays,
        lastSeen: lastSeen,
      );
      _calculatePlanForXien(config);
    } catch (e) {
      print('❌ Lỗi parse dòng Xiên: $e');
    }
  }

  void _updateCurrentCycleResult() {
    String searchKey = '';
    switch (_selectedMien) {
      case 'Tất cả':
        searchKey = 'Tất cả';
        break;
      case 'Nam':
        searchKey = 'Nam';
        break;
      case 'Trung':
        searchKey = 'Trung';
        break;
      case 'Bắc':
        searchKey = 'Bắc';
        break;
    }

    try {
      _cycleResult = _cachedSheetResults.firstWhere((e) => e
          .mienGroups.keys.first
          .toLowerCase()
          .contains(searchKey.toLowerCase()));
    } catch (e) {
      _cycleResult = null;
    }
  }

  // --- HELPER: Lấy threshold cho miền ---
  double _getThresholdForMien(String mien, AppConfig config) {
    final normalizedMien = mien.toLowerCase();
    if (normalizedMien.contains('nam')) {
      return config.probability.thresholdLnNam;
    } else if (normalizedMien.contains('trung')) {
      return config.probability.thresholdLnTrung;
    } else if (normalizedMien.contains('bắc') ||
        normalizedMien.contains('bac')) {
      return config.probability.thresholdLnBac;
    } else {
      return config.probability.thresholdLnTatCa;
    }
  }

  // Helper hiển thị tên Miền
  String _getEndRegionName(String mienName) {
    final normalized = mienName.toLowerCase();
    if (normalized.contains('nam')) return 'Miền Nam';
    if (normalized.contains('trung')) return 'Miền Trung';
    if (normalized.contains('bắc') || normalized.contains('bac'))
      return 'Miền Bắc';
    return 'Miền Bắc';
  }

  String _getStartRegionName(String mienName) {
    final normalized = mienName.toLowerCase();
    if (normalized.contains('nam')) return 'Miền Nam';
    if (normalized.contains('trung')) return 'Miền Trung';
    if (normalized.contains('bắc') || normalized.contains('bac'))
      return 'Miền Bắc';
    return 'Miền Nam';
  }

  Future<void> _calculatePlanForRegion(
    CycleAnalysisResult result,
    String mienName,
    AppConfig? config,
  ) async {
    if (config == null) return;
    if (_allResults.isEmpty) return;

    String normalizedMien = mienName.toLowerCase();
    double thresholdLn = _getThresholdForMien(mienName, config);

    print(
        '\n========== TÍNH TOÁN KẾ HOẠCH CHO $mienName (Số: ${result.targetNumber}) ==========');

    // 2. Lấy dữ liệu phân tích chi tiết
    final analysisData = await AnalysisService.getAnalysisData(
      result.targetNumber,
      _allResults,
      mienName,
    );

    DateTime? finalEndDate;
    int daysNeeded = 0;

    if (analysisData != null) {
      // 3. ✅ Chạy mô phỏng tìm ngày kết thúc (P_total < threshold)
      final simResult = await AnalysisService.findEndDateForCycleThreshold(
        analysisData,
        0.01,
        _allResults,
        thresholdLn,
        mien: mienName,
      );

      if (simResult != null) {
        finalEndDate = simResult.endDate;
        daysNeeded = simResult.daysNeeded;
        print(
            '   ✅ [Plan] Target End Date: ${date_utils.DateUtils.formatDate(finalEndDate)}');
      }
    }

    finalEndDate ??= DateTime.now().add(const Duration(days: 2));
    DateTime startDate = DateTime.now().add(const Duration(days: 1));

    // 4. ✅ TỐI ƯU HÓA NGÀY BẮT ĐẦU (Tăng dần Start Date để khớp Budget)
    try {
      final type = _mapMienToEnum(mienName);
      final budgetService =
          BudgetCalculationService(sheetsService: _sheetsService);
      final budgetResult =
          await budgetService.calculateAvailableBudgetByEndDate(
        totalCapital: config.budget.totalCapital,
        targetTable: type.budgetTableName,
        configBudget: type.getBudgetConfig(config),
        endDate: finalEndDate,
      );

      final optimalStart = await AnalysisService.findOptimalStartDateForCycle(
        baseStartDate: startDate,
        endDate: finalEndDate,
        availableBudget: budgetResult.budgetMax,
        mien: type == BettingTableTypeEnum.tatca ? 'Tất cả' : type.displayName,
        targetNumber: result.targetNumber,
        cycleResult: result,
        allResults: _allResults,
        bettingService: _bettingService,
        maxMienCount: type == BettingTableTypeEnum.tatca
            ? finalEndDate.difference(startDate).inDays
            : 0,
      );

      if (optimalStart != null) {
        startDate = optimalStart;
        daysNeeded = finalEndDate.difference(startDate).inDays;
        print(
            '   🚀 [Plan] Optimized Start Date: ${date_utils.DateUtils.formatDate(startDate)}');
      }
    } catch (e) {
      print('   ⚠️ [Plan] Lỗi tối ưu hiển thị ngày bắt đầu: $e');
    }

    // ✅ TÁCH BIỆT DỮ LIỆU HIỂN THỊ
    final startRegionStr = _getStartRegionName(mienName);
    final endRegionStr = _getEndRegionName(mienName);

    // 1. Summary String: CHỈ hiện Bắt đầu (cho thẻ Summary)
    String startInfoString =
        "${date_utils.DateUtils.formatDate(startDate)} ($startRegionStr)";
    if (daysNeeded > 60) {
      startInfoString += " (⚠️ >60 ngày)";
    }

    // 2. Detail String: Hiện Kết thúc (cho tab Chi tiết)
    String endInfoString =
        "🏁 Kết thúc: ${date_utils.DateUtils.formatDate(finalEndDate)} ($endRegionStr)";

    // Gán vào State
    if (normalizedMien.contains('nam')) {
      _dateNam = startDate;
      _endDateNam = finalEndDate;
      _optimalNam = startInfoString;
      _endPlanNam = endInfoString;
    } else if (normalizedMien.contains('trung')) {
      _dateTrung = startDate;
      _endDateTrung = finalEndDate;
      _optimalTrung = startInfoString;
      _endPlanTrung = endInfoString;
    } else if (normalizedMien.contains('bắc')) {
      _dateBac = startDate;
      _endDateBac = finalEndDate;
      _optimalBac = startInfoString;
      _endPlanBac = endInfoString;
    } else {
      _dateTatCa = startDate;
      _endDateTatCa = finalEndDate;
      _optimalTatCa = startInfoString;
      _endPlanTatCa = endInfoString;
    }
  }

  Future<void> _calculatePlanForXien(AppConfig? config) async {
    if (_ganPairInfo == null || config == null) return;

    final thresholdLn = config.probability.thresholdLnXien;
    final pairAnalysis = PairAnalysisData(
      firstNumber: _ganPairInfo!.pairs[0].pair.first,
      secondNumber: _ganPairInfo!.pairs[0].pair.second,
      lnP1Pair: 0,
      lnPTotalXien: 0,
      daysSinceLastSeen: _ganPairInfo!.daysGan.toDouble(),
      lastSeenDate: _ganPairInfo!.lastSeen,
    );

    const pPair = 0.055;
    final simResult = await AnalysisService.findEndDateForXienThreshold(
        pairAnalysis, pPair, thresholdLn);

    final start = DateTime.now().add(const Duration(days: 1));

    if (simResult != null) {
      _dateXien = start;
      _endDateXien = simResult.endDate;
      _optimalXien = "${date_utils.DateUtils.formatDate(start)} (Miền Bắc)";
      _endPlanXien =
          "🏁 Kết thúc: ${date_utils.DateUtils.formatDate(simResult.endDate)} (Miền Bắc)";
    } else {
      _dateXien = start;
      _endDateXien = start.add(const Duration(days: 5));
      _optimalXien = "Đang tính toán...";
      _endPlanXien = "...";
    }
  }

  Future<void> createCycleBettingTable(String number, AppConfig config) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final params = await _prepareFarmingParams(
        mien: 'Tất cả',
        config: config,
        targetNumber: number,
      );
      await _createBettingTableGeneric(params, config);
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createNamGanBettingTable(String number, AppConfig config) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final params = await _prepareFarmingParams(
        mien: 'Nam',
        config: config,
        targetNumber: number,
      );
      await _createBettingTableGeneric(params, config);
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createTrungGanBettingTable(
      String number, AppConfig config) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final params = await _prepareFarmingParams(
        mien: 'Trung',
        config: config,
        targetNumber: number,
      );
      await _createBettingTableGeneric(params, config);
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createBacGanBettingTable(String number, AppConfig config) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final params = await _prepareFarmingParams(
        mien: 'Bắc',
        config: config,
        targetNumber: number,
      );
      await _createBettingTableGeneric(params, config);
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // ✅ ĐÃ SỬA: Ưu tiên lấy cached state (_endDateNam...)
  Future<BettingTableParams> _prepareFarmingParams({
    required String mien,
    required AppConfig config,
    required String targetNumber,
  }) async {
    final type = _mapMienToEnum(mien);

    DateTime startDate = DateTime.now().add(const Duration(days: 1));
    DateTime endDate;

    DateTime? cachedEndDate;
    bool isMatchingTarget =
        _cycleResult != null && _cycleResult!.targetNumber == targetNumber;

    if (isMatchingTarget) {
      switch (type) {
        case BettingTableTypeEnum.tatca:
          cachedEndDate = _endDateTatCa;
          break;
        case BettingTableTypeEnum.nam:
          cachedEndDate = _endDateNam;
          break;
        case BettingTableTypeEnum.trung:
          cachedEndDate = _endDateTrung;
          break;
        case BettingTableTypeEnum.bac:
          cachedEndDate = _endDateBac;
          break;
      }
    }

    if (cachedEndDate != null) {
      print(
          '✅ Using cached EndDate for $mien: ${date_utils.DateUtils.formatDate(cachedEndDate)}');
      endDate = cachedEndDate;
    } else {
      print(
          '⚠️ Cached EndDate mismatch or null. Recalculating for $targetNumber ($mien)...');
      final double threshold = _getThresholdForMien(mien, config);
      final analysisData = await AnalysisService.getAnalysisData(
        targetNumber,
        _allResults,
        mien,
      );

      endDate = startDate.add(const Duration(days: 3));

      if (analysisData != null) {
        final simResult = await AnalysisService.findEndDateForCycleThreshold(
          analysisData,
          0.01,
          _allResults,
          threshold,
          mien: mien,
        );
        if (simResult != null) {
          endDate = simResult.endDate;
        }
      }
    }

    if (endDate.difference(startDate).inDays < 1) {
      endDate = startDate.add(const Duration(days: 1));
    }

    final actualDuration = endDate.difference(startDate).inDays;
    final durationLimit = actualDuration > 0 ? actualDuration : 1;

    print('\n========== CHUẨN BỊ TẠO BẢNG CƯỢC ($mien) ==========');
    print('   🎯 Số mục tiêu: $targetNumber');
    print(
        '   🏁 Ngày kết thúc (Cố định): ${date_utils.DateUtils.formatDate(endDate)}');
    print(
        '   🚀 Ngày bắt đầu (Gốc): ${date_utils.DateUtils.formatDate(startDate)} -> Sẽ được tối ưu ngay sau đây...');

    return BettingTableParams(
      type: type,
      targetNumber: targetNumber,
      startDate: startDate,
      endDate: endDate,
      startMienIndex: 0,
      durationLimit: durationLimit,
      soNgayGan: _cycleResult?.maxGanDays ?? 0,
      cycleResult: _cycleResult!,
      allResults: _allResults,
    );
  }

  Future<void> _createBettingTableGeneric(
    BettingTableParams params,
    AppConfig config,
  ) async {
    print(
        '🚀 [Generic] Starting table creation for ${params.type.displayName}...');
    try {
      // STEP 1: Calculate budget
      final budgetService =
          BudgetCalculationService(sheetsService: _sheetsService);
      final budgetResult =
          await budgetService.calculateAvailableBudgetByEndDate(
        totalCapital: config.budget.totalCapital,
        targetTable: params.type.budgetTableName,
        configBudget: params.type.getBudgetConfig(config),
        endDate: params.endDate,
      );

      // STEP 2: Optimize start date
      print('🔍 Optimizing start date (Budget: ${budgetResult.budgetMax})...');
      DateTime finalStartDate = params.startDate;

      try {
        final optimalStart = await AnalysisService.findOptimalStartDateForCycle(
          baseStartDate: params.startDate,
          endDate: params.endDate,
          availableBudget: budgetResult.budgetMax,
          mien: params.type == BettingTableTypeEnum.tatca
              ? 'Tất cả'
              : params.type.displayName,
          targetNumber: params.targetNumber,
          cycleResult: params.cycleResult,
          allResults: params.allResults,
          bettingService: _bettingService,
          maxMienCount: params.type == BettingTableTypeEnum.tatca
              ? params.durationLimit
              : 0,
        );

        if (optimalStart != null) {
          finalStartDate = optimalStart;
          print(
              '✅ Optimized start date: ${date_utils.DateUtils.formatDate(finalStartDate)}');
        } else {
          print('⚠️ Could not optimize start date, using default');
        }
      } catch (e) {
        print('⚠️ Error optimizing start date: $e');
      }

      // STEP 3: Generate table
      final table = await params.type.generateTable(
        service: _bettingService,
        result: params.cycleResult,
        start: finalStartDate,
        end: params.endDate,
        startIdx: params.startMienIndex,
        min: budgetResult.budgetMax * 0.9,
        max: budgetResult.budgetMax,
        results: params.allResults,
        maxCount: params.type == BettingTableTypeEnum.tatca
            ? params.durationLimit
            : 0,
        durationLimit: params.endDate.difference(finalStartDate).inDays,
      );

      // STEP 4: Save to sheet
      await _saveTableToSheet(params.type, table, params.cycleResult);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  BettingTableTypeEnum _mapMienToEnum(String mien) {
    final normalized = mien.toLowerCase().trim();
    switch (normalized) {
      case 'tất cả':
      case 'tatca':
      case 'all':
        return BettingTableTypeEnum.tatca;
      case 'nam':
        return BettingTableTypeEnum.nam;
      case 'trung':
        return BettingTableTypeEnum.trung;
      case 'bắc':
      case 'bac':
        return BettingTableTypeEnum.bac;
      default:
        throw Exception('Miền không hợp lệ: $mien');
    }
  }

  Future<void> createXienBettingTable() async {
    if (_ganPairInfo == null) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      var config = await _storageService.loadConfig();
      config ??= AppConfig.defaultConfig();

      final start = _dateXien ?? DateTime.now().add(const Duration(days: 1));
      final endDate = _endDateXien ?? start.add(const Duration(days: 3));

      final actualBettingDays = endDate.difference(start).inDays;
      final effectiveDurationBase = actualBettingDays + _ganPairInfo!.daysGan;

      final budgetRes =
          await BudgetCalculationService(sheetsService: _sheetsService)
              .calculateAvailableBudgetByEndDate(
                  totalCapital: config.budget.totalCapital,
                  targetTable: 'xien',
                  configBudget: config.budget.xienBudget,
                  endDate: endDate);

      List<BettingRow> table;
      try {
        final rawTable = await _bettingService.generateXienTable(
          ganInfo: _ganPairInfo!,
          startDate: start,
          xienBudget: budgetRes.budgetMax,
          durationBase: effectiveDurationBase,
        );

        table = rawTable.map<BettingRow>((row) {
          return BettingRow.forXien(
            stt: row.stt,
            ngay: row.ngay,
            mien: 'Bắc',
            so: row.so,
            cuocMien: row.cuocMien,
            tongTien: row.tongTien,
            loi: row.loi1So,
          );
        }).toList();
      } catch (e) {
        rethrow;
      }

      await _saveXienTable(table);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- HELPERS ---

  Future<void> _saveTableToSheet(BettingTableTypeEnum type,
      List<BettingRow> table, CycleAnalysisResult result) async {
    await _sheetsService.clearSheet(type.sheetName);

    final updates = <String, BatchUpdateData>{};
    final metadataRow = [
      result.maxGanDays.toString(),
      date_utils.DateUtils.formatDate(result.lastSeenDate),
      result.ganNumbersDisplay,
      result.targetNumber,
    ];
    final headerRow = [
      'STT',
      'Ngày',
      'Miền',
      'Số',
      'Số lô',
      'Cược/số',
      'Cược/miền',
      'Tổng tiền',
      'Lời (1 số)',
      'Lời (2 số)'
    ];
    final dataRows = table.map((e) => e.toSheetRow()).toList();

    updates[type.sheetName] = BatchUpdateData(
      range: 'A1',
      values: [metadataRow, [], headerRow, ...dataRows],
    );

    await _sheetsService.batchUpdateRanges(updates);
  }

  Future<void> _saveXienTable(List<BettingRow> table) async {
    await _sheetsService.clearSheet('xienBot');

    final updates = <String, BatchUpdateData>{};
    final metadataRow = [
      _ganPairInfo!.daysGan.toString(),
      date_utils.DateUtils.formatDate(_ganPairInfo!.lastSeen),
      _ganPairInfo!.pairsDisplay,
      table.first.so
    ];
    final headerRow = [
      'STT',
      'Ngày',
      'Miền',
      'Số',
      'Cược/miền',
      'Tổng tiền',
      'Lời'
    ];
    final dataRows = table.map((e) => e.toSheetRow()).toList();

    updates['xienBot'] = BatchUpdateData(
      range: 'A1',
      values: [metadataRow, [], headerRow, ...dataRows],
    );

    await _sheetsService.batchUpdateRanges(updates);
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

  Future<void> _sendTelegram(String msg) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _telegramService.sendMessage(msg);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Lỗi gửi Telegram: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  String _buildCycleMessage() {
    final buffer = StringBuffer();
    final title = switch (_selectedMien) {
      'Nam' => '🌴 PHÂN TÍCH CHU KỲ MIỀN NAM 🌴',
      'Trung' => '🔍 PHÂN TÍCH MIỀN TRUNG 🔍',
      'Bắc' => '🎯 PHÂN TÍCH MIỀN BẮC 🎯',
      _ => '📊 PHÂN TÍCH CHU KỲ (TẤT CẢ) 📊'
    };
    buffer.writeln('<b>$title</b>\n');
    buffer.writeln('<b>Miền:</b> $_selectedMien\n');
    buffer.writeln('<b>Số ngày gan:</b> ${_cycleResult!.maxGanDays} ngày');
    buffer.writeln(
        '<b>Lần cuối về:</b> ${date_utils.DateUtils.formatDate(_cycleResult!.lastSeenDate)}');

    buffer.writeln('<b>Số mục tiêu:</b> ${_cycleResult!.targetNumber}\n');

    // Kết hợp Start (optimal) và End (plan) để báo cáo đầy đủ trên Telegram
    if (_selectedMien == 'Tất cả') {
      if (_optimalTatCa != "Chưa có" && !_optimalTatCa.contains("Thiếu vốn")) {
        buffer.writeln(
            '<b>Kế hoạch (Tất cả):</b>\n$_optimalTatCa\n$_endPlanTatCa\n');
      }
    } else if (_selectedMien == 'Nam') {
      if (_optimalNam != "Chưa có" && !_optimalNam.contains("Thiếu vốn")) {
        buffer.writeln('<b>Kế hoạch (Nam):</b>\n$_optimalNam\n$_endPlanNam\n');
      }
    } else if (_selectedMien == 'Trung') {
      if (_optimalTrung != "Chưa có" && !_optimalTrung.contains("Thiếu vốn")) {
        buffer.writeln(
            '<b>Kế hoạch (Trung):</b>\n$_optimalTrung\n$_endPlanTrung\n');
      }
    } else if (_selectedMien == 'Bắc') {
      if (_optimalBac != "Chưa có" && !_optimalBac.contains("Thiếu vốn")) {
        buffer.writeln('<b>Kế hoạch (Bắc):</b>\n$_optimalBac\n$_endPlanBac\n');
      }
    }

    buffer.writeln(
        '<b>Nhóm số gan nhất:</b>\n${_cycleResult!.ganNumbersDisplay}\n');
    return buffer.toString();
  }

  String _buildGanPairMessage() {
    final buffer = StringBuffer();
    buffer.writeln('<b>📈 PHÂN TÍCH CẶP XIÊN 📈</b>\n');
    for (int i = 0; i < _ganPairInfo!.pairs.length && i < 2; i++) {
      final p = _ganPairInfo!.pairs[i];
      buffer.writeln(
          '${i + 1}. Miền Bắc | Cặp <b>${p.display}</b> (${p.daysGan} ngày)');
    }
    buffer.writeln('\n<b>Cặp gan nhất:</b> ${_ganPairInfo!.pairs[0].display}');
    buffer.writeln('<b>Số ngày gan:</b> ${_ganPairInfo!.daysGan} ngày');
    buffer.writeln(
        '<b>Lần cuối về:</b> ${date_utils.DateUtils.formatDate(_ganPairInfo!.lastSeen)}');

    if (_optimalXien != "Chưa có" && !_optimalXien.contains("Thiếu vốn")) {
      buffer.writeln('\n<b>Kế hoạch:</b>\n$_optimalXien\n$_endPlanXien');
    }
    return buffer.toString();
  }

  Future<NumberDetail?> analyzeNumberDetail(String number) async {
    return await _analysisService.analyzeNumberDetail(_allResults, number);
  }
}
