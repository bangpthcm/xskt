import 'package:flutter/material.dart';

import '../../../core/utils/date_utils.dart' as date_utils;
import '../../../core/utils/number_utils.dart';
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

  @override
  String toString() {
    return 'BettingTableParams('
        'type: ${type.displayName}, '
        'target: $targetNumber, '
        'start: ${date_utils.DateUtils.formatDate(startDate)}, '
        'end: ${date_utils.DateUtils.formatDate(endDate)}, '
        'startIdx: $startMienIndex, '
        'duration: $durationLimit)';
  }
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

  // State Chung
  bool _isLoading = false;
  String? _errorMessage;

  // Dữ liệu phân tích
  GanPairInfo? _ganPairInfo;
  CycleAnalysisResult?
      _cycleResult; // Dữ liệu hiển thị danh sách số (thay đổi theo filter)
  String _selectedMien = 'Tất cả';
  List<LotteryResult> _allResults = [];

  // ✅ State Tối ưu Tổng hợp (Tính 1 lần, dùng mãi mãi)
  String _optimalTatCa = "Đang tính...";
  String _optimalTrung = "Đang tính...";
  String _optimalBac = "Đang tính...";
  String _optimalXien = "Đang tính...";

  DateTime? _dateTatCa;
  DateTime? _dateTrung;
  DateTime? _dateBac;
  DateTime? _dateXien;
  DateTime? _endDateTatCa;
  DateTime? _endDateTrung;
  DateTime? _endDateBac;
  DateTime? _endDateXien;
  String? _startMienTatCa; // Chỉ dùng cho loại Tất cả

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  GanPairInfo? get ganPairInfo => _ganPairInfo;
  CycleAnalysisResult? get cycleResult => _cycleResult;
  String get selectedMien => _selectedMien;
  String get optimalTatCa => _optimalTatCa;
  String get optimalTrung => _optimalTrung;
  String get optimalBac => _optimalBac;
  String get optimalXien => _optimalXien;
  DateTime? get dateTatCa => _dateTatCa;
  DateTime? get dateTrung => _dateTrung;
  DateTime? get dateBac => _dateBac;
  DateTime? get dateXien => _dateXien;
  DateTime? get endDateTatCa => _endDateTatCa;
  DateTime? get endDateTrung => _endDateTrung;
  DateTime? get endDateBac => _endDateBac;
  DateTime? get endDateXien => _endDateXien;

  String get latestDataInfo {
    if (_allResults.isEmpty) return "Miền ... ngày ...";
    final last = _allResults.last;
    return "Miền ${last.mien} ngày ${last.ngay}";
  }

  // --- ACTIONS ---

  void setSelectedMien(String mien) {
    if (_selectedMien == mien) return;
    _selectedMien = mien;
    _reloadCycleOnly();
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

  Future<String?> findOptimalStartDateForType({
    required BettingTableTypeEnum type,
    required String targetNumber,
    required AppConfig config,
  }) async {
    try {
      print('🔍 [ViewModel] Tìm start date: ${type.displayName}');

      // Step 1: Tìm end date (dựa P_total)
      final pThreshold =
          config.probability.getThreshold(_getMienFromType(type));

      NumberAnalysisData? targetNumberData;
      DateTime? projectedEndDate;

      if (type == BettingTableTypeEnum.tatca) {
        targetNumberData = await AnalysisService.findNumberWithMinPTotal(
          _allResults,
          'tatca',
          pThreshold,
        );
      } else if (type == BettingTableTypeEnum.trung) {
        targetNumberData = await AnalysisService.findNumberWithMinPTotal(
          _allResults,
          'Trung',
          pThreshold,
        );
      } else {
        targetNumberData = await AnalysisService.findNumberWithMinPTotal(
          _allResults,
          'Bắc',
          pThreshold,
        );
      }

      if (targetNumberData == null) {
        return "Không tìm được số mục tiêu";
      }

      // Step 2: Tính end date
      final pStats = AnalysisService.calculatePStats(_allResults);
      final endDateResult = await AnalysisService.findEndDateForCycleThreshold(
        targetNumberData,
        pStats.p,
        _allResults,
        pThreshold,
        mien: _getMienFromType(type),
      );

      if (endDateResult == null) {
        return "Không tính được end date";
      }

      projectedEndDate = endDateResult.endDate;

      // Step 3: Tính budget khả dụng
      final budgetService =
          BudgetCalculationService(sheetsService: _sheetsService);
      final budgetResult =
          await budgetService.calculateAvailableBudgetByEndDate(
        totalCapital: config.budget.totalCapital,
        targetTable: type.budgetTableName,
        configBudget: type.getBudgetConfig(config),
        endDate: projectedEndDate,
      );

      if (budgetResult.available < 50000) {
        return "Thiếu vốn (${NumberUtils.formatCurrency(budgetResult.available)})";
      }

      // Step 4: Tìm start date sao cho budget đủ
      final lastInfo = _getLastResultInfo();
      DateTime baseStart;
      int startMienIdx;

      if (lastInfo.isLastBac) {
        baseStart = lastInfo.date.add(const Duration(days: 1));
        startMienIdx = 0;
      } else {
        baseStart = lastInfo.date;
        startMienIdx = lastInfo.mienIndex + 1;
      }

      final optimalStart = await AnalysisService.findOptimalStartDateForCycle(
        baseStartDate: baseStart,
        endDate: projectedEndDate,
        availableBudget: budgetResult.budgetMax,
        mien: _getMienFromType(type),
        targetNumber: targetNumberData.number,
        cycleResult: _cycleResult!,
        allResults: _allResults,
        bettingService: _bettingService,
        maxMienCount: config.duration.cycleDuration,
      );

      if (optimalStart == null) {
        return "Quá hạn/Thiếu vốn";
      }

      // ✅ Cập nhật state
      if (type == BettingTableTypeEnum.tatca) {
        _dateTatCa = optimalStart;
        return date_utils.DateUtils.formatDate(optimalStart);
      } else if (type == BettingTableTypeEnum.trung) {
        _dateTrung = optimalStart;
        return date_utils.DateUtils.formatDate(optimalStart);
      } else {
        _dateBac = optimalStart;
        return date_utils.DateUtils.formatDate(optimalStart);
      }
    } catch (e) {
      print('❌ Error in findOptimalStartDateForType: $e');
      return "Lỗi: $e";
    }
  }

  // ✅ CẬP NHẬT: Hàm loadAnalysis (gộp logic)
  Future<void> loadAnalysis({bool useCache = true}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      print('🔄 [ViewModel] Load Analysis...');

      _allResults = await _cachedDataService.loadKQXS(
        forceRefresh: !useCache,
        incrementalOnly: useCache,
      );

      print('✅ KQXS loaded: ${_allResults.length} records');

      // ✅ HỢP NHẤT: Một quy trình phân tích (không Farm/Probability)
      await _analyzeFullFlowUnified();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Lỗi phân tích: $e';
      print('❌ Error: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  // ✅ THÊM: Hàm phân tích hợp nhất (thay thế _analyzeFullFlow)
  Future<void> _analyzeFullFlowUnified() async {
    print('🔄 [Analysis] Starting unified analysis...');

    try {
      // Step 1: Tìm Gan pair cho Xiên
      _ganPairInfo ??= await _analysisService.findGanPairsMienBac(_allResults);

      // Step 2: Reload cycle data theo miền được chọn
      await _reloadCycleOnly();

      // Step 3: Tính ngày bắt đầu tối ưu cho tất cả loại
      await _calculateAllOptimalEntriesV2();

      print('✅ [Analysis] Unified analysis completed');
    } catch (e) {
      print('❌ [Analysis] Error: $e');
      rethrow;
    }
  }

  // ✅ THÊM: Hàm tính ngày tối ưu (cập nhật, dùng P_total)
  Future<void> _calculateAllOptimalEntriesV2() async {
    _optimalTatCa = "Đang tính...";
    _optimalTrung = "Đang tính...";
    _optimalBac = "Đang tính...";
    _optimalXien = "Đang tính...";

    notifyListeners();

    try {
      final config = await _storageService.loadConfig();
      if (config == null) return;

      final allSheetsData = await _sheetsService
          .batchGetValues(['xsktBot1', 'trungBot', 'bacBot', 'xienBot']);

      // Tính Tất cả (Chu kỳ)
      await _calculateOptimalForType(
        BettingTableTypeEnum.tatca,
        config,
        allSheetsData,
      );

      // Tính Trung (Chu kỳ)
      await _calculateOptimalForType(
        BettingTableTypeEnum.trung,
        config,
        allSheetsData,
      );

      // Tính Bắc (Chu kỳ)
      await _calculateOptimalForType(
        BettingTableTypeEnum.bac,
        config,
        allSheetsData,
      );

      // Tính Xiên
      await _calculateOptimalForXien(config, allSheetsData);

      print('✅ Tính xong tất cả optimal dates');
      notifyListeners();
    } catch (e) {
      print('❌ Error calculating optimal entries: $e');
      _optimalTatCa = "Lỗi";
      _optimalTrung = "Lỗi";
      _optimalBac = "Lỗi";
      _optimalXien = "Lỗi";
      notifyListeners();
    }
  }

  // ✅ CẬP NHẬT: Hàm tính toán optimal cho từng loại (Sửa logic bất nhất dữ liệu)
  Future<void> _calculateOptimalForType(
    BettingTableTypeEnum type,
    AppConfig config,
    Map<String, List<List<dynamic>>> allSheetsData,
  ) async {
    try {
      final mien = _getMienFromType(type);
      print('🔍 Calculating optimal for ${type.displayName} ($mien)...');

      // 1. Lọc dữ liệu chuẩn theo miền
      final resultsForP = type == BettingTableTypeEnum.tatca
          ? _allResults
          : _allResults.where((r) => r.mien == mien).toList();

      if (resultsForP.isEmpty) {
        _updateOptimalState(type, "Không đủ dữ liệu");
        return;
      }

      // 2. Tính P Stats
      final pStats =
          AnalysisService.calculatePStats(resultsForP, fixedMien: mien);

      // Step 1: Tìm số mục tiêu (Dựa trên P_total)
      final pThreshold = config.probability.getThreshold(mien);
      final targetNumberData = await AnalysisService.findNumberWithMinPTotal(
        _allResults,
        mien,
        pThreshold,
      );

      if (targetNumberData == null) {
        _updateOptimalState(type, "Không đủ dữ liệu");
        return;
      }

      print(
          '   ✅ Found target: ${targetNumberData.number} (Gan: ${targetNumberData.currentGan})');

      // 🔥 BƯỚC KHẮC PHỤC: Tạo CycleResult giả lập khớp với số mục tiêu
      // Không gọi analyzeCycle() nữa vì nó sẽ trả về số Max Gan (sai mục đích)
      final specificCycleResult = CycleAnalysisResult(
        targetNumber: targetNumberData.number,
        ganNumbers: {targetNumberData.number},
        maxGanDays: targetNumberData.currentGan
            .toInt(), // Quan trọng: Phải dùng gan của chính nó
        lastSeenDate: targetNumberData.lastSeenDate,
        mienGroups: {}, // Không quan trọng khi tính optimal
        // Các chỉ số phụ (để 0 hoặc tính nếu cần thiết, tạm thời để 0 để code chạy)
        historicalGan: 0,
        occurrenceCount: 0,
        expectedCount: 0.0,
        analysisDays: 0,
      );

      // Step 2: Tính end date
      final endDateResult = await AnalysisService.findEndDateForCycleThreshold(
        targetNumberData,
        pStats.p,
        _allResults,
        pThreshold,
        mien: mien,
      );

      if (endDateResult == null) {
        _updateOptimalState(type, "Không tính được end date");
        return;
      }

      final endDate = endDateResult.endDate;

      // Step 3: Tính budget khả dụng
      final budgetService =
          BudgetCalculationService(sheetsService: _sheetsService);
      final budgetResult = await budgetService.calculateAvailableBudgetFromData(
        totalCapital: config.budget.totalCapital,
        targetTable: type.budgetTableName,
        configBudget: type.getBudgetConfig(config),
        endDate: endDate,
        allSheetsData: allSheetsData,
      );

      if (budgetResult.available < 50000) {
        _updateOptimalState(type,
            "Thiếu vốn (${NumberUtils.formatCurrency(budgetResult.available)})");
        return;
      }

      // Step 4: Tìm start date
      final lastInfo = _getLastResultInfo();
      DateTime baseStart;

      // Logic xác định ngày bắt đầu quét
      if (lastInfo.isLastBac) {
        baseStart = lastInfo.date.add(const Duration(days: 1));
      } else {
        baseStart = lastInfo.date;
      }

      final optimalStart = await AnalysisService.findOptimalStartDateForCycle(
        baseStartDate: baseStart,
        endDate: endDate,
        availableBudget: budgetResult.budgetMax,
        mien: mien,
        targetNumber: targetNumberData.number,
        cycleResult:
            specificCycleResult, // 👈 SỬA: Dùng object khớp hoàn toàn với targetNumber
        allResults: resultsForP,
        bettingService: _bettingService,
        maxMienCount: _getDurationForType(type, config),
      );

      if (optimalStart == null) {
        _updateOptimalState(type, "Quá hạn/Thiếu vốn");
        return;
      }

      final startDateStr = date_utils.DateUtils.formatDate(optimalStart);

      if (type == BettingTableTypeEnum.tatca) {
        _dateTatCa = optimalStart;
        _endDateTatCa = endDate;
        _optimalTatCa = startDateStr;
        // Lưu lại Mien bắt đầu cho Tất cả (logic cũ của anh có vẻ chưa set cái này trong flow tự động)
        // Tạm thời mặc định là logic xoay vòng
      } else if (type == BettingTableTypeEnum.trung) {
        _dateTrung = optimalStart;
        _endDateTrung = endDate;
        _optimalTrung = startDateStr;
      } else {
        _dateBac = optimalStart;
        _endDateBac = endDate;
        _optimalBac = startDateStr;
      }

      print('   ✅ Success: $startDateStr');
    } catch (e) {
      print('   ❌ Error: $e');
      _updateOptimalState(type, "Lỗi");
    }
  }

  // ✅ THÊM: Helper - Tính optimal cho Xiên
  Future<void> _calculateOptimalForXien(
    AppConfig config,
    Map<String, List<List<dynamic>>> allSheetsData,
  ) async {
    try {
      print('🔍 Calculating optimal for Xiên...');

      if (_ganPairInfo == null) {
        _optimalXien = "Chưa có cặp";
        return;
      }

      // Step 1: Tìm cặp với P_total nhỏ nhất
      final pairData = await AnalysisService.findPairWithMinPTotal(_allResults);

      if (pairData == null) {
        _optimalXien = "Không đủ dữ liệu";
        return;
      }

      print('   ✅ Found pair: ${pairData.pairDisplay}');

      // Step 2: Tính end date (P1 < ngưỡng)
      final pThreshold = config.probability.getThreshold('xien');
      final endDateResult = await AnalysisService.findEndDateForXienThreshold(
        pairData,
        AnalysisService.estimatePairProbability(1, 30),
        pThreshold,
      );

      if (endDateResult == null) {
        _optimalXien = "Không tính được end date";
        return;
      }

      final endDate = endDateResult.endDate;

      // Step 3: Tính budget khả dụng
      final budgetService =
          BudgetCalculationService(sheetsService: _sheetsService);
      final budgetResult = await budgetService.calculateAvailableBudgetFromData(
        totalCapital: config.budget.totalCapital,
        targetTable: 'xien',
        configBudget: config.budget.xienBudget,
        endDate: endDate,
        allSheetsData: allSheetsData,
      );

      if (budgetResult.available < 50000) {
        _optimalXien =
            "Thiếu vốn (${NumberUtils.formatCurrency(budgetResult.available)})";
        return;
      }

      // Step 4: Tìm start date
      final lastInfo = _getLastResultInfo();
      DateTime baseStart = lastInfo.date.add(const Duration(days: 1));

      final optimalStart = await AnalysisService.findOptimalStartDateForXien(
        baseStartDate: baseStart,
        endDate: endDate,
        availableBudget: budgetResult.budgetMax,
        ganInfo: _ganPairInfo!,
        bettingService: _bettingService,
      );

      if (optimalStart == null) {
        _optimalXien = "Quá hạn/Thiếu vốn";
        return;
      }

      _dateXien = optimalStart;
      _endDateXien = endDate; // ✅ THÊM DÒNG NÀY
      _optimalXien = date_utils.DateUtils.formatDate(optimalStart);

      print('   ✅ Success: $_optimalXien');
    } catch (e) {
      print('   ❌ Error: $e');
      _optimalXien = "Lỗi";
    }
  }

  // ✅ THÊM: Helper - Lấy miền từ type
  String _getMienFromType(BettingTableTypeEnum type) {
    switch (type) {
      case BettingTableTypeEnum.tatca:
        return 'tatca';
      case BettingTableTypeEnum.trung:
        return 'Trung';
      case BettingTableTypeEnum.bac:
        return 'Bắc';
    }
  }

  Future<void> _reloadCycleOnly() async {
    try {
      final config = await _storageService.loadConfig();
      if (config == null) return;

      List<LotteryResult> filteredResults;
      String mienForCalc;

      // 1. Chuẩn bị dữ liệu theo filter
      if (_selectedMien == 'Tất cả') {
        filteredResults = _allResults;
        mienForCalc = 'tatca';
      } else {
        filteredResults =
            _allResults.where((r) => r.mien == _selectedMien).toList();
        mienForCalc = _selectedMien;
      }

      // 2. Tìm số Tốt Nhất (Min P_total) - Giống hệt logic tính Optimal
      final pThreshold = config.probability.getThreshold(mienForCalc);
      final bestNode = await AnalysisService.findNumberWithMinPTotal(
        _allResults,
        mienForCalc,
        pThreshold,
      );

      if (bestNode != null) {
        print('🎯 [UI] Hiển thị số tối ưu: ${bestNode.number}');
        // 3. Nếu tìm thấy, lấy thống kê chi tiết cho số này để hiển thị lên UI
        _cycleResult = await _analysisService.analyzeSpecificNumber(
            filteredResults, bestNode.number);
      } else {
        // 4. Nếu không tìm thấy (hiếm), fallback về logic cũ (hiển thị số Gan nhất)
        _cycleResult = await _analysisService.analyzeCycle(filteredResults);
      }

      notifyListeners();
    } catch (e) {
      print('Reload cycle error: $e');
    }
  }

  void _updateOptimalState(BettingTableTypeEnum type, String value) {
    switch (type) {
      case BettingTableTypeEnum.tatca:
        _optimalTatCa = value;
        break;
      case BettingTableTypeEnum.trung:
        _optimalTrung = value;
        break;
      case BettingTableTypeEnum.bac:
        _optimalBac = value;
        break;
    }
  }

  // --- CREATE TABLES ---

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

  Future<BettingTableParams> _prepareFarmingParams({
    required String mien,
    required AppConfig config,
    required String targetNumber,
  }) async {
    print('🔄 [Farming] Preparing params for $mien...');

    final type = _mapMienToEnum(mien);

    // 1. Xác định Start Date và End Date từ kết quả phân tích
    DateTime startDate;
    DateTime endDate;
    int startMienIndex;

    if (type == BettingTableTypeEnum.tatca) {
      if (_dateTatCa == null) {
        throw Exception(
            'Chưa tính ngày tối ưu cho Tất cả. Hãy quay lại tab Phân tích.');
      }
      startDate = _dateTatCa!;

      // ✅ SỬA: Ưu tiên dùng EndDate đã tính toán (25/12), nếu không có mới dùng config
      if (_endDateTatCa != null && _endDateTatCa!.isAfter(startDate)) {
        endDate = _endDateTatCa!;
      } else {
        final durationConfig = config.duration.cycleDuration;
        endDate = startDate.add(Duration(days: durationConfig));
      }

      startMienIndex = _startMienTatCa != null
          ? ['Nam', 'Trung', 'Bắc'].indexOf(_startMienTatCa!)
          : 0;
    } else if (type == BettingTableTypeEnum.trung) {
      if (_dateTrung == null) {
        throw Exception(
            'Chưa tính ngày tối ưu cho Miền Trung. Hãy quay lại tab Phân tích.');
      }
      startDate = _dateTrung!;

      // ✅ SỬA: Ưu tiên dùng EndDate Trung
      if (_endDateTrung != null && _endDateTrung!.isAfter(startDate)) {
        endDate = _endDateTrung!;
      } else {
        final durationConfig = config.duration.trungDuration;
        endDate = startDate.add(Duration(days: durationConfig));
      }

      startMienIndex = 0;
    } else {
      // Bắc
      if (_dateBac == null) {
        throw Exception(
            'Chưa tính ngày tối ưu cho Miền Bắc. Hãy quay lại tab Phân tích.');
      }
      startDate = _dateBac!;

      // ✅ SỬA: Ưu tiên dùng EndDate Bắc
      if (_endDateBac != null && _endDateBac!.isAfter(startDate)) {
        endDate = _endDateBac!;
      } else {
        final durationConfig = config.duration.bacDuration;
        endDate = startDate.add(Duration(days: durationConfig));
      }

      startMienIndex = 0;
    }

    if (_cycleResult == null) {
      throw Exception('Chưa có kết quả phân tích Chu kỳ.');
    }

    // 2. Tính lại duration thực tế (Số ngày giữa Start và End)
    // Để đảm bảo generator chạy đúng đến ngày EndDate
    final actualDuration = endDate.difference(startDate).inDays;
    final durationLimit = actualDuration > 0 ? actualDuration : 1;

    print('✅ [Farming] Prepared (Corrected):');
    print('   Type: ${type.displayName}');
    print('   Start: ${date_utils.DateUtils.formatDate(startDate)}');
    print('   End: ${date_utils.DateUtils.formatDate(endDate)}');
    print('   Duration: $durationLimit days');

    return BettingTableParams(
      type: type,
      targetNumber: targetNumber,
      startDate: startDate,
      endDate: endDate,
      startMienIndex: startMienIndex,
      durationLimit: durationLimit, // Truyền duration đã tính lại
      soNgayGan: _cycleResult!.maxGanDays,
      cycleResult: _cycleResult!,
      allResults: _allResults,
    );
  }

  Future<void> _createBettingTableGeneric(
    BettingTableParams params,
    AppConfig config,
  ) async {
    print('🚀 [Generic] Starting table creation...');
    print('   $params');

    try {
      print('💰 Step 1: Calculating budget...');
      final budgetService =
          BudgetCalculationService(sheetsService: _sheetsService);

      final budgetResult =
          await budgetService.calculateAvailableBudgetByEndDate(
        totalCapital: config.budget.totalCapital,
        targetTable: params.type.budgetTableName,
        configBudget: params.type.getBudgetConfig(config),
        endDate: params.endDate,
      );

      print(
          '   ✅ Budget available: ${NumberUtils.formatCurrency(budgetResult.budgetMax)}');

      print('📋 Step 2: Generating betting table...');
      final table = await params.type.generateTable(
        service: _bettingService,
        result: params.cycleResult,
        start: params.startDate,
        end: params.endDate,
        startIdx: params.startMienIndex,
        min: budgetResult.budgetMax * 0.9,
        max: budgetResult.budgetMax,
        results: params.allResults,
        maxCount: params.type == BettingTableTypeEnum.tatca
            ? params.durationLimit
            : 0,
        durationLimit: params.durationLimit,
      );

      print('   ✅ Generated ${table.length} rows');
      print('   ✅ Total: ${NumberUtils.formatCurrency(table.last.tongTien)}');

      print('💾 Step 3: Saving to Google Sheets...');
      await _saveTableToSheet(params.type, table, params.cycleResult);
      print('   ✅ Saved to ${params.type.sheetName}');

      _isLoading = false;
      notifyListeners();

      print('✅ [Generic] Table creation completed!');
    } catch (e) {
      print('❌ [Generic] Error: $e');
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
      case 'nam':
      case 'all':
      case 'mixed':
        return BettingTableTypeEnum.tatca;
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
      final config = await _storageService.loadConfig();
      if (config == null) throw Exception('Config not found');

      final configDuration = config.duration.xienDuration;
      final fixedEndDate =
          _ganPairInfo!.lastSeen.add(Duration(days: configDuration));

      final lastInfo = _getLastResultInfo();
      DateTime start = lastInfo.date.add(const Duration(days: 1));

      if (_dateXien != null) {
        start = _dateXien!;
      }

      final actualBettingDays = fixedEndDate.difference(start).inDays;
      final effectiveDurationBase = actualBettingDays + _ganPairInfo!.daysGan;

      final budgetRes =
          await BudgetCalculationService(sheetsService: _sheetsService)
              .calculateAvailableBudgetByEndDate(
                  totalCapital: config.budget.totalCapital,
                  targetTable: 'xien',
                  configBudget: config.budget.xienBudget,
                  endDate: fixedEndDate);

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

  int _getDurationForType(BettingTableTypeEnum type, AppConfig config) {
    return switch (type) {
      BettingTableTypeEnum.tatca => config.duration.cycleDuration,
      BettingTableTypeEnum.trung => config.duration.trungDuration,
      BettingTableTypeEnum.bac => config.duration.bacDuration,
    };
  }

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

  // --- UTILS ---

  ({DateTime date, String mien, int mienIndex, bool isLastBac})
      _getLastResultInfo() {
    DateTime? latest;
    String? mien;
    for (final r in _allResults) {
      final d = date_utils.DateUtils.parseDate(r.ngay);
      if (d != null &&
          (latest == null ||
              d.isAfter(latest) ||
              (d.isAtSameMomentAs(latest) && _isMienLater(r.mien, mien!)))) {
        latest = d;
        mien = r.mien;
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

    // ✅ THÊM: Hiển thị ngày kết thúc dự kiến tương ứng với miền đang chọn
    if (_selectedMien == 'Tất cả' && _endDateTatCa != null) {
      buffer.writeln(
          '<b>Ngày kết thúc (dự kiến):</b> ${date_utils.DateUtils.formatDate(_endDateTatCa!)}');
    } else if (_selectedMien == 'Trung' && _endDateTrung != null) {
      buffer.writeln(
          '<b>Ngày kết thúc (dự kiến):</b> ${date_utils.DateUtils.formatDate(_endDateTrung!)}');
    } else if (_selectedMien == 'Bắc' && _endDateBac != null) {
      buffer.writeln(
          '<b>Ngày kết thúc (dự kiến):</b> ${date_utils.DateUtils.formatDate(_endDateBac!)}');
    }

    buffer.writeln('<b>Số mục tiêu:</b> ${_cycleResult!.targetNumber}\n');

    if (_selectedMien == 'Tất cả') {
      if (_optimalTatCa != "Đang tính..." &&
          !_optimalTatCa.contains("Thiếu vốn")) {
        buffer.writeln('<b>Kế hoạch (Tất cả):</b> $_optimalTatCa\n');
      }
    } else if (_selectedMien == 'Trung') {
      if (_optimalTrung != "Đang tính..." &&
          !_optimalTrung.contains("Thiếu vốn")) {
        buffer.writeln('<b>Kế hoạch (Trung):</b> $_optimalTrung\n');
      }
    } else if (_selectedMien == 'Bắc') {
      if (_optimalBac != "Đang tính..." && !_optimalBac.contains("Thiếu vốn")) {
        buffer.writeln('<b>Kế hoạch (Bắc):</b> $_optimalBac\n');
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

    // ✅ THÊM: Hiển thị ngày kết thúc
    if (_endDateXien != null) {
      buffer.writeln(
          '<b>Ngày kết thúc (dự kiến):</b> ${date_utils.DateUtils.formatDate(_endDateXien!)}');
    }

    if (_optimalXien != "Đang tính..." && !_optimalXien.contains("Thiếu vốn")) {
      buffer.writeln('\n<b>Kế hoạch:</b> $_optimalXien');
    }
    return buffer.toString();
  }

  Future<NumberDetail?> analyzeNumberDetail(String number) async {
    return await _analysisService.analyzeNumberDetail(_allResults, number);
  }
}
