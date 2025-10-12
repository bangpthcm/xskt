// lib/presentation/screens/analysis/analysis_viewmodel.dart
import 'package:flutter/material.dart';
import '../../../data/models/gan_pair_info.dart';
import '../../../data/models/cycle_analysis_result.dart';
import '../../../data/models/lottery_result.dart';
import '../../../data/models/app_config.dart';
import '../../../data/services/google_sheets_service.dart';
import '../../../data/services/analysis_service.dart';
import '../../../data/services/storage_service.dart';
import '../../../data/services/telegram_service.dart';
import '../../../data/services/betting_table_service.dart';
import '../../../core/utils/date_utils.dart' as date_utils;

class AnalysisViewModel extends ChangeNotifier {
  final GoogleSheetsService _sheetsService;
  final AnalysisService _analysisService;
  final StorageService _storageService;
  final TelegramService _telegramService;
  final BettingTableService _bettingService;

  AnalysisViewModel({
    required GoogleSheetsService sheetsService,
    required AnalysisService analysisService,
    required StorageService storageService,
    required TelegramService telegramService,
    required BettingTableService bettingService,
  })  : _sheetsService = sheetsService,
        _analysisService = analysisService,
        _storageService = storageService,
        _telegramService = telegramService,
        _bettingService = bettingService;

  bool _isLoading = false;
  String? _errorMessage;
  GanPairInfo? _ganPairInfo;
  CycleAnalysisResult? _cycleResult;
  String _selectedMien = 'Tất cả';
  List<LotteryResult> _allResults = [];

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  GanPairInfo? get ganPairInfo => _ganPairInfo;
  CycleAnalysisResult? get cycleResult => _cycleResult;
  String get selectedMien => _selectedMien;

  void setSelectedMien(String mien) {
    _selectedMien = mien;
    notifyListeners();
  }

  Future<void> loadAnalysis({bool useCache = true}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
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

      _ganPairInfo = await _analysisService.findGanPairsMienBac(_allResults);

      if (_selectedMien == 'Tất cả') {
        _cycleResult = await _analysisService.analyzeCycle(_allResults);
      } else {
        final filteredResults = _allResults
            .where((r) => r.mien == _selectedMien)
            .toList();
        _cycleResult = await _analysisService.analyzeCycle(filteredResults);
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Lỗi phân tích: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createCycleBettingTable(AppConfig config) async {
    if (_cycleResult == null) {
      _errorMessage = 'Chưa có dữ liệu chu kỳ';
      notifyListeners();
      return;
    }

    // ✅ BỎ điều kiện kiểm tra maxGanDays > 3
    
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final latestDate = _allResults
          .map((r) => date_utils.DateUtils.parseDate(r.ngay))
          .where((d) => d != null)
          .reduce((a, b) => a!.isAfter(b!) ? a : b);

      final startDate = latestDate!.add(const Duration(days: 1));
      var endDate = _cycleResult!.lastSeenDate.add(const Duration(days: 8));
      
      double budgetMax = config.budget.budgetMax;
      
      if (date_utils.DateUtils.getWeekday(endDate) == 1) {
        endDate = endDate.add(const Duration(days: 1));
        budgetMax += 200000.0;
      }

      final newTable = await _bettingService.generateCycleTable(
        cycleResult: _cycleResult!,
        startDate: startDate,
        endDate: endDate,
        startMienIndex: 0,
        budgetMin: config.budget.budgetMin,
        budgetMax: budgetMax,
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

  Future<void> createXienBettingTable() async {
    if (_ganPairInfo == null) {
      _errorMessage = 'Chưa có dữ liệu cặp số gan';
      notifyListeners();
      return;
    }

    // ✅ BỎ điều kiện kiểm tra daysGan > 155

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final latestDate = _allResults
          .map((r) => date_utils.DateUtils.parseDate(r.ngay))
          .where((d) => d != null)
          .reduce((a, b) => a!.isAfter(b!) ? a : b);

      final startDate = latestDate!.add(const Duration(days: 1));
      
      final newTable = await _bettingService.generateXienTable(
        ganInfo: _ganPairInfo!,
        startDate: startDate,
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
    print('📝 Saving cycle table to sheet...'); // ✅ ADD
    print('📊 Table rows: ${table.length}'); // ✅ ADD
    
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
    
    print('✅ Cycle table saved successfully!'); // ✅ ADD
  }

  Future<void> _saveXienTableToSheet(List<dynamic> table) async {
    print('📝 Saving xien table to sheet...'); // ✅ ADD
    print('📊 Table rows: ${table.length}'); // ✅ ADD
    
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
    
    print('✅ Xien table saved successfully!'); // ✅ ADD
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

  // ✅ THÊM METHOD NÀY
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}