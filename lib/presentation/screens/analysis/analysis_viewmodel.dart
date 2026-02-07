// lib/presentation/screens/analysis/analysis_viewmodel.dart

import 'dart:convert';

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
    required String endMien,
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
          endMien: endMien,
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

// ✅ NEW: Model chứa kết quả tính toán ngày/miền đầy đủ
class RegionPlanResult {
  final DateTime startDate;
  final DateTime endDate;
  final String endMien;
  final int startMienIndex;
  final int daysNeeded;
  final bool hasBudgetError;
  final String? budgetErrorMessage;

  RegionPlanResult({
    required this.startDate,
    required this.endDate,
    required this.endMien,
    required this.startMienIndex,
    required this.daysNeeded,
    this.hasBudgetError = false,
    this.budgetErrorMessage,
  });

  // Format cho Summary Card
  String formatStartInfo() {
    if (hasBudgetError) return "⚠️ Thiếu vốn";

    final startRegionStr = _getStartRegionName(startMienIndex);
    String result =
        "${date_utils.DateUtils.formatDate(startDate)} ($startRegionStr)";

    if (daysNeeded > 60) {
      result += " (>60 ngày)";
    }

    return result;
  }

  // Format cho Detail Card
  String formatEndInfo() {
    if (hasBudgetError) {
      return "❌ Vốn không đủ";
    }
    return "🏁 Kết thúc: ${date_utils.DateUtils.formatDate(endDate)} ($endMien)";
  }

  String _getStartRegionName(int index) {
    return switch (index) {
      0 => 'Miền Nam',
      1 => 'Miền Trung',
      2 => 'Miền Bắc',
      _ => 'Miền Nam',
    };
  }
}

class BettingTableParams {
  final BettingTableTypeEnum type;
  final String targetNumber;
  final DateTime startDate;
  final DateTime endDate;
  final String endMien;
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
    required this.endMien,
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

  // ✅ NEW: Cache kết quả tính toán đầy đủ
  RegionPlanResult? _cachedPlanTatCa;
  RegionPlanResult? _cachedPlanNam;
  RegionPlanResult? _cachedPlanTrung;
  RegionPlanResult? _cachedPlanBac;
  RegionPlanResult? _cachedPlanXien;

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  GanPairInfo? get ganPairInfo => _ganPairInfo;
  CycleAnalysisResult? get cycleResult => _cycleResult;
  String get selectedMien => _selectedMien;

  // ✅ NEW: Getters sử dụng cache result
  String get optimalTatCa =>
      _cachedPlanTatCa?.formatStartInfo() ?? "Đang tính ...";
  String get optimalNam => _cachedPlanNam?.formatStartInfo() ?? "Đang tính ...";
  String get optimalTrung =>
      _cachedPlanTrung?.formatStartInfo() ?? "Đang tính ...";
  String get optimalBac => _cachedPlanBac?.formatStartInfo() ?? "Đang tính ...";
  String get optimalXien =>
      _cachedPlanXien?.formatStartInfo() ?? "Đang tính ...";

  String get endPlanTatCa => _cachedPlanTatCa?.formatEndInfo() ?? "...";
  String get endPlanNam => _cachedPlanNam?.formatEndInfo() ?? "...";
  String get endPlanTrung => _cachedPlanTrung?.formatEndInfo() ?? "...";
  String get endPlanBac => _cachedPlanBac?.formatEndInfo() ?? "...";
  String get endPlanXien => _cachedPlanXien?.formatEndInfo() ?? "...";

  DateTime? get dateTatCa => _cachedPlanTatCa?.startDate;
  DateTime? get dateNam => _cachedPlanNam?.startDate;
  DateTime? get dateTrung => _cachedPlanTrung?.startDate;
  DateTime? get dateBac => _cachedPlanBac?.startDate;
  DateTime? get dateXien => _cachedPlanXien?.startDate;

  DateTime? get endDateTatCa => _cachedPlanTatCa?.endDate;
  DateTime? get endDateNam => _cachedPlanNam?.endDate;
  DateTime? get endDateTrung => _cachedPlanTrung?.endDate;
  DateTime? get endDateBac => _cachedPlanBac?.endDate;
  DateTime? get endDateXien => _cachedPlanXien?.endDate;

  String get endMienTatCa => _cachedPlanTatCa?.endMien ?? 'Miền Bắc';
  int get startIdxTatCa => _cachedPlanTatCa?.startMienIndex ?? 0;

  DateTime? get sheetHeaderDateTime {
    if (_sheetHeaderDate.isEmpty) return null;
    try {
      return DateFormat('dd/MM/yyyy').parse(_sheetHeaderDate);
    } catch (e) {
      return null;
    }
  }

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
    if (useCache) {
      _isLoading = true;
    }

    _errorMessage = null;
    if (!useCache) {
      _cachedPlanTatCa = null;
      _cachedPlanNam = null;
      _cachedPlanTrung = null;
      _cachedPlanBac = null;
      _cachedPlanXien = null;
      // Thông báo UI cập nhật ngay lập tức để hiện trạng thái "Đang tính"
      notifyListeners();
    } else {
      notifyListeners();
    }

    try {
      // 1. Init
      var config = await _storageService.loadConfig();
      if (config == null) {
        config = AppConfig.defaultConfig();
        await _storageService.saveConfig(config);
      }
      await _sheetsService.initialize(config.googleSheets);

      // 2. Đọc Cache từ Sheet
      bool cacheHit = false;
      if (useCache) {
        try {
          print('🔍 [AnalysisViewModel] Đang đọc Cache từ analysis...');
          final cacheJson = await _sheetsService.getAnalysisCache();

          if (cacheJson != null && cacheJson.trim().isNotEmpty) {
            final cacheData = jsonDecode(cacheJson);

            if (cacheData['date'] != null) _sheetHeaderDate = cacheData['date'];
            if (cacheData['region'] != null)
              _sheetHeaderRegion = cacheData['region'];

            print('✅ Cache HIT! Đang áp dụng dữ liệu Summary...');
            _applyCacheData(cacheData);
            cacheHit = true;
          }
        } catch (e) {
          print('⚠️ Lỗi đọc/parse cache: $e. Sẽ tính toán lại...');
        }
      }

      // 3. Load KQXS nền
      if (_allResults.isEmpty) {
        _allResults = await _cachedDataService.loadKQXS(
          forceRefresh: !useCache,
          incrementalOnly: useCache,
        );
      }

      // 4. Load Sheet Data
      final rawData = await _sheetsService.getAnalysisCycleData();
      if (rawData.isEmpty) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      if (rawData.isNotEmpty) {
        final headerRow = rawData[0];
        if (headerRow.length > 3) {
          _sheetHeaderDate = headerRow[1];
          _sheetHeaderRegion = headerRow[3];
        }
      }

      _parseRawDataToResults(rawData);
      _updateCurrentCycleResult();

      // 5. Nếu có cache, DỪNG TẠI ĐÂY
      if (cacheHit) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      // 6. KHÔNG CÓ CACHE: TÍNH TOÁN LẠI
      _isLoading = false;
      notifyListeners();

      // Tính toán tuần tự cho từng miền
      final tatCaResult = _findResultByMien('Tất cả');
      if (tatCaResult != null) {
        await _calculateAndCachePlan('Tất cả', tatCaResult, config);
        notifyListeners();
      }

      if (_ganPairInfo != null) {
        await _calculateAndCacheXienPlan(config);
        notifyListeners();
      }

      final regions = ['Nam', 'Trung', 'Bắc'];
      for (var region in regions) {
        final res = _findResultByMien(region);
        if (res != null) {
          await _calculateAndCachePlan(region, res, config);
          notifyListeners();
        }
      }

      // Save Cache
      await _saveCurrentStateToCache();
    } catch (e) {
      _errorMessage = 'Lỗi tải dữ liệu: $e';
      print('❌ Fatal Error: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  // ✅ HÀM TÍNH TOÁN CHUNG (Core Logic)
  // Được dùng bởi cả loadAnalysis() và createBettingTable()
  Future<RegionPlanResult> _calculateRegionPlan({
    required String mienName,
    required CycleAnalysisResult result,
    required AppConfig config,
  }) async {
    final type = _mapMienToEnum(mienName);
    final thresholdLn = _getThresholdForMien(mienName, config);

    // BƯỚC 1: Tính End Date
    DateTime? endDate;
    String endMien = _getEndRegionName(mienName);
    int daysNeeded = 0;

    final analysisData = await AnalysisService.getAnalysisData(
      result.targetNumber,
      _allResults,
      mienName,
    );

    if (analysisData != null) {
      final simResult = await AnalysisService.findEndDateForCycleThreshold(
        analysisData,
        0.01,
        _allResults,
        thresholdLn,
        mien: mienName,
      );

      if (simResult != null) {
        endDate = simResult.endDate;
        endMien = simResult.endMien;
        daysNeeded = simResult.daysNeeded;
      }
    }

    // Fallback nếu không tính được
    if (endDate == null) {
      print(
          '⚠️ [_calculateRegionPlan] Không tính được End Date cho $mienName, dùng +7 ngày');
      DateTime startFallback = DateFormat('dd/MM/yyyy')
          .parse(_sheetHeaderDate)
          .add(const Duration(days: 1));
      endDate = startFallback.add(const Duration(days: 7));
      daysNeeded = 7;
    }

    // BƯỚC 2: Tính Budget & Optimal Start Date
    DateTime startDate = DateFormat('dd/MM/yyyy')
        .parse(_sheetHeaderDate)
        .add(const Duration(days: 1));
    int startMienIndex = 0;
    String? budgetError;

    try {
      final budgetResult = await BudgetCalculationService(
        sheetsService: _sheetsService,
      ).calculateAvailableBudgetByEndDate(
        totalCapital: config.budget.totalCapital,
        targetTable: type.budgetTableName,
        configBudget: type.getBudgetConfig(config),
        endDate: endDate,
        endMien: endMien,
      );

      print(
          '🐛 [_calculateRegionPlan $mienName] End: ${DateFormat('dd/MM').format(endDate)} | Budget: ${budgetResult.budgetMax}');

      final optimalResult = await AnalysisService.findOptimalStartDateForCycle(
        baseStartDate: startDate,
        endDate: endDate,
        endMien: endMien,
        availableBudget: budgetResult.budgetMax,
        budgetMin: budgetResult.budgetMax * 0.77,
        mien: type == BettingTableTypeEnum.tatca ? 'Tất cả' : type.displayName,
        targetNumber: result.targetNumber,
        cycleResult: result,
        allResults: _allResults,
        bettingService: _bettingService,
        maxMienCount: type == BettingTableTypeEnum.tatca
            ? endDate.difference(startDate).inDays
            : 0,
      );

      if (optimalResult != null) {
        startDate = optimalResult.date;
        startMienIndex = optimalResult.mienIndex;
      } else {
        budgetError = "⚠️ Thiếu vốn";
      }
    } catch (e) {
      if (e is BudgetInsufficientException) {
        budgetError = "⚠️ Thiếu vốn";
      }
    }

    return RegionPlanResult(
      startDate: startDate,
      endDate: endDate,
      endMien: endMien,
      startMienIndex: startMienIndex,
      daysNeeded: daysNeeded,
      hasBudgetError: budgetError != null,
      budgetErrorMessage: budgetError,
    );
  }

  // ✅ Wrapper cho loadAnalysis(): Tính toán + Cache vào State
  Future<void> _calculateAndCachePlan(
    String mienName,
    CycleAnalysisResult result,
    AppConfig config,
  ) async {
    final plan = await _calculateRegionPlan(
      mienName: mienName,
      result: result,
      config: config,
    );

    // Cache vào state tương ứng
    final normalized = mienName.toLowerCase();
    if (normalized.contains('nam')) {
      _cachedPlanNam = plan;
    } else if (normalized.contains('trung')) {
      _cachedPlanTrung = plan;
    } else if (normalized.contains('bắc')) {
      _cachedPlanBac = plan;
    } else {
      _cachedPlanTatCa = plan;
    }
  }

  // ✅ Tương tự cho Xiên
  Future<void> _calculateAndCacheXienPlan(AppConfig config) async {
    if (_ganPairInfo == null) return;

    try {
      final thresholdLn = config.probability.thresholdLnXien;
      final pairAnalysis =
          await AnalysisService.findPairWithMinPTotal(_allResults);

      if (pairAnalysis == null) {
        _cachedPlanXien = null;
        return;
      }

      final simResult = await AnalysisService.findEndDateForXienThreshold(
        pairAnalysis,
        0.055,
        thresholdLn,
      );

      DateTime start = DateFormat('dd/MM/yyyy')
          .parse(_sheetHeaderDate)
          .add(const Duration(days: 1));
      String? xienError;

      if (simResult != null) {
        final endDate = simResult.endDate;

        try {
          final budgetRes = await BudgetCalculationService(
            sheetsService: _sheetsService,
          ).calculateAvailableBudgetByEndDate(
            totalCapital: config.budget.totalCapital,
            targetTable: 'xien',
            configBudget: config.budget.xienBudget,
            endDate: endDate,
            endMien: 'Miền Bắc',
          );

          final optimalStart =
              await AnalysisService.findOptimalStartDateForXien(
            baseStartDate: start,
            endDate: endDate,
            availableBudget: budgetRes.budgetMax,
            ganInfo: _ganPairInfo!,
            bettingService: _bettingService,
          );

          if (optimalStart != null) start = optimalStart;
        } catch (e) {
          if (e is BudgetInsufficientException) xienError = "⚠️ Thiếu vốn";
        }

        _cachedPlanXien = RegionPlanResult(
          startDate: start,
          endDate: endDate,
          endMien: 'Miền Bắc',
          startMienIndex: 2,
          daysNeeded: simResult.daysNeeded,
          hasBudgetError: xienError != null,
          budgetErrorMessage: xienError,
        );
      }
    } catch (e) {
      _cachedPlanXien = null;
    }
  }

  // ✅ Wrapper cho createBettingTable(): Sử dụng cache hoặc tính mới
  Future<BettingTableParams> _prepareFarmingParams({
    required String mien,
    required AppConfig config,
    required String targetNumber,
  }) async {
    final type = _mapMienToEnum(mien);

    // Lấy cache tương ứng
    RegionPlanResult? cachedPlan;
    switch (type) {
      case BettingTableTypeEnum.tatca:
        cachedPlan = _cachedPlanTatCa;
        break;
      case BettingTableTypeEnum.nam:
        cachedPlan = _cachedPlanNam;
        break;
      case BettingTableTypeEnum.trung:
        cachedPlan = _cachedPlanTrung;
        break;
      case BettingTableTypeEnum.bac:
        cachedPlan = _cachedPlanBac;
        break;
    }

    // Nếu có cache và hợp lệ -> Dùng luôn
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (cachedPlan != null &&
        !cachedPlan.hasBudgetError &&
        cachedPlan.startDate.isAfter(today)) {
      print('✅ [_prepareFarmingParams] Dùng cache cho $mien');

      return BettingTableParams(
        type: type,
        targetNumber: targetNumber,
        startDate: cachedPlan.startDate,
        endDate: cachedPlan.endDate,
        endMien: cachedPlan.endMien,
        startMienIndex: cachedPlan.startMienIndex,
        durationLimit:
            cachedPlan.endDate.difference(cachedPlan.startDate).inDays,
        soNgayGan: _cycleResult?.maxGanDays ?? 0,
        cycleResult: _cycleResult!,
        allResults: _allResults,
      );
    }

    // Không có cache hợp lệ -> Tính mới
    print(
        '⚠️ [_prepareFarmingParams] Cache không hợp lệ, tính toán lại cho $mien');

    final freshPlan = await _calculateRegionPlan(
      mienName: mien,
      result: _cycleResult!,
      config: config,
    );

    // Cập nhật cache luôn
    switch (type) {
      case BettingTableTypeEnum.tatca:
        _cachedPlanTatCa = freshPlan;
        break;
      case BettingTableTypeEnum.nam:
        _cachedPlanNam = freshPlan;
        break;
      case BettingTableTypeEnum.trung:
        _cachedPlanTrung = freshPlan;
        break;
      case BettingTableTypeEnum.bac:
        _cachedPlanBac = freshPlan;
        break;
    }
    notifyListeners();

    return BettingTableParams(
      type: type,
      targetNumber: targetNumber,
      startDate: freshPlan.startDate,
      endDate: freshPlan.endDate,
      endMien: freshPlan.endMien,
      startMienIndex: freshPlan.startMienIndex,
      durationLimit: freshPlan.endDate.difference(freshPlan.startDate).inDays,
      soNgayGan: _cycleResult?.maxGanDays ?? 0,
      cycleResult: _cycleResult!,
      allResults: _allResults,
    );
  }

  // ✅ CREATE TABLE METHODS (Giữ nguyên nhưng dùng _prepareFarmingParams mới)
  Future<void> createCycleBettingTable(
      String number, AppConfig uiConfig) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final config = await _storageService.loadConfig() ?? uiConfig;
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

  Future<void> createNamGanBettingTable(
      String number, AppConfig uiConfig) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final config = await _storageService.loadConfig() ?? uiConfig;
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
      String number, AppConfig uiConfig) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final config = await _storageService.loadConfig() ?? uiConfig;
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

  Future<void> createBacGanBettingTable(
      String number, AppConfig uiConfig) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final config = await _storageService.loadConfig() ?? uiConfig;
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

  Future<void> _createBettingTableGeneric(
    BettingTableParams params,
    AppConfig config,
  ) async {
    try {
      await _sheetsService.clearSheet(params.type.sheetName);

      final budgetService =
          BudgetCalculationService(sheetsService: _sheetsService);
      final budgetResult =
          await budgetService.calculateAvailableBudgetByEndDate(
        totalCapital: config.budget.totalCapital,
        targetTable: params.type.budgetTableName,
        configBudget: params.type.getBudgetConfig(config),
        endDate: params.endDate,
        endMien: params.endMien,
      );

      final table = await params.type.generateTable(
        service: _bettingService,
        result: params.cycleResult,
        start: params.startDate,
        end: params.endDate,
        endMien: params.endMien,
        startIdx: params.startMienIndex,
        min: budgetResult.budgetMax * 0.77,
        max: budgetResult.budgetMax,
        results: params.allResults,
        maxCount: params.type == BettingTableTypeEnum.tatca
            ? params.durationLimit
            : 0,
        durationLimit: params.endDate.difference(params.startDate).inDays,
      );

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

  Future<void> createXienBettingTable() async {
    if (_ganPairInfo == null || _cachedPlanXien == null) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      var config = await _storageService.loadConfig();
      config ??= AppConfig.defaultConfig();

      final budgetRes = await BudgetCalculationService(
        sheetsService: _sheetsService,
      ).calculateAvailableBudgetByEndDate(
        totalCapital: config.budget.totalCapital,
        targetTable: 'xien',
        configBudget: config.budget.xienBudget,
        endDate: _cachedPlanXien!.endDate,
        endMien: 'Miền Bắc',
      );

      final table = await _bettingService.generateXienTable(
        ganInfo: _ganPairInfo!,
        startDate: _cachedPlanXien!.startDate,
        xienBudget: budgetRes.budgetMax,
        endDate: _cachedPlanXien!.endDate,
      );

      await _saveXienTable(table);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- HELPER METHODS (Giữ nguyên) ---

  void _parseRawDataToResults(List<List<String>> rawData) {
    _cachedSheetResults.clear();
    _ganPairInfo = null;

    for (int i = 1; i < rawData.length; i++) {
      try {
        final row = rawData[i];
        if (row.isEmpty) continue;
        final rawMien = row[0];
        final mienKey = rawMien.trim().toLowerCase();

        if (mienKey.contains('miền xét') || mienKey.contains('mien xet'))
          continue;

        if (mienKey.contains('xiên') || mienKey.contains('xien')) {
          if (_ganPairInfo == null) {
            _parseXienRowOnly(row);
          }
          continue;
        }

        final result = _parseRowToResult(row);
        _cachedSheetResults.add(result);
      } catch (e) {
        print('Error parsing row $i: $e');
      }
    }
  }

  void _parseXienRowOnly(List<String> row) {
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
        lastSeen: lastSeen,
      );

      _ganPairInfo = GanPairInfo(
        pairs: [pairObj],
        daysGan: ganCurDays,
        lastSeen: lastSeen,
      );
    } catch (e) {
      print('Error parsing xien row: $e');
    }
  }

  CycleAnalysisResult? _findResultByMien(String key) {
    try {
      return _cachedSheetResults.firstWhere((e) =>
          e.mienGroups.keys.first.toLowerCase().contains(key.toLowerCase()));
    } catch (e) {
      return null;
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

  void _updateCurrentCycleResult() {
    String searchKey = switch (_selectedMien) {
      'Tất cả' => 'Tất cả',
      'Nam' => 'Nam',
      'Trung' => 'Trung',
      'Bắc' => 'Bắc',
      _ => 'Tất cả',
    };

    try {
      _cycleResult = _cachedSheetResults.firstWhere((e) => e
          .mienGroups.keys.first
          .toLowerCase()
          .contains(searchKey.toLowerCase()));
    } catch (e) {
      _cycleResult = null;
    }
  }

  double _getThresholdForMien(String mien, AppConfig config) {
    final normalized = mien.toLowerCase();
    if (normalized.contains('nam')) {
      return config.probability.thresholdLnNam;
    } else if (normalized.contains('trung')) {
      return config.probability.thresholdLnTrung;
    } else if (normalized.contains('bắc') || normalized.contains('bac')) {
      return config.probability.thresholdLnBac;
    } else {
      return config.probability.thresholdLnTatCa;
    }
  }

  String _getEndRegionName(String mienName) {
    final normalized = mienName.toLowerCase();
    if (normalized.contains('nam')) return 'Miền Nam';
    if (normalized.contains('trung')) return 'Miền Trung';
    if (normalized.contains('bắc') || normalized.contains('bac'))
      return 'Miền Bắc';
    return 'Miền Bắc';
  }

  BettingTableTypeEnum _mapMienToEnum(String mien) {
    final normalized = mien.toLowerCase().trim();
    return switch (normalized) {
      'tất cả' || 'tatca' || 'all' => BettingTableTypeEnum.tatca,
      'nam' => BettingTableTypeEnum.nam,
      'trung' => BettingTableTypeEnum.trung,
      'bắc' || 'bac' => BettingTableTypeEnum.bac,
      _ => throw Exception('Miền không hợp lệ: $mien'),
    };
  }

  void _applyCacheData(Map<String, dynamic> cache) {
    final plans = cache['plans'] ?? {};

    void apply(String key, Function(RegionPlanResult) setFunc) {
      if (plans[key] != null) {
        final item = plans[key];
        try {
          final plan = RegionPlanResult(
            startDate: DateTime.parse(item['dStart']),
            endDate: DateTime.parse(item['dEnd']),
            endMien: item['endMien'] ?? 'Miền Bắc',
            startMienIndex: item['startIdx'] ?? 0,
            daysNeeded: item['daysNeeded'] ?? 0,
            hasBudgetError: item['hasBudgetError'] ?? false,
            budgetErrorMessage: item['budgetError'],
          );
          setFunc(plan);
        } catch (e) {
          print('Error parsing cached plan for $key: $e');
        }
      }
    }

    apply('tatca', (p) => _cachedPlanTatCa = p);
    apply('nam', (p) => _cachedPlanNam = p);
    apply('trung', (p) => _cachedPlanTrung = p);
    apply('bac', (p) => _cachedPlanBac = p);
    apply('xien', (p) => _cachedPlanXien = p);
  }

  Future<void> _saveCurrentStateToCache() async {
    try {
      Map<String, dynamic> toPlan(RegionPlanResult? p) {
        if (p == null) return {};
        return {
          'dStart': p.startDate.toIso8601String(),
          'dEnd': p.endDate.toIso8601String(),
          'endMien': p.endMien,
          'startIdx': p.startMienIndex,
          'daysNeeded': p.daysNeeded,
          'hasBudgetError': p.hasBudgetError,
          'budgetError': p.budgetErrorMessage,
        };
      }

      final cacheData = {
        "date": _sheetHeaderDate,
        "region": _sheetHeaderRegion,
        "plans": {
          "tatca": toPlan(_cachedPlanTatCa),
          "nam": toPlan(_cachedPlanNam),
          "trung": toPlan(_cachedPlanTrung),
          "bac": toPlan(_cachedPlanBac),
          "xien": toPlan(_cachedPlanXien),
        }
      };

      await _sheetsService.saveAnalysisCache(jsonEncode(cacheData));
      print('💾 Cache saved to Sheet successfully.');
    } catch (e) {
      print('❌ Failed to save cache: $e');
    }
  }

  Future<void> _saveTableToSheet(
    BettingTableTypeEnum type,
    List<BettingRow> table,
    CycleAnalysisResult result,
  ) async {
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

    // Hiển thị plan tương ứng
    RegionPlanResult? plan = switch (_selectedMien) {
      'Tất cả' => _cachedPlanTatCa,
      'Nam' => _cachedPlanNam,
      'Trung' => _cachedPlanTrung,
      'Bắc' => _cachedPlanBac,
      _ => null,
    };

    if (plan != null && !plan.hasBudgetError) {
      buffer.writeln('<b>Kế hoạch:</b>');
      buffer.writeln(plan.formatStartInfo());
      buffer.writeln('${plan.formatEndInfo()}\n');
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

    if (_cachedPlanXien != null && !_cachedPlanXien!.hasBudgetError) {
      buffer.writeln('\n<b>Kế hoạch:</b>');
      buffer.writeln(_cachedPlanXien!.formatStartInfo());
      buffer.writeln(_cachedPlanXien!.formatEndInfo());
    }

    return buffer.toString();
  }

  Future<NumberDetail?> analyzeNumberDetail(String number) async {
    return await _analysisService.analyzeNumberDetail(_allResults, number);
  }
}
