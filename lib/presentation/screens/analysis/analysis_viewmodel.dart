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
  CycleAnalysisResult? _cycleResult; // Dữ liệu hiển thị danh sách số (thay đổi theo filter)
  String _selectedMien = 'Tất cả';
  List<LotteryResult> _allResults = [];
  
  // ✅ State Tối ưu Tổng hợp (Tính 1 lần, dùng mãi mãi)
  // Biến String để hiển thị lên UI
  String _optimalTatCa = "Đang tính...";
  String _optimalTrung = "Đang tính...";
  String _optimalBac = "Đang tính...";
  String _optimalXien = "Đang tính...";

  // Biến DateTime để dùng khi tạo bảng (đảm bảo chính xác)
  DateTime? _dateTatCa;
  DateTime? _dateTrung;
  DateTime? _dateBac;
  DateTime? _dateXien;
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

  String get latestDataInfo {
    if (_allResults.isEmpty) return "Miền ... ngày ...";
    final last = _allResults.last; 
    return "Miền ${last.mien} ngày ${last.ngay}";
  }

  // --- ACTIONS ---

  void setSelectedMien(String mien) {
    if (_selectedMien == mien) return;
    _selectedMien = mien;
    // ✅ CHỈ reload danh sách số, KHÔNG tính lại ngày tối ưu
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

  // Hàm load chính (Gọi khi vào màn hình hoặc refresh)
  Future<void> loadAnalysis({bool useCache = true}) async {
    _isLoading = true; _errorMessage = null; notifyListeners();
    try {
      _allResults = await _cachedDataService.loadKQXS(forceRefresh: !useCache, incrementalOnly: useCache);
      await _analyzeFullFlow();
      _isLoading = false; notifyListeners();
    } catch (e) {
      _errorMessage = 'Lỗi phân tích: $e';
      _isLoading = false; notifyListeners();
    }
  }

  // ✅ Hàm reload nhẹ (Gọi khi đổi Filter)
  Future<void> _reloadCycleOnly() async {
    try {
      if (_selectedMien == 'Tất cả') {
        _cycleResult = await _analysisService.analyzeCycle(_allResults);
      } else {
        final filtered = _allResults.where((r) => r.mien == _selectedMien).toList();
        _cycleResult = await _analysisService.analyzeCycle(filtered);
      }
      notifyListeners();
    } catch (e) {
      print('Reload cycle error: $e');
    }
  }

  // Luồng phân tích đầy đủ
  Future<void> _analyzeFullFlow() async {
    // 1. Phân tích Gan Pair (nếu chưa có)
    if (_ganPairInfo == null) {
      _ganPairInfo = await _analysisService.findGanPairsMienBac(_allResults);
    }
    
    // 2. Phân tích Chu kỳ cho view hiện tại
    await _reloadCycleOnly();
    
    // 3. Chạy tính toán Tối ưu Tổng hợp (Chạy ngầm song song cho cả 4 loại)
    // Tính 1 lần, lưu vào biến, không tính lại khi đổi tab
    _calculateAllOptimalEntries();
  }

  // ✅ HÀM TÍNH TOÁN TỐI ƯU TỔNG HỢP (CORE FIX)
  Future<void> _calculateAllOptimalEntries() async {
    _optimalTatCa = "Đang tính...";
    _optimalTrung = "Đang tính...";
    _optimalBac = "Đang tính...";
    _optimalXien = "Đang tính...";
    // notifyListeners(); // Có thể bỏ để tránh UI update quá nhiều lần

    try {
      final allSheetsData = await _sheetsService.batchGetValues([
        'xsktBot1', 'trungBot', 'bacBot', 'xienBot'
      ]);
      
      final config = await _storageService.loadConfig();
      if (config == null) return;

      final budgetService = BudgetCalculationService(sheetsService: _sheetsService);
      final lastInfo = _getLastResultInfo();

      // Helper function: Tính toán cho 1 loại cụ thể
      Future<void> calculateForType(BettingTableTypeEnum type) async {
        try {
          CycleAnalysisResult? tempResult;
          List<LotteryResult> tempResultsList;

          if (type == BettingTableTypeEnum.tatca) {
            tempResultsList = _allResults;
            // Tận dụng kết quả nếu có sẵn
            if (_selectedMien == 'Tất cả' && _cycleResult != null) {
              tempResult = _cycleResult;
            } else {
              tempResult = await _analysisService.analyzeCycle(_allResults);
            }
          } else {
            final mienFilter = type == BettingTableTypeEnum.trung ? 'Trung' : 'Bắc';
            tempResultsList = _allResults.where((r) => r.mien == mienFilter).toList();
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
          final fixedEndDate = tempResult.lastSeenDate.add(Duration(days: duration));

          final budgetResult = await budgetService.calculateAvailableBudgetFromData(
            totalCapital: config.budget.totalCapital,
            targetTable: type.budgetTableName,
            configBudget: type.getBudgetConfig(config),
            endDate: fixedEndDate,
            allSheetsData: allSheetsData,
          );

          if (budgetResult.available < 50000) {
            _updateOptimalState(type, "Thiếu vốn (${NumberUtils.formatCurrency(budgetResult.available)})");
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
                _updateOptimalState(type, "$mienName ${date_utils.DateUtils.formatDate(startDateCursor)}");
              } else if (type == BettingTableTypeEnum.trung) {
                _dateTrung = startDateCursor;
                _updateOptimalState(type, date_utils.DateUtils.formatDate(startDateCursor));
              } else {
                _dateBac = startDateCursor;
                _updateOptimalState(type, date_utils.DateUtils.formatDate(startDateCursor));
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

      // Chạy song song 4 tác vụ
      await Future.wait([
        calculateForType(BettingTableTypeEnum.tatca),
        calculateForType(BettingTableTypeEnum.trung),
        calculateForType(BettingTableTypeEnum.bac),
        if (_ganPairInfo != null) _findOptimalXienEntry(allSheetsData, config),
      ]);

    } catch (e) {
      _optimalTatCa = "Lỗi"; _optimalTrung = "Lỗi"; _optimalBac = "Lỗi"; _optimalXien = "Lỗi";
    }
    notifyListeners();
  }

  void _updateOptimalState(BettingTableTypeEnum type, String value) {
    switch (type) {
      case BettingTableTypeEnum.tatca: _optimalTatCa = value; break;
      case BettingTableTypeEnum.trung: _optimalTrung = value; break;
      case BettingTableTypeEnum.bac: _optimalBac = value; break;
    }
  }

  // Tính toán Xiên
  Future<void> _findOptimalXienEntry(
    Map<String, List<List<dynamic>>> allSheetsData, 
    AppConfig config
  ) async {
    try {
      final configDuration = config.duration.xienDuration;
      final fixedEndDate = _ganPairInfo!.lastSeen.add(Duration(days: configDuration));

      final budgetService = BudgetCalculationService(sheetsService: _sheetsService);
      final budgetResult = await budgetService.calculateAvailableBudgetFromData(
        totalCapital: config.budget.totalCapital,
        targetTable: 'xien',
        configBudget: config.budget.xienBudget,
        endDate: fixedEndDate,
        allSheetsData: allSheetsData,
      );

      if (budgetResult.available < 50000) {
        _optimalXien = "Thiếu vốn (${NumberUtils.formatCurrency(budgetResult.available)})";
        return;
      }

      final lastInfo = _getLastResultInfo();
      DateTime startDateCursor = lastInfo.date.add(const Duration(days: 1));
      bool found = false;
      
      for (int i = 0; i < 15; i++) {
        if (startDateCursor.isAfter(fixedEndDate)) break;
        try {
          final actualBettingDays = fixedEndDate.difference(startDateCursor).inDays;
          if (actualBettingDays <= 1) break; 
          
          final effectiveDurationBase = actualBettingDays + _ganPairInfo!.daysGan;
          final table = await _bettingService.generateXienTable(
             ganInfo: _ganPairInfo!,
             startDate: startDateCursor,
             xienBudget: budgetResult.budgetMax,
             durationBase: effectiveDurationBase,
             fitBudgetOnly: true, 
          );

          if (table.isNotEmpty && table.last.tongTien > budgetResult.budgetMax) throw Exception();

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
      final dates = _calculateDateParameters(type, result, config);

      final budgetService = BudgetCalculationService(sheetsService: _sheetsService);
      final budgetResult = await budgetService.calculateAvailableBudgetByEndDate(
        totalCapital: config.budget.totalCapital,
        targetTable: type.budgetTableName,
        configBudget: type.getBudgetConfig(config),
        endDate: dates.endDate,
      );

      final table = await type.generateTable(
        service: _bettingService,
        result: result,
        start: dates.startDate,
        end: dates.endDate,
        startIdx: dates.startMienIndex,
        min: budgetResult.budgetMax * 0.9,
        max: budgetResult.budgetMax,
        results: _allResults,
        maxCount: dates.targetCount,
        durationLimit: _getDurationForType(type, config),
      );

      await _saveTableToSheet(type, table, result);
      _isLoading = false; notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false; notifyListeners();
    }
  }
  
  Future<void> createXienBettingTable() async {
    if (_ganPairInfo == null) return;
    _isLoading = true; _errorMessage = null; notifyListeners();
    try {
      final config = await _storageService.loadConfig();
      if (config == null) throw Exception('Config not found');

      final configDuration = config.duration.xienDuration;
      final fixedEndDate = _ganPairInfo!.lastSeen.add(Duration(days: configDuration));
      
      final lastInfo = _getLastResultInfo();
      DateTime start = lastInfo.date.add(const Duration(days: 1));
      
      // ✅ Ưu tiên dùng ngày đã tính toán tối ưu nếu có
      if (_dateXien != null) {
        start = _dateXien!;
      }

      final actualBettingDays = fixedEndDate.difference(start).inDays;
      final effectiveDurationBase = actualBettingDays + _ganPairInfo!.daysGan;

      final budgetRes = await BudgetCalculationService(sheetsService: _sheetsService)
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
      _isLoading = false; notifyListeners();
    } catch (e) {
      _errorMessage = e.toString(); _isLoading = false; notifyListeners();
    }
  }

  // --- HELPERS ---

  Future<CycleAnalysisResult> _prepareCycleResult(BettingTableTypeEnum type, String number) async {
    // Nếu tạo bảng từ tab Tất cả, dùng result hiện tại
    if (type == BettingTableTypeEnum.tatca) {
      if (_cycleResult == null) throw Exception('Chưa có dữ liệu chu kỳ');
      return _cycleResult!;
    }
    
    // Nếu tạo bảng từ nút shortcut (Trung/Bắc) nhưng đang ở tab khác, cần check lại số đó
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
  _calculateDateParameters(
    BettingTableTypeEnum type, 
    CycleAnalysisResult result,
    AppConfig config,
  ) {
    final duration = _getDurationForType(type, config);
    final fixedEndDate = result.lastSeenDate.add(Duration(days: duration));

    final lastInfo = _getLastResultInfo();
    var startDate = lastInfo.isLastBac ? lastInfo.date.add(const Duration(days: 1)) : lastInfo.date;
    var startIdx = lastInfo.isLastBac ? 0 : lastInfo.mienIndex + 1;

    // ✅ ƯU TIÊN DÙNG NGÀY ĐÃ TÍNH TOÁN (OPTIMAL)
    if (type == BettingTableTypeEnum.tatca && _dateTatCa != null) {
      startDate = _dateTatCa!;
      if (_startMienTatCa != null) {
        startIdx = ['Nam', 'Trung', 'Bắc'].indexOf(_startMienTatCa!);
      }
    } else if (type == BettingTableTypeEnum.trung && _dateTrung != null) {
      startDate = _dateTrung!;
    } else if (type == BettingTableTypeEnum.bac && _dateBac != null) {
      startDate = _dateBac!;
    }

    if (type == BettingTableTypeEnum.tatca) {
      var targetCount = config.duration.cycleDuration;
      return (
        startDate: startDate, 
        endDate: fixedEndDate, 
        startMienIndex: startIdx, 
        targetCount: targetCount
      );
    } else {
      return (
        startDate: startDate, 
        endDate: fixedEndDate, 
        startMienIndex: startIdx, 
        targetCount: 0
      );
    }
  }

  int _getDurationForType(BettingTableTypeEnum type, AppConfig config) {
    return switch (type) {
      BettingTableTypeEnum.tatca => config.duration.cycleDuration,
      BettingTableTypeEnum.trung => config.duration.trungDuration,
      BettingTableTypeEnum.bac => config.duration.bacDuration,
    };
  }

  Future<void> _saveTableToSheet(BettingTableTypeEnum type, List<BettingRow> table, CycleAnalysisResult result) async {
    await _sheetsService.clearSheet(type.sheetName);
    
    final updates = <String, BatchUpdateData>{};
    final metadataRow = [
      result.maxGanDays.toString(),
      date_utils.DateUtils.formatDate(result.lastSeenDate),
      result.ganNumbersDisplay,
      result.targetNumber,
    ];
    final headerRow = ['STT', 'Ngày', 'Miền', 'Số', 'Số lô', 'Cược/số', 'Cược/miền', 'Tổng tiền', 'Lời (1 số)', 'Lời (2 số)'];
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
    final metadataRow = [_ganPairInfo!.daysGan.toString(), date_utils.DateUtils.formatDate(_ganPairInfo!.lastSeen), _ganPairInfo!.pairsDisplay, table.first.so];
    final headerRow = ['STT', 'Ngày', 'Miền', 'Số', 'Cược/miền', 'Tổng tiền', 'Lời'];
    final dataRows = table.map((e) => e.toSheetRow()).toList();

    updates['xienBot'] = BatchUpdateData(
      range: 'A1',
      values: [metadataRow, [], headerRow, ...dataRows],
    );
    
    await _sheetsService.batchUpdateRanges(updates);
  }

  // --- UTILS ---

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
    
    // Thêm thông tin tổng hợp dự kiến
    if (_selectedMien == 'Tất cả') {
       if (_optimalTatCa != "Đang tính..." && !_optimalTatCa.contains("Thiếu vốn")) {
         buffer.writeln('<b>Kế hoạch (Tất cả):</b> $_optimalTatCa\n');
       }
    } else if (_selectedMien == 'Trung') {
       if (_optimalTrung != "Đang tính..." && !_optimalTrung.contains("Thiếu vốn")) {
         buffer.writeln('<b>Kế hoạch (Trung):</b> $_optimalTrung\n');
       }
    } else if (_selectedMien == 'Bắc') {
       if (_optimalBac != "Đang tính..." && !_optimalBac.contains("Thiếu vốn")) {
         buffer.writeln('<b>Kế hoạch (Bắc):</b> $_optimalBac\n');
       }
    }

    buffer.writeln('<b>Nhóm số gan nhất:</b>\n${_cycleResult!.ganNumbersDisplay}\n');
    return buffer.toString();
  }

  String _buildGanPairMessage() {
    final buffer = StringBuffer();
    buffer.writeln('<b>📈 PHÂN TÍCH CẶP XIÊN 📈</b>\n');
    for (int i = 0; i < _ganPairInfo!.pairs.length && i < 2; i++) {
      final p = _ganPairInfo!.pairs[i];
      buffer.writeln('${i + 1}. Miền Bắc | Cặp <b>${p.display}</b> (${p.daysGan} ngày)');
    }
    buffer.writeln('\n<b>Cặp gan nhất:</b> ${_ganPairInfo!.pairs[0].display}');
    buffer.writeln('<b>Số ngày gan:</b> ${_ganPairInfo!.daysGan} ngày');
    buffer.writeln('<b>Lần cuối về:</b> ${date_utils.DateUtils.formatDate(_ganPairInfo!.lastSeen)}');
    
    if (_optimalXien != "Đang tính..." && !_optimalXien.contains("Thiếu vốn")) {
       buffer.writeln('\n<b>Kế hoạch:</b> $_optimalXien');
    }
    return buffer.toString();
  }

  Future<NumberDetail?> analyzeNumberDetail(String number) async {
    return await _analysisService.analyzeNumberDetail(_allResults, number);
  }
}