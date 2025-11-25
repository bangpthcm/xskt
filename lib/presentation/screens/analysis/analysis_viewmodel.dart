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
import '../../../data/services/rss_parser_service.dart';
import '../../../data/services/backfill_service.dart';
import '../../../core/utils/date_utils.dart' as date_utils;
import '../../../data/services/budget_calculation_service.dart';
import '../../../core/utils/number_utils.dart';
import '../../../data/services/budget_calculation_service.dart';
import '../../../data/services/cached_data_service.dart';

// ✅ THÊM: Constants cho thresholds
class AnalysisThresholds {
  static const int tatca = 3;   // Alert khi > 3 ngày
  static const int nam = 0;     // Nam: không có threshold
  static const int trung = 14;   // Alert khi > 14 ngày
  static const int bac = 15;    // Alert khi > 15 ngày
  static const int xien = 145;  // Alert khi > 145 ngày
  
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
  final RssParserService _rssService;

  AnalysisViewModel({
    required CachedDataService cachedDataService,
    required GoogleSheetsService sheetsService,
    required AnalysisService analysisService,
    required StorageService storageService,
    required TelegramService telegramService,
    required BettingTableService bettingService,
    required RssParserService rssService,
  })  : _cachedDataService = cachedDataService, 
        _sheetsService = sheetsService,
        _analysisService = analysisService,
        _storageService = storageService,
        _telegramService = telegramService,
        _bettingService = bettingService,
        _rssService = rssService;

  bool _isLoading = false;
  String? _errorMessage;
  String? _lastDataHash;
  GanPairInfo? _ganPairInfo;
  CycleAnalysisResult? _cycleResult;
  String _selectedMien = 'Tất cả';
  List<LotteryResult> _allResults = [];
  
  // ✅ Cache alert status
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
      // ✅ STEP 1: Load data (với cache hoặc không)
      await _loadData(useCache: useCache);
      
      // ✅ STEP 2: Analyze in background (không block UI)
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
    
    if (!useCache) {
      // Backfill trước
      final backfillService = BackfillService(
        sheetsService: _sheetsService,
        rssService: _rssService,
      );
      
      final syncResult = await backfillService.syncAllFromRSS();
      print('📊 RSS sync result: ${syncResult.message}');
    }

    // Load KQXS với caching
    _allResults = await _cachedDataService.loadKQXS(
      forceRefresh: !useCache,
      incrementalOnly: useCache,
    );

    final cacheStatus = await _cachedDataService.getCacheStatus();
    print('📊 Cache status: $cacheStatus');
    print('📊 Loaded ${_allResults.length} results');
  }

  // ✅ LAZY: Analyze in background
  Future<void> _analyzeInBackground() async {
    print('🔄 Analyzing in background...');
    
    // Phân tích Xiên (nhanh)
    _ganPairInfo = await _analysisService.findGanPairsMienBac(_allResults);
    notifyListeners(); // ✅ Update UI ngay khi có kết quả Xiên
    
    // Phân tích Chu kỳ (chậm hơn)
    if (_selectedMien == 'Tất cả') {
      _cycleResult = await _analysisService.analyzeCycle(_allResults);
    } else {
      final filteredResults = _allResults
          .where((r) => r.mien == _selectedMien)
          .toList();
      _cycleResult = await _analysisService.analyzeCycle(filteredResults);
    }
    notifyListeners(); // ✅ Update UI khi có kết quả Chu kỳ
    
    // Cache alerts (không block UI)
    await _cacheAllAlerts();
    notifyListeners();
    
    print('✅ Background analysis completed');
  }

  // ✅ ADD: Method clear cache
  Future<void> clearCacheAndReload() async {
    await _cachedDataService.clearCache();
    await loadAnalysis(useCache: false);
  }
  
  Future<void> _cacheAllAlerts() async {
    try {
      print('💾 Caching alerts...');
      
      // ✅ OPTIMIZATION: Check nếu data không thay đổi
      final currentDataHash = '${_allResults.length}_${_allResults.last.ngay}';
      if (_lastDataHash == currentDataHash && 
          _tatCaAlertCache != null && 
          _trungAlertCache != null && 
          _bacAlertCache != null) {
        print('   📦 Using cached alerts (data unchanged)');
        return;
      }
      
      // ✅ PARALLEL: Tính toán song song
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
      
      _lastDataHash = currentDataHash; // ✅ Save hash
      
      print('   ✅ Alert cache updated');
      
    } catch (e) {
      print('⚠️ Error caching alerts: $e');
      _tatCaAlertCache = false;
      _trungAlertCache = false;
      _bacAlertCache = false;
    }
  }

  /// ✅ Generic method - Tạo bảng cược cho bất kỳ type nào
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
      // ✅ STEP 1: Xác định CycleResult
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

      // ✅ STEP 3: TÍNH ENDDATE TRƯỚC (để dùng cho budget calculation)
      print('⏳ STEP 3: Calculating end date...');
      
      DateTime endDate;
      int targetMienCount = 9;

      if (tableType == BettingTableTypeEnum.tatca) {
        // ✅ LOGIC CHO TẤT CẢ
        print('   📊 TATCA logic: checking Tuesday...');
        
        String targetMien = 'Nam';
        for (final entry in cycleResult!.mienGroups.entries) {
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

            print('   🔍 Last date: ${date_utils.DateUtils.formatDate(lastDate)} (weekday: $lastWeekday)');
            print('   🔍 Second last: ${date_utils.DateUtils.formatDate(secondLastDate)} (weekday: $secondLastWeekday)');

            bool needExtraTurn = false;

            final lastDateHasNam = simulatedRows.any((row) =>
                (row['date'] as DateTime).isAtSameMomentAs(lastDate) && row['mien'] == 'Nam');

            if (lastDateHasNam && lastWeekday == 1) {
              print('   ⚠️ Last date has Nam on Tuesday → adding extra turn');
              needExtraTurn = true;
            }

            if (!needExtraTurn) {
              final secondLastDateHasNam = simulatedRows.any((row) =>
                  (row['date'] as DateTime).isAtSameMomentAs(secondLastDate) && row['mien'] == 'Nam');

              if (secondLastDateHasNam && secondLastWeekday == 1) {
                print('   ⚠️ Second last has Nam on Tuesday → adding extra turn');
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
        // ✅ LOGIC CHO TRUNG - TÌM NGÀY CUỐI CÙNG CỦA DỮ LIỆU TRUNG
        print('   📊 ${tableType.displayName} logic: calculating from Trung data...');
        
        endDate = cycleResult.lastSeenDate.add(const Duration(days: 28));
        print('   📅 Latest Trung date: ${date_utils.DateUtils.formatDate(cycleResult.lastSeenDate)}');
        targetMienCount = 0;

      } else {
        // ✅ LOGIC CHO BẮC - TÌM NGÀY CUỐI CÙNG CỦA DỮ LIỆU BẮC
        print('   📊 ${tableType.displayName} logic: calculating from Bắc data...');
        
        endDate = cycleResult.lastSeenDate.add(const Duration(days: 35));
        print('   📅 Latest Bắc date: ${date_utils.DateUtils.formatDate(cycleResult.lastSeenDate)}');
        targetMienCount = 0;
      }

      print('   📅 End date: ${date_utils.DateUtils.formatDate(endDate)}');
      print('   🎯 Target mien count: $targetMienCount');

      // ✅ STEP 2: TÍNH BUDGET với endDate
      print('⏳ STEP 2: Calculating budget...');
      
      final budgetService = BudgetCalculationService(
        sheetsService: _sheetsService,
      );

      // ✅ TRUYỀN endDate VÀO HÀM TÍNH BUDGET
      final budgetResult = await budgetService.calculateAvailableBudgetByEndDate(
        totalCapital: config.budget.totalCapital,
        targetTable: tableType.budgetTableName,
        configBudget: tableType.getBudgetConfig(config),
        endDate: endDate,  // ✅ TRUYỀN endDate VỪA TÍNH
      );

      final budgetMax = budgetResult.budgetMax;
      final budgetMin = budgetMax * 0.9;

      print('   💰 Budget: ${NumberUtils.formatCurrency(budgetMin)} - ${NumberUtils.formatCurrency(budgetMax)}');

      // ✅ STEP 4: TÍNH startDate và startMienIndex (cho bảng)
      print('⏳ STEP 4: Calculating start date and mien index...');
      
      final startDateInfo = _calculateStartDateAndMienIndex(tableType);
      final startDate = startDateInfo['startDate'] as DateTime;
      final startMienIndex = startDateInfo['startMienIndex'] as int;

      print('   📅 Start date: ${date_utils.DateUtils.formatDate(startDate)}');
      print('   🌍 Start mien index: $startMienIndex');

      // ✅ STEP 5: Generate table
      print('⏳ STEP 5: Generating table...');
      
      try {
        final newTable = await tableType.generateTable(
          bettingService: _bettingService,
          cycleResult: cycleResult!,
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
          const profitTarget = 200.0;

          print('   Testing: budgetMax=${NumberUtils.formatCurrency(hugeBudget)}, profit=200');

          final testTable = await tableType.generateTable(
            bettingService: _bettingService,
            cycleResult: cycleResult!,
            startDate: startDate,
            endDate: endDate,
            startMienIndex: startMienIndex,
            budgetMin: budgetMax,
            budgetMax: hugeBudget,
            allResults: _allResults,
            maxMienCount: targetMienCount,
          );

          if (testTable == null || testTable.isEmpty) {
            throw Exception('Không tìm được giải pháp ngay cả với budget 100x');
          }

          final estimatedTotal = testTable.last.tongTien;
          print('   ✅ Found! Estimated minimum: ${NumberUtils.formatCurrency(estimatedTotal)}');
          
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
                cycleResult: cycleResult!,
                startDate: startDate,
                endDate: endDate,
                startMienIndex: startMienIndex,
                budgetMin: midBudget * 0.95,
                budgetMax: midBudget,
                allResults: _allResults,
                maxMienCount: targetMienCount,
              );

              if (result != null && result.isNotEmpty) {
                bestTable = result;
                actualMinimumRequired = result.last.tongTien;
                highBudget = midBudget - 1;
              } else {
                lowBudget = midBudget + 1;
              }
            } catch (e) {
              lowBudget = midBudget + 1;
            }

            if (i % 5 == 0) {
              print('   Iteration $i: Range ${NumberUtils.formatCurrency(lowBudget)} - ${NumberUtils.formatCurrency(highBudget)}');
            }

            if (highBudget < lowBudget) break;
          }

          print('\n✅ Minimum found: ${NumberUtils.formatCurrency(actualMinimumRequired)}');

          if (actualMinimumRequired <= budgetMax) {
            print('   ✔ Within original budget! Saving...');
            await tableType.saveTable(
              sheetsService: _sheetsService,
              table: bestTable!,
              cycleResult: cycleResult!,
            );
            _isLoading = false;
            notifyListeners();
            return;
          }

          throw Exception('Minimum required is $actualMinimumRequired');

        } catch (testError) {
          print('⚠️ 100x strategy result: $testError');
          
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

  // ✅ SIMPLIFIED
  Future<void> createCycleBettingTable(
    String targetNumber,
    AppConfig config,
  ) async {
    print('📊 createCycleBettingTable called: $targetNumber');

    // ✅ Delegate to generic method
    await _createBettingTableGeneric(
      tableType: BettingTableTypeEnum.tatca,
      targetNumber: targetNumber,
      config: config,
    );
  }

  // ✅ SỬA _simulateTableRows() - THÊM initialCount

  List<Map<String, dynamic>> _simulateTableRows({
    required DateTime startDate,
    required int startMienIndex,
    required String targetMien,
    required int targetCount,
    required List<String> mienOrder,
    int initialCount = 0,  // ✅ THÊM PARAMETER
  }) {
    final rows = <Map<String, dynamic>>[];
    
    DateTime currentDate = startDate;
    int targetMienCount = initialCount;  // ✅ BẮT ĐẦU TỪ initialCount
    bool isFirstDay = true;
    
    outerLoop:
    while (targetMienCount < targetCount) {
      final initialMienIdx = isFirstDay ? startMienIndex : 0;
      
      for (int i = initialMienIdx; i < mienOrder.length; i++) {
        final currentMien = mienOrder[i];
        
        rows.add({
          'date': currentDate,
          'mien': currentMien,
        });
        
        if (currentMien == targetMien) {
          targetMienCount++;
          
          if (targetMienCount >= targetCount) {
            print('   📊 Simulated ${rows.length} total rows (from $initialCount to $targetCount = ${targetMienCount - initialCount} new $targetMien turns)');
            print('   📅 Last date: ${date_utils.DateUtils.formatDate(currentDate)}');
            break outerLoop;
          }
        }
      }
      
      isFirstDay = false;
      currentDate = currentDate.add(const Duration(days: 1));
    }
    
    return rows;
  }

  // ✅ THÊM HELPER _countTargetMienOccurrences NẾU CHƯA CÓ
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


  // ✅ THÊM HELPER: TÍNH ENDDATE DỰA TRÊN SỐ LƯỢT QUAY
  DateTime _calculateEndDateByMienCount({
    required DateTime startDate,
    required int startMienIndex,
    required String targetMien,
    required int targetCount,
    required List<String> mienOrder,
  }) {
    DateTime checkDate = startDate;
    int currentMienIndex = startMienIndex;
    int count = 0;
    
    while (count < targetCount) {
      final currentMien = mienOrder[currentMienIndex];
      
      if (currentMien == targetMien) {
        count++;
        if (count >= targetCount) {
          return checkDate;
        }
      }
      
      currentMienIndex++;
      if (currentMienIndex >= mienOrder.length) {
        currentMienIndex = 0;
        checkDate = checkDate.add(const Duration(days: 1));
      }
    }
    
    return checkDate;
  }

  // ✅ THÊM HELPER: TÌM 2 DÒNG CUỐI
  Map<String, Map<String, dynamic>?> _findLastTwoRows({
    required DateTime startDate,
    required DateTime endDate,
    required int startMienIndex,
    required List<String> mienOrder,
  }) {
    Map<String, dynamic>? lastRow;
    Map<String, dynamic>? secondLastRow;
    
    DateTime checkDate = startDate;
    int currentMienIndex = startMienIndex;
    
    while (checkDate.isBefore(endDate.add(const Duration(days: 1)))) {
      final currentMien = mienOrder[currentMienIndex];
      
      // Shift rows
      if (lastRow != null) {
        secondLastRow = lastRow;
      }
      
      lastRow = {
        'date': checkDate,
        'mien': currentMien,
      };
      
      currentMienIndex++;
      if (currentMienIndex >= mienOrder.length) {
        currentMienIndex = 0;
        checkDate = checkDate.add(const Duration(days: 1));
      }
    }
    
    return {
      'last': lastRow,
      'secondLast': secondLastRow,
    };
  }

  String _getWeekdayName(int weekday) {
    const names = ['Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'Chủ nhật'];
    return names[weekday];
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
      final endDate = latestDate!.add(const Duration(days: 175));
      
      final config = await _storageService.loadConfig();
      
      // ✅ NEW LOGIC: Tính budget động
      final budgetService = BudgetCalculationService(
        sheetsService: _sheetsService,
      );
      
      final budgetResult = await budgetService.calculateAvailableBudgetByEndDate(
        totalCapital: config!.budget.totalCapital,
        targetTable: 'xien',
        configBudget: config.budget.xienBudget,
        endDate: endDate,
      );
      
      final xienBudget = budgetResult.budgetMax;
      
      print('💰 Xiên budget: ${NumberUtils.formatCurrency(xienBudget)}');
      
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
        print('❌ Generate table error: $generateError');
        
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

    await _sheetsService.updateRange(
      'xienBot',
      'A1:D1',
      [
        [
          _ganPairInfo!.daysGan.toString(),
          date_utils.DateUtils.formatDate(_ganPairInfo!.lastSeen),
          _ganPairInfo!.pairsDisplay,
          table.first.so,
        ]
      ],
    );

    await _sheetsService.updateRange(
      'xienBot',
      'A3:G3',
      [
        ['STT', 'Ngày', 'Miền', 'Số', 'Cược/miền', 'Tổng tiền', 'Lời']
      ],
    );

    final dataRows = table.map((row) => row.toSheetRow()).toList().cast<List<String>>();
    await _sheetsService.updateRange('xienBot', 'A4', dataRows);
  }

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
      
      // ✅ CHỌN TIÊU ĐỀ THEO FILTER ĐANG CHỌN
      switch (_selectedMien) {
        case 'Tất cả':
          buffer.writeln('<b>📊 PHÂN TÍCH CHU KỲ (TẤT CẢ) 📊</b>\n');
          break;
        case 'Nam':
          buffer.writeln('<b>🌴 PHÂN TÍCH CHU KỲ MIỀN NAM 🌴</b>\n');
          break;
        case 'Trung':
          buffer.writeln('<b>🔍 PHÂN TÍCH MIỀN TRUNG 🔍</b>\n');
          break;
        case 'Bắc':
          buffer.writeln('<b>🎯 PHÂN TÍCH MIỀN BẮC 🎯</b>\n');
          break;
        default:
          buffer.writeln('<b>📊 PHÂN TÍCH CHU KỲ 00-99 📊</b>\n');
      }
      
      buffer.writeln('<b>Filter:</b> $_selectedMien\n');
      buffer.writeln('<b>Số ngày gan:</b> ${_cycleResult!.maxGanDays} ngày');
      buffer.writeln('<b>Lần cuối về:</b> ${date_utils.DateUtils.formatDate(_cycleResult!.lastSeenDate)}');
      buffer.writeln('<b>Số mục tiêu:</b> ${_cycleResult!.targetNumber}\n');
      
      buffer.writeln('<b>Nhóm số gan nhất:</b>');
      buffer.writeln(_cycleResult!.ganNumbersDisplay);
      buffer.writeln();
      
      // ✅ CHỈ HIỂN THỊ PHÂN BỔ KHI FILTER = "TẤT CẢ"
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
  
  /// ✅ Helper: Tạo CycleResult từ số cho Trung/Bắc
  Future<CycleAnalysisResult?> _createCycleResultForNumber(
    String targetNumber,
    BettingTableTypeEnum tableType,
  ) async {
    print('🔍 Creating cycle result for number: $targetNumber, type: ${tableType.displayName}');
    
    final numberDetail = await _analysisService.analyzeNumberDetail(
      _allResults,
      targetNumber,
    );

    if (numberDetail == null) {
      print('❌ No number detail found');
      return null;
    }

    final mienName = tableType == BettingTableTypeEnum.trung ? 'Trung' : 'Bắc';
    final mienDetail = numberDetail.mienDetails[mienName];

    if (mienDetail == null) {
      print('❌ No mien detail found for $mienName');
      return null;
    }

    final cycleResult = CycleAnalysisResult(
      ganNumbers: {targetNumber},
      maxGanDays: mienDetail.daysGan,
      lastSeenDate: mienDetail.lastSeenDate,
      mienGroups: {mienName: [targetNumber]},
      targetNumber: targetNumber,
    );
    
    print('✅ Cycle result created: $mienName, ${mienDetail.daysGan} days gan');
    return cycleResult;
  }

  /// ✅ Helper: Tính startDate và startMienIndex
  Map<String, dynamic> _calculateStartDateAndMienIndex(
    BettingTableTypeEnum tableType,
  ) {
    print('📅 Calculating start date and mien index...');
    
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

    if (latestDate == null || latestMien == null) {
      throw Exception('Không tìm thấy KQXS mới nhất');
    }

    final mienOrder = ['Nam', 'Trung', 'Bắc'];
    final latestMienIndex = mienOrder.indexOf(latestMien);

    DateTime startDate;
    int startMienIndex;

    if (latestMienIndex == 2) {
      // Mien cuối cùng là Bắc → ngày mai từ Nam
      startDate = latestDate.add(const Duration(days: 1));
      startMienIndex = 0;
      print('   📍 Last: Bắc → Start tomorrow from Nam');
    } else {
      // Mien cuối cùng là Nam/Trung → hôm nay từ mien tiếp theo
      startDate = latestDate;
      startMienIndex = latestMienIndex + 1;
      print('   📍 Last: $latestMien → Start today from ${mienOrder[startMienIndex]}');
    }

    print('   📅 Start date: ${date_utils.DateUtils.formatDate(startDate)}');
    print('   🌍 Start mien index: $startMienIndex (${mienOrder[startMienIndex]})');

    return {
      'startDate': startDate,
      'startMienIndex': startMienIndex,
    };
  }

  Future<void> _saveAnalysisHistory() async {
    try {
      final existingData = await _sheetsService.getAllValues('xsktGan');
      
      final lastResult = _allResults.last;
      final ngayCuoiKQXS = lastResult.ngay;
      final mienCuoiKQXS = lastResult.mien;
      
      final filtersToSave = ['Tất cả', 'Nam', 'Trung', 'Bắc'];
      final historiesToAdd = <AnalysisHistory>[];
      
      for (final filterMien in filtersToSave) {
        CycleAnalysisResult? cycleResult;
        
        if (filterMien == 'Tất cả') {
          cycleResult = await _analysisService.analyzeCycle(_allResults);
        } else {
          final filteredResults = _allResults
              .where((r) => r.mien == filterMien)
              .toList();
          cycleResult = await _analysisService.analyzeCycle(filteredResults);
        }
        
        if (cycleResult == null) continue;
        
        final newHistory = AnalysisHistory.fromCycleResult(
          stt: existingData.length + historiesToAdd.length,
          ngayCuoiKQXS: ngayCuoiKQXS,
          mienCuoiKQXS: mienCuoiKQXS,
          soNgayGan: cycleResult.maxGanDays,
          ngayLanCuoiVe: date_utils.DateUtils.formatDate(cycleResult.lastSeenDate),
          nhomGan: cycleResult.ganNumbersDisplay,
          mienGroups: cycleResult.mienGroups,
          filter: filterMien,
        );
        
        bool isDuplicate = false;
        if (existingData.length > 1) {
          for (int i = 1; i < existingData.length; i++) {
            try {
              final existing = AnalysisHistory.fromSheetRow(existingData[i]);
              if (existing.isDuplicate(newHistory)) {
                isDuplicate = true;
                break;
              }
            } catch (e) {
              // Skip
            }
          }
        }
        
        if (!isDuplicate) {
          historiesToAdd.add(newHistory);
        }
      }
      
      if (historiesToAdd.isNotEmpty) {
        if (existingData.isEmpty) {
          await _sheetsService.updateRange(
            'xsktGan',
            'A1:J1',
            [
              [
                'STT',
                'Ngày cuối KQXS',
                'Miền cuối KQXS',
                'Số ngày GAN',
                'Lần cuối về',
                'Nhóm GAN',
                'Nam',
                'Trung',
                'Bắc',
                'Filter',
              ]
            ],
          );
        }
        
        int startSTT = existingData.isEmpty ? 1 : existingData.length;
        for (int i = 0; i < historiesToAdd.length; i++) {
          final history = historiesToAdd[i];
          historiesToAdd[i] = AnalysisHistory(
            stt: startSTT + i,
            ngayCuoiKQXS: history.ngayCuoiKQXS,
            mienCuoiKQXS: history.mienCuoiKQXS,
            soNgayGan: history.soNgayGan,
            ngayLanCuoiVe: history.ngayLanCuoiVe,
            nhomGan: history.nhomGan,
            mienNam: history.mienNam,
            mienTrung: history.mienTrung,
            mienBac: history.mienBac,
            filter: history.filter,
          );
        }
        
        final rowNumber = existingData.length + 1;
        final rows = historiesToAdd.map((h) => h.toSheetRow()).toList();
        await _sheetsService.updateRange(
          'xsktGan',
          'A$rowNumber',
          rows,
        );
      }
    } catch (e) {
      print('❌ Error saving analysis history: $e');
    }
  }

  Future<void> _saveXienAnalysisHistory() async {
    try {
      final existingData = await _sheetsService.getAllValues('xienGan');
      
      final lastResult = _allResults.last;
      final ngayCuoiKQXS = lastResult.ngay;
      final mienCuoiKQXS = lastResult.mien;
      
      final newHistories = <XienAnalysisHistory>[];
      
      for (int i = 0; i < _ganPairInfo!.pairs.length && i < 2; i++) {
        final pairWithDays = _ganPairInfo!.pairs[i];
        
        final newHistory = XienAnalysisHistory(
          stt: existingData.length + i,
          ngayCuoiKQXS: ngayCuoiKQXS,
          mienCuoiKQXS: mienCuoiKQXS,
          soNgayGan: pairWithDays.daysGan,
          ngayLanCuoiVe: date_utils.DateUtils.formatDate(pairWithDays.lastSeen),
          capSo: pairWithDays.display,
        );
        
        newHistories.add(newHistory);
      }
      
      final historiesToAdd = <XienAnalysisHistory>[];
      
      for (final newHistory in newHistories) {
        bool isDuplicate = false;
        
        if (existingData.length > 1) {
          for (int i = 1; i < existingData.length; i++) {
            try {
              final existing = XienAnalysisHistory.fromSheetRow(existingData[i]);
              if (existing.isDuplicate(newHistory)) {
                isDuplicate = true;
                break;
              }
            } catch (e) {
              // Skip
            }
          }
        }
        
        if (!isDuplicate) {
          historiesToAdd.add(newHistory);
        }
      }
      
      if (historiesToAdd.isNotEmpty) {
        if (existingData.isEmpty) {
          await _sheetsService.updateRange(
            'xienGan',
            'A1:F1',
            [
              [
                'STT',
                'Ngày cuối KQXS',
                'Miền cuối KQXS',
                'Số ngày GAN',
                'Lần cuối về',
                'Nhóm GAN',
              ]
            ],
          );
        }
        
        int startSTT = existingData.isEmpty ? 1 : existingData.length;
        for (int i = 0; i < historiesToAdd.length; i++) {
          final history = historiesToAdd[i];
          historiesToAdd[i] = XienAnalysisHistory(
            stt: startSTT + i,
            ngayCuoiKQXS: history.ngayCuoiKQXS,
            mienCuoiKQXS: history.mienCuoiKQXS,
            soNgayGan: history.soNgayGan,
            ngayLanCuoiVe: history.ngayLanCuoiVe,
            capSo: history.capSo,
          );
        }
        
        final startRow = existingData.length + 1;
        final rows = historiesToAdd.map((h) => h.toSheetRow()).toList();
        
        await _sheetsService.updateRange(
          'xienGan',
          'A$startRow',
          rows,
        );
      }
    } catch (e) {
      print('❌ Error saving xien analysis history: $e');
    }
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
          buffer.writeln(
            '<b>Miền $mien:</b> ${detail.daysGan} ngày - '
            'Lần cuối: ${detail.lastSeenDateStr}'
          );
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

  Future<void> createTrungGanBettingTable(
    String targetNumber,
    AppConfig config,
  ) async {
    print('📊 createTrungGanBettingTable called: $targetNumber');
    
    await _createBettingTableGeneric(
      tableType: BettingTableTypeEnum.trung,
      targetNumber: targetNumber,
      config: config,
    );
  }

  Future<void> createBacGanBettingTable(
    String targetNumber,
    AppConfig config,
  ) async {
    print('📊 createBacGanBettingTable called: $targetNumber');
    
    await _createBettingTableGeneric(
      tableType: BettingTableTypeEnum.bac,
      targetNumber: targetNumber,
      config: config,
    );
  }

  // ✅ Alert getters (BỎ hasCycleAlert cho "Tất cả")
  bool get hasCycleAlert {
    // ✅ KIỂM TRA ĐÚNG CHO "TẤT CẢ"
    if (_cycleResult == null) return false;
    if (_selectedMien != 'Tất cả') return false;
    return _cycleResult!.maxGanDays > AnalysisThresholds.tatca;
  }

  /// Kiểm tra Trung có gan > 9 ngày
  bool get hasTrungAlert {
    if (_cycleResult == null) return false;
    if (_selectedMien != 'Trung') return false;
    return _cycleResult!.maxGanDays > AnalysisThresholds.trung;
  }

  /// Kiểm tra Bắc có gan > 15 ngày
  bool get hasBacAlert {
    if (_cycleResult == null) return false;
    if (_selectedMien != 'Bắc') return false;
    return _cycleResult!.maxGanDays > AnalysisThresholds.bac;
  }

  /// Kiểm tra Xiên có gan > 2 ngày
  bool get hasXienAlert {
    if (_ganPairInfo == null) return false;
    return _ganPairInfo!.daysGan > AnalysisThresholds.xien;
  }

  /// ✅ Kiểm tra có bất kỳ alert nào (dùng cache)
  bool get hasAnyAlert {
    bool hasAlert = false;
    
    // Check Xiên
    if (_ganPairInfo != null && _ganPairInfo!.daysGan > AnalysisThresholds.xien) {
      hasAlert = true;
    }
    
    // ✅ CHECK TẤT CẢ (DÙNG CACHE)
    if (_tatCaAlertCache == true) {
      hasAlert = true;
    }
    
    // Check Trung (dùng cache)
    if (_trungAlertCache == true) {
      hasAlert = true;
    }
    
    // Check Bắc (dùng cache)
    if (_bacAlertCache == true) {
      hasAlert = true;
    }
    
    return hasAlert;
  }

}