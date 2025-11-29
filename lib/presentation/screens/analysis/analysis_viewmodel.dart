// lib/presentation/screens/analysis/analysis_viewmodel.dart
import 'package:flutter/material.dart';
import '../../../data/models/gan_pair_info.dart';
import '../../../data/models/cycle_analysis_result.dart';
import '../../../data/models/lottery_result.dart';
import '../../../data/models/app_config.dart';
import '../../../data/models/analysis_history.dart';
import '../../../data/models/xien_analysis_history.dart';
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

class AnalysisThresholds {
  static const int tatca = 3;   
  static const int nam = 0;     
  static const int trung = 14;   
  static const int bac = 15;    
  static const int xien = 145;  
  
  static const Map<String, int> byMien = {
    'Tất cả': tatca,
    'Nam': nam,
    'Trung': trung,
    'Bắc': bac,
  };
  
  static int getThreshold(String mien) => byMien[mien] ?? 0;
  
  static String formatWithThreshold(int currentDays, String mien) {
    final threshold = getThreshold(mien);
    return threshold == 0 
        ? '$currentDays ngày' 
        : '$currentDays ngày/$threshold ngày';
  }
}

enum BettingTableTypeEnum { tatca, trung, bac }

extension BettingTableTypeExtension on BettingTableTypeEnum {
  String get sheetName {
    switch (this) {
      case BettingTableTypeEnum.tatca:
        return 'xsktBot1';
      case BettingTableTypeEnum.trung:
        return 'trungBot';
      case BettingTableTypeEnum.bac:
        return 'bacBot';
    }
  }

  String get displayName {
    switch (this) {
      case BettingTableTypeEnum.tatca:
        return 'Tất cả';
      case BettingTableTypeEnum.trung:
        return 'Miền Trung';
      case BettingTableTypeEnum.bac:
        return 'Miền Bắc';
    }
  }

  String get budgetTableName {
    switch (this) {
      case BettingTableTypeEnum.tatca:
        return 'tatca';
      case BettingTableTypeEnum.trung:
        return 'trung';
      case BettingTableTypeEnum.bac:
        return 'bac';
    }
  }

  double? getBudgetConfig(AppConfig config) {
    switch (this) {
      case BettingTableTypeEnum.tatca:
        return null;
      case BettingTableTypeEnum.trung:
        return config.budget.trungBudget;
      case BettingTableTypeEnum.bac:
        return config.budget.bacBudget;
    }
  }

  Future<List<BettingRow>> generateTable({
    required BettingTableService bettingService,
    required CycleAnalysisResult cycleResult,
    required DateTime startDate,
    required DateTime endDate,
    required int startMienIndex,
    required double budgetMin,
    required double budgetMax,
    required List<LotteryResult> allResults,
    required int maxMienCount, 
  }) async {
    switch (this) {
      case BettingTableTypeEnum.tatca:
        return await bettingService.generateCycleTable(
          cycleResult: cycleResult,
          startDate: startDate,
          endDate: endDate,
          startMienIndex: startMienIndex,
          budgetMin: budgetMin,
          budgetMax: budgetMax,
          allResults: allResults,
          maxMienCount: maxMienCount,
        );

      case BettingTableTypeEnum.trung:
        return await bettingService.generateTrungGanTable(
          cycleResult: cycleResult,
          startDate: startDate,
          endDate: endDate,
          budgetMin: budgetMin,
          budgetMax: budgetMax,
        );

      case BettingTableTypeEnum.bac:
        return await bettingService.generateBacGanTable(
          cycleResult: cycleResult,
          startDate: startDate,
          endDate: endDate,
          budgetMin: budgetMin,
          budgetMax: budgetMax,
        );
    }
  }

  Future<void> saveTable({
    required GoogleSheetsService sheetsService,
    required List<BettingRow> table,
    required CycleAnalysisResult cycleResult,
  }) async {
    print('📝 Saving table to $sheetName...');
    
    await sheetsService.clearSheet(sheetName);

    await sheetsService.updateRange(
      sheetName,
      'A1:D1',
      [
        [
          cycleResult.maxGanDays.toString(),
          date_utils.DateUtils.formatDate(cycleResult.lastSeenDate),
          cycleResult.ganNumbersDisplay,
          cycleResult.targetNumber,
        ]
      ],
    );

    await sheetsService.updateRange(
      sheetName,
      'A3:J3',
      [
        ['STT', 'Ngày', 'Miền', 'Số', 'Số lô', 'Cược/số', 'Cược/miền', 'Tổng tiền', 'Lời (1 số)', 'Lời (2 số)']
      ],
    );

    final dataRows = table.map((row) => row.toSheetRow()).toList().cast<List<String>>();
    await sheetsService.updateRange(sheetName, 'A4', dataRows);
    
    print('✅ Table saved to $sheetName');
  }
}

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

  bool _isLoading = false;
  String? _errorMessage;
  String? _lastDataHash;
  GanPairInfo? _ganPairInfo;
  CycleAnalysisResult? _cycleResult;
  String _selectedMien = 'Tất cả';
  List<LotteryResult> _allResults = [];
  
  bool? _tatCaAlertCache;
  bool? _trungAlertCache;
  bool? _bacAlertCache;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  GanPairInfo? get ganPairInfo => _ganPairInfo;
  CycleAnalysisResult? get cycleResult => _cycleResult;
  String get selectedMien => _selectedMien;
  bool? get tatCaAlertCache => _tatCaAlertCache;
  bool? get trungAlertCache => _trungAlertCache;
  bool? get bacAlertCache => _bacAlertCache;

  void setSelectedMien(String mien) {
    _selectedMien = mien;
    notifyListeners();
  }

  Future<void> loadAnalysis({bool useCache = true}) async {
    print('🔍 loadAnalysis called with useCache: $useCache');
    
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _loadData(useCache: useCache);
      _analyzeInBackground();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Lỗi phân tích: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadData({required bool useCache}) async {
    print('📊 Loading KQXS data...');
    
    // Đã xóa phần gọi BackfillService (syncAllFromRSS)

    // Load KQXS với caching
    _allResults = await _cachedDataService.loadKQXS(
      forceRefresh: !useCache,
      incrementalOnly: useCache,
    );

    final cacheStatus = await _cachedDataService.getCacheStatus();
    print('📊 Cache status: $cacheStatus');
    print('📊 Loaded ${_allResults.length} results');
  }

  Future<void> _analyzeInBackground() async {
    print('🔄 Analyzing in background...');
    
    _ganPairInfo = await _analysisService.findGanPairsMienBac(_allResults);
    notifyListeners(); 
    
    if (_selectedMien == 'Tất cả') {
      _cycleResult = await _analysisService.analyzeCycle(_allResults);
    } else {
      final filteredResults = _allResults
          .where((r) => r.mien == _selectedMien)
          .toList();
      _cycleResult = await _analysisService.analyzeCycle(filteredResults);
    }
    notifyListeners(); 
    
    await _cacheAllAlerts();
    notifyListeners();
    
    print('✅ Background analysis completed');
  }

  Future<void> clearCacheAndReload() async {
    await _cachedDataService.clearCache();
    await loadAnalysis(useCache: false);
  }
  
  Future<void> _cacheAllAlerts() async {
    try {
      print('💾 Caching alerts...');
      
      final currentDataHash = '${_allResults.length}_${_allResults.last.ngay}';
      if (_lastDataHash == currentDataHash && 
          _tatCaAlertCache != null && 
          _trungAlertCache != null && 
          _bacAlertCache != null) {
        print('   📦 Using cached alerts (data unchanged)');
        return;
      }
      
      final results = await Future.wait([
        _analysisService.analyzeCycle(_allResults),
        _analysisService.analyzeCycle(
          _allResults.where((r) => r.mien == 'Trung').toList(),
        ),
        _analysisService.analyzeCycle(
          _allResults.where((r) => r.mien == 'Bắc').toList(),
        ),
      ]);
      
      _tatCaAlertCache = results[0] != null && results[0]!.maxGanDays > AnalysisThresholds.tatca;
      _trungAlertCache = results[1] != null && results[1]!.maxGanDays > AnalysisThresholds.trung;
      _bacAlertCache = results[2] != null && results[2]!.maxGanDays > AnalysisThresholds.bac;
      
      _lastDataHash = currentDataHash;
      
      print('   ✅ Alert cache updated');
      
    } catch (e) {
      print('⚠️ Error caching alerts: $e');
      _tatCaAlertCache = false;
      _trungAlertCache = false;
      _bacAlertCache = false;
    }
  }

  // Generic create table method
  Future<void> _createBettingTableGeneric({
    required BettingTableTypeEnum tableType,
    required String targetNumber,
    required AppConfig config,
  }) async {

    print('🎯 _createBettingTableGeneric: type=${tableType.displayName}, number=$targetNumber');

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      print('⏳ STEP 1: Getting cycle result...');
      
      final CycleAnalysisResult? cycleResult;

      if (tableType == BettingTableTypeEnum.tatca) {
        cycleResult = _cycleResult;
        if (cycleResult == null) {
          throw Exception('Chưa có dữ liệu chu kỳ');
        }
        print('   ✅ Using current cycle result');
      } else {
        cycleResult = await _createCycleResultForNumber(targetNumber, tableType);
        if (cycleResult == null) {
          throw Exception('Không tìm thấy thông tin số $targetNumber cho ${tableType.displayName}');
        }
        print('   ✅ Created cycle result from number');
      }

      print('⏳ STEP 3: Calculating end date...');
      
      DateTime endDate;
      int targetMienCount = 9;

      if (tableType == BettingTableTypeEnum.tatca) {
        print('   📊 TATCA logic: checking Tuesday...');
        
        String targetMien = 'Nam';
        for (final entry in cycleResult.mienGroups.entries) {
          if (entry.value.contains(cycleResult.targetNumber)) {
            targetMien = entry.key;
            break;
          }
        }
        print('   🌍 Target mien: $targetMien');

        final mienOrder = ['Nam', 'Trung', 'Bắc'];
        final startDateInfo = _calculateStartDateAndMienIndex(tableType);
        final startDate = startDateInfo['startDate'] as DateTime;
        final startMienIndex = startDateInfo['startMienIndex'] as int;

        int initialMienCount = _countTargetMienOccurrences(
          startDate: cycleResult.lastSeenDate,
          endDate: startDate,
          targetMien: targetMien,
          allResults: _allResults,
        );
        print('   📊 Initial mien count: $initialMienCount');

        targetMienCount = 9;

        final simulatedRows = _simulateTableRows(
          startDate: startDate,
          startMienIndex: startMienIndex,
          targetMien: targetMien,
          targetCount: targetMienCount,
          mienOrder: mienOrder,
          initialCount: initialMienCount,
        );

        if (simulatedRows.isNotEmpty) {
          final uniqueDates = <DateTime>{};
          for (final row in simulatedRows) {
            uniqueDates.add(row['date'] as DateTime);
          }

          final sortedDates = uniqueDates.toList()..sort();

          if (sortedDates.length >= 2) {
            final lastDate = sortedDates[sortedDates.length - 1];
            final secondLastDate = sortedDates[sortedDates.length - 2];

            final lastWeekday = date_utils.DateUtils.getWeekday(lastDate);
            final secondLastWeekday = date_utils.DateUtils.getWeekday(secondLastDate);

            bool needExtraTurn = false;

            final lastDateHasNam = simulatedRows.any((row) =>
                (row['date'] as DateTime).isAtSameMomentAs(lastDate) && row['mien'] == 'Nam');

            if (lastDateHasNam && lastWeekday == 1) {
              needExtraTurn = true;
            }

            if (!needExtraTurn) {
              final secondLastDateHasNam = simulatedRows.any((row) =>
                  (row['date'] as DateTime).isAtSameMomentAs(secondLastDate) && row['mien'] == 'Nam');

              if (secondLastDateHasNam && secondLastWeekday == 1) {
                needExtraTurn = true;
              }
            }

            if (needExtraTurn) {
              print('   📈 Increasing count: $targetMienCount → ${targetMienCount + 1}');
              targetMienCount += 1;
            }
          }
        }

        endDate = cycleResult.lastSeenDate.add(const Duration(days: 10));

      } else if (tableType == BettingTableTypeEnum.trung) {
        print('   📊 ${tableType.displayName} logic: calculating from Trung data...');
        endDate = cycleResult.lastSeenDate.add(const Duration(days: 28));
        targetMienCount = 0;

      } else {
        print('   📊 ${tableType.displayName} logic: calculating from Bắc data...');
        endDate = cycleResult.lastSeenDate.add(const Duration(days: 35));
        targetMienCount = 0;
      }

      print('   📅 End date: ${date_utils.DateUtils.formatDate(endDate)}');
      print('   🎯 Target mien count: $targetMienCount');

      print('⏳ STEP 2: Calculating budget...');
      
      final budgetService = BudgetCalculationService(
        sheetsService: _sheetsService,
      );

      final budgetResult = await budgetService.calculateAvailableBudgetByEndDate(
        totalCapital: config.budget.totalCapital,
        targetTable: tableType.budgetTableName,
        configBudget: tableType.getBudgetConfig(config),
        endDate: endDate,
      );

      final budgetMax = budgetResult.budgetMax;
      final budgetMin = budgetMax * 0.9;

      print('   💰 Budget: ${NumberUtils.formatCurrency(budgetMin)} - ${NumberUtils.formatCurrency(budgetMax)}');

      print('⏳ STEP 4: Calculating start date and mien index...');
      
      final startDateInfo = _calculateStartDateAndMienIndex(tableType);
      final startDate = startDateInfo['startDate'] as DateTime;
      final startMienIndex = startDateInfo['startMienIndex'] as int;

      print('   📅 Start date: ${date_utils.DateUtils.formatDate(startDate)}');
      print('   🌍 Start mien index: $startMienIndex');

      print('⏳ STEP 5: Generating table...');
      
      try {
        final newTable = await tableType.generateTable(
          bettingService: _bettingService,
          cycleResult: cycleResult,
          startDate: startDate,
          endDate: endDate,
          startMienIndex: startMienIndex,
          budgetMin: budgetMin,
          budgetMax: budgetMax,
          allResults: _allResults,
          maxMienCount: targetMienCount,
        );

        print('✅ Generated ${newTable.length} rows');

        await tableType.saveTable(
          sheetsService: _sheetsService,
          table: newTable,
          cycleResult: cycleResult,
        );

        _isLoading = false;
        notifyListeners();

      } catch (generateError) {
        print('❌ Generate failed with current budget: $generateError');
        print('\n🔍 Trying with 100x budget + profitTarget=200...');

        double actualMinimumRequired = budgetMax;

        try {
          final hugeBudget = budgetMax * 100;
          
          final testTable = await tableType.generateTable(
            bettingService: _bettingService,
            cycleResult: cycleResult,
            startDate: startDate,
            endDate: endDate,
            startMienIndex: startMienIndex,
            budgetMin: budgetMax,
            budgetMax: hugeBudget,
            allResults: _allResults,
            maxMienCount: targetMienCount,
          );

          if (testTable.isEmpty) {
            throw Exception('Không tìm được giải pháp ngay cả với budget 100x');
          }

          final estimatedTotal = testTable.last.tongTien;
          actualMinimumRequired = estimatedTotal;

          print('\n🔍 Binary searching for actual minimum...');
          
          double lowBudget = 1.0;
          double highBudget = estimatedTotal;
          List<BettingRow>? bestTable = testTable;

          for (int i = 0; i < 20; i++) {
            final midBudget = (lowBudget + highBudget) / 2;

            try {
              final result = await tableType.generateTable(
                bettingService: _bettingService,
                cycleResult: cycleResult,
                startDate: startDate,
                endDate: endDate,
                startMienIndex: startMienIndex,
                budgetMin: midBudget * 0.95,
                budgetMax: midBudget,
                allResults: _allResults,
                maxMienCount: targetMienCount,
              );

              if (result.isNotEmpty) {
                bestTable = result;
                actualMinimumRequired = result.last.tongTien;
                highBudget = midBudget - 1;
              } else {
                lowBudget = midBudget + 1;
              }
            } catch (e) {
              lowBudget = midBudget + 1;
            }

            if (highBudget < lowBudget) break;
          }

          if (actualMinimumRequired <= budgetMax) {
            await tableType.saveTable(
              sheetsService: _sheetsService,
              table: bestTable!,
              cycleResult: cycleResult,
            );
            _isLoading = false;
            notifyListeners();
            return;
          }

          throw Exception('Minimum required is $actualMinimumRequired');

        } catch (testError) {
          throw BudgetInsufficientException(
            tableName: tableType.displayName,
            budgetResult: budgetResult,
            minimumRequired: actualMinimumRequired,
          );
        }
      }
    } on BudgetInsufficientException catch (e) {
      print('❌ Budget insufficient: $e');
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    } on OptimizationFailedException catch (e) {
      print('❌ Optimization failed: $e');
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    } catch (e, stackTrace) {
      print('❌ Unexpected error: $e');
      print('   Stack: $stackTrace');
      _errorMessage = 'Lỗi tạo bảng: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  // Wrapper methods
  Future<void> createCycleBettingTable(String targetNumber, AppConfig config) async {
    await _createBettingTableGeneric(
      tableType: BettingTableTypeEnum.tatca,
      targetNumber: targetNumber,
      config: config,
    );
  }

  Future<void> createTrungGanBettingTable(String targetNumber, AppConfig config) async {
    await _createBettingTableGeneric(
      tableType: BettingTableTypeEnum.trung,
      targetNumber: targetNumber,
      config: config,
    );
  }

  Future<void> createBacGanBettingTable(String targetNumber, AppConfig config) async {
    await _createBettingTableGeneric(
      tableType: BettingTableTypeEnum.bac,
      targetNumber: targetNumber,
      config: config,
    );
  }

  List<Map<String, dynamic>> _simulateTableRows({
    required DateTime startDate,
    required int startMienIndex,
    required String targetMien,
    required int targetCount,
    required List<String> mienOrder,
    int initialCount = 0,
  }) {
    final rows = <Map<String, dynamic>>[];
    DateTime currentDate = startDate;
    int targetMienCount = initialCount;
    bool isFirstDay = true;
    
    outerLoop:
    while (targetMienCount < targetCount) {
      final initialMienIdx = isFirstDay ? startMienIndex : 0;
      
      for (int i = initialMienIdx; i < mienOrder.length; i++) {
        final currentMien = mienOrder[i];
        rows.add({'date': currentDate, 'mien': currentMien});
        
        if (currentMien == targetMien) {
          targetMienCount++;
          if (targetMienCount >= targetCount) break outerLoop;
        }
      }
      isFirstDay = false;
      currentDate = currentDate.add(const Duration(days: 1));
    }
    return rows;
  }

  int _countTargetMienOccurrences({
    required DateTime startDate,
    required DateTime endDate,
    required String targetMien,
    required List<LotteryResult> allResults,
  }) {
    final uniqueDates = <String>{};
    for (final result in allResults) {
      final date = date_utils.DateUtils.parseDate(result.ngay);
      if (date == null) continue;
      if (date.isAfter(startDate) && 
          (date.isBefore(endDate) || date.isAtSameMomentAs(endDate)) &&
          result.mien == targetMien) {
        uniqueDates.add(result.ngay);
      }
    }
    return uniqueDates.length;
  }
  
  Future<CycleAnalysisResult?> _createCycleResultForNumber(String targetNumber, BettingTableTypeEnum tableType) async {
    final numberDetail = await _analysisService.analyzeNumberDetail(_allResults, targetNumber);
    if (numberDetail == null) return null;

    final mienName = tableType == BettingTableTypeEnum.trung ? 'Trung' : 'Bắc';
    final mienDetail = numberDetail.mienDetails[mienName];
    if (mienDetail == null) return null;

    return CycleAnalysisResult(
      ganNumbers: {targetNumber},
      maxGanDays: mienDetail.daysGan,
      lastSeenDate: mienDetail.lastSeenDate,
      mienGroups: {mienName: [targetNumber]},
      targetNumber: targetNumber,
    );
  }

  Map<String, dynamic> _calculateStartDateAndMienIndex(BettingTableTypeEnum tableType) {
    DateTime? latestDate;
    String? latestMien;

    for (final result in _allResults) {
      final date = date_utils.DateUtils.parseDate(result.ngay);
      if (date != null) {
        if (latestDate == null ||
            date.isAfter(latestDate) ||
            (date.isAtSameMomentAs(latestDate) && _isMienLater(result.mien, latestMien ?? ''))) {
          latestDate = date;
          latestMien = result.mien;
        }
      }
    }

    if (latestDate == null || latestMien == null) throw Exception('Không tìm thấy KQXS mới nhất');

    final mienOrder = ['Nam', 'Trung', 'Bắc'];
    final latestMienIndex = mienOrder.indexOf(latestMien);
    DateTime startDate;
    int startMienIndex;

    if (latestMienIndex == 2) {
      startDate = latestDate.add(const Duration(days: 1));
      startMienIndex = 0;
    } else {
      startDate = latestDate;
      startMienIndex = latestMienIndex + 1;
    }

    return {'startDate': startDate, 'startMienIndex': startMienIndex};
  }

  bool _isMienLater(String newMien, String oldMien) {
    const mienPriority = {'Nam': 1, 'Trung': 2, 'Bắc': 3};
    return (mienPriority[newMien] ?? 0) > (mienPriority[oldMien] ?? 0);
  }

  Future<void> createXienBettingTable() async {
    if (_ganPairInfo == null) {
      _errorMessage = 'Chưa có dữ liệu cặp số gan';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final latestDate = _allResults
          .map((r) => date_utils.DateUtils.parseDate(r.ngay))
          .where((d) => d != null)
          .reduce((a, b) => a!.isAfter(b!) ? a : b);

      final startDate = latestDate!.add(const Duration(days: 1));
      final endDate = latestDate.add(const Duration(days: 175));
      final config = await _storageService.loadConfig();
      
      final budgetService = BudgetCalculationService(sheetsService: _sheetsService);
      final budgetResult = await budgetService.calculateAvailableBudgetByEndDate(
        totalCapital: config!.budget.totalCapital,
        targetTable: 'xien',
        configBudget: config.budget.xienBudget,
        endDate: endDate,
      );
      
      final xienBudget = budgetResult.budgetMax;
      
      try {
        final newTable = await _bettingService.generateXienTable(
          ganInfo: _ganPairInfo!,
          startDate: startDate,
          xienBudget: xienBudget,
        );

        await _saveXienTableToSheet(newTable);
        _isLoading = false;
        notifyListeners();
      } catch (generateError) {
        try {
          final testTable = await _bettingService.generateXienTable(
            ganInfo: _ganPairInfo!,
            startDate: startDate,
            xienBudget: xienBudget * 2,
          );
          final estimatedTotal = testTable.isNotEmpty ? testTable.last.tongTien : xienBudget;
          throw OptimizationFailedException(
            tableName: 'Xiên',
            budgetResult: budgetResult,
            estimatedTotal: estimatedTotal,
          );
        } catch (testError) {
          rethrow;
        }
      }
    } on BudgetInsufficientException catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    } on OptimizationFailedException catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Lỗi tạo bảng: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _saveXienTableToSheet(List<dynamic> table) async {
    await _sheetsService.clearSheet('xienBot');
    await _sheetsService.updateRange('xienBot', 'A1:D1', [[
          _ganPairInfo!.daysGan.toString(),
          date_utils.DateUtils.formatDate(_ganPairInfo!.lastSeen),
          _ganPairInfo!.pairsDisplay,
          table.first.so,
        ]]);
    await _sheetsService.updateRange('xienBot', 'A3:G3', [['STT', 'Ngày', 'Miền', 'Số', 'Cược/miền', 'Tổng tiền', 'Lời']]);
    final dataRows = table.map((row) => row.toSheetRow()).toList().cast<List<String>>();
    await _sheetsService.updateRange('xienBot', 'A4', dataRows);
  }

  // (Các hàm gửi telegram và getter không đổi)
  Future<void> sendCycleAnalysisToTelegram() async {
    if (_cycleResult == null) {
      _errorMessage = 'Chưa có dữ liệu chu kỳ';
      notifyListeners();
      return;
    }
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final buffer = StringBuffer();
      switch (_selectedMien) {
        case 'Tất cả': buffer.writeln('<b>📊 PHÂN TÍCH CHU KỲ (TẤT CẢ) 📊</b>\n'); break;
        case 'Nam': buffer.writeln('<b>🌴 PHÂN TÍCH CHU KỲ MIỀN NAM 🌴</b>\n'); break;
        case 'Trung': buffer.writeln('<b>🔍 PHÂN TÍCH MIỀN TRUNG 🔍</b>\n'); break;
        case 'Bắc': buffer.writeln('<b>🎯 PHÂN TÍCH MIỀN BẮC 🎯</b>\n'); break;
        default: buffer.writeln('<b>📊 PHÂN TÍCH CHU KỲ 00-99 📊</b>\n');
      }
      buffer.writeln('<b>Filter:</b> $_selectedMien\n');
      buffer.writeln('<b>Số ngày gan:</b> ${_cycleResult!.maxGanDays} ngày');
      buffer.writeln('<b>Lần cuối về:</b> ${date_utils.DateUtils.formatDate(_cycleResult!.lastSeenDate)}');
      buffer.writeln('<b>Số mục tiêu:</b> ${_cycleResult!.targetNumber}\n');
      buffer.writeln('<b>Nhóm số gan nhất:</b>');
      buffer.writeln(_cycleResult!.ganNumbersDisplay);
      buffer.writeln();
      
      if (_selectedMien == 'Tất cả') {
        buffer.writeln('<b>Phân bổ theo miền:</b>');
        for (final mien in ['Nam', 'Trung', 'Bắc']) {
          if (_cycleResult!.mienGroups.containsKey(mien)) {
            buffer.writeln('- Miền $mien: ${_cycleResult!.mienGroups[mien]!.join(", ")}');
          }
        }
      }
      await _telegramService.sendMessage(buffer.toString());
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Lỗi gửi Telegram: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> sendGanPairAnalysisToTelegram() async {
    if (_ganPairInfo == null) {
      _errorMessage = 'Chưa có dữ liệu cặp số gan';
      notifyListeners();
      return;
    }
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final buffer = StringBuffer();
      buffer.writeln('<b>📈 PHÂN TÍCH CẶP XIÊN BẮC 📈</b>\n');
      buffer.writeln('Đây là 2 cặp số đã lâu nhất chưa xuất hiện cùng nhau:\n');
      for (int i = 0; i < _ganPairInfo!.pairs.length && i < 2; i++) {
        final pairWithDays = _ganPairInfo!.pairs[i];
        buffer.writeln('${i + 1}. Cặp <b>${pairWithDays.display}</b> (${pairWithDays.daysGan} ngày)');
      }
      buffer.writeln('\n<b>Cặp gan nhất:</b> ${_ganPairInfo!.pairs[0].display}');
      buffer.writeln('<b>Số ngày gan:</b> ${_ganPairInfo!.daysGan} ngày');
      buffer.writeln('<b>Lần cuối về:</b> ${date_utils.DateUtils.formatDate(_ganPairInfo!.lastSeen)}');
      await _telegramService.sendMessage(buffer.toString());
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Lỗi gửi Telegram: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<NumberDetail?> analyzeNumberDetail(String number) async {
    return await _analysisService.analyzeNumberDetail(_allResults, number);
  }

  Future<void> sendNumberDetailToTelegram(NumberDetail numberDetail) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final buffer = StringBuffer();
      buffer.writeln('<b>📊 CHI TIẾT SỐ ${numberDetail.number} 📊</b>\n');
      for (final mien in ['Nam', 'Trung', 'Bắc']) {
        if (numberDetail.mienDetails.containsKey(mien)) {
          final detail = numberDetail.mienDetails[mien]!;
          buffer.writeln('<b>Miền $mien:</b> ${detail.daysGan} ngày - Lần cuối: ${detail.lastSeenDateStr}');
        }
      }
      await _telegramService.sendMessage(buffer.toString());
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Lỗi gửi Telegram: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  bool get hasCycleAlert {
    if (_cycleResult == null) return false;
    if (_selectedMien != 'Tất cả') return false;
    return _cycleResult!.maxGanDays > AnalysisThresholds.tatca;
  }

  bool get hasTrungAlert {
    if (_cycleResult == null) return false;
    if (_selectedMien != 'Trung') return false;
    return _cycleResult!.maxGanDays > AnalysisThresholds.trung;
  }

  bool get hasBacAlert {
    if (_cycleResult == null) return false;
    if (_selectedMien != 'Bắc') return false;
    return _cycleResult!.maxGanDays > AnalysisThresholds.bac;
  }

  bool get hasXienAlert {
    if (_ganPairInfo == null) return false;
    return _ganPairInfo!.daysGan > AnalysisThresholds.xien;
  }

  bool get hasAnyAlert {
    bool hasAlert = false;
    if (_ganPairInfo != null && _ganPairInfo!.daysGan > AnalysisThresholds.xien) hasAlert = true;
    if (_tatCaAlertCache == true) hasAlert = true;
    if (_trungAlertCache == true) hasAlert = true;
    if (_bacAlertCache == true) hasAlert = true;
    return hasAlert;
  }
}