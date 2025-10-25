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
  bool? _trungAlertCache;
  bool? _bacAlertCache;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  GanPairInfo? get ganPairInfo => _ganPairInfo;
  CycleAnalysisResult? get cycleResult => _cycleResult;
  String get selectedMien => _selectedMien;
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
      
      // Check Trung
      final trungResults = _allResults.where((r) => r.mien == 'Trung').toList();
      final trungResult = await _analysisService.analyzeCycle(trungResults);
      _trungAlertCache = trungResult != null && trungResult.maxGanDays > 15;
      
      // Check Bắc
      final bacResults = _allResults.where((r) => r.mien == 'Bắc').toList();
      final bacResult = await _analysisService.analyzeCycle(bacResults);
      _bacAlertCache = bacResult != null && bacResult.maxGanDays > 17;
      
    } catch (e) {
      print('⚠️ Error caching alerts: $e');
      _trungAlertCache = false;
      _bacAlertCache = false;
    }
  }

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

      DateTime endDate = _cycleResult!.lastSeenDate.add(const Duration(days: 9));

      double budgetMax = config.budget.budgetMax;
      
      final lastDayWeekday = date_utils.DateUtils.getWeekday(endDate);
      final secondLastDate = endDate.subtract(const Duration(days: 1));
      final secondLastWeekday = date_utils.DateUtils.getWeekday(secondLastDate);
      
      if (lastDayWeekday == 1 || secondLastWeekday == 1) {
        endDate = endDate.add(const Duration(days: 1));
        budgetMax += config.budget.tuesdayExtraBudget;
      }

      final newTable = await _bettingService.generateCycleTable(
        cycleResult: _cycleResult!,
        startDate: startDate,
        endDate: endDate,
        startMienIndex: startMienIndex,
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

  String _getWeekdayName(int weekday) {
    const names = ['Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'Chủ nhật'];
    return names[weekday];
  }

  bool _isMienLater(String newMien, String oldMien) {
    const mienPriority = {'Nam': 1, 'Trung': 2, 'Bắc': 3};
    return (mienPriority[newMien] ?? 0) > (mienPriority[oldMien] ?? 0);
  }

  Future<void> createCycleBettingTableForNumber(
    String targetNumber,
    AppConfig config,
  ) async {
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

      DateTime endDate = lastSeenDate.add(const Duration(days: 9));

      double budgetMax = config.budget.budgetMax;
      
      final lastDayWeekday = date_utils.DateUtils.getWeekday(endDate);
      final secondLastDate = endDate.subtract(const Duration(days: 1));
      final secondLastWeekday = date_utils.DateUtils.getWeekday(secondLastDate);
      
      if (lastDayWeekday == 1 || secondLastWeekday == 1) {
        endDate = endDate.add(const Duration(days: 1));
        budgetMax += config.budget.tuesdayExtraBudget;
      }

      final newTable = await _bettingService.generateCycleTable(
        cycleResult: customCycleResult,
        startDate: startDate,
        endDate: endDate,
        startMienIndex: startMienIndex,
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

      final newTable = await _bettingService.generateBacGanTable(
        cycleResult: customCycleResult,
        startDate: startDate,
        endDate: endDate,
        budgetMin: config.budget.budgetMin,
        budgetMax: config.budget.budgetMax,
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

      final newTable = await _bettingService.generateTrungGanTable(
        cycleResult: customCycleResult,
        startDate: startDate,
        endDate: endDate,
        budgetMin: config.budget.budgetMin,
        budgetMax: config.budget.budgetMax,
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
    // Bỏ alert cho "Tất cả"
    return false;
  }

  /// Kiểm tra Trung có gan > 15 ngày
  bool get hasTrungAlert {
    if (_cycleResult == null) return false;
    if (_selectedMien != 'Trung') return false;
    return _cycleResult!.maxGanDays > 15;
  }

  /// Kiểm tra Bắc có gan > 17 ngày
  bool get hasBacAlert {
    if (_cycleResult == null) return false;
    if (_selectedMien != 'Bắc') return false;
    return _cycleResult!.maxGanDays > 17;
  }

  /// Kiểm tra Xiên có gan > 155 ngày
  bool get hasXienAlert {
    if (_ganPairInfo == null) return false;
    return _ganPairInfo!.daysGan > 155;
  }

  /// ✅ Kiểm tra có bất kỳ alert nào (dùng cache)
  bool get hasAnyAlert {
    bool hasAlert = false;
    
    // Check Xiên
    if (_ganPairInfo != null && _ganPairInfo!.daysGan > 155) {
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
    if (_ganPairInfo != null && _ganPairInfo!.daysGan > 155) {
      alerts['Xiên'] = AlertInfo(
        threshold: 155,
        currentDays: _ganPairInfo!.daysGan,
        targetNumber: _ganPairInfo!.randomPair.display,
      );
    }
    
    // Check Trung
    if (_trungAlertCache == true) {
      alerts['Trung'] = AlertInfo(
        threshold: 15,
        currentDays: _cycleResult?.maxGanDays ?? 0,
        targetNumber: _cycleResult?.targetNumber ?? '',
      );
    }
    
    // Check Bắc
    if (_bacAlertCache == true) {
      alerts['Bắc'] = AlertInfo(
        threshold: 17,
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
      messages.add('🔥 Xiên: ${_ganPairInfo!.daysGan} ngày (>155)');
    }
    
    if (_trungAlertCache == true) {
      messages.add('🔥 Trung: gan >15 ngày');
    }
    
    if (_bacAlertCache == true) {
      messages.add('🔥 Bắc: gan >17 ngày');
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