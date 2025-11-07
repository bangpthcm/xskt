// lib/presentation/screens/betting/betting_viewmodel.dart
import 'package:flutter/material.dart';
import '../../../data/models/betting_row.dart';
import '../../../data/models/gan_pair_info.dart';
import '../../../data/models/cycle_analysis_result.dart';
import '../../../data/models/lottery_result.dart';
import '../../../data/services/google_sheets_service.dart';
import '../../../data/services/betting_table_service.dart';
import '../../../data/services/telegram_service.dart';
import '../../../data/services/analysis_service.dart';
import '../../../data/models/app_config.dart';
import '../../../core/utils/date_utils.dart' as date_utils;
import '../../../data/services/budget_calculation_service.dart';
import '../../../core/utils/number_utils.dart';
import '../../../data/services/budget_calculation_service.dart';
import '../../../data/services/telegram_service.dart';

enum BettingTableType { xien, cycle, trung, bac }  // ✅ ADD trung, bac

class BettingViewModel extends ChangeNotifier {
  final GoogleSheetsService _sheetsService;
  final BettingTableService _bettingService;
  final TelegramService _telegramService;
  final AnalysisService _analysisService;

  BettingViewModel({
    required GoogleSheetsService sheetsService,
    required BettingTableService bettingService,
    required TelegramService telegramService,
    required AnalysisService analysisService,
  })  : _sheetsService = sheetsService,
        _bettingService = bettingService,
        _telegramService = telegramService,
        _analysisService = analysisService;

  bool _isLoading = false;
  String? _errorMessage;
  List<BettingRow>? _xienTable;
  List<BettingRow>? _cycleTable;
  List<BettingRow>? _trungTable;  // ✅ ADD
  List<BettingRow>? _bacTable;     // ✅ ADD
  Map<String, dynamic>? _xienMetadata;
  Map<String, dynamic>? _cycleMetadata;
  Map<String, dynamic>? _trungMetadata;  // ✅ ADD
  Map<String, dynamic>? _bacMetadata;     // ✅ ADD

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<BettingRow>? get xienTable => _xienTable;
  List<BettingRow>? get cycleTable => _cycleTable;
  List<BettingRow>? get trungTable => _trungTable;  // ✅ ADD
  List<BettingRow>? get bacTable => _bacTable;       // ✅ ADD
  Map<String, dynamic>? get xienMetadata => _xienMetadata;
  Map<String, dynamic>? get cycleMetadata => _cycleMetadata;
  Map<String, dynamic>? get trungMetadata => _trungMetadata;  // ✅ ADD
  Map<String, dynamic>? get bacMetadata => _bacMetadata;       // ✅ ADD

  // ✅ HELPER FUNCTION GLOBAL
  /// ✅ Parse number từ Google Sheets (format VN: dấu chấm = nghìn)
  static double _parseSheetNumber(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    
    String str = value.toString().trim();
    if (str.isEmpty) return 0.0;
    
    int dotCount = '.'.allMatches(str).length;
    int commaCount = ','.allMatches(str).length;
    
    // CASE 1: Có cả chấm VÀ phẩy
    if (dotCount > 0 && commaCount > 0) {
      str = str.replaceAll('.', '').replaceAll(',', '.');
    }
    // CASE 2: Chỉ có dấu chấm
    else if (dotCount > 0) {
      if (dotCount > 1) {
        str = str.replaceAll('.', '');
      } else {
        final dotIndex = str.indexOf('.');
        final afterDot = str.length - dotIndex - 1;
        if (afterDot == 3) {
          str = str.replaceAll('.', '');
        }
      }
    }
    // CASE 3: Chỉ có dấu phẩy
    else if (commaCount > 0) {
      if (commaCount > 1) {
        str = str.replaceAll(',', '');
      } else {
        final commaIndex = str.indexOf(',');
        final afterComma = str.length - commaIndex - 1;
        if (afterComma <= 2) {
          str = str.replaceAll(',', '.');
        } else if (afterComma == 3) {
          str = str.replaceAll(',', '');
        }
      }
    }
    
    str = str.replaceAll(' ', '');
    
    try {
      return double.parse(str);
    } catch (e) {
      return 0.0;
    }
  }
  
  static int _parseSheetInt(dynamic value) {
    return _parseSheetNumber(value).round();
  }

  Future<void> loadBettingTables() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _loadXienTable();
      await _loadCycleTable();
      await _loadTrungTable();  // ✅ ADD
      await _loadBacTable();     // ✅ ADD

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Lỗi tải bảng cược: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadXienTable() async {
    try {
      print('🔍 Loading xien table from xienBot...');
      final values = await _sheetsService.getAllValues('xienBot');
      
      if (values.isEmpty || values.length < 4) {
        _xienTable = null;
        _xienMetadata = null;
        return;
      }

      _xienMetadata = {
        'so_ngay_gan': values[0].isNotEmpty ? values[0][0] : '',
        'lan_cuoi_ve': values[0].length > 1 ? values[0][1] : '',
        'nhom_cap_so': values[0].length > 2 ? values[0][2] : '',
        'cap_so_muc_tieu': values[0].length > 3 ? values[0][3] : '',
      };

      _xienTable = [];
      for (int i = 3; i < values.length; i++) {
        final row = values[i];
        if (row.isEmpty || row[0].toString().trim().isEmpty) continue;
        if (row.length < 7) continue;

        try {
          _xienTable!.add(BettingRow.forXien(
            stt: int.parse(row[0].toString().trim()),
            ngay: row[1].toString().trim(),
            mien: row[2].toString().trim(),
            so: row[3].toString().trim(),
            cuocMien: _parseSheetNumber(row[4]),
            tongTien: _parseSheetNumber(row[5]),
            loi: _parseSheetNumber(row[6]),
          ));
        } catch (e) {
          print('❌ Error parsing xien row $i: $e');
        }
      }
    } catch (e) {
      print('❌ Error loading xien table: $e');
      _xienTable = null;
      _xienMetadata = null;
    }
  }

  Future<void> _loadCycleTable() async {
    try {
      print('🔍 Loading cycle table from xsktBot1...');
      final values = await _sheetsService.getAllValues('xsktBot1');
      
      if (values.isEmpty || values.length < 4) {
        _cycleTable = null;
        _cycleMetadata = null;
        return;
      }

      _cycleMetadata = {
        'so_ngay_gan': values[0].isNotEmpty ? values[0][0] : '',
        'lan_cuoi_ve': values[0].length > 1 ? values[0][1] : '',
        'nhom_so_gan': values[0].length > 2 ? values[0][2] : '',
        'so_muc_tieu': values[0].length > 3 ? values[0][3] : '',
      };

      _cycleTable = [];
      for (int i = 3; i < values.length; i++) {
        final row = values[i];
        if (row.isEmpty || row[0].toString().trim().isEmpty) continue;
        if (row.length < 10) continue;

        try {
          _cycleTable!.add(BettingRow.forCycle(
            stt: int.parse(row[0].toString().trim()),
            ngay: row[1].toString().trim(),
            mien: row[2].toString().trim(),
            so: row[3].toString().trim(),
            soLo: _parseSheetInt(row[4]),
            cuocSo: _parseSheetNumber(row[5]),
            cuocMien: _parseSheetNumber(row[6]),
            tongTien: _parseSheetNumber(row[7]),
            loi1So: _parseSheetNumber(row[8]),
            loi2So: _parseSheetNumber(row[9]),
          ));
        } catch (e) {
          print('❌ Error parsing cycle row $i: $e');
        }
      }
    } catch (e) {
      print('❌ Error loading cycle table: $e');
      _cycleTable = null;
      _cycleMetadata = null;
    }
  }

  // ✅ ADD: Load Trung table
  Future<void> _loadTrungTable() async {
    try {
      print('🔍 Loading trung table from trungBot...');
      final values = await _sheetsService.getAllValues('trungBot');
      
      if (values.isEmpty || values.length < 4) {
        _trungTable = null;
        _trungMetadata = null;
        return;
      }

      _trungMetadata = {
        'so_ngay_gan': values[0].isNotEmpty ? values[0][0] : '',
        'lan_cuoi_ve': values[0].length > 1 ? values[0][1] : '',
        'nhom_so_gan': values[0].length > 2 ? values[0][2] : '',
        'so_muc_tieu': values[0].length > 3 ? values[0][3] : '',
      };

      _trungTable = [];
      for (int i = 3; i < values.length; i++) {
        final row = values[i];
        if (row.isEmpty || row[0].toString().trim().isEmpty) continue;
        if (row.length < 10) continue;

        try {
          _trungTable!.add(BettingRow.forCycle(
            stt: int.parse(row[0].toString().trim()),
            ngay: row[1].toString().trim(),
            mien: row[2].toString().trim(),
            so: row[3].toString().trim(),
            soLo: _parseSheetInt(row[4]),
            cuocSo: _parseSheetNumber(row[5]),
            cuocMien: _parseSheetNumber(row[6]),
            tongTien: _parseSheetNumber(row[7]),
            loi1So: _parseSheetNumber(row[8]),
            loi2So: _parseSheetNumber(row[9]),
          ));
        } catch (e) {
          print('❌ Error parsing trung row $i: $e');
        }
      }
    } catch (e) {
      print('❌ Error loading trung table: $e');
      _trungTable = null;
      _trungMetadata = null;
    }
  }

  // ✅ ADD: Load Bac table
  Future<void> _loadBacTable() async {
    try {
      print('🔍 Loading bac table from bacBot...');
      final values = await _sheetsService.getAllValues('bacBot');
      
      if (values.isEmpty || values.length < 4) {
        _bacTable = null;
        _bacMetadata = null;
        return;
      }

      _bacMetadata = {
        'so_ngay_gan': values[0].isNotEmpty ? values[0][0] : '',
        'lan_cuoi_ve': values[0].length > 1 ? values[0][1] : '',
        'nhom_so_gan': values[0].length > 2 ? values[0][2] : '',
        'so_muc_tieu': values[0].length > 3 ? values[0][3] : '',
      };

      _bacTable = [];
      for (int i = 3; i < values.length; i++) {
        final row = values[i];
        if (row.isEmpty || row[0].toString().trim().isEmpty) continue;
        if (row.length < 10) continue;

        try {
          _bacTable!.add(BettingRow.forCycle(
            stt: int.parse(row[0].toString().trim()),
            ngay: row[1].toString().trim(),
            mien: row[2].toString().trim(),
            so: row[3].toString().trim(),
            soLo: _parseSheetInt(row[4]),
            cuocSo: _parseSheetNumber(row[5]),
            cuocMien: _parseSheetNumber(row[6]),
            tongTien: _parseSheetNumber(row[7]),
            loi1So: _parseSheetNumber(row[8]),
            loi2So: _parseSheetNumber(row[9]),
          ));
        } catch (e) {
          print('❌ Error parsing bac row $i: $e');
        }
      }
    } catch (e) {
      print('❌ Error loading bac table: $e');
      _bacTable = null;
      _bacMetadata = null;
    }
  }

  Future<void> regenerateTable(BettingTableType type, AppConfig config) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (type == BettingTableType.xien) {
        await _regenerateXienTable(config);
      } else if (type == BettingTableType.cycle) {
        await _regenerateCycleTable(config);
      } else if (type == BettingTableType.trung) {  // ✅ ADD
        await _regenerateTrungTable(config);
      } else if (type == BettingTableType.bac) {    // ✅ ADD
        await _regenerateBacTable(config);
      }

      await loadBettingTables();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Lỗi tạo bảng: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  // ✅ ADD: Regenerate Trung table
  Future<void> _regenerateTrungTable(AppConfig config) async {
    final allValues = await _sheetsService.getAllValues('KQXS');
    final results = <LotteryResult>[];
    
    for (int i = 1; i < allValues.length; i++) {
      try {
        results.add(LotteryResult.fromSheetRow(allValues[i]));
      } catch (e) {}
    }

    final filteredResults = results.where((r) => r.mien == 'Trung').toList();
    final cycleResult = await _analysisService.analyzeCycle(filteredResults);
    
    if (cycleResult == null) {
      throw Exception('Không đủ điều kiện tạo bảng Miền Trung');
    }

    final latestDate = results
        .map((r) => date_utils.DateUtils.parseDate(r.ngay))
        .where((d) => d != null)
        .reduce((a, b) => a!.isAfter(b!) ? a : b);

    final startDate = latestDate!.add(const Duration(days: 1));
    final endDate = cycleResult.lastSeenDate.add(const Duration(days: 35));

    // ✅ NEW LOGIC: Tính budget động
    final budgetService = BudgetCalculationService(
      sheetsService: _sheetsService,
    );
    
    final budgetResult = await budgetService.calculateAvailableBudget(
      totalCapital: config.budget.totalCapital,
      targetTable: 'trung',
      configBudget: config.budget.trungBudget,
    );
    
    final budgetMax = budgetResult.budgetMax;
    final budgetMin = budgetMax * 0.95;
    
    print('💰 Trung budget (regenerate): ${NumberUtils.formatCurrency(budgetMax)}');

    try {
      final newTable = await _bettingService.generateTrungGanTable(
        cycleResult: cycleResult,
        startDate: startDate,
        endDate: endDate,
        budgetMin: budgetMin,
        budgetMax: budgetMax,
      );

      await _saveTrungTableToSheet(newTable, cycleResult);
      
    } catch (generateError) {
      print('❌ Generate table error: $generateError');
      
      try {
        final testTable = await _bettingService.generateTrungGanTable(
          cycleResult: cycleResult,
          startDate: startDate,
          endDate: endDate,
          budgetMin: 1.0,
          budgetMax: budgetMax * 2,
        );
        
        final estimatedTotal = testTable.isNotEmpty ? testTable.last.tongTien : budgetMax;
        
        throw OptimizationFailedException(
          tableName: 'Miền Trung',
          budgetResult: budgetResult,
          estimatedTotal: estimatedTotal,
        );
      } catch (testError) {
        rethrow;
      }
    }
  }

  // ✅ ADD: Regenerate Bac table
  Future<void> _regenerateBacTable(AppConfig config) async {
    final allValues = await _sheetsService.getAllValues('KQXS');
    final results = <LotteryResult>[];
    
    for (int i = 1; i < allValues.length; i++) {
      try {
        results.add(LotteryResult.fromSheetRow(allValues[i]));
      } catch (e) {}
    }

    final filteredResults = results.where((r) => r.mien == 'Bắc').toList();
    final cycleResult = await _analysisService.analyzeCycle(filteredResults);
    
    if (cycleResult == null) {
      throw Exception('Không đủ điều kiện tạo bảng Miền Bắc');
    }

    final latestDate = results
        .map((r) => date_utils.DateUtils.parseDate(r.ngay))
        .where((d) => d != null)
        .reduce((a, b) => a!.isAfter(b!) ? a : b);

    final startDate = latestDate!.add(const Duration(days: 1));
    final endDate = cycleResult.lastSeenDate.add(const Duration(days: 35));

    // ✅ NEW LOGIC: Tính budget động
    final budgetService = BudgetCalculationService(
      sheetsService: _sheetsService,
    );
    
    final budgetResult = await budgetService.calculateAvailableBudget(
      totalCapital: config.budget.totalCapital,
      targetTable: 'bac',
      configBudget: config.budget.bacBudget,
    );
    
    final budgetMax = budgetResult.budgetMax;
    final budgetMin = budgetMax * 0.95;
    
    print('💰 Bắc budget (regenerate): ${NumberUtils.formatCurrency(budgetMax)}');

    try {
      final newTable = await _bettingService.generateBacGanTable(
        cycleResult: cycleResult,
        startDate: startDate,
        endDate: endDate,
        budgetMin: budgetMin,
        budgetMax: budgetMax,
      );

      await _saveBacTableToSheet(newTable, cycleResult);
      
    } catch (generateError) {
      print('❌ Generate table error: $generateError');
      
      try {
        final testTable = await _bettingService.generateBacGanTable(
          cycleResult: cycleResult,
          startDate: startDate,
          endDate: endDate,
          budgetMin: 1.0,
          budgetMax: budgetMax * 2,
        );
        
        final estimatedTotal = testTable.isNotEmpty ? testTable.last.tongTien : budgetMax;
        
        throw OptimizationFailedException(
          tableName: 'Miền Bắc',
          budgetResult: budgetResult,
          estimatedTotal: estimatedTotal,
        );
      } catch (testError) {
        rethrow;
      }
    }
  }

  Future<void> _regenerateXienTable(AppConfig config) async {
    final allValues = await _sheetsService.getAllValues('KQXS');
    final results = <LotteryResult>[];
    
    for (int i = 1; i < allValues.length; i++) {
      try {
        results.add(LotteryResult.fromSheetRow(allValues[i]));
      } catch (e) {}
    }

    final ganInfo = await _analysisService.findGanPairsMienBac(results);
    
    if (ganInfo == null) {
      throw Exception('Không đủ điều kiện tạo bảng xiên');
    }

    final latestDate = results
        .map((r) => date_utils.DateUtils.parseDate(r.ngay))
        .where((d) => d != null)
        .reduce((a, b) => a!.isAfter(b!) ? a : b);

    final startDate = latestDate!.add(const Duration(days: 1));
    
    // ✅ NEW LOGIC: Tính budget động
    final budgetService = BudgetCalculationService(
      sheetsService: _sheetsService,
    );
    
    final budgetResult = await budgetService.calculateAvailableBudget(
      totalCapital: config.budget.totalCapital,
      targetTable: 'xien',
      configBudget: config.budget.xienBudget,
    );
    
    final xienBudget = budgetResult.budgetMax;
    
    print('💰 Xiên budget (regenerate): ${NumberUtils.formatCurrency(xienBudget)}');
    
    try {
      final newTable = await _bettingService.generateXienTable(
        ganInfo: ganInfo,
        startDate: startDate,
        xienBudget: xienBudget,
      );

      await _saveXienTableToSheet(newTable, ganInfo);
      
    } catch (generateError) {
      print('❌ Generate table error: $generateError');
      
      try {
        final testTable = await _bettingService.generateXienTable(
          ganInfo: ganInfo,
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
  }

  Future<void> _regenerateCycleTable(AppConfig config) async {
    final allValues = await _sheetsService.getAllValues('KQXS');
    final results = <LotteryResult>[];
    
    for (int i = 1; i < allValues.length; i++) {
      try {
        results.add(LotteryResult.fromSheetRow(allValues[i]));
      } catch (e) {}
    }

    final cycleResult = await _analysisService.analyzeCycle(results);
    
    if (cycleResult == null) {
      throw Exception('Không đủ điều kiện tạo bảng chu kỳ');
    }

    // ✅ NEW LOGIC: Tính budget động
    final budgetService = BudgetCalculationService(
      sheetsService: _sheetsService,
    );
    
    final budgetResult = await budgetService.calculateAvailableBudget(
      totalCapital: config.budget.totalCapital,
      targetTable: 'tatca',
      configBudget: null,
    );
    
    final budgetMax = budgetResult.budgetMax;
    
    print('💰 Available budget for Tất cả (regenerate): ${NumberUtils.formatCurrency(budgetMax)}');

    // ✅ BƯỚC 2: Tìm ngày bắt đầu
    DateTime? latestDate;
    String? latestMien;
    
    for (final result in results) {
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

    String targetMien = 'Nam';
    for (final entry in cycleResult.mienGroups.entries) {
      if (entry.value.contains(cycleResult.targetNumber)) {
        targetMien = entry.key;
        break;
      }
    }

    // ✅ BƯỚC 3: Tính số lượt
    int targetMienCount = 9;
    
    DateTime endDate = _calculateEndDateByMienCount(
      startDate: startDate,
      startMienIndex: startMienIndex,
      targetMien: targetMien,
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
      print('📅 Adding extra turn (9 → 10)');
      targetMienCount = 10;
      
      endDate = _calculateEndDateByMienCount(
        startDate: startDate,
        startMienIndex: startMienIndex,
        targetMien: targetMien,
        targetCount: targetMienCount,
        mienOrder: mienOrder,
      );
    }

    print('🎯 Final targetMienCount: $targetMienCount');
    print('💰 Final budgetMax: ${NumberUtils.formatCurrency(budgetMax)}');

    // ✅ BƯỚC 4: Generate table
    try {
      final newTable = await _bettingService.generateCycleTable(
        cycleResult: cycleResult,
        startDate: startDate,
        endDate: endDate,
        startMienIndex: startMienIndex,
        budgetMin: budgetMax * 0.95,
        budgetMax: budgetMax,
        allResults: results,
        maxMienCount: targetMienCount,
      );

      await _saveCycleTableToSheet(newTable, cycleResult);
      
    } catch (generateError) {
      print('❌ Generate table error: $generateError');
      
      try {
        final testTable = await _bettingService.generateCycleTable(
          cycleResult: cycleResult,
          startDate: startDate,
          endDate: endDate,
          startMienIndex: startMienIndex,
          budgetMin: 1.0,
          budgetMax: budgetMax * 2,
          allResults: results,
          maxMienCount: targetMienCount,
        );
        
        final estimatedTotal = testTable.isNotEmpty ? testTable.last.tongTien : budgetMax;
        
        throw OptimizationFailedException(
          tableName: 'Tất cả',
          budgetResult: budgetResult,
          estimatedTotal: estimatedTotal,
        );
      } catch (testError) {
        rethrow;
      }
    }
  }

  // ✅ COPY 2 HELPER FUNCTIONS
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

  // ✅ HELPER METHODS (thêm vào class BettingViewModel)
  bool _doesMienDrawOnDay(String mien, int weekday) {
    if (mien == 'Nam') {
      return weekday != 4;  // Không quay thứ 6
    } else if (mien == 'Trung') {
      return weekday != 4;  // Không quay thứ 6
    } else {
      return true;  // Bắc quay mỗi ngày
    }
  }

  bool _isMienLater(String newMien, String oldMien) {
    const mienPriority = {'Nam': 1, 'Trung': 2, 'Bắc': 3};
    return (mienPriority[newMien] ?? 0) > (mienPriority[oldMien] ?? 0);
  }

  Future<void> _saveXienTableToSheet(List<BettingRow> table, GanPairInfo ganInfo) async {
    await _sheetsService.clearSheet('xienBot');
    await _sheetsService.updateRange('xienBot', 'A1:D1', [
      [ganInfo.daysGan.toString(), date_utils.DateUtils.formatDate(ganInfo.lastSeen), 
       ganInfo.pairsDisplay, table.first.so]
    ]);
    await _sheetsService.updateRange('xienBot', 'A3:G3', [
      ['STT', 'Ngày', 'Miền', 'Số', 'Cược/miền', 'Tổng tiền', 'Lời']
    ]);
    await _sheetsService.updateRange('xienBot', 'A4', table.map((r) => r.toSheetRow()).toList());
  }

  Future<void> _saveCycleTableToSheet(List<BettingRow> table, CycleAnalysisResult cycleResult) async {
    await _sheetsService.clearSheet('xsktBot1');
    await _sheetsService.updateRange('xsktBot1', 'A1:D1', [
      [cycleResult.maxGanDays.toString(), date_utils.DateUtils.formatDate(cycleResult.lastSeenDate),
       cycleResult.ganNumbersDisplay, cycleResult.targetNumber]
    ]);
    await _sheetsService.updateRange('xsktBot1', 'A3:J3', [
      ['STT', 'Ngày', 'Miền', 'Số', 'Số lô', 'Cược/số', 'Cược/miền', 'Tổng tiền', 'Lời (1 số)', 'Lời (2 số)']
    ]);
    await _sheetsService.updateRange('xsktBot1', 'A4', table.map((r) => r.toSheetRow()).toList());
  }

  // ✅ ADD: Save Trung table
  Future<void> _saveTrungTableToSheet(List<BettingRow> table, CycleAnalysisResult cycleResult) async {
    await _sheetsService.clearSheet('trungBot');
    await _sheetsService.updateRange('trungBot', 'A1:D1', [
      [cycleResult.maxGanDays.toString(), date_utils.DateUtils.formatDate(cycleResult.lastSeenDate),
       cycleResult.ganNumbersDisplay, cycleResult.targetNumber]
    ]);
    await _sheetsService.updateRange('trungBot', 'A3:J3', [
      ['STT', 'Ngày', 'Miền', 'Số', 'Số lô', 'Cược/số', 'Cược/miền', 'Tổng tiền', 'Lời (1 số)', 'Lời (2 số)']
    ]);
    await _sheetsService.updateRange('trungBot', 'A4', table.map((r) => r.toSheetRow()).toList());
  }

  // ✅ ADD: Save Bac table
  Future<void> _saveBacTableToSheet(List<BettingRow> table, CycleAnalysisResult cycleResult) async {
    await _sheetsService.clearSheet('bacBot');
    await _sheetsService.updateRange('bacBot', 'A1:D1', [
      [cycleResult.maxGanDays.toString(), date_utils.DateUtils.formatDate(cycleResult.lastSeenDate),
       cycleResult.ganNumbersDisplay, cycleResult.targetNumber]
    ]);
    await _sheetsService.updateRange('bacBot', 'A3:J3', [
      ['STT', 'Ngày', 'Miền', 'Số', 'Số lô', 'Cược/số', 'Cược/miền', 'Tổng tiền', 'Lời (1 số)', 'Lời (2 số)']
    ]);
    await _sheetsService.updateRange('bacBot', 'A4', table.map((r) => r.toSheetRow()).toList());
  }

  Future<void> sendToTelegram(BettingTableType type) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (type == BettingTableType.xien) {
        if (_xienTable == null || _xienMetadata == null) {
          throw Exception('Chưa có bảng xiên');
        }
        final message = _telegramService.formatXienTableMessage(
          _xienTable!, _xienMetadata!['cap_so_muc_tieu'],
          int.parse(_xienMetadata!['so_ngay_gan']), _xienMetadata!['lan_cuoi_ve'],
        );
        await _telegramService.sendMessage(message);
      } else if (type == BettingTableType.cycle) {
        if (_cycleTable == null || _cycleMetadata == null) {
          throw Exception('Chưa có bảng chu kỳ');
        }
        // ✅ SỬ DỤNG METHOD MỚI VỚI TYPE
        final message = _telegramService.formatCycleTableMessageWithType(
          _cycleTable!, 
          _cycleMetadata!['nhom_so_gan'], 
          _cycleMetadata!['so_muc_tieu'],
          TelegramTableType.tatCa,  // ✅ TRUYỀN TYPE
        );
        await _telegramService.sendMessage(message);
      } else if (type == BettingTableType.trung) {
        if (_trungTable == null || _trungMetadata == null) {
          throw Exception('Chưa có bảng Miền Trung');
        }
        // ✅ SỬ DỤNG METHOD MỚI VỚI TYPE
        final message = _telegramService.formatCycleTableMessageWithType(
          _trungTable!, 
          _trungMetadata!['nhom_so_gan'], 
          _trungMetadata!['so_muc_tieu'],
          TelegramTableType.trung,  // ✅ TRUYỀN TYPE
        );
        await _telegramService.sendMessage(message);
      } else if (type == BettingTableType.bac) {
        if (_bacTable == null || _bacMetadata == null) {
          throw Exception('Chưa có bảng Miền Bắc');
        }
        // ✅ SỬ DỤNG METHOD MỚI VỚI TYPE
        final message = _telegramService.formatCycleTableMessageWithType(
          _bacTable!, 
          _bacMetadata!['nhom_so_gan'], 
          _bacMetadata!['so_muc_tieu'],
          TelegramTableType.bac,  // ✅ TRUYỀN TYPE
        );
        await _telegramService.sendMessage(message);
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Lỗi gửi Telegram: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteTable(BettingTableType type) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (type == BettingTableType.xien) {
        await _sheetsService.clearSheet('xienBot');
        _xienTable = null;
        _xienMetadata = null;
      } else if (type == BettingTableType.cycle) {
        await _sheetsService.clearSheet('xsktBot1');
        _cycleTable = null;
        _cycleMetadata = null;
      } else if (type == BettingTableType.trung) {  // ✅ ADD
        await _sheetsService.clearSheet('trungBot');
        _trungTable = null;
        _trungMetadata = null;
      } else if (type == BettingTableType.bac) {    // ✅ ADD
        await _sheetsService.clearSheet('bacBot');
        _bacTable = null;
        _bacMetadata = null;
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Lỗi xóa bảng: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}