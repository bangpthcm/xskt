// lib/presentation/screens/analysis/analysis_viewmodel.dart
import 'package:flutter/material.dart';
import '../../../data/models/gan_pair_info.dart';
import '../../../data/models/cycle_analysis_result.dart';
import '../../../data/models/lottery_result.dart';
import '../../../data/models/app_config.dart';
import '../../../data/models/analysis_history.dart';
import '../../../data/models/xien_analysis_history.dart';
import '../../../data/models/number_detail.dart';
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

class AnalysisViewModel extends ChangeNotifier {
  final GoogleSheetsService _sheetsService;
  final AnalysisService _analysisService;
  final StorageService _storageService;
  final TelegramService _telegramService;
  final BettingTableService _bettingService;
  final RssParserService _rssService;

  AnalysisViewModel({
    required GoogleSheetsService sheetsService,
    required AnalysisService analysisService,
    required StorageService storageService,
    required TelegramService telegramService,
    required BettingTableService bettingService,
    required RssParserService rssService,
  })  : _sheetsService = sheetsService,
        _analysisService = analysisService,
        _storageService = storageService,
        _telegramService = telegramService,
        _bettingService = bettingService,
        _rssService = rssService;

  bool _isLoading = false;
  String? _errorMessage;
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
      // BƯỚC 1: ĐỒNG BỘ RSS
      if (!useCache) {
        print('🔄 Starting RSS sync...');
        
        try {
          final backfillService = BackfillService(
            sheetsService: _sheetsService,
            rssService: _rssService,
          );
          
          final syncResult = await backfillService.syncAllFromRSS();
          print('📊 RSS sync result: ${syncResult.message}');
          
          if (syncResult.hasError) {
            print('⚠️ RSS sync had errors: ${syncResult.message}');
            _errorMessage = 'Cảnh báo: ${syncResult.message}';
            notifyListeners();
          }
        } catch (syncError) {
          print('❌ RSS sync failed: $syncError');
          _errorMessage = 'Cảnh báo: Không thể đồng bộ RSS - $syncError';
          notifyListeners();
        }
      }

      // BƯỚC 2: LẤY DỮ LIỆU
      final allValues = await _sheetsService.getAllValues('KQXS');
      
      if (allValues.length < 2) {
        throw Exception('Không có dữ liệu trong sheet');
      }

      _allResults = [];
      for (int i = 1; i < allValues.length; i++) {
        try {
          _allResults.add(LotteryResult.fromSheetRow(allValues[i]));
        } catch (e) {
          // Skip invalid rows
        }
      }

      // BƯỚC 3: PHÂN TÍCH
      _ganPairInfo = await _analysisService.findGanPairsMienBac(_allResults);

      if (_selectedMien == 'Tất cả') {
        _cycleResult = await _analysisService.analyzeCycle(_allResults);
      } else {
        final filteredResults = _allResults
            .where((r) => r.mien == _selectedMien)
            .toList();
        _cycleResult = await _analysisService.analyzeCycle(filteredResults);
      }

      // BƯỚC 4: LƯU LỊCH SỬ
      if (!useCache) {
        print('💾 Saving analysis history...');
        
        if (_cycleResult != null && _allResults.isNotEmpty) {
          await _saveAnalysisHistory();
        }
        
        if (_ganPairInfo != null && _allResults.isNotEmpty) {
          await _saveXienAnalysisHistory();
        }
      }
      
      // BƯỚC 5: CACHE ALERT
      await _cacheAllAlerts();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Lỗi phân tích: $e';
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> _cacheAllAlerts() async {
    try {
      print('💾 Caching alerts...');
      
      // ✅ CHECK TẤT CẢ (KHÔNG LỌC THEO MIỀN)
      final tatCaResult = await _analysisService.analyzeCycle(_allResults);
      _tatCaAlertCache = tatCaResult != null && tatCaResult.maxGanDays > 3;
      
      // Check Trung
      final trungResults = _allResults.where((r) => r.mien == 'Trung').toList();
      final trungResult = await _analysisService.analyzeCycle(trungResults);
      _trungAlertCache = trungResult != null && trungResult.maxGanDays > 14;
      
      // Check Bắc
      final bacResults = _allResults.where((r) => r.mien == 'Bắc').toList();
      final bacResult = await _analysisService.analyzeCycle(bacResults);
      _bacAlertCache = bacResult != null && bacResult.maxGanDays > 16;
      
      print('   ✅ Alert cache: Tất cả=$_tatCaAlertCache, Trung=$_trungAlertCache, Bắc=$_bacAlertCache');
      
    } catch (e) {
      print('⚠️ Error caching alerts: $e');
      _tatCaAlertCache = false;
      _trungAlertCache = false;
      _bacAlertCache = false;
    }
  }

  // ✅ SỬA createCycleBettingTable() - ĐƠN GIẢN HÓA

  Future<void> createCycleBettingTable(AppConfig config) async {
    if (_cycleResult == null) {
      _errorMessage = 'Chưa có dữ liệu chu kỳ';
      notifyListeners();
      return;
    }
    
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // ✅ BƯỚC 1: Tính budget khả dụng
      final budgetService = BudgetCalculationService(
        sheetsService: _sheetsService,
      );
      
      final availableBudget = await budgetService.calculateTatCaBudget(
        config.budget.totalCapital,
      );
      
      print('💰 Available budget for Tất cả: ${NumberUtils.formatCurrency(availableBudget)}');
      
      // ✅ Validate budget
      if (availableBudget <= 50000) {
        throw Exception(
          'Không đủ vốn để tạo bảng Tất cả!\n'
          'Vốn khả dụng: ${NumberUtils.formatCurrency(availableBudget)} VNĐ\n'
          'Cần tối thiểu: 50,000 VNĐ'
        );
      }

      // ✅ BƯỚC 2: Tìm ngày bắt đầu (logic cũ, giữ nguyên)
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
        throw Exception('Không tìm thấy dữ liệu KQXS');
      }

      final mienOrder = ['Nam', 'Trung', 'Bắc'];
      final latestMienIndex = mienOrder.indexOf(latestMien);
      print('📅 Latest KQXS: ${date_utils.DateUtils.formatDate(latestDate!)} - $latestMien');
      
      DateTime startDate;
      int startMienIndex;
      
      if (latestMienIndex == 2) {
        startDate = latestDate.add(const Duration(days: 1));
        startMienIndex = 0;
      } else {
        startDate = latestDate;
        startMienIndex = latestMienIndex + 1;
      }

      String targetMien = 'Nam';
      for (final entry in _cycleResult!.mienGroups.entries) {
        if (entry.value.contains(_cycleResult!.targetNumber)) {
          targetMien = entry.key;
          break;
        }
      }

      // ✅ BƯỚC 3: Tính số lượt và budget
      int targetMienCount = 9;
      double budgetMax = availableBudget;  // ✅ Dùng budget động
      
      DateTime endDate = _cycleResult!.lastSeenDate.add(const Duration(days: 15));
      print('📅 Start betting: ${date_utils.DateUtils.formatDate(startDate)} - startMienIndex: $startMienIndex (${mienOrder[startMienIndex]})');
      print('🔍 Starting with targetMienCount: $targetMienCount');
      print('📅 Estimated endDate: ${date_utils.DateUtils.formatDate(endDate)}');
      
      int initialMienCount = _countTargetMienOccurrences(
        startDate: _cycleResult!.lastSeenDate,
        endDate: startDate,
        targetMien: targetMien,
        allResults: _allResults,
      );

      print('📊 Initial mien count: $initialMienCount');

      // ✅ CHECK TUESDAY: Simulate để tìm 2 ngày cuối
      final simulatedRows = _simulateTableRows(
        startDate: startDate,
        startMienIndex: startMienIndex,
        targetMien: targetMien,
        targetCount: targetMienCount,
        mienOrder: mienOrder,
        initialCount: initialMienCount,
      );

      // ✅ Check Tuesday logic - CHỈ TĂNG LƯỢT, KHÔNG TĂNG BUDGET
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
          
          print('🔍 Last date: ${date_utils.DateUtils.formatDate(lastDate)} - Weekday: $lastWeekday');
          print('🔍 Second last date: ${date_utils.DateUtils.formatDate(secondLastDate)} - Weekday: $secondLastWeekday');
          
          bool needExtraTurn = false;
          
          final lastDateHasNam = simulatedRows.any((row) => 
            (row['date'] as DateTime).isAtSameMomentAs(lastDate) && 
            row['mien'] == 'Nam'
          );
          
          if (lastDateHasNam && lastWeekday == 1) {
            print('   ⚠️ Last date has Nam on Tuesday!');
            needExtraTurn = true;
          }
          
          if (!needExtraTurn) {
            final secondLastDateHasNam = simulatedRows.any((row) => 
              (row['date'] as DateTime).isAtSameMomentAs(secondLastDate) && 
              row['mien'] == 'Nam'
            );
            
            if (secondLastDateHasNam && secondLastWeekday == 1) {
              print('   ⚠️ Second last date has Nam on Tuesday!');
              needExtraTurn = true;
            }
          }
          
          if (needExtraTurn) {
            print('📅 Adding extra turn (9 → 10) - NO budget increase');
            targetMienCount = 10;
            // ✅ KHÔNG TĂNG budgetMax
          }
        }
      }

      print('🎯 Final targetMienCount: $targetMienCount');
      print('💰 Final budgetMax: ${NumberUtils.formatCurrency(budgetMax)}');

      // ✅ BƯỚC 4: Generate table
      final newTable = await _bettingService.generateCycleTable(
        cycleResult: _cycleResult!,
        startDate: startDate,
        endDate: endDate,
        startMienIndex: startMienIndex,
        budgetMin: budgetMax * 0.95,  // ✅ -5% flexibility
        budgetMax: budgetMax,
        allResults: _allResults,
        maxMienCount: targetMienCount,
      );

      await _saveCycleTableToSheet(newTable);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Lỗi tạo bảng: $e';
      _isLoading = false;
      notifyListeners();
    }
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


  Future<void> createCycleBettingTableForNumber(
    String targetNumber,
    AppConfig config,
  ) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // ✅ BƯỚC 1: Analyze số đó
      final numberDetail = await _analysisService.analyzeNumberDetail(
        _allResults,
        targetNumber,
      );

      if (numberDetail == null) {
        throw Exception('Không tìm thấy thông tin số $targetNumber');
      }

      int maxDaysGan = 0;
      DateTime? lastSeenDate;
      String? selectedMien;

      for (final entry in numberDetail.mienDetails.entries) {
        if (entry.value.daysGan > maxDaysGan) {
          maxDaysGan = entry.value.daysGan;
          lastSeenDate = entry.value.lastSeenDate;
          selectedMien = entry.key;
        }
      }

      if (lastSeenDate == null) {
        throw Exception('Không tìm thấy ngày xuất hiện cuối');
      }

      final customCycleResult = CycleAnalysisResult(
        ganNumbers: {targetNumber},
        maxGanDays: maxDaysGan,
        lastSeenDate: lastSeenDate,
        mienGroups: {selectedMien!: [targetNumber]},
        targetNumber: targetNumber,
      );

      // ✅ BƯỚC 2: Tính budget khả dụng
      final budgetService = BudgetCalculationService(
        sheetsService: _sheetsService,
      );
      
      final availableBudget = await budgetService.calculateTatCaBudget(
        config.budget.totalCapital,
      );
      
      print('💰 Available budget for number $targetNumber: ${NumberUtils.formatCurrency(availableBudget)}');
      
      // ✅ Validate budget
      if (availableBudget <= 50000) {
        throw Exception(
          'Không đủ vốn để tạo bảng!\n'
          'Vốn khả dụng: ${NumberUtils.formatCurrency(availableBudget)} VNĐ\n'
          'Cần tối thiểu: 50,000 VNĐ'
        );
      }

      // ✅ BƯỚC 3: Tìm ngày bắt đầu
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

      final mienOrder = ['Nam', 'Trung', 'Bắc'];
      final latestMienIndex = mienOrder.indexOf(latestMien!);
      
      DateTime startDate;
      int startMienIndex;
      
      if (latestMienIndex == 2) {
        startDate = latestDate!.add(const Duration(days: 1));
        startMienIndex = 0;
      } else {
        startDate = latestDate!;
        startMienIndex = latestMienIndex + 1;
      }

      // ✅ BƯỚC 4: Tính số lượt
      int targetMienCount = 9;
      double budgetMax = availableBudget;  // ✅ Dùng budget động
      
      DateTime endDate = _calculateEndDateByMienCount(
        startDate: startDate,
        startMienIndex: startMienIndex,
        targetMien: selectedMien,
        targetCount: targetMienCount,
        mienOrder: mienOrder,
      );
      
      final lastTwoRows = _findLastTwoRows(
        startDate: startDate,
        endDate: endDate,
        startMienIndex: startMienIndex,
        mienOrder: mienOrder,
      );
      
      bool needExtraTurn = false;
      
      if (lastTwoRows['last'] != null) {
        final lastRow = lastTwoRows['last']!;
        final lastWeekday = date_utils.DateUtils.getWeekday(lastRow['date']);
        if (lastRow['mien'] == 'Nam' && lastWeekday == 1) {
          needExtraTurn = true;
        }
      }
      
      if (!needExtraTurn && lastTwoRows['secondLast'] != null) {
        final secondLast = lastTwoRows['secondLast']!;
        final secondWeekday = date_utils.DateUtils.getWeekday(secondLast['date']);
        if (secondLast['mien'] == 'Nam' && secondWeekday == 1) {
          needExtraTurn = true;
        }
      }
      
      if (needExtraTurn) {
        targetMienCount = 10;
        // ✅ KHÔNG TĂNG budgetMax
        
        endDate = _calculateEndDateByMienCount(
          startDate: startDate,
          startMienIndex: startMienIndex,
          targetMien: selectedMien,
          targetCount: targetMienCount,
          mienOrder: mienOrder,
        );
      }

      // ✅ BƯỚC 5: Generate table
      final newTable = await _bettingService.generateCycleTable(
        cycleResult: customCycleResult,
        startDate: startDate,
        endDate: endDate,
        startMienIndex: startMienIndex,
        budgetMin: budgetMax * 0.95,
        budgetMax: budgetMax,
        allResults: _allResults,
        maxMienCount: targetMienCount,
      );

      await _saveCycleTableToSheet(newTable);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Lỗi tạo bảng: $e';
      _isLoading = false;
      notifyListeners();
    }
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
      
      final config = await _storageService.loadConfig();
      
      final newTable = await _bettingService.generateXienTable(
        ganInfo: _ganPairInfo!,
        startDate: startDate,
        xienBudget: config?.budget.xienBudget ?? 19000.0,
      );

      await _saveXienTableToSheet(newTable);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Lỗi tạo bảng: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _saveCycleTableToSheet(List<dynamic> table) async {
    await _sheetsService.clearSheet('xsktBot1');

    await _sheetsService.updateRange(
      'xsktBot1',
      'A1:D1',
      [
        [
          _cycleResult!.maxGanDays.toString(),
          date_utils.DateUtils.formatDate(_cycleResult!.lastSeenDate),
          _cycleResult!.ganNumbersDisplay,
          _cycleResult!.targetNumber,
        ]
      ],
    );

    await _sheetsService.updateRange(
      'xsktBot1',
      'A3:J3',
      [
        ['STT', 'Ngày', 'Miền', 'Số', 'Số lô', 'Cược/số', 'Cược/miền', 'Tổng tiền', 'Lời (1 số)', 'Lời (2 số)']
      ],
    );

    final dataRows = table.map((row) => row.toSheetRow()).toList().cast<List<String>>();
    await _sheetsService.updateRange('xsktBot1', 'A4', dataRows);
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
      buffer.writeln('<b>📊 PHÂN TÍCH CHU KỲ 00-99 📊</b>\n');
      buffer.writeln('<b>Filter:</b> $_selectedMien\n');
      buffer.writeln('<b>Số ngày gan:</b> ${_cycleResult!.maxGanDays} ngày');
      buffer.writeln('<b>Lần cuối về:</b> ${date_utils.DateUtils.formatDate(_cycleResult!.lastSeenDate)}');
      buffer.writeln('<b>Số mục tiêu:</b> ${_cycleResult!.targetNumber}\n');
      
      buffer.writeln('<b>Nhóm số gan nhất:</b>');
      buffer.writeln(_cycleResult!.ganNumbersDisplay);
      buffer.writeln();
      
      buffer.writeln('<b>Phân bổ theo miền:</b>');
      for (final mien in ['Nam', 'Trung', 'Bắc']) {
        if (_cycleResult!.mienGroups.containsKey(mien)) {
          buffer.writeln('- Miền $mien: ${_cycleResult!.mienGroups[mien]!.join(", ")}');
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
      buffer.writeln('<b>📈 CẶP SỐ GAN MIỀN BẮC 📈</b>\n');
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

  /// Tạo bảng cược cho số gan Miền Bắc
  Future<void> createBacGanBettingTable(
    String targetNumber,
    AppConfig config,
  ) async {
    print('🎯 Creating Bắc gan betting table for number: $targetNumber');
    
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final numberDetail = await _analysisService.analyzeNumberDetail(
        _allResults,
        targetNumber,
      );

      if (numberDetail == null) {
        throw Exception('Không tìm thấy thông tin số $targetNumber');
      }

      final bacDetail = numberDetail.mienDetails['Bắc'];
      if (bacDetail == null) {
        throw Exception('Số $targetNumber chưa có dữ liệu Miền Bắc');
      }

      final customCycleResult = CycleAnalysisResult(
        ganNumbers: {targetNumber},
        maxGanDays: bacDetail.daysGan,
        lastSeenDate: bacDetail.lastSeenDate,
        mienGroups: {'Bắc': [targetNumber]},
        targetNumber: targetNumber,
      );

      final latestDate = _allResults
          .map((r) => date_utils.DateUtils.parseDate(r.ngay))
          .where((d) => d != null)
          .reduce((a, b) => a!.isAfter(b!) ? a : b);

      final startDate = latestDate!.add(const Duration(days: 1));
      final endDate = bacDetail.lastSeenDate.add(const Duration(days: 35));

      // ✅ Dùng bacBudget từ config
      final budgetMax = config.budget.bacBudget;
      final budgetMin = budgetMax * 0.95;
      
      print('💰 Bắc budget: ${NumberUtils.formatCurrency(budgetMax)}');

      final newTable = await _bettingService.generateBacGanTable(
        cycleResult: customCycleResult,
        startDate: startDate,
        endDate: endDate,
        budgetMin: budgetMin,
        budgetMax: budgetMax,
      );

      await _saveBacTableToSheet(newTable, customCycleResult);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Lỗi tạo bảng: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Tạo bảng cược cho số gan Miền Trung
  Future<void> createTrungGanBettingTable(
    String targetNumber,
    AppConfig config,
  ) async {
    print('🎯 Creating Trung gan betting table for number: $targetNumber');
    
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final numberDetail = await _analysisService.analyzeNumberDetail(
        _allResults,
        targetNumber,
      );

      if (numberDetail == null) {
        throw Exception('Không tìm thấy thông tin số $targetNumber');
      }

      final trungDetail = numberDetail.mienDetails['Trung'];
      if (trungDetail == null) {
        throw Exception('Số $targetNumber chưa có dữ liệu Miền Trung');
      }

      final customCycleResult = CycleAnalysisResult(
        ganNumbers: {targetNumber},
        maxGanDays: trungDetail.daysGan,
        lastSeenDate: trungDetail.lastSeenDate,
        mienGroups: {'Trung': [targetNumber]},
        targetNumber: targetNumber,
      );

      final latestDate = _allResults
          .map((r) => date_utils.DateUtils.parseDate(r.ngay))
          .where((d) => d != null)
          .reduce((a, b) => a!.isAfter(b!) ? a : b);

      final startDate = latestDate!.add(const Duration(days: 1));
      final endDate = trungDetail.lastSeenDate.add(const Duration(days: 35));

      // ✅ Dùng trungBudget từ config
      final budgetMax = config.budget.trungBudget;
      final budgetMin = budgetMax * 0.95;
      
      print('💰 Trung budget: ${NumberUtils.formatCurrency(budgetMax)}');

      final newTable = await _bettingService.generateTrungGanTable(
        cycleResult: customCycleResult,
        startDate: startDate,
        endDate: endDate,
        budgetMin: budgetMin,
        budgetMax: budgetMax,
      );

      await _saveTrungTableToSheet(newTable, customCycleResult);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Lỗi tạo bảng: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<CycleAnalysisResult?> analyzeCycleForAllMien() async {
    return await _analysisService.analyzeCycle(_allResults);
  }

  /// Phân tích chu kỳ cho một miền cụ thể
  Future<CycleAnalysisResult?> analyzeCycleForMien(String mien) async {
    final filteredResults = _allResults.where((r) => r.mien == mien).toList();
    return await _analysisService.analyzeCycle(filteredResults);
  }

  Future<void> _saveTrungTableToSheet(
    List<dynamic> table,
    CycleAnalysisResult cycleResult,
  ) async {
    print('📝 Saving trung table to trungBot sheet...');
    
    await _sheetsService.clearSheet('trungBot');

    await _sheetsService.updateRange(
      'trungBot',
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

    await _sheetsService.updateRange(
      'trungBot',
      'A3:J3',
      [
        ['STT', 'Ngày', 'Miền', 'Số', 'Số lô', 'Cược/số', 'Cược/miền', 'Tổng tiền', 'Lời (1 số)', 'Lời (2 số)']
      ],
    );

    final dataRows = table.map((row) => row.toSheetRow()).toList().cast<List<String>>();
    await _sheetsService.updateRange('trungBot', 'A4', dataRows);
    
    print('✅ Trung table saved to trungBot!');
  }

  Future<void> _saveBacTableToSheet(
    List<dynamic> table,
    CycleAnalysisResult cycleResult,
  ) async {
    print('📝 Saving bac table to bacBot sheet...');
    
    await _sheetsService.clearSheet('bacBot');

    await _sheetsService.updateRange(
      'bacBot',
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

    await _sheetsService.updateRange(
      'bacBot',
      'A3:J3',
      [
        ['STT', 'Ngày', 'Miền', 'Số', 'Số lô', 'Cược/số', 'Cược/miền', 'Tổng tiền', 'Lời (1 số)', 'Lời (2 số)']
      ],
    );

    final dataRows = table.map((row) => row.toSheetRow()).toList().cast<List<String>>();
    await _sheetsService.updateRange('bacBot', 'A4', dataRows);
    
    print('✅ Bac table saved to bacBot!');
  }

  // ✅ Alert getters (BỎ hasCycleAlert cho "Tất cả")
  bool get hasCycleAlert {
    // ✅ KIỂM TRA ĐÚNG CHO "TẤT CẢ"
    if (_cycleResult == null) return false;
    if (_selectedMien != 'Tất cả') return false;
    return _cycleResult!.maxGanDays > 3;
  }

  /// Kiểm tra Trung có gan > 14 ngày
  bool get hasTrungAlert {
    if (_cycleResult == null) return false;
    if (_selectedMien != 'Trung') return false;
    return _cycleResult!.maxGanDays > 14;
  }

  /// Kiểm tra Bắc có gan > 16 ngày
  bool get hasBacAlert {
    if (_cycleResult == null) return false;
    if (_selectedMien != 'Bắc') return false;
    return _cycleResult!.maxGanDays > 16;
  }

  /// Kiểm tra Xiên có gan > 2 ngày
  bool get hasXienAlert {
    if (_ganPairInfo == null) return false;
    return _ganPairInfo!.daysGan > 152;
  }

  /// ✅ Kiểm tra có bất kỳ alert nào (dùng cache)
  bool get hasAnyAlert {
    bool hasAlert = false;
    
    // Check Xiên
    if (_ganPairInfo != null && _ganPairInfo!.daysGan > 152) {
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

  /// Lấy thông tin alert cho từng filter
  Map<String, AlertInfo> getAlertInfo() {
    final alerts = <String, AlertInfo>{};
    
    // Check Xiên
    if (_ganPairInfo != null && _ganPairInfo!.daysGan > 152) {
      alerts['Xiên'] = AlertInfo(
        threshold: 152,
        currentDays: _ganPairInfo!.daysGan,
        targetNumber: _ganPairInfo!.randomPair.display,
      );
    }
    
    // ✅ CHECK TẤT CẢ
    if (_tatCaAlertCache == true) {
      alerts['Tất cả'] = AlertInfo(
        threshold: 3,
        currentDays: _cycleResult?.maxGanDays ?? 0,
        targetNumber: _cycleResult?.targetNumber ?? '',
      );
    }
    
    // Check Trung
    if (_trungAlertCache == true) {
      alerts['Trung'] = AlertInfo(
        threshold: 14,
        currentDays: _cycleResult?.maxGanDays ?? 0,
        targetNumber: _cycleResult?.targetNumber ?? '',
      );
    }
    
    // Check Bắc
    if (_bacAlertCache == true) {
      alerts['Bắc'] = AlertInfo(
        threshold: 16,
        currentDays: _cycleResult?.maxGanDays ?? 0,
        targetNumber: _cycleResult?.targetNumber ?? '',
      );
    }
    
    return alerts;
  }

  /// Lấy message thông báo
  String getAlertMessage() {
    final messages = <String>[];
    
    if (hasXienAlert) {
      messages.add('🔥 Xiên: ${_ganPairInfo!.daysGan} ngày (>152)');
    }
    
    // ✅ THÊM MESSAGE CHO "TẤT CẢ"
    if (_tatCaAlertCache == true) {
      messages.add('🔥 Chu kỳ (Tất cả): gan >3 ngày');
    }
    
    if (_trungAlertCache == true) {
      messages.add('🔥 Trung: gan >14 ngày');
    }
    
    if (_bacAlertCache == true) {
      messages.add('🔥 Bắc: gan >16 ngày');
    }
    
    if (messages.isEmpty) {
      return 'Chưa có số nào thỏa điều kiện';
    }
    
    return messages.join('\n');
  }
}

// ✅ Model cho alert info
class AlertInfo {
  final int threshold;
  final int currentDays;
  final String targetNumber;

  AlertInfo({
    required this.threshold,
    required this.currentDays,
    required this.targetNumber,
  });

  bool get isAlert => currentDays > threshold;
}