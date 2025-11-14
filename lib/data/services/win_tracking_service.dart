// lib/data/services/win_tracking_service.dart
// ✅ OPTIMIZED VERSION with Batch Operations

import '../models/cycle_win_history.dart';
import '../models/xien_win_history.dart';
import 'google_sheets_service.dart';

class WinTrackingService {
  final GoogleSheetsService _sheetsService;
  
  // ✅ Cache pending dates (refresh mỗi 5 phút)
  final Map<String, _PendingCache> _pendingCache = {};
  static const Duration _pendingCacheDuration = Duration(minutes: 5);

  WinTrackingService({required GoogleSheetsService sheetsService})
      : _sheetsService = sheetsService;

  GoogleSheetsService get sheetsService => _sheetsService;

  // ============================================
  // ✅ OPTIMIZED: LOAD PENDING DATES WITH BATCH
  // ============================================

  /// ✅ NEW: Load tất cả pending dates cùng lúc (1 API call)
  Future<Map<String, List<String>>> loadAllPendingDates({
    bool useCache = true,
  }) async {
    print('📊 Loading all pending dates (batch mode)...');
    
    // ✅ Define all betting tables
    final tables = ['xsktBot1', 'xienBot', 'trungBot', 'bacBot'];
    
    // ✅ Check cache first
    if (useCache) {
      final cachedResult = <String, List<String>>{};
      bool allCached = true;
      
      for (final table in tables) {
        final cached = _pendingCache[table];
        if (cached != null && !cached.isExpired) {
          cachedResult[table] = cached.dates;
        } else {
          allCached = false;
          break;
        }
      }
      
      if (allCached) {
        print('   ✅ Using cached pending dates');
        return cachedResult;
      }
    }
    
    try {
      // ✅ BATCH READ: 1 API call thay vì 4 calls
      final batchData = await _sheetsService.batchGetValues(tables);
      
      final result = <String, List<String>>{};
      
      // ✅ Parse pending dates for each table
      for (final table in tables) {
        final values = batchData[table] ?? [];
        final pendingDates = _parsePendingDatesFromSheet(table, values);
        
        result[table] = pendingDates;
        
        // ✅ Cache it
        _pendingCache[table] = _PendingCache(
          dates: pendingDates,
          timestamp: DateTime.now(),
        );
        
        print('   📋 $table: ${pendingDates.length} pending dates');
      }
      
      print('✅ Loaded all pending dates (1 batch call)');
      return result;
      
    } catch (e) {
      print('❌ Error loading pending dates: $e');
      return {};
    }
  }

  /// ✅ Helper: Parse pending dates from sheet data
  List<String> _parsePendingDatesFromSheet(
    String worksheetName,
    List<List<String>> values,
  ) {
    if (values.length < 4) return [];

    final isXien = worksheetName == 'xienBot';
    final statusColIndex = isXien ? 7 : 10;

    final pendingDates = <String>{};

    for (int i = 3; i < values.length; i++) {
      final row = values[i];
      
      if (row.isEmpty || row[0].trim().isEmpty) continue;
      if (row.length <= 1) continue;

      final date = row[1].trim();
      if (date.isEmpty) continue;

      final checked = row.length > statusColIndex
          ? row[statusColIndex].toUpperCase() == 'TRUE'
          : false;

      if (!checked) {
        pendingDates.add(date);
      }
    }

    return pendingDates.toList()..sort();
  }

  // ============================================
  // BACKWARD COMPATIBLE METHODS
  // ============================================
  
  Future<List<String>> getCyclePendingCheckDates() async {
    final all = await loadAllPendingDates();
    return all['xsktBot1'] ?? [];
  }

  Future<List<String>> getXienPendingCheckDates() async {
    final all = await loadAllPendingDates();
    return all['xienBot'] ?? [];
  }

  Future<List<String>> getTrungPendingCheckDates() async {
    final all = await loadAllPendingDates();
    return all['trungBot'] ?? [];
  }

  Future<List<String>> getBacPendingCheckDates() async {
    final all = await loadAllPendingDates();
    return all['bacBot'] ?? [];
  }

  void _clearPendingCache(String worksheetName) {
    _pendingCache.remove(worksheetName);
    print('🗑️ Cleared pending cache for $worksheetName');
  }

  // ============================================
  // ✅ OPTIMIZED: BATCH STATUS UPDATES
  // ============================================

  /// ✅ NEW: Update nhiều status rows cùng lúc
  Future<void> batchUpdateCycleStatus(
    List<BatchStatusUpdate> updates,
  ) async {
    if (updates.isEmpty) return;
    
    print('📤 Batch updating ${updates.length} cycle rows...');

    // ✅ Group by consecutive rows
    final groups = _groupConsecutiveRows(updates);
    
    for (final group in groups) {
      if (group.length == 1) {
        // Single row
        final u = group.first;
        await updateCycleBettingStatus(
          rowNumber: u.rowNumber,
          checked: u.checked,
          result: u.result,
          winDate: u.winDate,
          winMien: u.winMien,
          actualProfit: u.actualProfit,
        );
      } else {
        // ✅ Batch update consecutive rows
        await _batchUpdateConsecutiveRows('xsktBot1', group);
      }
    }

    _clearPendingCache('xsktBot1');
    print('✅ Batch update complete');
  }

  List<List<BatchStatusUpdate>> _groupConsecutiveRows(
    List<BatchStatusUpdate> updates,
  ) {
    if (updates.isEmpty) return [];
    
    final sorted = List<BatchStatusUpdate>.from(updates)
      ..sort((a, b) => a.rowNumber.compareTo(b.rowNumber));

    final groups = <List<BatchStatusUpdate>>[];
    var currentGroup = <BatchStatusUpdate>[sorted.first];

    for (int i = 1; i < sorted.length; i++) {
      if (sorted[i].rowNumber == currentGroup.last.rowNumber + 1) {
        currentGroup.add(sorted[i]);
      } else {
        groups.add(currentGroup);
        currentGroup = [sorted[i]];
      }
    }
    
    groups.add(currentGroup);
    return groups;
  }

  Future<void> _batchUpdateConsecutiveRows(
    String worksheetName,
    List<BatchStatusUpdate> group,
  ) async {
    final startRow = group.first.rowNumber;
    final endRow = group.last.rowNumber;
    
    print('   📊 Updating rows $startRow-$endRow...');

    final rows = group.map((u) {
      return [
        u.checked ? 'TRUE' : 'FALSE',
        u.result,
        u.winDate ?? '',
        u.winMien ?? '',
        u.actualProfit != null 
            ? u.actualProfit!.toStringAsFixed(2).replaceAll('.', ',')
            : '',
      ];
    }).toList();

    await _sheetsService.updateRange(
      worksheetName,
      'K$startRow:O$endRow',
      rows,
    );
  }

  // ============================================
  // EXISTING STATUS UPDATE METHODS (Keep for compatibility)
  // ============================================
  
  Future<void> updateCycleBettingStatus({
    required int rowNumber,
    required bool checked,
    required String result,
    String? winDate,
    String? winMien,
    double? actualProfit,
  }) async {
    print('📝 Updating cycle status at row $rowNumber...');
    
    final updates = <String>[
      checked ? 'TRUE' : 'FALSE',
      result,
      winDate ?? '',
      winMien ?? '',
      actualProfit != null 
          ? actualProfit.toStringAsFixed(2).replaceAll('.', ',')
          : '',
    ];

    await _sheetsService.updateRange(
      'xsktBot1',
      'K$rowNumber:O$rowNumber',
      [updates],
    );

    _clearPendingCache('xsktBot1');
    print('   ✅ Updated');
  }

  Future<void> updateXienBettingStatus({
    required int rowNumber,
    required bool checked,
    required String result,
    String? winDate,
    double? actualProfit,
  }) async {
    print('📝 Updating xien status at row $rowNumber...');
    
    final updates = <String>[
      checked ? 'TRUE' : 'FALSE',
      result,
      winDate ?? '',
      actualProfit != null 
          ? actualProfit.toStringAsFixed(2).replaceAll('.', ',')
          : '',
    ];

    await _sheetsService.updateRange(
      'xienBot',
      'H$rowNumber:K$rowNumber',
      [updates],
    );

    _clearPendingCache('xienBot');
    print('   ✅ Updated');
  }

  Future<void> updateTrungBettingStatus({
    required int rowNumber,
    required bool checked,
    required String result,
    String? winDate,
    String? winMien,
    double? actualProfit,
  }) async {
    print('📝 Updating trung status at row $rowNumber...');
    
    final updates = <String>[
      checked ? 'TRUE' : 'FALSE',
      result,
      winDate ?? '',
      winMien ?? '',
      actualProfit != null 
          ? actualProfit.toStringAsFixed(2).replaceAll('.', ',')
          : '',
    ];

    await _sheetsService.updateRange(
      'trungBot',
      'K$rowNumber:O$rowNumber',
      [updates],
    );

    _clearPendingCache('trungBot');
    print('   ✅ Updated');
  }

  Future<void> updateBacBettingStatus({
    required int rowNumber,
    required bool checked,
    required String result,
    String? winDate,
    String? winMien,
    double? actualProfit,
  }) async {
    print('📝 Updating bac status at row $rowNumber...');
    
    final updates = <String>[
      checked ? 'TRUE' : 'FALSE',
      result,
      winDate ?? '',
      winMien ?? '',
      actualProfit != null 
          ? actualProfit.toStringAsFixed(2).replaceAll('.', ',')
          : '',
    ];

    await _sheetsService.updateRange(
      'bacBot',
      'K$rowNumber:O$rowNumber',
      [updates],
    );

    _clearPendingCache('bacBot');
    print('   ✅ Updated');
  }

  // ============================================
  // WIN HISTORY OPERATIONS (Keep as is)
  // ============================================
  
  Future<void> saveCycleWinHistory(CycleWinHistory history) async {
    print('💾 Saving cycle win history...');
    
    final existingData = await _sheetsService.getAllValues('cycleWinHistory');
    
    if (existingData.isEmpty) {
      print('   📋 Creating header...');
      await _sheetsService.updateRange(
        'cycleWinHistory',
        'A1:P1',
        [
          [
            'STT', 'Ngày kiểm tra', 'Số mục tiêu', 'Ngày bắt đầu cược',
            'Ngày trúng', 'Miền trúng', 'Số lần trúng', 'Các tỉnh trúng',
            'Tiền cược/số', 'Tổng tiền đã cược', 'Tiền về', 'Lời/Lỗ',
            'ROI (%)', 'Số ngày cược', 'Trạng thái', 'Ghi chú',
          ]
        ],
      );
    }

    final newSTT = existingData.isEmpty ? 1 : existingData.length;
    final updatedHistory = CycleWinHistory(
      stt: newSTT,
      ngayKiemTra: history.ngayKiemTra,
      soMucTieu: history.soMucTieu,
      ngayBatDau: history.ngayBatDau,
      ngayTrung: history.ngayTrung,
      mienTrung: history.mienTrung,
      soLanTrung: history.soLanTrung,
      cacTinhTrung: history.cacTinhTrung,
      tienCuocSo: history.tienCuocSo,
      tongTienCuoc: history.tongTienCuoc,
      tienVe: history.tienVe,
      loiLo: history.loiLo,
      roi: history.roi,
      soNgayCuoc: history.soNgayCuoc,
      trangThai: history.trangThai,
      ghiChu: history.ghiChu,
    );

    await _sheetsService.appendRows(
      'cycleWinHistory',
      [updatedHistory.toSheetRow()],
    );
    
    print('   ✅ Saved cycle win history (STT: $newSTT)');
  }

  Future<void> saveXienWinHistory(XienWinHistory history) async {
    print('💾 Saving xien win history...');
    
    final existingData = await _sheetsService.getAllValues('xienWinHistory');
    
    if (existingData.isEmpty) {
      print('   📋 Creating header...');
      await _sheetsService.updateRange(
        'xienWinHistory',
        'A1:P1',
        [
          [
            'STT', 'Ngày kiểm tra', 'Cặp số mục tiêu', 'Ngày bắt đầu cược',
            'Ngày trúng', 'Miền trúng', 'Số lần trúng cặp', 'Chi tiết trúng',
            'Tiền cược/miền', 'Tổng tiền đã cược', 'Tiền về', 'Lời/Lỗ',
            'ROI (%)', 'Số ngày cược', 'Trạng thái', 'Ghi chú',
          ]
        ],
      );
    }

    final newSTT = existingData.isEmpty ? 1 : existingData.length;
    final updatedHistory = XienWinHistory(
      stt: newSTT,
      ngayKiemTra: history.ngayKiemTra,
      capSoMucTieu: history.capSoMucTieu,
      ngayBatDau: history.ngayBatDau,
      ngayTrung: history.ngayTrung,
      mienTrung: history.mienTrung,
      soLanTrungCap: history.soLanTrungCap,
      chiTietTrung: history.chiTietTrung,
      tienCuocMien: history.tienCuocMien,
      tongTienCuoc: history.tongTienCuoc,
      tienVe: history.tienVe,
      loiLo: history.loiLo,
      roi: history.roi,
      soNgayCuoc: history.soNgayCuoc,
      trangThai: history.trangThai,
      ghiChu: history.ghiChu,
    );

    await _sheetsService.appendRows(
      'xienWinHistory',
      [updatedHistory.toSheetRow()],
    );
    
    print('   ✅ Saved xien win history (STT: $newSTT)');
  }

  Future<void> saveTrungWinHistory(CycleWinHistory history) async {
    print('💾 Saving trung win history...');
    
    final existingData = await _sheetsService.getAllValues('trungWinHistory');
    
    if (existingData.isEmpty) {
      await _sheetsService.updateRange(
        'trungWinHistory',
        'A1:P1',
        [
          [
            'STT', 'Ngày kiểm tra', 'Số mục tiêu', 'Ngày bắt đầu cược',
            'Ngày trúng', 'Miền trúng', 'Số lần trúng', 'Các tỉnh trúng',
            'Tiền cược/số', 'Tổng tiền đã cược', 'Tiền về', 'Lời/Lỗ',
            'ROI (%)', 'Số ngày cược', 'Trạng thái', 'Ghi chú',
          ]
        ],
      );
    }

    final newSTT = existingData.isEmpty ? 1 : existingData.length;
    final updatedHistory = CycleWinHistory(
      stt: newSTT,
      ngayKiemTra: history.ngayKiemTra,
      soMucTieu: history.soMucTieu,
      ngayBatDau: history.ngayBatDau,
      ngayTrung: history.ngayTrung,
      mienTrung: history.mienTrung,
      soLanTrung: history.soLanTrung,
      cacTinhTrung: history.cacTinhTrung,
      tienCuocSo: history.tienCuocSo,
      tongTienCuoc: history.tongTienCuoc,
      tienVe: history.tienVe,
      loiLo: history.loiLo,
      roi: history.roi,
      soNgayCuoc: history.soNgayCuoc,
      trangThai: history.trangThai,
      ghiChu: history.ghiChu,
    );

    await _sheetsService.appendRows(
      'trungWinHistory',
      [updatedHistory.toSheetRow()],
    );
    
    print('   ✅ Saved trung win history (STT: $newSTT)');
  }

  Future<void> saveBacWinHistory(CycleWinHistory history) async {
    print('💾 Saving bac win history...');
    
    final existingData = await _sheetsService.getAllValues('bacWinHistory');
    
    if (existingData.isEmpty) {
      await _sheetsService.updateRange(
        'bacWinHistory',
        'A1:P1',
        [
          [
            'STT', 'Ngày kiểm tra', 'Số mục tiêu', 'Ngày bắt đầu cược',
            'Ngày trúng', 'Miền trúng', 'Số lần trúng', 'Các tỉnh trúng',
            'Tiền cược/số', 'Tổng tiền đã cược', 'Tiền về', 'Lời/Lỗ',
            'ROI (%)', 'Số ngày cược', 'Trạng thái', 'Ghi chú',
          ]
        ],
      );
    }

    final newSTT = existingData.isEmpty ? 1 : existingData.length;
    final updatedHistory = CycleWinHistory(
      stt: newSTT,
      ngayKiemTra: history.ngayKiemTra,
      soMucTieu: history.soMucTieu,
      ngayBatDau: history.ngayBatDau,
      ngayTrung: history.ngayTrung,
      mienTrung: history.mienTrung,
      soLanTrung: history.soLanTrung,
      cacTinhTrung: history.cacTinhTrung,
      tienCuocSo: history.tienCuocSo,
      tongTienCuoc: history.tongTienCuoc,
      tienVe: history.tienVe,
      loiLo: history.loiLo,
      roi: history.roi,
      soNgayCuoc: history.soNgayCuoc,
      trangThai: history.trangThai,
      ghiChu: history.ghiChu,
    );

    await _sheetsService.appendRows(
      'bacWinHistory',
      [updatedHistory.toSheetRow()],
    );
    
    print('   ✅ Saved bac win history (STT: $newSTT)');
  }

  Future<List<CycleWinHistory>> getAllCycleWinHistory() async {
    print('📚 Loading all cycle win history...');
    
    final values = await _sheetsService.getAllValues('cycleWinHistory');
    
    if (values.length < 2) {
      print('   ⚠️ No cycle win history found');
      return [];
    }
    
    final histories = <CycleWinHistory>[];
    for (int i = 1; i < values.length; i++) {
      try {
        histories.add(CycleWinHistory.fromSheetRow(values[i]));
      } catch (e) {
        print('⚠️ Error parsing cycle win history row $i: $e');
      }
    }
    
    print('   ✅ Loaded ${histories.length} cycle win records');
    return histories;
  }

  Future<List<XienWinHistory>> getAllXienWinHistory() async {
    print('📚 Loading all xien win history...');
    
    final values = await _sheetsService.getAllValues('xienWinHistory');
    
    if (values.length < 2) {
      print('   ⚠️ No xien win history found');
      return [];
    }
    
    final histories = <XienWinHistory>[];
    for (int i = 1; i < values.length; i++) {
      try {
        histories.add(XienWinHistory.fromSheetRow(values[i]));
      } catch (e) {
        print('⚠️ Error parsing xien win history row $i: $e');
      }
    }
    
    print('   ✅ Loaded ${histories.length} xien win records');
    return histories;
  }

  void clearAllPendingCache() {
    _pendingCache.clear();
    print('🗑️ Cleared all pending caches');
  }

  Map<String, String> getPendingCacheInfo() {
    final info = <String, String>{};
    
    for (final entry in _pendingCache.entries) {
      final age = DateTime.now().difference(entry.value.timestamp);
      info[entry.key] = '${entry.value.dates.length} dates, ${age.inMinutes}min old';
    }
    
    return info;
  }
}

// ============================================
// HELPER CLASSES
// ============================================

class _PendingCache {
  final List<String> dates;
  final DateTime timestamp;

  _PendingCache({
    required this.dates,
    required this.timestamp,
  });

  bool get isExpired {
    final age = DateTime.now().difference(timestamp);
    return age > WinTrackingService._pendingCacheDuration;
  }
}

class BatchStatusUpdate {
  final int rowNumber;
  final bool checked;
  final String result;
  final String? winDate;
  final String? winMien;
  final double? actualProfit;

  BatchStatusUpdate({
    required this.rowNumber,
    required this.checked,
    required this.result,
    this.winDate,
    this.winMien,
    this.actualProfit,
  });
}