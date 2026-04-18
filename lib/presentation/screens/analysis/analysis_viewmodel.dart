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

// --- MODEL ---
class RegionPlanResult {
  final DateTime startDate;
  final DateTime endDate;
  final String endMien;
  final int startMienIndex;
  final int daysNeeded;
  final bool hasBudgetError;
  final String? budgetErrorMessage;
  final double? loi1So;

  RegionPlanResult({
    required this.startDate,
    required this.endDate,
    required this.endMien,
    required this.startMienIndex,
    required this.daysNeeded,
    this.hasBudgetError = false,
    this.budgetErrorMessage,
    this.loi1So,
  });

  String formatStartInfo() {
    if (hasBudgetError) return "⚠️ Thiếu vốn";
    final region = switch (startMienIndex) {
      0 => 'Miền Nam',
      1 => 'Miền Trung',
      2 => 'Miền Bắc',
      _ => 'Miền Nam',
    };
    String result = "${date_utils.DateUtils.formatDate(startDate)} ($region)";
    if (daysNeeded > 60) result += " (>60 ngày)";
    return result;
  }

  String formatEndInfo() {
    if (hasBudgetError) return "❌ Vốn không đủ";
    return "🏁 Kết thúc: ${date_utils.DateUtils.formatDate(endDate)} ($endMien)";
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
    required this.cycleResult,
    required this.allResults,
  });
}

// --- VIEW MODEL ---
class AnalysisViewModel extends ChangeNotifier {
  final CachedDataService _cachedDataService;
  final GoogleSheetsService _sheetsService;
  final StorageService _storageService;
  final TelegramService _telegramService;
  final BettingTableService _bettingService;

  AnalysisViewModel({
    required CachedDataService cachedDataService,
    required GoogleSheetsService sheetsService,
    required StorageService storageService,
    required TelegramService telegramService,
    required BettingTableService bettingService,
  })  : _cachedDataService = cachedDataService,
        _sheetsService = sheetsService,
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
  final List<CycleAnalysisResult> _cachedSheetResults = [];

  String _sheetHeaderDate = "";
  String _sheetHeaderRegion = "";

  RegionPlanResult? _cachedPlanTatCa;
  RegionPlanResult? _cachedPlanNam;
  RegionPlanResult? _cachedPlanTrung;
  RegionPlanResult? _cachedPlanBac;
  RegionPlanResult? _cachedPlanXien;

  // --- GETTERS ---
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  GanPairInfo? get ganPairInfo => _ganPairInfo;
  CycleAnalysisResult? get cycleResult => _cycleResult;
  String get selectedMien => _selectedMien;

  String get optimalTatCa =>
      _cachedPlanTatCa?.formatStartInfo() ?? "Đang tính ...";
  String get optimalNam => _cachedPlanNam?.formatStartInfo() ?? "Đang tính ...";
  String get optimalTrung =>
      _cachedPlanTrung?.formatStartInfo() ?? "Đang tính ...";
  String get optimalBac => _cachedPlanBac?.formatStartInfo() ?? "Đang tính ...";
  String get optimalXien =>
      _cachedPlanXien?.formatStartInfo() ?? "Đang tính ...";

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

  /// Lời 1 số theo miền đang chọn — đọc từ cache, không tính lại
  double? get loi1SoForSelectedMien => switch (_selectedMien) {
        'Nam' => _cachedPlanNam?.loi1So,
        'Trung' => _cachedPlanTrung?.loi1So,
        'Bắc' => _cachedPlanBac?.loi1So,
        _ => _cachedPlanTatCa?.loi1So,
      };

  DateTime? get sheetHeaderDateTime {
    if (_sheetHeaderDate.isEmpty) return null;
    try {
      return DateFormat('dd/MM/yyyy').parse(_sheetHeaderDate);
    } catch (_) {
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

  Future<void> loadAnalysis({bool useCache = true}) async {
    _isLoading = useCache;
    _errorMessage = null;

    if (!useCache) {
      _cachedPlanTatCa = null;
      _cachedPlanNam = null;
      _cachedPlanTrung = null;
      _cachedPlanBac = null;
      _cachedPlanXien = null;
    }
    notifyListeners();

    try {
      // 1. Init config
      var config =
          await _storageService.loadConfig() ?? AppConfig.defaultConfig();
      await _storageService.saveConfig(config);
      await _sheetsService.initialize(config.googleSheets);

      // 2. Thử đọc cache từ Sheet
      bool cacheHit = false;
      if (useCache) {
        try {
          final cacheJson = await _sheetsService.getAnalysisCache();
          if (cacheJson != null && cacheJson.trim().isNotEmpty) {
            final cacheData = jsonDecode(cacheJson);
            if (cacheData['date'] != null) _sheetHeaderDate = cacheData['date'];
            if (cacheData['region'] != null)
              _sheetHeaderRegion = cacheData['region'];
            _applyCacheData(cacheData);
            cacheHit = true;
            print('✅ Cache HIT!');
          }
        } catch (e) {
          print('⚠️ Lỗi đọc cache: $e');
        }
      }

      // 3. Load KQXS (nền)
      if (_allResults.isEmpty) {
        _allResults = await _cachedDataService.loadKQXS(
          forceRefresh: !useCache,
          incrementalOnly: useCache,
        );
      }

      // 4. Load dữ liệu phân tích từ Sheet
      final rawData = await _sheetsService.getAnalysisCycleData();
      if (rawData.isEmpty) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      final headerRow = rawData[0];
      if (headerRow.length > 3) {
        _sheetHeaderDate = headerRow[1];
        _sheetHeaderRegion = headerRow[3];
      }

      _parseRawDataToResults(rawData);
      _updateCurrentCycleResult();

      if (cacheHit) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      // 5. Không có cache → tính toán
      _isLoading = false;
      notifyListeners();

      for (final mien in ['Tất cả', 'Nam', 'Trung', 'Bắc']) {
        final res = _findResultByMien(mien);
        if (res != null) {
          await _calculateAndCachePlan(mien, res, config);
          notifyListeners();
        }
      }

      if (_ganPairInfo != null) {
        await _calculateAndCacheXienPlan(config);
        notifyListeners();
      }

      await _saveCurrentStateToCache();
    } catch (e) {
      _errorMessage = 'Lỗi tải dữ liệu: $e';
      print('❌ Fatal Error: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- TÍNH TOÁN PLAN (bao gồm loi1So) ---

  Future<RegionPlanResult> _calculateRegionPlan({
    required String mienName,
    required CycleAnalysisResult result,
    required AppConfig config,
  }) async {
    final type = _mapMienToEnum(mienName);
    final thresholdLn = _getThresholdForMien(mienName, config);

    // Bước 1: Tính End Date
    DateTime endDate;
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
      } else {
        endDate = _fallbackEndDate();
        daysNeeded = 7;
      }
    } else {
      endDate = _fallbackEndDate();
      daysNeeded = 7;
    }

    // Bước 2: Budget & Optimal Start
    DateTime startDate = _defaultStartDate();
    int startMienIndex = 0;
    String? budgetError;
    double? loi1So;

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

        // Bước 3: Tính loi1So bằng preview bảng
        try {
          final preview = await type.generateTable(
            service: _bettingService,
            result: result,
            start: startDate,
            end: endDate,
            endMien: endMien,
            startIdx: startMienIndex,
            min: budgetResult.budgetMax * 0.77,
            max: budgetResult.budgetMax,
            results: _allResults,
            maxCount: type == BettingTableTypeEnum.tatca
                ? endDate.difference(startDate).inDays
                : 0,
            durationLimit: endDate.difference(startDate).inDays,
          );
          if (preview.isNotEmpty) {
            loi1So = preview.last.loi1So;
            print('💰 [$mienName] Lời 1 số: ${loi1So.toStringAsFixed(0)}');
          }
        } catch (e) {
          print('⚠️ Không tính được loi1So cho $mienName: $e');
        }
      } else {
        budgetError = "⚠️ Thiếu vốn";
      }
    } catch (e) {
      if (e is BudgetInsufficientException) budgetError = "⚠️ Thiếu vốn";
    }

    return RegionPlanResult(
      startDate: startDate,
      endDate: endDate,
      endMien: endMien,
      startMienIndex: startMienIndex,
      daysNeeded: daysNeeded,
      hasBudgetError: budgetError != null,
      budgetErrorMessage: budgetError,
      loi1So: loi1So,
    );
  }

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
    _setPlan(mienName, plan);
  }

  Future<void> _calculateAndCacheXienPlan(AppConfig config) async {
    if (_ganPairInfo == null) return;

    try {
      final pairAnalysis =
          await AnalysisService.findPairWithMinPTotal(_allResults);
      if (pairAnalysis == null) {
        _cachedPlanXien = null;
        return;
      }

      final simResult = await AnalysisService.findEndDateForXienThreshold(
        pairAnalysis,
        0.055,
        config.probability.thresholdLnXien,
      );
      if (simResult == null) {
        _cachedPlanXien = null;
        return;
      }

      final endDate = simResult.endDate;
      DateTime start = _defaultStartDate();
      String? xienError;
      double? loi1So;

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

        final optimalStart = await AnalysisService.findOptimalStartDateForXien(
          baseStartDate: start,
          endDate: endDate,
          availableBudget: budgetRes.budgetMax,
          ganInfo: _ganPairInfo!,
          bettingService: _bettingService,
        );

        if (optimalStart != null) {
          start = optimalStart;
          try {
            final preview = await _bettingService.generateXienTable(
              ganInfo: _ganPairInfo!,
              startDate: start,
              xienBudget: budgetRes.budgetMax,
              endDate: endDate,
            );
            if (preview.isNotEmpty) {
              loi1So = preview.last.loi1So;
              print('💰 [Xiên] Lời 1 cặp: ${loi1So.toStringAsFixed(0)}');
            }
          } catch (e) {
            print('⚠️ Không tính được loi1So Xiên: $e');
          }
        }
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
        loi1So: loi1So,
      );
    } catch (e) {
      _cachedPlanXien = null;
    }
  }

  // --- TẠO BẢNG CƯỢC ---

  Future<BettingTableParams> _prepareFarmingParams({
    required String mien,
    required AppConfig config,
    required String targetNumber,
  }) async {
    final type = _mapMienToEnum(mien);
    final cachedPlan = _getPlan(type);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (cachedPlan != null &&
        !cachedPlan.hasBudgetError &&
        cachedPlan.startDate.isAfter(today)) {
      print('✅ Dùng cache cho $mien');
      return _buildParams(type, targetNumber, cachedPlan);
    }

    print('⚠️ Tính toán lại cho $mien');
    final freshPlan = await _calculateRegionPlan(
      mienName: mien,
      result: _cycleResult!,
      config: config,
    );
    _setPlan(mien, freshPlan);
    notifyListeners();
    return _buildParams(type, targetNumber, freshPlan);
  }

  BettingTableParams _buildParams(
    BettingTableTypeEnum type,
    String targetNumber,
    RegionPlanResult plan,
  ) {
    return BettingTableParams(
      type: type,
      targetNumber: targetNumber,
      startDate: plan.startDate,
      endDate: plan.endDate,
      endMien: plan.endMien,
      startMienIndex: plan.startMienIndex,
      durationLimit: plan.endDate.difference(plan.startDate).inDays,
      cycleResult: _cycleResult!,
      allResults: _allResults,
    );
  }

  Future<void> createCycleBettingTable(
          String number, AppConfig uiConfig) async =>
      _createWithMien('Tất cả', number, uiConfig);

  Future<void> createNamGanBettingTable(
          String number, AppConfig uiConfig) async =>
      _createWithMien('Nam', number, uiConfig);

  Future<void> createTrungGanBettingTable(
          String number, AppConfig uiConfig) async =>
      _createWithMien('Trung', number, uiConfig);

  Future<void> createBacGanBettingTable(
          String number, AppConfig uiConfig) async =>
      _createWithMien('Bắc', number, uiConfig);

  Future<void> _createWithMien(
      String mien, String number, AppConfig uiConfig) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final config = await _storageService.loadConfig() ?? uiConfig;
      final params = await _prepareFarmingParams(
        mien: mien,
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

      final budgetResult = await BudgetCalculationService(
        sheetsService: _sheetsService,
      ).calculateAvailableBudgetByEndDate(
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
        durationLimit: params.durationLimit,
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
      var config =
          await _storageService.loadConfig() ?? AppConfig.defaultConfig();

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

  // --- PARSE / UPDATE ---

  void _parseRawDataToResults(List<List<String>> rawData) {
    _cachedSheetResults.clear();
    _ganPairInfo = null;

    for (int i = 1; i < rawData.length; i++) {
      try {
        final row = rawData[i];
        if (row.isEmpty) continue;
        final mienKey = row[0].trim().toLowerCase();

        if (mienKey.contains('miền xét') || mienKey.contains('mien xet'))
          continue;

        if (mienKey.contains('xiên') || mienKey.contains('xien')) {
          if (_ganPairInfo == null) _parseXienRowOnly(row);
          continue;
        }

        _cachedSheetResults.add(_parseRowToResult(row));
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
      final first = parts.isNotEmpty ? parts[0] : '00';
      final second = parts.length > 1 ? parts[1] : '00';

      _ganPairInfo = GanPairInfo(
        pairs: [
          PairWithDays(
            pair: NumberPair(first, second),
            daysGan: ganCurDays,
            lastSeen: lastSeen,
          )
        ],
        daysGan: ganCurDays,
        lastSeen: lastSeen,
      );
    } catch (e) {
      print('Error parsing xien row: $e');
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
      } catch (_) {
        return DateTime.now();
      }
    }

    final mien = getVal(0);
    final targetNumber = getVal(1);
    final ganCurDays = parseInt(getVal(4));
    final lastSeen = parseDate(getVal(5));
    final ganPrevDays = parseInt(getVal(7));
    final ganPrevPrevDays = parseInt(getVal(9));

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
      historicalGan:
          ganPrevDays > ganPrevPrevDays ? ganPrevDays : ganPrevPrevDays,
    );
  }

  void _updateCurrentCycleResult() {
    try {
      _cycleResult = _cachedSheetResults.firstWhere((e) => e
          .mienGroups.keys.first
          .toLowerCase()
          .contains(_selectedMien.toLowerCase()));
    } catch (_) {
      _cycleResult = null;
    }
  }

  CycleAnalysisResult? _findResultByMien(String key) {
    try {
      return _cachedSheetResults.firstWhere((e) =>
          e.mienGroups.keys.first.toLowerCase().contains(key.toLowerCase()));
    } catch (_) {
      return null;
    }
  }

  // --- HELPERS ---

  DateTime _defaultStartDate() => DateFormat('dd/MM/yyyy')
      .parse(_sheetHeaderDate)
      .add(const Duration(days: 1));

  DateTime _fallbackEndDate() =>
      _defaultStartDate().add(const Duration(days: 7));

  double _getThresholdForMien(String mien, AppConfig config) {
    final n = mien.toLowerCase();
    if (n.contains('nam')) return config.probability.thresholdLnNam;
    if (n.contains('trung')) return config.probability.thresholdLnTrung;
    if (n.contains('bắc') || n.contains('bac'))
      return config.probability.thresholdLnBac;
    return config.probability.thresholdLnTatCa;
  }

  String _getEndRegionName(String mienName) {
    final n = mienName.toLowerCase();
    if (n.contains('nam')) return 'Miền Nam';
    if (n.contains('trung')) return 'Miền Trung';
    return 'Miền Bắc';
  }

  BettingTableTypeEnum _mapMienToEnum(String mien) {
    return switch (mien.toLowerCase().trim()) {
      'tất cả' || 'tatca' || 'all' => BettingTableTypeEnum.tatca,
      'nam' => BettingTableTypeEnum.nam,
      'trung' => BettingTableTypeEnum.trung,
      'bắc' || 'bac' => BettingTableTypeEnum.bac,
      _ => throw Exception('Miền không hợp lệ: $mien'),
    };
  }

  RegionPlanResult? _getPlan(BettingTableTypeEnum type) => switch (type) {
        BettingTableTypeEnum.tatca => _cachedPlanTatCa,
        BettingTableTypeEnum.nam => _cachedPlanNam,
        BettingTableTypeEnum.trung => _cachedPlanTrung,
        BettingTableTypeEnum.bac => _cachedPlanBac,
      };

  void _setPlan(dynamic mienOrType, RegionPlanResult plan) {
    if (mienOrType is BettingTableTypeEnum) {
      switch (mienOrType) {
        case BettingTableTypeEnum.tatca:
          _cachedPlanTatCa = plan;
        case BettingTableTypeEnum.nam:
          _cachedPlanNam = plan;
        case BettingTableTypeEnum.trung:
          _cachedPlanTrung = plan;
        case BettingTableTypeEnum.bac:
          _cachedPlanBac = plan;
      }
    } else {
      final n = (mienOrType as String).toLowerCase();
      if (n.contains('nam'))
        _cachedPlanNam = plan;
      else if (n.contains('trung'))
        _cachedPlanTrung = plan;
      else if (n.contains('bắc') || n.contains('bac'))
        _cachedPlanBac = plan;
      else
        _cachedPlanTatCa = plan;
    }
  }

  // --- CACHE ---

  void _applyCacheData(Map<String, dynamic> cache) {
    final plans = cache['plans'] as Map<String, dynamic>? ?? {};

    RegionPlanResult? parsePlan(dynamic item) {
      if (item == null || (item as Map).isEmpty) return null;
      try {
        return RegionPlanResult(
          startDate: DateTime.parse(item['dStart']),
          endDate: DateTime.parse(item['dEnd']),
          endMien: item['endMien'] ?? 'Miền Bắc',
          startMienIndex: item['startIdx'] ?? 0,
          daysNeeded: item['daysNeeded'] ?? 0,
          hasBudgetError: item['hasBudgetError'] ?? false,
          budgetErrorMessage: item['budgetError'],
          loi1So: (item['loi1So'] as num?)?.toDouble(),
        );
      } catch (e) {
        print('Error parsing cached plan: $e');
        return null;
      }
    }

    _cachedPlanTatCa = parsePlan(plans['tatca']);
    _cachedPlanNam = parsePlan(plans['nam']);
    _cachedPlanTrung = parsePlan(plans['trung']);
    _cachedPlanBac = parsePlan(plans['bac']);
    _cachedPlanXien = parsePlan(plans['xien']);
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
          'loi1So': p.loi1So,
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
      print('💾 Cache saved (bao gồm loi1So).');
    } catch (e) {
      print('❌ Failed to save cache: $e');
    }
  }

  // --- LƯU SHEET ---

  Future<void> _saveTableToSheet(
    BettingTableTypeEnum type,
    List<BettingRow> table,
    CycleAnalysisResult result,
  ) async {
    await _sheetsService.clearSheet(type.sheetName);

    final updates = <String, BatchUpdateData>{
      type.sheetName: BatchUpdateData(
        range: 'A1',
        values: [
          [
            result.maxGanDays.toString(),
            date_utils.DateUtils.formatDate(result.lastSeenDate),
            result.ganNumbersDisplay,
            result.targetNumber,
          ],
          [],
          [
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
          ],
          ...table.map((e) => e.toSheetRow()),
        ],
      ),
    };

    await _sheetsService.batchUpdateRanges(updates);
  }

  Future<void> _saveXienTable(List<BettingRow> table) async {
    await _sheetsService.clearSheet('xienBot');

    final updates = <String, BatchUpdateData>{
      'xienBot': BatchUpdateData(
        range: 'A1',
        values: [
          [
            _ganPairInfo!.daysGan.toString(),
            date_utils.DateUtils.formatDate(_ganPairInfo!.lastSeen),
            _ganPairInfo!.pairsDisplay,
            table.first.so,
          ],
          [],
          ['STT', 'Ngày', 'Miền', 'Số', 'Cược/miền', 'Tổng tiền', 'Lời'],
          ...table.map((e) => e.toSheetRow()),
        ],
      ),
    };

    await _sheetsService.batchUpdateRanges(updates);
  }

  // --- TELEGRAM ---

  Future<void> sendCycleAnalysisToTelegram() async {
    if (_cycleResult == null) return;
    final topic = switch (_selectedMien) {
      'Nam' => TelegramTopic.nam,
      'Trung' => TelegramTopic.trung,
      'Bắc' => TelegramTopic.bac,
      _ => TelegramTopic.cycle,
    };
    await _sendTelegram(_buildCycleMessage(), topic: topic);
  }

  Future<void> sendGanPairAnalysisToTelegram() async {
    if (_ganPairInfo == null) return;
    await _sendTelegram(_buildGanPairMessage(), topic: TelegramTopic.xien);
  }

  Future<void> _sendTelegram(String msg, {TelegramTopic? topic}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _telegramService.sendMessage(msg, topic: topic);
    } catch (e) {
      _errorMessage = 'Lỗi gửi Telegram: $e';
    }
    _isLoading = false;
    notifyListeners();
  }

  String _buildCycleMessage() {
    final plan = switch (_selectedMien) {
      'Nam' => _cachedPlanNam,
      'Trung' => _cachedPlanTrung,
      'Bắc' => _cachedPlanBac,
      _ => _cachedPlanTatCa,
    };
    final title = switch (_selectedMien) {
      'Nam' => '🌴 PHÂN TÍCH CHU KỲ MIỀN NAM 🌴',
      'Trung' => '🔍 PHÂN TÍCH MIỀN TRUNG 🔍',
      'Bắc' => '🎯 PHÂN TÍCH MIỀN BẮC 🎯',
      _ => '📊 PHÂN TÍCH CHU KỲ (TẤT CẢ) 📊',
    };

    final buffer = StringBuffer()
      ..writeln('<b>$title</b>\n')
      ..writeln('<b>Miền:</b> $_selectedMien\n')
      ..writeln('<b>Số ngày gan:</b> ${_cycleResult!.maxGanDays} ngày')
      ..writeln(
          '<b>Lần cuối về:</b> ${date_utils.DateUtils.formatDate(_cycleResult!.lastSeenDate)}')
      ..writeln('<b>Số mục tiêu:</b> ${_cycleResult!.targetNumber}\n');

    if (plan != null && !plan.hasBudgetError) {
      buffer
        ..writeln('<b>Kế hoạch:</b>')
        ..writeln(plan.formatStartInfo())
        ..writeln('${plan.formatEndInfo()}\n');
      if (plan.loi1So != null) {
        buffer.writeln(
            '<b>Lời 1 số dự kiến:</b> ${plan.loi1So!.toStringAsFixed(0)} đ\n');
      }
    }

    buffer.writeln(
        '<b>Nhóm số gan nhất:</b>\n${_cycleResult!.ganNumbersDisplay}\n');
    return buffer.toString();
  }

  String _buildGanPairMessage() {
    final buffer = StringBuffer()..writeln('<b>📈 PHÂN TÍCH CẶP XIÊN 📈</b>\n');

    for (int i = 0; i < _ganPairInfo!.pairs.length && i < 2; i++) {
      final p = _ganPairInfo!.pairs[i];
      buffer.writeln(
          '${i + 1}. Miền Bắc | Cặp <b>${p.display}</b> (${p.daysGan} ngày)');
    }

    buffer
      ..writeln('\n<b>Cặp gan nhất:</b> ${_ganPairInfo!.pairs[0].display}')
      ..writeln('<b>Số ngày gan:</b> ${_ganPairInfo!.daysGan} ngày')
      ..writeln(
          '<b>Lần cuối về:</b> ${date_utils.DateUtils.formatDate(_ganPairInfo!.lastSeen)}');

    if (_cachedPlanXien != null && !_cachedPlanXien!.hasBudgetError) {
      buffer
        ..writeln('\n<b>Kế hoạch:</b>')
        ..writeln(_cachedPlanXien!.formatStartInfo())
        ..writeln(_cachedPlanXien!.formatEndInfo());
      if (_cachedPlanXien!.loi1So != null) {
        buffer.writeln(
            '\n<b>Lời 1 cặp dự kiến:</b> ${_cachedPlanXien!.loi1So!.toStringAsFixed(0)} đ');
      }
    }

    return buffer.toString();
  }
}
