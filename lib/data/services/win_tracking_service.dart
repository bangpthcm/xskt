// lib/data/services/win_tracking_service.dart
// ✅ VERSION TỐI ƯU - GIẢM API CALLS

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
  // PHẦN 1: OPTIMIZED PENDING DATE CHECKS
  // ============================================

  /// ✅ Get pending dates CHU KỲ (TẤT CẢ) - với caching
  Future<List<String>> getCyclePendingCheckDates() async {
    return await _getCachedPendingDates('xsktBot1');
  }

  /// ✅ Get pending dates XIÊN - với caching
  Future<List<String>> getXienPendingCheckDates() async {
    return await _getCachedPendingDates('xienBot');
  }

  /// ✅ Get pending dates MIỀN TRUNG - với caching
  Future<List<String>> getTrungPendingCheckDates() async {
    return await _getCachedPendingDates('trungBot');
  }

  /// ✅ Get pending dates MIỀN BẮC - với caching
  Future<List<String>> getBacPendingCheckDates() async {
    return await _getCachedPendingDates('bacBot');
  }

  /// ✅ HELPER: Get pending dates với cache
  Future<List<String>> _getCachedPendingDates(String worksheetName) async {
    print('🔍 Getting pending dates for $worksheetName...');
    
    // 1. CHECK CACHE
    final cached = _pendingCache[worksheetName];
    if (cached != null && !cached.isExpired) {
      print('   ✅ Using cached pending dates (${cached.dates.length} dates)');
      return cached.dates;
    }

    // 2. LOAD FROM SHEET (OPTIMIZED)
    final dates = await _loadPendingDatesOptimized(worksheetName);
    
    // 3. SAVE TO CACHE
    _pendingCache[worksheetName] = _PendingCache(
      dates: dates,
      timestamp: DateTime.now(),
    );
    
    print('   ✅ Loaded ${dates.length} pending dates (cached for 5min)');
    return dates;
  }

  /// ✅ CORE: Load pending dates - CHỈ load 2 cột (Ngày + Status)
  Future<List<String>> _loadPendingDatesOptimized(String worksheetName) async {
    try {
      final allValues = await _sheetsService.getAllValues(worksheetName);
      
      if (allValues.length < 4) {
        print('   ⚠️ No data in $worksheetName');
        return [];
      }

      // Xác định cột status (K cho cycle, H cho xiên)
      final isXien = worksheetName == 'xienBot';
      final statusColIndex = isXien ? 7 : 10; // H=7, K=10 (0-indexed)

      final pendingDates = <String>{};

      // ✅ CHỈ PARSE 2 CỘT: B (Ngày) và K/H (Status)
      for (int i = 3; i < allValues.length; i++) {
        final row = allValues[i];
        
        // Skip empty rows
        if (row.isEmpty || row[0].toString().trim().isEmpty) continue;
        if (row.length <= 1) continue;

        final date = row[1].toString().trim();
        if (date.isEmpty) continue;

        // Check status
        final checked = row.length > statusColIndex
            ? row[statusColIndex].toString().toUpperCase() == 'TRUE'
            : false;

        if (!checked) {
          pendingDates.add(date);
        }
      }

      return pendingDates.toList()..sort();

    } catch (e) {
      print('   ❌ Error loading pending dates: $e');
      return [];
    }
  }

  /// ✅ CLEAR cache khi update status (để refresh lần sau)
  void _clearPendingCache(String worksheetName) {
    _pendingCache.remove(worksheetName);
    print('🗑️ Cleared pending cache for $worksheetName');
  }

  // ============================================
  // PHẦN 2: OPTIMIZED STATUS UPDATES
  // ============================================

  /// ✅ Update CHU KỲ status - CHỈ update status columns
  Future<void> updateCycleBettingStatus({
    required int rowNumber,
    required bool checked,
    required String result,
    String? winDate,
    String? winMien,
    double? actualProfit,
  }) async {
    print('📝 Updating cycle status at row $rowNumber...');
    
    // Prepare status values
    final updates = <String>[
      checked ? 'TRUE' : 'FALSE',  // K: Đã kiểm tra
      result,                       // L: Kết quả
      winDate ?? '',                // M: Ngày trúng
      winMien ?? '',                // N: Miền trúng
      actualProfit != null 
          ? actualProfit.toStringAsFixed(2).replaceAll('.', ',')
          : '',                     // O: Lời thực tế
    ];

    // ✅ CHỈ UPDATE 5 CỘT (K→O), KHÔNG UPDATE TOÀN BỘ ROW
    await _sheetsService.updateRange(
      'xsktBot1',
      'K$rowNumber:O$rowNumber',
      [updates],
    );

    // Clear cache để load lại lần sau
    _clearPendingCache('xsktBot1');
    
    print('   ✅ Updated (reduced API payload)');
  }

  /// ✅ Update XIÊN status - CHỈ update status columns
  Future<void> updateXienBettingStatus({
    required int rowNumber,
    required bool checked,
    required String result,
    String? winDate,
    double? actualProfit,
  }) async {
    print('📝 Updating xien status at row $rowNumber...');
    
    final updates = <String>[
      checked ? 'TRUE' : 'FALSE',  // H: Đã kiểm tra
      result,                       // I: Kết quả
      winDate ?? '',                // J: Ngày trúng
      actualProfit != null 
          ? actualProfit.toStringAsFixed(2).replaceAll('.', ',')
          : '',                     // K: Lời thực tế
    ];

    // ✅ CHỈ UPDATE 4 CỘT (H→K)
    await _sheetsService.updateRange(
      'xienBot',
      'H$rowNumber:K$rowNumber',
      [updates],
    );

    _clearPendingCache('xienBot');
    print('   ✅ Updated');
  }

  /// ✅ Update MIỀN TRUNG status
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

  /// ✅ Update MIỀN BẮC status
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
  // PHẦN 3: BATCH STATUS UPDATES (NEW!)
  // ============================================

  /// ✅ NEW: Batch update nhiều rows cùng lúc (giảm API calls)
  Future<void> batchUpdateCycleStatus(
    List<BatchStatusUpdate> updates,
  ) async {
    if (updates.isEmpty) return;
    
    print('📤 Batch updating ${updates.length} cycle rows...');

    // Group updates by consecutive rows để optimize
    final groups = _groupConsecutiveRows(updates);
    
    for (final group in groups) {
      if (group.length == 1) {
        // Single row - use normal update
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
        // Multiple consecutive rows - batch update
        await _batchUpdateConsecutiveRows('xsktBot1', group);
      }
    }

    _clearPendingCache('xsktBot1');
    print('   ✅ Batch update complete');
  }

  /// ✅ Helper: Group consecutive rows
  List<List<BatchStatusUpdate>> _groupConsecutiveRows(
    List<BatchStatusUpdate> updates,
  ) {
    if (updates.isEmpty) return [];
    
    // Sort by row number
    final sorted = List<BatchStatusUpdate>.from(updates)
      ..sort((a, b) => a.rowNumber.compareTo(b.rowNumber));

    final groups = <List<BatchStatusUpdate>>[];
    var currentGroup = <BatchStatusUpdate>[sorted.first];

    for (int i = 1; i < sorted.length; i++) {
      if (sorted[i].rowNumber == currentGroup.last.rowNumber + 1) {
        // Consecutive - add to current group
        currentGroup.add(sorted[i]);
      } else {
        // Not consecutive - start new group
        groups.add(currentGroup);
        currentGroup = [sorted[i]];
      }
    }
    
    groups.add(currentGroup);
    return groups;
  }

  /// ✅ Helper: Batch update consecutive rows
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
  // PHẦN 4: WIN HISTORY OPERATIONS (GIỮ NGUYÊN)
  // ============================================

  /// Lưu lịch sử trúng số chu kỳ
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

  /// Lưu lịch sử trúng số xiên
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

  /// Lưu lịch sử trúng số Miền Trung
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

  /// Lưu lịch sử trúng số Miền Bắc
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

  // ============================================
  // PHẦN 5: READ OPERATIONS (GIỮ NGUYÊN)
  // ============================================

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

  // ============================================
  // PHẦN 6: UTILITY METHODS
  // ============================================

  /// ✅ NEW: Force refresh pending cache
  void clearAllPendingCache() {
    _pendingCache.clear();
    print('🗑️ Cleared all pending caches');
  }

  /// ✅ NEW: Get cache info
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

/// ✅ Cache cho pending dates
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

/// ✅ Model cho batch update
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