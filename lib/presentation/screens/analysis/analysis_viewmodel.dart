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
  final bool isFromCache; // ✅ Cờ đánh dấu lấy từ Cache

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
    this.isFromCache = false, // Mặc định false
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

  String? _endMienTatCa;
  DateTime? _endDateTatCa;
  DateTime? _endDateNam;
  DateTime? _endDateTrung;
  DateTime? _endDateBac;
  DateTime? _endDateXien;

  int _startIdxTatCa = 0;
  int _startIdxNam = 0;
  int _startIdxTrung = 0;
  int _startIdxBac = 0;

  // Getters
  int get startIdxTatCa => _startIdxTatCa;
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
  String get endMienTatCa => _endMienTatCa ?? 'Miền Bắc';

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

  // ✅ HÀM LOAD CHÍNH (Load cache để tránh tính lại lần đầu)
  Future<void> loadAnalysis({bool useCache = true}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Init
      var config = await _storageService.loadConfig();
      if (config == null) {
        config = AppConfig.defaultConfig();
        await _storageService.saveConfig(config);
      }
      await _sheetsService.initialize(config.googleSheets);

      // ============================================================
      // 🚀 ƯU TIÊN 1: Đọc Cache từ Sheet ngay lập tức
      // ============================================================
      bool cacheHit = false;
      if (useCache) {
        try {
          print('🔍 [AnalysisViewModel] Đang đọc Cache từ analysis...');
          final cacheJson = await _sheetsService.getAnalysisCache();

          if (cacheJson != null && cacheJson.trim().isNotEmpty) {
            final cacheData = jsonDecode(cacheJson);

            // 1. Cập nhật thông tin Header
            if (cacheData['date'] != null) _sheetHeaderDate = cacheData['date'];
            if (cacheData['region'] != null)
              _sheetHeaderRegion = cacheData['region'];

            // 2. Gán dữ liệu (Optimal, StartDate, EndDate...)
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

      // 4. Nếu có cache, DỪNG TẠI ĐÂY (UI hiển thị dữ liệu từ cache)
      if (cacheHit) {
        final rawData = await _sheetsService.getAnalysisCycleData();
        if (rawData.isNotEmpty) {
          _parseRawDataToResults(rawData);
          _updateCurrentCycleResult();
        }

        _isLoading = false;
        notifyListeners();
        return;
      }

      // ============================================================
      // NẾU KHÔNG CÓ CACHE: TÍNH TOÁN LẠI TỪ ĐẦU
      // ============================================================

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

      _resetPlanStates();
      _isLoading = false;
      notifyListeners();

      final tatCaResult = _findResultByMien('Tất cả');
      if (tatCaResult != null) {
        await _calculatePlanForRegion(tatCaResult, 'Tất cả', config);
        notifyListeners();
      }

      if (_ganPairInfo != null) {
        await _calculatePlanForXien(config);
        notifyListeners();
      }

      final regions = ['Nam', 'Trung', 'Bắc'];
      for (var region in regions) {
        final res = _findResultByMien(region);
        if (res != null) {
          await _calculatePlanForRegion(res, region, config);
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
          lastSeen: lastSeen);

      _ganPairInfo = GanPairInfo(
          pairs: [pairObj], daysGan: ganCurDays, lastSeen: lastSeen);
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

  void _resetPlanStates() {
    _optimalTatCa = "Đang tính...";
    _endPlanTatCa = "...";
    _optimalNam = "Đang chờ...";
    _endPlanNam = "...";
    _optimalTrung = "Đang chờ...";
    _endPlanTrung = "...";
    _optimalBac = "Đang chờ...";
    _endPlanBac = "...";
    _optimalXien = "Đang tính...";
    _endPlanXien = "...";
  }

  // ✅ Helper: Lấy Index miền từ chuỗi hiển thị
  int _parseStartIdxFromString(String optimalStr) {
    final lower = optimalStr.toLowerCase();
    if (lower.contains('trung')) return 1;
    if (lower.contains('bắc') || lower.contains('bac')) return 2;
    return 0; // Mặc định Nam
  }

  // ✅ Helper: Lấy Miền kết thúc từ chuỗi hiển thị
  String _parseEndMienFromString(String endStr) {
    final lower = endStr.toLowerCase();
    if (lower.contains('nam')) return 'Miền Nam';
    if (lower.contains('trung')) return 'Miền Trung';
    if (lower.contains('bắc') || lower.contains('bac')) return 'Miền Bắc';
    return 'Miền Bắc'; // Fallback
  }

  // ✅ CẬP NHẬT: Parse Full Info từ Cache
  void _applyCacheData(Map<String, dynamic> cache) {
    final plans = cache['plans'] ?? {};

    void apply(
        String key,
        Function(String opt, String end, DateTime? dStart, DateTime? dEnd,
                int startIdx, String endMien)
            setFunc) {
      if (plans[key] != null) {
        final item = plans[key];
        DateTime? dStart;
        DateTime? dEnd;
        try {
          if (item['dStart'] != null) dStart = DateTime.parse(item['dStart']);
          if (item['dEnd'] != null) dEnd = DateTime.parse(item['dEnd']);
        } catch (e) {
          print('Error parsing date in cache for $key: $e');
        }

        final optimalStr = item['optimal'] ?? "Lỗi cache";
        final endStr = item['end'] ?? "...";

        final startIdx = _parseStartIdxFromString(optimalStr);
        final endMien = _parseEndMienFromString(endStr);

        setFunc(optimalStr, endStr, dStart, dEnd, startIdx, endMien);
      }
    }

    apply('tatca', (o, e, s, d, idx, em) {
      _optimalTatCa = o;
      _endPlanTatCa = e;
      _dateTatCa = s;
      _endDateTatCa = d;
      _startIdxTatCa = idx;
      _endMienTatCa = em;
    });
    apply('nam', (o, e, s, d, idx, em) {
      _optimalNam = o;
      _endPlanNam = e;
      _dateNam = s;
      _endDateNam = d;
      _startIdxNam = idx;
    });
    apply('trung', (o, e, s, d, idx, em) {
      _optimalTrung = o;
      _endPlanTrung = e;
      _dateTrung = s;
      _endDateTrung = d;
      _startIdxTrung = idx;
    });
    apply('bac', (o, e, s, d, idx, em) {
      _optimalBac = o;
      _endPlanBac = e;
      _dateBac = s;
      _endDateBac = d;
      _startIdxBac = idx;
    });
    apply('xien', (o, e, s, d, idx, em) {
      _optimalXien = o;
      _endPlanXien = e;
      _dateXien = s;
      _endDateXien = d;
    });
  }

  Future<void> _saveCurrentStateToCache() async {
    try {
      final cacheData = {
        "date": _sheetHeaderDate,
        "region": _sheetHeaderRegion,
        "plans": {
          "tatca": {
            "optimal": _optimalTatCa,
            "end": _endPlanTatCa,
            "dStart": _dateTatCa?.toIso8601String(),
            "dEnd": _endDateTatCa?.toIso8601String()
          },
          "nam": {
            "optimal": _optimalNam,
            "end": _endPlanNam,
            "dStart": _dateNam?.toIso8601String(),
            "dEnd": _endDateNam?.toIso8601String()
          },
          "trung": {
            "optimal": _optimalTrung,
            "end": _endPlanTrung,
            "dStart": _dateTrung?.toIso8601String(),
            "dEnd": _endDateTrung?.toIso8601String()
          },
          "bac": {
            "optimal": _optimalBac,
            "end": _endPlanBac,
            "dStart": _dateBac?.toIso8601String(),
            "dEnd": _endDateBac?.toIso8601String()
          },
          "xien": {
            "optimal": _optimalXien,
            "end": _endPlanXien,
            "dStart": _dateXien?.toIso8601String(),
            "dEnd": _endDateXien?.toIso8601String()
          },
        }
      };
      await _sheetsService.saveAnalysisCache(jsonEncode(cacheData));
      print('💾 Cache saved to Sheet successfully.');
    } catch (e) {
      print('❌ Failed to save cache: $e');
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

  String _getEndRegionName(String mienName) {
    final normalized = mienName.toLowerCase();
    if (normalized.contains('nam')) return 'Miền Nam';
    if (normalized.contains('trung')) return 'Miền Trung';
    if (normalized.contains('bắc') || normalized.contains('bac')) {
      return 'Miền Bắc';
    }
    return 'Miền Bắc';
  }

  String _getStartRegionName(String mienName, int startMienIndex) {
    final normalized = mienName.toLowerCase();

    if (normalized.contains('nam')) return 'Miền Nam';
    if (normalized.contains('trung')) return 'Miền Trung';
    if (normalized.contains('bắc') || normalized.contains('bac'))
      return 'Miền Bắc';

    return switch (startMienIndex) {
      0 => 'Miền Nam',
      1 => 'Miền Trung',
      2 => 'Miền Bắc',
      _ => 'Miền Nam',
    };
  }

  Future<void> _calculatePlanForRegion(
    CycleAnalysisResult result,
    String mienName,
    AppConfig? config,
  ) async {
    if (config == null || _allResults.isEmpty) return;

    String normalizedMien = mienName.toLowerCase();
    double thresholdLn = _getThresholdForMien(mienName, config);

    final analysisData = await AnalysisService.getAnalysisData(
      result.targetNumber,
      _allResults,
      mienName,
    );

    DateTime? finalEndDate;
    String endMien = _getEndRegionName(mienName);
    int daysNeeded = 0;
    String? budgetErrorStatus;

    if (analysisData != null) {
      final simResult = await AnalysisService.findEndDateForCycleThreshold(
        analysisData,
        0.01,
        _allResults,
        thresholdLn,
        mien: mienName,
      );

      if (simResult != null) {
        finalEndDate = simResult.endDate;
        endMien = simResult.endMien;
        daysNeeded = simResult.daysNeeded;
        if (normalizedMien.contains('tất cả') || normalizedMien == 'tatca') {
          _endMienTatCa = simResult.endMien;
        }
      }
    }

    finalEndDate ??= DateTime.now().add(const Duration(days: 2));

    DateTime startDate = DateFormat('dd/MM/yyyy')
        .parse(_sheetHeaderDate)
        .add(const Duration(days: 1));

    int foundStartIdx = 0;

    try {
      final type = _mapMienToEnum(mienName);
      final budgetResult =
          await BudgetCalculationService(sheetsService: _sheetsService)
              .calculateAvailableBudgetByEndDate(
        totalCapital: config.budget.totalCapital,
        targetTable: type.budgetTableName,
        configBudget: type.getBudgetConfig(config),
        endDate: finalEndDate,
        endMien: endMien,
      );

      final optimalResult = await AnalysisService.findOptimalStartDateForCycle(
        baseStartDate: startDate,
        endDate: finalEndDate,
        endMien: endMien,
        availableBudget: budgetResult.budgetMax,
        budgetMin: budgetResult.budgetMax * 0.66,
        mien: type == BettingTableTypeEnum.tatca ? 'Tất cả' : type.displayName,
        targetNumber: result.targetNumber,
        cycleResult: result,
        allResults: _allResults,
        bettingService: _bettingService,
        maxMienCount: type == BettingTableTypeEnum.tatca
            ? finalEndDate.difference(startDate).inDays
            : 0,
      );

      if (optimalResult != null) {
        startDate = optimalResult.date;
        foundStartIdx = optimalResult.mienIndex;
      } else {
        budgetErrorStatus = "⚠️ Thiếu vốn";
      }
    } catch (e) {
      if (e is BudgetInsufficientException) {
        budgetErrorStatus = "⚠️ Thiếu vốn";
      }
    }

    final startRegionStr = _getStartRegionName(mienName, foundStartIdx);
    String startInfoString = budgetErrorStatus ??
        "${date_utils.DateUtils.formatDate(startDate)} ($startRegionStr)";

    if (budgetErrorStatus == null && daysNeeded > 60) {
      startInfoString += " (⚠️ >60 ngày)";
    }

    String endInfoString = budgetErrorStatus != null
        ? "❌ Vốn không đủ"
        : "🏁 Kết thúc: ${date_utils.DateUtils.formatDate(finalEndDate)} ($endMien)";

    if (normalizedMien.contains('nam')) {
      _dateNam = startDate;
      _startIdxNam = foundStartIdx;
      _endDateNam = finalEndDate;
      _optimalNam = startInfoString;
      _endPlanNam = endInfoString;
    } else if (normalizedMien.contains('trung')) {
      _dateTrung = startDate;
      _startIdxTrung = foundStartIdx;
      _endDateTrung = finalEndDate;
      _optimalTrung = startInfoString;
      _endPlanTrung = endInfoString;
    } else if (normalizedMien.contains('bắc')) {
      _dateBac = startDate;
      _startIdxBac = foundStartIdx;
      _endDateBac = finalEndDate;
      _optimalBac = startInfoString;
      _endPlanBac = endInfoString;
    } else {
      _dateTatCa = startDate;
      _startIdxTatCa = foundStartIdx;
      _endDateTatCa = finalEndDate;
      _optimalTatCa = startInfoString;
      _endPlanTatCa = endInfoString;
    }
  }

  Future<void> _calculatePlanForXien(AppConfig? config) async {
    if (_ganPairInfo == null || config == null) return;
    if (_allResults.isEmpty) return;

    try {
      final thresholdLn = config.probability.thresholdLnXien;
      final pairAnalysis =
          await AnalysisService.findPairWithMinPTotal(_allResults);

      if (pairAnalysis == null) {
        _optimalXien = "Không có dữ liệu";
        _endPlanXien = "...";
        return;
      }

      final simResult = await AnalysisService.findEndDateForXienThreshold(
          pairAnalysis, 0.055, thresholdLn);
      DateTime start = DateFormat('dd/MM/yyyy')
          .parse(_sheetHeaderDate)
          .add(const Duration(days: 1));
      String? xienError;

      if (simResult != null) {
        final endDate = simResult.endDate;
        try {
          final budgetRes =
              await BudgetCalculationService(sheetsService: _sheetsService)
                  .calculateAvailableBudgetByEndDate(
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

        _dateXien = start;
        _endDateXien = endDate;
        _optimalXien =
            xienError ?? "${date_utils.DateUtils.formatDate(start)} (Miền Bắc)";
        _endPlanXien = xienError != null
            ? "❌ Thiếu vốn"
            : "🏁 Kết thúc: ${date_utils.DateUtils.formatDate(endDate)} (Miền Bắc)";
      }
    } catch (e) {
      _optimalXien = "Lỗi tính toán";
      _endPlanXien = "...";
    }
  }

  // ✅ FIX: Load lại config mới nhất để tránh lỗi TotalCapital=0
  Future<void> createCycleBettingTable(
      String number, AppConfig uiConfig) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final config = await _storageService.loadConfig() ?? uiConfig;
      print('🐛 DEBUG: TotalCapital = ${config.budget.totalCapital}');

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

  // ✅ FIX: Logic ưu tiên lấy dữ liệu từ Cache để tránh lệch tiền/lệch ngày
  Future<BettingTableParams> _prepareFarmingParams({
    required String mien,
    required AppConfig config,
    required String targetNumber,
  }) async {
    final type = _mapMienToEnum(mien);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    DateTime startDate = today.add(const Duration(days: 1));
    DateTime? cachedEndDate;
    int? cachedStartIdx;
    String? cachedEndMien;
    bool usingCache = false;

    // Logic lấy dữ liệu từ Cache
    switch (type) {
      case BettingTableTypeEnum.tatca:
        if (_dateTatCa != null && _dateTatCa!.isAfter(today)) {
          startDate = _dateTatCa!;
          cachedEndDate = _endDateTatCa;
          cachedStartIdx = _startIdxTatCa;
          cachedEndMien = _endMienTatCa;
        }
        break;
      case BettingTableTypeEnum.nam:
        if (_dateNam != null && _dateNam!.isAfter(today)) {
          startDate = _dateNam!;
          cachedEndDate = _endDateNam;
          cachedStartIdx = _startIdxNam;
          cachedEndMien = 'Miền Nam';
        }
        break;
      case BettingTableTypeEnum.trung:
        if (_dateTrung != null && _dateTrung!.isAfter(today)) {
          startDate = _dateTrung!;
          cachedEndDate = _endDateTrung;
          cachedStartIdx = _startIdxTrung;
          cachedEndMien = 'Miền Trung';
        }
        break;
      case BettingTableTypeEnum.bac:
        if (_dateBac != null && _dateBac!.isAfter(today)) {
          startDate = _dateBac!;
          cachedEndDate = _endDateBac;
          cachedStartIdx = _startIdxBac;
          cachedEndMien = 'Miền Bắc';
        }
        break;
    }

    DateTime endDate;
    String endMien = _getEndRegionName(mien);
    int startMienIndex = 0;

    if (cachedEndDate != null) {
      // ✅ DÙNG CACHE
      endDate = cachedEndDate;
      startMienIndex = cachedStartIdx ?? 0;
      if (cachedEndMien != null) endMien = cachedEndMien;
      usingCache = true;

      print(
          '🐛 DEBUG [Tạo bảng $mien]: Dùng Full Cache -> Start: ${DateFormat('dd/MM').format(startDate)} | End: ${DateFormat('dd/MM').format(endDate)} | StartMien: $startMienIndex');
    } else {
      // ✅ KHÔNG DÙNG CACHE (Fallback)
      print(
          '⚠️ DEBUG [Tạo bảng $mien]: Không có Cache EndDate, dùng logic tự tính');

      bool isMatchingTarget =
          _cycleResult != null && _cycleResult!.targetNumber == targetNumber;

      if (isMatchingTarget) {
        switch (type) {
          case BettingTableTypeEnum.tatca:
            endDate = _endDateTatCa ?? startDate.add(const Duration(days: 3));
            endMien = _endMienTatCa ?? 'Miền Bắc';
            startMienIndex = _startIdxTatCa;
            break;
          case BettingTableTypeEnum.nam:
            endDate = _endDateNam ?? startDate.add(const Duration(days: 3));
            endMien = 'Miền Nam';
            startMienIndex = _startIdxNam;
            break;
          case BettingTableTypeEnum.trung:
            endDate = _endDateTrung ?? startDate.add(const Duration(days: 3));
            endMien = 'Miền Trung';
            startMienIndex = _startIdxTrung;
            break;
          case BettingTableTypeEnum.bac:
            endDate = _endDateBac ?? startDate.add(const Duration(days: 3));
            endMien = 'Miền Bắc';
            startMienIndex = _startIdxBac;
            break;
        }
      } else {
        endDate = startDate.add(const Duration(days: 3));
      }
    }

    final durationLimit = endDate.difference(startDate).inDays;

    return BettingTableParams(
      type: type,
      targetNumber: targetNumber,
      startDate: startDate,
      endDate: endDate,
      endMien: endMien,
      startMienIndex: startMienIndex,
      durationLimit: durationLimit > 0 ? durationLimit : 1,
      soNgayGan: _cycleResult?.maxGanDays ?? 0,
      cycleResult: _cycleResult!,
      allResults: _allResults,
      isFromCache: usingCache, // ✅ Truyền cờ này ra
    );
  }

  Future<void> _createBettingTableGeneric(
    BettingTableParams params,
    AppConfig config,
  ) async {
    try {
      // ✅ BƯỚC 1: XÓA SHEET TRƯỚC
      await _sheetsService.clearSheet(params.type.sheetName);

      final budgetService =
          BudgetCalculationService(sheetsService: _sheetsService);

      // ✅ BƯỚC 2: Tính toán ngân sách
      final budgetResult =
          await budgetService.calculateAvailableBudgetByEndDate(
        totalCapital: config.budget.totalCapital,
        targetTable: params.type.budgetTableName,
        configBudget: params.type.getBudgetConfig(config),
        endDate: params.endDate,
        endMien: params.endMien,
      );

      DateTime finalStartDate = params.startDate;

      // ✅ BƯỚC 3: Tìm ngày bắt đầu tối ưu
      // CHỈ CHẠY NẾU KHÔNG PHẢI TỪ CACHE
      if (!params.isFromCache) {
        try {
          print('🔍 Đang tính toán lại ngày tối ưu (do không dùng cache)...');
          final optimalStart =
              await AnalysisService.findOptimalStartDateForCycle(
            baseStartDate: params.startDate,
            endDate: params.endDate,
            endMien: params.endMien,
            availableBudget: budgetResult.budgetMax,
            budgetMin: budgetResult.budgetMax * 0.66,
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

          if (optimalStart != null) finalStartDate = optimalStart.date;
        } catch (e) {
          print('⚠️ Lỗi tìm ngày tối ưu: $e. Dùng ngày mặc định.');
        }
      } else {
        print(
            '✅ Dùng ngày từ Cache, bỏ qua tính toán lại: ${DateFormat('dd/MM').format(finalStartDate)}');
      }

      // ✅ BƯỚC 4: Tạo bảng chi tiết
      final table = await params.type.generateTable(
        service: _bettingService,
        result: params.cycleResult,
        start: finalStartDate,
        end: params.endDate,
        endMien: params.endMien,
        startIdx: params.startMienIndex,
        min: budgetResult.budgetMax * 0.66,
        max: budgetResult.budgetMax,
        results: params.allResults,
        maxCount: params.type == BettingTableTypeEnum.tatca
            ? params.durationLimit
            : 0,
        durationLimit: params.endDate.difference(finalStartDate).inDays,
      );

      // ✅ BƯỚC 5: Lưu vào Sheet
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

      final budgetRes =
          await BudgetCalculationService(sheetsService: _sheetsService)
              .calculateAvailableBudgetByEndDate(
                  totalCapital: config.budget.totalCapital,
                  targetTable: 'xien',
                  configBudget: config.budget.xienBudget,
                  endDate: endDate,
                  endMien: 'Miền Bắc');

      final table = await _bettingService.generateXienTable(
        ganInfo: _ganPairInfo!,
        startDate: start,
        xienBudget: budgetRes.budgetMax,
        endDate: endDate,
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
