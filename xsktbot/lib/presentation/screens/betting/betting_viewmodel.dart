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

enum BettingTableType { xien, cycle }

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
  Map<String, dynamic>? _xienMetadata;
  Map<String, dynamic>? _cycleMetadata;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<BettingRow>? get xienTable => _xienTable;
  List<BettingRow>? get cycleTable => _cycleTable;
  Map<String, dynamic>? get xienMetadata => _xienMetadata;
  Map<String, dynamic>? get cycleMetadata => _cycleMetadata;

  // ✅ HELPER FUNCTION GLOBAL
  static double _parseSheetNumber(dynamic value) {
    String str = value.toString().trim();
    
    int dotCount = str.split('.').length - 1;
    int commaCount = str.split(',').length - 1;
    
    // Case 1: Có cả dấu chấm và dấu phẩy
    if (dotCount > 0 && commaCount > 0) {
      // Format EU: 1.339,20 (dấu chấm trước dấu phẩy)
      if (str.lastIndexOf('.') < str.lastIndexOf(',')) {
        str = str.replaceAll('.', '').replaceAll(',', '.');
      } 
      // Format US: 1,339.20 (dấu phẩy trước dấu chấm)
      else {
        str = str.replaceAll(',', '');
      }
    } 
    // Case 2: Chỉ có dấu phẩy
    else if (commaCount > 0) {
      // Nhiều dấu phẩy hoặc dấu phẩy không ở cuối → phân cách nghìn
      if (commaCount > 1 || (commaCount == 1 && str.indexOf(',') < str.length - 3)) {
        str = str.replaceAll(',', '');
      } 
      // 1 dấu phẩy ở gần cuối → thập phân
      else {
        str = str.replaceAll(',', '.');
      }
    } 
    // Case 3: Chỉ có dấu chấm
    else if (dotCount > 1) {
      // Nhiều dấu chấm → phân cách nghìn (1.339.20)
      int lastDotIndex = str.lastIndexOf('.');
      str = str.substring(0, lastDotIndex).replaceAll('.', '') + 
            '.' + str.substring(lastDotIndex + 1);
    }
    
    str = str.replaceAll(' ', '');
    return double.parse(str);
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
      
      print('📊 Got ${values.length} rows from xienBot');
      
      if (values.isEmpty || values.length < 4) {
        print('⚠️ Not enough rows for xien table');
        _xienTable = null;
        _xienMetadata = null;
        return;
      }

      print('📋 Row 0: ${values[0]}');
      _xienMetadata = {
        'so_ngay_gan': values[0].isNotEmpty ? values[0][0] : '',
        'lan_cuoi_ve': values[0].length > 1 ? values[0][1] : '',
        'nhom_cap_so': values[0].length > 2 ? values[0][2] : '',
        'cap_so_muc_tieu': values[0].length > 3 ? values[0][3] : '',
      };
      print('✅ Metadata: $_xienMetadata');

      _xienTable = [];
      for (int i = 3; i < values.length; i++) {
        final row = values[i];
        
        if (row.isEmpty || row[0].toString().trim().isEmpty) {
          print('⏭️ Skip empty row $i');
          continue;
        }

        if (row.length < 7) {
          print('⚠️ Row $i only has ${row.length} columns, expected 7');
          continue;
        }

        try {
          final bettingRow = BettingRow.forXien(
            stt: int.parse(row[0].toString().trim()),
            ngay: row[1].toString().trim(),
            mien: row[2].toString().trim(),
            so: row[3].toString().trim(),
            cuocMien: _parseSheetNumber(row[4]),
            tongTien: _parseSheetNumber(row[5]),
            loi: _parseSheetNumber(row[6]),
          );
          _xienTable!.add(bettingRow);
        } catch (e) {
          print('❌ Error parsing xien row $i: $e');
          print('   Row data: $row');
        }
      }
      
      print('✅ Loaded ${_xienTable!.length} xien betting rows');
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
      
      print('📊 Got ${values.length} rows from xsktBot1');
      
      if (values.isEmpty || values.length < 4) {
        print('⚠️ Not enough rows for cycle table');
        _cycleTable = null;
        _cycleMetadata = null;
        return;
      }

      print('📋 Row 0: ${values[0]}');
      _cycleMetadata = {
        'so_ngay_gan': values[0].isNotEmpty ? values[0][0] : '',
        'lan_cuoi_ve': values[0].length > 1 ? values[0][1] : '',
        'nhom_so_gan': values[0].length > 2 ? values[0][2] : '',
        'so_muc_tieu': values[0].length > 3 ? values[0][3] : '',
      };
      print('✅ Metadata: $_cycleMetadata');

      _cycleTable = [];
      for (int i = 3; i < values.length; i++) {
        final row = values[i];
        
        if (row.isEmpty || row[0].toString().trim().isEmpty) {
          print('⏭️ Skip empty row $i');
          continue;
        }

        if (row.length < 10) {
          print('⚠️ Row $i only has ${row.length} columns, expected 10');
          continue;
        }

        try {
          final bettingRow = BettingRow.forCycle(
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
          );
          _cycleTable!.add(bettingRow);
        } catch (e) {
          print('❌ Error parsing cycle row $i: $e');
          print('   Row data: $row');
        }
      }
      
      print('✅ Loaded ${_cycleTable!.length} cycle betting rows');
    } catch (e) {
      print('❌ Error loading cycle table: $e');
      _cycleTable = null;
      _cycleMetadata = null;
    }
  }

  Future<void> regenerateTable(
    BettingTableType type,
    AppConfig config,
  ) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (type == BettingTableType.xien) {
        await _regenerateXienTable(config);
      } else {
        await _regenerateCycleTable(config);
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

  Future<void> _regenerateXienTable(AppConfig config) async {
    final allValues = await _sheetsService.getAllValues('KQXS');
    final results = <LotteryResult>[];
    
    for (int i = 1; i < allValues.length; i++) {
      try {
        results.add(LotteryResult.fromSheetRow(allValues[i]));
      } catch (e) {
        // Skip invalid rows
      }
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
    
    final newTable = await _bettingService.generateXienTable(
      ganInfo: ganInfo,
      startDate: startDate,
      xienBudget: config.budget.xienBudget,
    );

    await _saveXienTableToSheet(newTable, ganInfo);
  }

  Future<void> _regenerateCycleTable(AppConfig config) async {
    final allValues = await _sheetsService.getAllValues('KQXS');
    final results = <LotteryResult>[];
    
    for (int i = 1; i < allValues.length; i++) {
      try {
        results.add(LotteryResult.fromSheetRow(allValues[i]));
      } catch (e) {
        // Skip invalid rows
      }
    }

    final cycleResult = await _analysisService.analyzeCycle(results);
    
    if (cycleResult == null) {
      throw Exception('Không đủ điều kiện tạo bảng chu kỳ');
    }

    final startDate = cycleResult.lastSeenDate.add(const Duration(days: 1));
    var endDate = cycleResult.lastSeenDate.add(const Duration(days: 8));
    
    double budgetMax = config.budget.budgetMax;
    
    if (date_utils.DateUtils.getWeekday(endDate) == 1) {
      endDate = endDate.add(const Duration(days: 1));
      budgetMax += 200000.0;
    }

    final newTable = await _bettingService.generateCycleTable(
      cycleResult: cycleResult,
      startDate: startDate,
      endDate: endDate,
      startMienIndex: 0,
      budgetMin: config.budget.budgetMin,
      budgetMax: budgetMax,
    );

    await _saveCycleTableToSheet(newTable, cycleResult);
  }

  Future<void> _saveXienTableToSheet(
    List<BettingRow> table,
    GanPairInfo ganInfo,
  ) async {
    await _sheetsService.clearSheet('xienBot');

    await _sheetsService.updateRange(
      'xienBot',
      'A1:D1',
      [
        [
          ganInfo.daysGan.toString(),
          date_utils.DateUtils.formatDate(ganInfo.lastSeen),
          ganInfo.pairsDisplay,
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

    final dataRows = table.map((row) => row.toSheetRow()).toList();
    await _sheetsService.updateRange(
      'xienBot',
      'A4',
      dataRows,
    );
  }

  Future<void> _saveCycleTableToSheet(
    List<BettingRow> table,
    CycleAnalysisResult cycleResult,
  ) async {
    await _sheetsService.clearSheet('xsktBot1');

    await _sheetsService.updateRange(
      'xsktBot1',
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
      'xsktBot1',
      'A3:J3',
      [
        ['STT', 'Ngày', 'Miền', 'Số', 'Số lô', 'Cược/số', 'Cược/miền', 'Tổng tiền', 'Lời (1 số)', 'Lời (2 số)']
      ],
    );

    final dataRows = table.map((row) => row.toSheetRow()).toList();
    await _sheetsService.updateRange(
      'xsktBot1',
      'A4',
      dataRows,
    );
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
          _xienTable!,
          _xienMetadata!['cap_so_muc_tieu'],
          int.parse(_xienMetadata!['so_ngay_gan']),
          _xienMetadata!['lan_cuoi_ve'],
        );

        await _telegramService.sendMessage(message);
      } else {
        if (_cycleTable == null || _cycleMetadata == null) {
          throw Exception('Chưa có bảng chu kỳ');
        }

        final message = _telegramService.formatCycleTableMessage(
          _cycleTable!,
          _cycleMetadata!['nhom_so_gan'],
          _cycleMetadata!['so_muc_tieu'],
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
      } else {
        await _sheetsService.clearSheet('xsktBot1');
        _cycleTable = null;
        _cycleMetadata = null;
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