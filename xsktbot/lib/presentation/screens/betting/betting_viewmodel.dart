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
      final values = await _sheetsService.getAllValues('xienBot');
      
      if (values.isEmpty || values.length < 4) {
        _xienTable = null;
        _xienMetadata = null;
        return;
      }

      _xienMetadata = {
        'so_ngay_gan': values[0][0],
        'lan_cuoi_ve': values[0][1],
        'nhom_cap_so': values[0][2],
        'cap_so_muc_tieu': values[0][3],
      };

      _xienTable = [];
      for (int i = 3; i < values.length; i++) {
        final row = values[i];
        if (row.isEmpty || row[0].isEmpty) continue;

        try {
          _xienTable!.add(BettingRow.forXien(
            stt: int.parse(row[0]),
            ngay: row[1],
            mien: row[2],
            so: row[3],
            cuocMien: double.parse(row[4].replaceAll(',', '')),
            tongTien: double.parse(row[5].replaceAll(',', '')),
            loi: double.parse(row[6].replaceAll(',', '')),
          ));
        } catch (e) {
          print('Error parsing xien row $i: $e');
        }
      }
    } catch (e) {
      print('Error loading xien table: $e');
      _xienTable = null;
      _xienMetadata = null;
    }
  }

  Future<void> _loadCycleTable() async {
    try {
      final values = await _sheetsService.getAllValues('xsktBot1');
      
      if (values.isEmpty || values.length < 4) {
        _cycleTable = null;
        _cycleMetadata = null;
        return;
      }

      _cycleMetadata = {
        'so_ngay_gan': values[0][0],
        'lan_cuoi_ve': values[0][1],
        'nhom_so_gan': values[0][2],
        'so_muc_tieu': values[0][3],
      };

      _cycleTable = [];
      for (int i = 3; i < values.length; i++) {
        final row = values[i];
        if (row.isEmpty || row[0].isEmpty) continue;

        try {
          _cycleTable!.add(BettingRow.forCycle(
            stt: int.parse(row[0]),
            ngay: row[1],
            mien: row[2],
            so: row[3],
            soLo: int.parse(row[4]),
            cuocSo: double.parse(row[5].replaceAll(',', '')),
            cuocMien: double.parse(row[6].replaceAll(',', '')),
            tongTien: double.parse(row[7].replaceAll(',', '')),
            loi1So: double.parse(row[8].replaceAll(',', '')),
            loi2So: double.parse(row[9].replaceAll(',', '')),
          ));
        } catch (e) {
          print('Error parsing cycle row $i: $e');
        }
      }
    } catch (e) {
      print('Error loading cycle table: $e');
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
        await _regenerateXienTable();
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

  Future<void> _regenerateXienTable() async {
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