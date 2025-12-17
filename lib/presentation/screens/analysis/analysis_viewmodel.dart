import 'package:flutter/material.dart';

import '../../../core/utils/date_utils.dart' as date_utils;
import '../../../core/utils/number_utils.dart';
import '../../../data/models/app_config.dart';
import '../../../data/models/betting_row.dart';
import '../../../data/models/cycle_analysis_result.dart';
import '../../../data/models/gan_pair_info.dart';
import '../../../data/models/lottery_result.dart';
import '../../../data/models/number_detail.dart';
import '../../../data/models/probability_config.dart';
import '../../../data/models/rebetting_candidate.dart';
import '../../../data/models/rebetting_summary.dart';
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
  bool _isRebettingMode = false;
  RebettingResult? _rebettingResult;
  String _selectedRebettingMien = 'Tất cả';

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
  // ✅ THÊM: State cho REBETTING mode
  String _optimalRebettingTatCa = "Đang tính...";
  String _optimalRebettingNam = "Đang tính...";
  String _optimalRebettingTrung = "Đang tính...";
  String _optimalRebettingBac = "Đang tính...";

  // ✅ THÊM: State cho PROBABILITY mode
  String _optimalProbabilityTatCa = "Đang tính...";
  String _optimalProbabilityTrung = "Đang tính...";
  String _optimalProbabilityBac = "Đang tính...";

  DateTime? _dateTatCa;
  DateTime? _dateTrung;
  DateTime? _dateBac;
  DateTime? _dateXien;
  String? _startMienTatCa; // Chỉ dùng cho loại Tất cả

  late bool _isProbabilityMode = false;
  ProbabilityAnalysisResult? _probabilityResultTatCa;
  ProbabilityAnalysisResult? _probabilityResultTrung;
  ProbabilityAnalysisResult? _probabilityResultBac;

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
  bool get isRebettingMode => _isRebettingMode;
  RebettingResult? get rebettingResult => _rebettingResult;
  String get selectedRebettingMien => _selectedRebettingMien;
  bool get isProbabilityMode => _isProbabilityMode;
  ProbabilityAnalysisResult? get probabilityResultTatCa =>
      _probabilityResultTatCa;
  ProbabilityAnalysisResult? get probabilityResultTrung =>
      _probabilityResultTrung;
  ProbabilityAnalysisResult? get probabilityResultBac => _probabilityResultBac;
  String get optimalRebettingTatCa => _optimalRebettingTatCa;
  String get optimalRebettingNam => _optimalRebettingNam;
  String get optimalRebettingTrung => _optimalRebettingTrung;
  String get optimalRebettingBac => _optimalRebettingBac;

  // ✅ THÊM: Getters cho PROBABILITY
  String get optimalProbabilityTatCa => _optimalProbabilityTatCa;
  String get optimalProbabilityTrung => _optimalProbabilityTrung;
  String get optimalProbabilityBac => _optimalProbabilityBac;

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

  void toggleProbabilityMode(bool value) {
    _isProbabilityMode = value;
    if (value) {
      loadProbabilityAnalysis();
    }
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

  ProbabilityAnalysisResult? getProbabilityResultForSelectedMien() {
    switch (_selectedMien) {
      case 'Tất cả':
        return _probabilityResultTatCa;
      case 'Trung':
        return _probabilityResultTrung;
      case 'Bắc':
        return _probabilityResultBac;
      default:
        return null;
    }
  }

  Future<void> loadProbabilityAnalysis() async {
    if (_allResults.isEmpty) {
      _errorMessage = 'Chưa có dữ liệu KQXS';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      print('🔄 Loading Probability Analysis...');

      final config =
          await _storageService.loadConfig() ?? AppConfig.defaultConfig();
      final threshold = config.probability.threshold;

      // Chạy song song cho 3 miền
      final results = await Future.wait([
        _analysisService.analyzeProbabilityMode(
            _allResults, 'Tất cả', threshold),
        _analysisService.analyzeProbabilityMode(
            _allResults, 'Trung', threshold),
        _analysisService.analyzeProbabilityMode(_allResults, 'Bắc', threshold),
      ]);

      _probabilityResultTatCa = results[0];
      _probabilityResultTrung = results[1];
      _probabilityResultBac = results[2];

      print('✅ Probability Analysis loaded successfully!');
      print('   Tất cả: $_probabilityResultTatCa');
      print('   Trung: $_probabilityResultTrung');
      print('   Bắc: $_probabilityResultBac');

      // ✨ THÊM: Tính ngày có thể vào dựa trên budget
      await _calculateOptimalProbabilityDates();
      print('✅ Optimal probability dates calculated');

      _isLoading = false;
      notifyListeners();
    } catch (e, stackTrace) {
      print('❌ ERROR in loadProbabilityAnalysis: $e');
      print('   StackTrace: $stackTrace');
      _errorMessage = 'Lỗi tính Probability: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _calculateOptimalProbabilityDates() async {
    _optimalProbabilityTatCa = "Đang tính...";
    _optimalProbabilityTrung = "Đang tính...";
    _optimalProbabilityBac = "Đang tính...";

    final config =
        await _storageService.loadConfig() ?? AppConfig.defaultConfig();

    // Tất cả
    if (_probabilityResultTatCa != null) {
      final dateStr = await _findOptimalDateForTarget(
        mien: 'Tất cả',
        targetNumber: _probabilityResultTatCa!.targetNumber,
        config: config,
      );
      _optimalProbabilityTatCa = dateStr ?? "Lỗi";
    }

    // Trung
    if (_probabilityResultTrung != null) {
      final dateStr = await _findOptimalDateForTarget(
        mien: 'Trung',
        targetNumber: _probabilityResultTrung!.targetNumber,
        config: config,
      );
      _optimalProbabilityTrung = dateStr ?? "Lỗi";
    }

    // Bắc
    if (_probabilityResultBac != null) {
      final dateStr = await _findOptimalDateForTarget(
        mien: 'Bắc',
        targetNumber: _probabilityResultBac!.targetNumber,
        config: config,
      );
      _optimalProbabilityBac = dateStr ?? "Lỗi";
    }

    notifyListeners();
  }

  // ✅ THÊM: Helper function tìm ngày tối ưu cho một số cụ thể
  Future<String?> _findOptimalDateForTarget({
    required String mien,
    required String targetNumber,
    required AppConfig config,
  }) async {
    try {
      final type = _mapMienToEnum(mien);
      final duration = _getDurationForType(type, config);

      // Tính CycleAnalysisResult cho số này
      List<LotteryResult> tempResultsList;
      CycleAnalysisResult? tempResult;

      if (type == BettingTableTypeEnum.tatca) {
        tempResultsList = _allResults;
        tempResult = await _analysisService.analyzeCycle(_allResults);
      } else {
        final mienFilter = type == BettingTableTypeEnum.trung ? 'Trung' : 'Bắc';
        tempResultsList =
            _allResults.where((r) => r.mien == mienFilter).toList();
        tempResult = await _analysisService.analyzeCycle(tempResultsList);
      }

      if (tempResult == null) {
        return "Không đủ dữ liệu";
      }

      // Tính endDate
      final fixedEndDate =
          tempResult.lastSeenDate.add(Duration(days: duration));

      // Tính budget
      final budgetService =
          BudgetCalculationService(sheetsService: _sheetsService);
      final budgetResult =
          await budgetService.calculateAvailableBudgetByEndDate(
        totalCapital: config.budget.totalCapital,
        targetTable: type.budgetTableName,
        configBudget: type.getBudgetConfig(config),
        endDate: fixedEndDate,
      );

      if (budgetResult.available < 50000) {
        return "Thiếu vốn (${NumberUtils.formatCurrency(budgetResult.available)})";
      }

      // Tìm ngày bắt đầu tối ưu (logic giống _calculateAllOptimalEntries)
      final lastInfo = _getLastResultInfo();
      DateTime startDateCursor;
      int startMienIdx;

      if (lastInfo.isLastBac) {
        startDateCursor = lastInfo.date.add(const Duration(days: 1));
        startMienIdx = 0;
      } else {
        startDateCursor = lastInfo.date;
        startMienIdx = lastInfo.mienIndex + 1;
      }

      bool found = false;
      const mienOrder = ['Nam', 'Trung', 'Bắc'];

      for (int i = 0; i < 15; i++) {
        if (startDateCursor.isAfter(fixedEndDate)) break;

        try {
          await type.generateTable(
            service: _bettingService,
            result: tempResult,
            start: startDateCursor,
            end: fixedEndDate,
            startIdx: startMienIdx,
            min: budgetResult.budgetMax * 0.9,
            max: budgetResult.budgetMax,
            results: tempResultsList,
            maxCount: duration,
            durationLimit: duration,
          );

          found = true;

          // Format kết quả
          if (type == BettingTableTypeEnum.tatca) {
            final mienName = mienOrder[startMienIdx];
            return "$mienName ${date_utils.DateUtils.formatDate(startDateCursor)}";
          } else {
            return date_utils.DateUtils.formatDate(startDateCursor);
          }
        } catch (_) {}

        // Tăng cursor
        if (type == BettingTableTypeEnum.tatca) {
          startMienIdx++;
          if (startMienIdx > 2) {
            startMienIdx = 0;
            startDateCursor = startDateCursor.add(const Duration(days: 1));
          }
        } else {
          startDateCursor = startDateCursor.add(const Duration(days: 1));
        }
      }

      if (!found) return "Quá hạn/Thiếu vốn";

      return null;
    } catch (e) {
      print('❌ Error in _findOptimalDateForTarget: $e');
      return "Lỗi";
    }
  }

  Future<void> loadAnalysis({bool useCache = true}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _allResults = await _cachedDataService.loadKQXS(
          forceRefresh: !useCache, incrementalOnly: useCache);
      await _analyzeFullFlow();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Lỗi phân tích: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _reloadCycleOnly() async {
    try {
      if (_selectedMien == 'Tất cả') {
        _cycleResult = await _analysisService.analyzeCycle(_allResults);
      } else {
        final filtered =
            _allResults.where((r) => r.mien == _selectedMien).toList();
        _cycleResult = await _analysisService.analyzeCycle(filtered);
      }
      notifyListeners();
    } catch (e) {
      print('Reload cycle error: $e');
    }
  }

  Future<void> _analyzeFullFlow() async {
    _ganPairInfo ??= await _analysisService.findGanPairsMienBac(_allResults);
    await _reloadCycleOnly();
    _calculateAllOptimalEntries();
  }

  Future<void> _calculateAllOptimalEntries() async {
    _optimalTatCa = "Đang tính...";
    _optimalTrung = "Đang tính...";
    _optimalBac = "Đang tính...";
    _optimalXien = "Đang tính...";

    try {
      final allSheetsData = await _sheetsService
          .batchGetValues(['xsktBot1', 'trungBot', 'bacBot', 'xienBot']);

      final config = await _storageService.loadConfig();
      if (config == null) return;

      final budgetService =
          BudgetCalculationService(sheetsService: _sheetsService);
      final lastInfo = _getLastResultInfo();

      Future<void> calculateForType(BettingTableTypeEnum type) async {
        try {
          CycleAnalysisResult? tempResult;
          List<LotteryResult> tempResultsList;

          if (type == BettingTableTypeEnum.tatca) {
            tempResultsList = _allResults;
            if (_selectedMien == 'Tất cả' && _cycleResult != null) {
              tempResult = _cycleResult;
            } else {
              tempResult = await _analysisService.analyzeCycle(_allResults);
            }
          } else {
            final mienFilter =
                type == BettingTableTypeEnum.trung ? 'Trung' : 'Bắc';
            tempResultsList =
                _allResults.where((r) => r.mien == mienFilter).toList();
            tempResult = await _analysisService.analyzeCycle(tempResultsList);
          }

          if (tempResult == null) {
            _updateOptimalState(type, "Không đủ dữ liệu");
            return;
          }

          final duration = switch (type) {
            BettingTableTypeEnum.tatca => config.duration.cycleDuration,
            BettingTableTypeEnum.trung => config.duration.trungDuration,
            BettingTableTypeEnum.bac => config.duration.bacDuration,
          };
          final fixedEndDate =
              tempResult.lastSeenDate.add(Duration(days: duration));

          final budgetResult =
              await budgetService.calculateAvailableBudgetFromData(
            totalCapital: config.budget.totalCapital,
            targetTable: type.budgetTableName,
            configBudget: type.getBudgetConfig(config),
            endDate: fixedEndDate,
            allSheetsData: allSheetsData,
          );

          if (budgetResult.available < 50000) {
            _updateOptimalState(type,
                "Thiếu vốn (${NumberUtils.formatCurrency(budgetResult.available)})");
            return;
          }

          DateTime startDateCursor;
          int startMienIdx;

          if (lastInfo.isLastBac) {
            startDateCursor = lastInfo.date.add(const Duration(days: 1));
            startMienIdx = 0;
          } else {
            startDateCursor = lastInfo.date;
            startMienIdx = lastInfo.mienIndex + 1;
          }

          bool found = false;
          final mienOrder = ['Nam', 'Trung', 'Bắc'];

          for (int i = 0; i < 15; i++) {
            if (startDateCursor.isAfter(fixedEndDate)) break;
            try {
              await type.generateTable(
                service: _bettingService,
                result: tempResult,
                start: startDateCursor,
                end: fixedEndDate,
                startIdx: startMienIdx,
                min: budgetResult.budgetMax * 0.9,
                max: budgetResult.budgetMax,
                results: tempResultsList,
                maxCount: duration,
                durationLimit: duration,
              );

              found = true;
              if (type == BettingTableTypeEnum.tatca) {
                final mienName = mienOrder[startMienIdx];
                _dateTatCa = startDateCursor;
                _startMienTatCa = mienName;
                _updateOptimalState(type,
                    "$mienName ${date_utils.DateUtils.formatDate(startDateCursor)}");
              } else if (type == BettingTableTypeEnum.trung) {
                _dateTrung = startDateCursor;
                _updateOptimalState(
                    type, date_utils.DateUtils.formatDate(startDateCursor));
              } else {
                _dateBac = startDateCursor;
                _updateOptimalState(
                    type, date_utils.DateUtils.formatDate(startDateCursor));
              }
              break;
            } catch (_) {}

            if (type == BettingTableTypeEnum.tatca) {
              startMienIdx++;
              if (startMienIdx > 2) {
                startMienIdx = 0;
                startDateCursor = startDateCursor.add(const Duration(days: 1));
              }
            } else {
              startDateCursor = startDateCursor.add(const Duration(days: 1));
            }
          }
          if (!found) _updateOptimalState(type, "Quá hạn/Thiếu vốn");
        } catch (e) {
          _updateOptimalState(type, "Lỗi");
        }
      }

      await Future.wait([
        calculateForType(BettingTableTypeEnum.tatca),
        calculateForType(BettingTableTypeEnum.trung),
        calculateForType(BettingTableTypeEnum.bac),
        if (_ganPairInfo != null) _findOptimalXienEntry(allSheetsData, config),
      ]);
    } catch (e) {
      _optimalTatCa = "Lỗi";
      _optimalTrung = "Lỗi";
      _optimalBac = "Lỗi";
      _optimalXien = "Lỗi";
    }
    notifyListeners();
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

  Future<void> _findOptimalXienEntry(
      Map<String, List<List<dynamic>>> allSheetsData, AppConfig config) async {
    try {
      final configDuration = config.duration.xienDuration;
      final fixedEndDate =
          _ganPairInfo!.lastSeen.add(Duration(days: configDuration));

      final budgetService =
          BudgetCalculationService(sheetsService: _sheetsService);
      final budgetResult = await budgetService.calculateAvailableBudgetFromData(
        totalCapital: config.budget.totalCapital,
        targetTable: 'xien',
        configBudget: config.budget.xienBudget,
        endDate: fixedEndDate,
        allSheetsData: allSheetsData,
      );

      if (budgetResult.available < 50000) {
        _optimalXien =
            "Thiếu vốn (${NumberUtils.formatCurrency(budgetResult.available)})";
        return;
      }

      final lastInfo = _getLastResultInfo();
      DateTime startDateCursor = lastInfo.date.add(const Duration(days: 1));
      bool found = false;

      for (int i = 0; i < 15; i++) {
        if (startDateCursor.isAfter(fixedEndDate)) break;
        try {
          final actualBettingDays =
              fixedEndDate.difference(startDateCursor).inDays;
          if (actualBettingDays <= 1) break;

          final effectiveDurationBase =
              actualBettingDays + _ganPairInfo!.daysGan;
          final table = await _bettingService.generateXienTable(
            ganInfo: _ganPairInfo!,
            startDate: startDateCursor,
            xienBudget: budgetResult.budgetMax,
            durationBase: effectiveDurationBase,
            fitBudgetOnly: true,
          );

          if (table.isNotEmpty && table.last.tongTien > budgetResult.budgetMax)
            throw Exception();

          found = true;
          _dateXien = startDateCursor;
          _optimalXien = date_utils.DateUtils.formatDate(startDateCursor);
          break;
        } catch (_) {}
        startDateCursor = startDateCursor.add(const Duration(days: 1));
      }
      if (!found) _optimalXien = "Quá hạn/Thiếu vốn";
    } catch (e) {
      _optimalXien = "Lỗi";
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

  Future<void> createRebettingBettingTable(
    RebettingCandidate candidate,
    AppConfig config,
  ) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final params = await _prepareRebettingParams(candidate);
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
    final duration = _getDurationForType(type, config);

    DateTime startDate;
    int startMienIndex;
    DateTime endDate;

    if (type == BettingTableTypeEnum.tatca) {
      if (_dateTatCa == null) {
        throw Exception(
            'Chưa tính ngày tối ưu cho Tất cả. Hãy quay lại tab Phân tích.');
      }
      startDate = _dateTatCa!;

      startMienIndex = _startMienTatCa != null
          ? ['Nam', 'Trung', 'Bắc'].indexOf(_startMienTatCa!)
          : 0;
      endDate = startDate.add(Duration(days: duration));
    } else if (type == BettingTableTypeEnum.trung) {
      if (_dateTrung == null) {
        throw Exception(
            'Chưa tính ngày tối ưu cho Miền Trung. Hãy quay lại tab Phân tích.');
      }
      startDate = _dateTrung!;
      startMienIndex = 0;
      endDate = startDate.add(Duration(days: duration));
    } else {
      if (_dateBac == null) {
        throw Exception(
            'Chưa tính ngày tối ưu cho Miền Bắc. Hãy quay lại tab Phân tích.');
      }
      startDate = _dateBac!;
      startMienIndex = 0;
      endDate = startDate.add(Duration(days: duration));
    }

    if (_cycleResult == null) {
      throw Exception('Chưa có kết quả phân tích Chu kỳ.');
    }

    print('✅ [Farming] Prepared:');
    print('   Type: ${type.displayName}');
    print('   Start: ${date_utils.DateUtils.formatDate(startDate)}');
    print('   End: ${date_utils.DateUtils.formatDate(endDate)}');
    print('   Duration: $duration days');

    return BettingTableParams(
      type: type,
      targetNumber: targetNumber,
      startDate: startDate,
      endDate: endDate,
      startMienIndex: startMienIndex,
      durationLimit: duration,
      soNgayGan: _cycleResult!.maxGanDays,
      cycleResult: _cycleResult!,
      allResults: _allResults,
    );
  }

  // ✅ [LOGIC ĐÃ SỬA] Tính toán params cho Rebetting có context
  Future<BettingTableParams> _prepareRebettingParams(
    RebettingCandidate candidate,
  ) async {
    print('🔄 [Rebetting] Preparing params for ${candidate.soMucTieu}...');

    // 1. Xác định enum type
    final type = _mapMienToEnum(candidate.mienTrung);

    // 2. Parse dates từ candidate
    final ngayTrungCu = date_utils.DateUtils.parseDate(candidate.ngayTrungCu);
    if (ngayTrungCu == null) {
      throw Exception('Ngày trúng cũ không hợp lệ: ${candidate.ngayTrungCu}');
    }

    final startDate = date_utils.DateUtils.parseDate(candidate.ngayCoTheVao);
    if (startDate == null) {
      throw Exception('Ngày bắt đầu không hợp lệ: ${candidate.ngayCoTheVao}');
    }

    // 3. Tính end date từ duration
    final endDate =
        ngayTrungCu.add(Duration(days: candidate.rebettingDuration));

    // ✅ FIX QUAN TRỌNG: Tính startMienIndex
    int startMienIndex = 0; // Mặc định là 0 (Nam)

    if (type == BettingTableTypeEnum.tatca) {
      // Với 'Tất cả', phải tính index dựa trên độ lệch ngày so với kết quả mới nhất
      final lastInfo = _getLastResultInfo();

      // Tính số ngày chênh lệch
      final diffDays = startDate.difference(lastInfo.date).inDays;

      // Logic: Index mới = (Index cũ + số ngày trôi qua) % 3
      if (diffDays >= 0) {
        startMienIndex = (lastInfo.mienIndex + diffDays) % 3;
        print(
            '   Calculated startMienIdx: $startMienIndex (Last: ${lastInfo.mienIndex}, Diff: $diffDays)');
      } else {
        startMienIndex = 0;
      }
    }

    // 4. Tạo fake CycleAnalysisResult từ candidate data
    final tempResult = CycleAnalysisResult(
      ganNumbers: {candidate.soMucTieu},
      maxGanDays: candidate.soNgayGanMoi,
      lastSeenDate: ngayTrungCu,
      mienGroups: {
        candidate.mienTrung: [candidate.soMucTieu]
      },
      targetNumber: candidate.soMucTieu,
    );

    print('✅ [Rebetting] Prepared:');
    print('   Type: ${type.displayName}');
    print('   Number: ${candidate.soMucTieu}');
    print('   Start: ${date_utils.DateUtils.formatDate(startDate)}');
    print('   Start Index: $startMienIndex');
    print('   End: ${date_utils.DateUtils.formatDate(endDate)}');
    print('   Duration: ${candidate.rebettingDuration} days');

    return BettingTableParams(
      type: type,
      targetNumber: candidate.soMucTieu,
      startDate: startDate,
      endDate: endDate,
      startMienIndex: startMienIndex,
      durationLimit: candidate.rebettingDuration,
      soNgayGan: candidate.soNgayGanMoi,
      cycleResult: tempResult,
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

    if (_optimalXien != "Đang tính..." && !_optimalXien.contains("Thiếu vốn")) {
      buffer.writeln('\n<b>Kế hoạch:</b> $_optimalXien');
    }
    return buffer.toString();
  }

  Future<NumberDetail?> analyzeNumberDetail(String number) async {
    return await _analysisService.analyzeNumberDetail(_allResults, number);
  }

  void toggleRebettingMode(bool value) {
    _isRebettingMode = value;
    if (value) {
      loadRebetting();
    }
    notifyListeners();
  }

  Future<void> loadRebetting() async {
    if (_allResults.isEmpty) {
      _errorMessage = 'Chưa có dữ liệu KQXS';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      print('🔄 Loading Rebetting data (New Logic 00-99)...');

      final config =
          await _storageService.loadConfig() ?? AppConfig.defaultConfig();
      print('✅ Config loaded');

      print('🔄 Calculating rebetting...');
      _rebettingResult = await _analysisService.calculateRebetting(
        allResults: _allResults,
        config: config,
        bettingService: _bettingService,
      );
      print('✅ Rebetting calculated: $_rebettingResult');

      await _calculateNgayCoTheVao();
      print('✅ ngayCoTheVao calculated');

      // ✨ THÊM: Tính ngày có thể vào dựa trên budget
      await _calculateOptimalRebettingDates();
      print('✅ Optimal rebetting dates calculated');

      _isLoading = false;
      notifyListeners();
      print('✅ Rebetting loading completed successfully!');
    } catch (e, stackTrace) {
      print('❌ ERROR in loadRebetting: $e');
      print('   StackTrace: $stackTrace');
      _errorMessage = 'Lỗi tính Rebetting: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
    }
  }

// ✅ THÊM: Hàm tính ngày cho REBETTING
  Future<void> _calculateOptimalRebettingDates() async {
    _optimalRebettingTatCa = "Đang tính...";
    _optimalRebettingNam = "Đang tính...";
    _optimalRebettingTrung = "Đang tính...";
    _optimalRebettingBac = "Đang tính...";

    if (_rebettingResult == null) return;

    // Lấy ngày từ candidate đã tính
    for (final entry in _rebettingResult!.selected.entries) {
      final mienKey = entry.key;
      final candidate = entry.value;

      if (candidate == null) {
        _updateOptimalRebetting(mienKey, "Không có");
        continue;
      }

      final ngayCoTheVao = candidate.ngayCoTheVao;
      if (ngayCoTheVao.isEmpty) {
        _updateOptimalRebetting(mienKey, "Lỗi");
      } else {
        _updateOptimalRebetting(mienKey, ngayCoTheVao);
      }
    }

    notifyListeners();
  }

  void _updateOptimalRebetting(String mienKey, String value) {
    switch (mienKey) {
      case 'tatCa':
        _optimalRebettingTatCa = value;
        break;
      case 'nam':
        _optimalRebettingNam = value;
        break;
      case 'trung':
        _optimalRebettingTrung = value;
        break;
      case 'bac':
        _optimalRebettingBac = value;
        break;
    }
  }

  // ✅ [LOGIC ĐÃ SỬA] Có truyền context neo miền vào Service
  Future<void> _calculateNgayCoTheVao() async {
    if (_rebettingResult == null) return;

    final config =
        await _storageService.loadConfig() ?? AppConfig.defaultConfig();
    final summaries = <String, RebettingSummary?>{};
    final selected = <String, RebettingCandidate?>{};

    // ✅ BƯỚC 1: Lấy thông tin KQXS mới nhất để làm mốc (anchor)
    final lastInfo = _getLastResultInfo();

    for (final entry in _rebettingResult!.selected.entries) {
      final mienKey = entry.key;
      final candidate = entry.value;

      if (candidate == null) {
        summaries[mienKey] = null;
        selected[mienKey] = null;
        continue;
      }

      final ngayTrungCu = date_utils.DateUtils.parseDate(candidate.ngayTrungCu);
      if (ngayTrungCu == null) {
        summaries[mienKey] = null;
        selected[mienKey] = null;
        continue;
      }

      final endDate =
          ngayTrungCu.add(Duration(days: candidate.rebettingDuration));

      double budgetMin = 100000;
      double budgetMax = 500000;

      if (mienKey == 'tatCa') {
        budgetMax = config.budget.totalCapital;
      } else if (mienKey == 'nam') {
        budgetMax = config.budget.totalCapital;
      } else if (mienKey == 'trung') {
        budgetMax = config.budget.trungBudget;
      } else if (mienKey == 'bac') {
        budgetMax = config.budget.bacBudget;
      }

      // ✅ BƯỚC 2: Chuẩn bị context neo (chỉ cần cho loại Tất cả)
      DateTime? anchorDate;
      int? anchorMienIndex;

      if (mienKey == 'tatCa') {
        anchorDate = lastInfo.date;
        anchorMienIndex = lastInfo.mienIndex;
      }

      // ✅ BƯỚC 3: Truyền context vào Service
      final ngayCoTheVao =
          await _bettingService.findOptimalStartDateForRebetting(
        endDate: endDate,
        budgetMin: budgetMin,
        budgetMax: budgetMax,
        mien: candidate.mienTrung,
        soMucTieu: candidate.soMucTieu,
        // NOTE: BettingService phải được cập nhật để dùng 2 tham số này tính startIdx
        anchorDate: anchorDate,
        anchorMienIndex: anchorMienIndex,
      );

      if (ngayCoTheVao != null) {
        final updatedCandidate = RebettingCandidate(
          soMucTieu: candidate.soMucTieu,
          mienTrung: candidate.mienTrung,
          ngayBatDauCu: candidate.ngayBatDauCu,
          ngayTrungCu: candidate.ngayTrungCu,
          soNgayGanCu: candidate.soNgayGanCu,
          soNgayGanMoi: candidate.soNgayGanMoi,
          rebettingDuration: candidate.rebettingDuration,
          ngayCoTheVao: ngayCoTheVao,
        );

        summaries[mienKey] = RebettingSummary(
          mien: _getMienDisplayName(mienKey),
          ngayCoTheVao: ngayCoTheVao,
          totalCandidates: _rebettingResult!.selected.values
              .where((c) =>
                  c != null && c.mienTrung == _getMienDisplayName(mienKey))
              .length,
        );

        selected[mienKey] = updatedCandidate;
      } else {
        summaries[mienKey] = null;
        selected[mienKey] = null;
      }
    }

    _rebettingResult = RebettingResult(
      summaries: summaries,
      selected: selected,
    );
  }

  void setSelectedRebettingMien(String mien) {
    _selectedRebettingMien = mien;
    notifyListeners();
  }

  String _getMienDisplayName(String key) {
    switch (key) {
      case 'tatCa':
        return 'Tất cả';
      case 'nam':
        return 'Nam';
      case 'trung':
        return 'Trung';
      case 'bac':
        return 'Bắc';
      default:
        return 'Unknown';
    }
  }

  Future<void> sendRebettingToTelegram(RebettingCandidate candidate) async {
    print('📤 Sending rebetting to Telegram: ${candidate.soMucTieu}');

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final message = _buildRebettingMessage(candidate);
      await _telegramService.sendMessage(message);

      print('✅ Rebetting message sent to Telegram');

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      print('❌ Error sending rebetting to Telegram: $e');
      _errorMessage = 'Lỗi gửi Telegram: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  String _buildRebettingMessage(RebettingCandidate candidate) {
    final buffer = StringBuffer();

    buffer.writeln('<b>💎 BẢNG CƯỢC REBETTING 💎</b>\n');

    buffer.writeln('<b>📋 Thông tin cổ:</b>');
    buffer.writeln('• Số mục tiêu: <b>${candidate.soMucTieu}</b>');
    buffer.writeln('• Miền: <b>${candidate.mienTrung}</b>');
    buffer.writeln('• Ngày trúng cũ: ${candidate.ngayTrungCu}');
    buffer.writeln('• Gan cũ: ${candidate.soNgayGanCu} ngày\n');

    buffer.writeln('<b>📊 Thông tin cược lại:</b>');
    buffer.writeln('• Gan mới: ${candidate.soNgayGanMoi} ngày');
    buffer.writeln('• Duration: <b>${candidate.rebettingDuration} ngày</b>');
    buffer.writeln('• Ngày bắt đầu: <b>${candidate.ngayCoTheVao}</b>\n');

    buffer.writeln('<b>💡 Ghi chú:</b>');
    buffer.writeln('Bảng cược đã được tạo và sẵn sàng sử dụng.');

    return buffer.toString();
  }
}
