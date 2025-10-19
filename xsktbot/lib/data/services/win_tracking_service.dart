// lib/data/services/win_tracking_service.dart

import '../models/cycle_win_history.dart';
import '../models/xien_win_history.dart';
import 'google_sheets_service.dart';

class WinTrackingService {
  final GoogleSheetsService _sheetsService;

  WinTrackingService({required GoogleSheetsService sheetsService})
      : _sheetsService = sheetsService;

  // ✅ ADD: Public getter để các service khác có thể access
  GoogleSheetsService get sheetsService => _sheetsService;

  /// Lưu lịch sử trúng số chu kỳ
  Future<void> saveCycleWinHistory(CycleWinHistory history) async {
    print('💾 Saving cycle win history...');
    
    final existingData = await _sheetsService.getAllValues('cycleWinHistory');
    
    // Thêm header nếu sheet trống
    if (existingData.isEmpty) {
      print('   📋 Creating header...');
      await _sheetsService.updateRange(
        'cycleWinHistory',
        'A1:P1',
        [
          [
            'STT',
            'Ngày kiểm tra',
            'Số mục tiêu',
            'Ngày bắt đầu cược',
            'Ngày trúng',
            'Miền trúng',
            'Số lần trúng',
            'Các tỉnh trúng',
            'Tiền cược/số',
            'Tổng tiền đã cược',
            'Tiền về',
            'Lời/Lỗ',
            'ROI (%)',
            'Số ngày cược',
            'Trạng thái',
            'Ghi chú',
          ]
        ],
      );
    }

    // Cập nhật STT
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

    // Thêm dòng mới
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
    
    // Thêm header nếu sheet trống
    if (existingData.isEmpty) {
      print('   📋 Creating header...');
      await _sheetsService.updateRange(
        'xienWinHistory',
        'A1:P1',
        [
          [
            'STT',
            'Ngày kiểm tra',
            'Cặp số mục tiêu',
            'Ngày bắt đầu cược',
            'Ngày trúng',
            'Miền trúng',
            'Số lần trúng cặp',
            'Chi tiết trúng',
            'Tiền cược/miền',
            'Tổng tiền đã cược',
            'Tiền về',
            'Lời/Lỗ',
            'ROI (%)',
            'Số ngày cược',
            'Trạng thái',
            'Ghi chú',
          ]
        ],
      );
    }

    // Cập nhật STT
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

    // Thêm dòng mới
    await _sheetsService.appendRows(
      'xienWinHistory',
      [updatedHistory.toSheetRow()],
    );
    
    print('   ✅ Saved xien win history (STT: $newSTT)');
  }

  /// Cập nhật trạng thái bảng cược chu kỳ
  Future<void> updateCycleBettingStatus({
    required int rowNumber,
    required bool checked,
    required String result,
    String? winDate,
    String? winMien,
    double? actualProfit,
  }) async {
    print('📝 Updating cycle betting status at row $rowNumber...');
    
    final updates = <String>[];
    updates.add(checked ? 'TRUE' : 'FALSE');
    updates.add(result);
    updates.add(winDate ?? '');
    updates.add(winMien ?? '');
    
    // Format profit with comma as decimal separator (EU format)
    if (actualProfit != null) {
      updates.add(actualProfit.toStringAsFixed(2).replaceAll('.', ','));
    } else {
      updates.add('');
    }

    await _sheetsService.updateRange(
      'xsktBot1',
      'K$rowNumber:O$rowNumber',
      [updates],
    );
    
    print('   ✅ Updated row $rowNumber');
  }

  /// Cập nhật trạng thái bảng cược xiên
  Future<void> updateXienBettingStatus({
    required int rowNumber,
    required bool checked,
    required String result,
    String? winDate,
    double? actualProfit,
  }) async {
    print('📝 Updating xien betting status at row $rowNumber...');
    
    final updates = <String>[];
    updates.add(checked ? 'TRUE' : 'FALSE');
    updates.add(result);
    updates.add(winDate ?? '');
    
    // Format profit with comma as decimal separator (EU format)
    if (actualProfit != null) {
      updates.add(actualProfit.toStringAsFixed(2).replaceAll('.', ','));
    } else {
      updates.add('');
    }

    await _sheetsService.updateRange(
      'xienBot',
      'H$rowNumber:K$rowNumber',
      [updates],
    );
    
    print('   ✅ Updated row $rowNumber');
  }

  /// Lấy danh sách các ngày cần kiểm tra từ bảng chu kỳ
  Future<List<String>> getCyclePendingCheckDates() async {
    print('🔍 Getting pending check dates for cycle...');
    
    final values = await _sheetsService.getAllValues('xsktBot1');
    
    if (values.length < 4) {
      print('   ⚠️ No data in cycle table');
      return [];
    }
    
    final pendingDates = <String>{};  // Use Set to avoid duplicates
    
    for (int i = 3; i < values.length; i++) {
      final row = values[i];
      
      if (row.isEmpty || row[0].toString().trim().isEmpty) {
        continue;
      }
      
      // Check column K (index 10): Đã kiểm tra
      final checked = row.length > 10 
          ? row[10].toString().toUpperCase() == 'TRUE' 
          : false;
      
      if (!checked) {
        final date = row[1].toString();  // Column B: Ngày
        pendingDates.add(date);
      }
    }
    
    final result = pendingDates.toList()..sort();
    print('   📅 Found ${result.length} pending dates: ${result.join(", ")}');
    
    return result;
  }

  /// Lấy danh sách các ngày cần kiểm tra từ bảng xiên
  Future<List<String>> getXienPendingCheckDates() async {
    print('🔍 Getting pending check dates for xien...');
    
    final values = await _sheetsService.getAllValues('xienBot');
    
    if (values.length < 4) {
      print('   ⚠️ No data in xien table');
      return [];
    }
    
    final pendingDates = <String>{};
    
    for (int i = 3; i < values.length; i++) {
      final row = values[i];
      
      if (row.isEmpty || row[0].toString().trim().isEmpty) {
        continue;
      }
      
      // Check column H (index 7): Đã kiểm tra
      final checked = row.length > 7 
          ? row[7].toString().toUpperCase() == 'TRUE' 
          : false;
      
      if (!checked) {
        final date = row[1].toString();  // Column B: Ngày
        pendingDates.add(date);
      }
    }
    
    final result = pendingDates.toList()..sort();
    print('   📅 Found ${result.length} pending dates: ${result.join(", ")}');
    
    return result;
  }

  /// Lấy tất cả lịch sử trúng số chu kỳ
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
        print('   Row data: ${values[i]}');
      }
    }
    
    print('   ✅ Loaded ${histories.length} cycle win records');
    return histories;
  }

  /// Lấy tất cả lịch sử trúng số xiên
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
        print('   Row data: ${values[i]}');
      }
    }
    
    print('   ✅ Loaded ${histories.length} xien win records');
    return histories;
  }

  /// Lấy lịch sử chu kỳ theo khoảng thời gian
  Future<List<CycleWinHistory>> getCycleHistoryByDateRange({
    required String startDate,
    required String endDate,
  }) async {
    final allHistory = await getAllCycleWinHistory();
    
    return allHistory.where((h) {
      final date = h.ngayTrung;
      return _isDateInRange(date, startDate, endDate);
    }).toList();
  }

  /// Lấy lịch sử xiên theo khoảng thời gian
  Future<List<XienWinHistory>> getXienHistoryByDateRange({
    required String startDate,
    required String endDate,
  }) async {
    final allHistory = await getAllXienWinHistory();
    
    return allHistory.where((h) {
      final date = h.ngayTrung;
      return _isDateInRange(date, startDate, endDate);
    }).toList();
  }

  /// Tìm kiếm lịch sử chu kỳ theo số
  Future<List<CycleWinHistory>> searchCycleByNumber(String number) async {
    final allHistory = await getAllCycleWinHistory();
    return allHistory.where((h) => h.soMucTieu == number).toList();
  }

  /// Tìm kiếm lịch sử xiên theo cặp số
  Future<List<XienWinHistory>> searchXienByPair(String pair) async {
    final allHistory = await getAllXienWinHistory();
    return allHistory.where((h) => h.capSoMucTieu == pair).toList();
  }

  /// Lấy lịch sử chu kỳ theo miền
  Future<List<CycleWinHistory>> getCycleHistoryByMien(String mien) async {
    final allHistory = await getAllCycleWinHistory();
    return allHistory.where((h) => h.mienTrung == mien).toList();
  }

  /// Lấy lịch sử chu kỳ theo trạng thái
  Future<List<CycleWinHistory>> getCycleHistoryByStatus(String status) async {
    final allHistory = await getAllCycleWinHistory();
    return allHistory.where((h) => h.trangThai == status).toList();
  }

  /// Lấy lịch sử xiên theo trạng thái
  Future<List<XienWinHistory>> getXienHistoryByStatus(String status) async {
    final allHistory = await getAllXienWinHistory();
    return allHistory.where((h) => h.trangThai == status).toList();
  }

  /// Xóa lịch sử chu kỳ cụ thể
  Future<void> deleteCycleWinHistory(int stt) async {
    print('🗑️ Deleting cycle win history STT: $stt...');
    
    final values = await _sheetsService.getAllValues('cycleWinHistory');
    
    if (values.length < 2) {
      print('   ⚠️ No data to delete');
      return;
    }

    // Find row index
    int? rowIndex;
    for (int i = 1; i < values.length; i++) {
      if (values[i].isNotEmpty && values[i][0].toString() == stt.toString()) {
        rowIndex = i;
        break;
      }
    }

    if (rowIndex == null) {
      print('   ⚠️ STT not found');
      return;
    }

    // Clear row (Google Sheets API doesn't support row deletion easily)
    final emptyRow = List.filled(16, '');
    await _sheetsService.updateRange(
      'cycleWinHistory',
      'A${rowIndex + 1}:P${rowIndex + 1}',
      [emptyRow],
    );
    
    print('   ✅ Deleted cycle win history STT: $stt');
  }

  /// Xóa lịch sử xiên cụ thể
  Future<void> deleteXienWinHistory(int stt) async {
    print('🗑️ Deleting xien win history STT: $stt...');
    
    final values = await _sheetsService.getAllValues('xienWinHistory');
    
    if (values.length < 2) {
      print('   ⚠️ No data to delete');
      return;
    }

    // Find row index
    int? rowIndex;
    for (int i = 1; i < values.length; i++) {
      if (values[i].isNotEmpty && values[i][0].toString() == stt.toString()) {
        rowIndex = i;
        break;
      }
    }

    if (rowIndex == null) {
      print('   ⚠️ STT not found');
      return;
    }

    // Clear row
    final emptyRow = List.filled(16, '');
    await _sheetsService.updateRange(
      'xienWinHistory',
      'A${rowIndex + 1}:P${rowIndex + 1}',
      [emptyRow],
    );
    
    print('   ✅ Deleted xien win history STT: $stt');
  }

  /// Cập nhật ghi chú cho lịch sử chu kỳ
  Future<void> updateCycleWinNote({
    required int stt,
    required String note,
  }) async {
    print('📝 Updating cycle win note for STT: $stt...');
    
    final values = await _sheetsService.getAllValues('cycleWinHistory');
    
    if (values.length < 2) {
      print('   ⚠️ No data found');
      return;
    }

    // Find row index
    int? rowIndex;
    for (int i = 1; i < values.length; i++) {
      if (values[i].isNotEmpty && values[i][0].toString() == stt.toString()) {
        rowIndex = i;
        break;
      }
    }

    if (rowIndex == null) {
      print('   ⚠️ STT not found');
      return;
    }

    // Update note (column P, index 15)
    await _sheetsService.updateRange(
      'cycleWinHistory',
      'P${rowIndex + 1}',
      [[note]],
    );
    
    print('   ✅ Updated note for STT: $stt');
  }

  /// Cập nhật ghi chú cho lịch sử xiên
  Future<void> updateXienWinNote({
    required int stt,
    required String note,
  }) async {
    print('📝 Updating xien win note for STT: $stt...');
    
    final values = await _sheetsService.getAllValues('xienWinHistory');
    
    if (values.length < 2) {
      print('   ⚠️ No data found');
      return;
    }

    // Find row index
    int? rowIndex;
    for (int i = 1; i < values.length; i++) {
      if (values[i].isNotEmpty && values[i][0].toString() == stt.toString()) {
        rowIndex = i;
        break;
      }
    }

    if (rowIndex == null) {
      print('   ⚠️ STT not found');
      return;
    }

    // Update note (column P, index 15)
    await _sheetsService.updateRange(
      'xienWinHistory',
      'P${rowIndex + 1}',
      [[note]],
    );
    
    print('   ✅ Updated note for STT: $stt');
  }

  /// Lấy thống kê tổng quan chu kỳ
  Future<WinTrackingStats> getCycleStats() async {
    final allHistory = await getAllCycleWinHistory();
    final wins = allHistory.where((h) => h.isWin).toList();
    
    final totalProfit = wins.fold<double>(0, (sum, h) => sum + h.loiLo);
    final totalBet = wins.fold<double>(0, (sum, h) => sum + h.tongTienCuoc);
    final totalReturn = wins.fold<double>(0, (sum, h) => sum + h.tienVe);
    final avgROI = wins.isNotEmpty
        ? wins.fold<double>(0, (sum, h) => sum + h.roi) / wins.length
        : 0.0;
    
    return WinTrackingStats(
      totalWins: wins.length,
      totalProfit: totalProfit,
      totalBet: totalBet,
      totalReturn: totalReturn,
      avgROI: avgROI,
      overallROI: totalBet > 0 ? (totalProfit / totalBet) * 100 : 0,
    );
  }

  /// Lấy thống kê tổng quan xiên
  Future<WinTrackingStats> getXienStats() async {
    final allHistory = await getAllXienWinHistory();
    final wins = allHistory.where((h) => h.isWin).toList();
    
    final totalProfit = wins.fold<double>(0, (sum, h) => sum + h.loiLo);
    final totalBet = wins.fold<double>(0, (sum, h) => sum + h.tongTienCuoc);
    final totalReturn = wins.fold<double>(0, (sum, h) => sum + h.tienVe);
    final avgROI = wins.isNotEmpty
        ? wins.fold<double>(0, (sum, h) => sum + h.roi) / wins.length
        : 0.0;
    
    return WinTrackingStats(
      totalWins: wins.length,
      totalProfit: totalProfit,
      totalBet: totalBet,
      totalReturn: totalReturn,
      avgROI: avgROI,
      overallROI: totalBet > 0 ? (totalProfit / totalBet) * 100 : 0,
    );
  }

  /// Helper: Check if date is in range
  bool _isDateInRange(String date, String startDate, String endDate) {
    try {
      final parts = date.split('/');
      if (parts.length != 3) return false;
      
      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final year = int.parse(parts[2]);
      final checkDate = DateTime(year, month, day);
      
      final startParts = startDate.split('/');
      final startDay = int.parse(startParts[0]);
      final startMonth = int.parse(startParts[1]);
      final startYear = int.parse(startParts[2]);
      final start = DateTime(startYear, startMonth, startDay);
      
      final endParts = endDate.split('/');
      final endDay = int.parse(endParts[0]);
      final endMonth = int.parse(endParts[1]);
      final endYear = int.parse(endParts[2]);
      final end = DateTime(endYear, endMonth, endDay);
      
      return checkDate.isAfter(start.subtract(const Duration(days: 1))) &&
             checkDate.isBefore(end.add(const Duration(days: 1)));
    } catch (e) {
      return false;
    }
  }
}

/// Class thống kê
class WinTrackingStats {
  final int totalWins;
  final double totalProfit;
  final double totalBet;
  final double totalReturn;
  final double avgROI;
  final double overallROI;

  WinTrackingStats({
    required this.totalWins,
    required this.totalProfit,
    required this.totalBet,
    required this.totalReturn,
    required this.avgROI,
    required this.overallROI,
  });

  @override
  String toString() {
    return 'WinTrackingStats('
        'wins: $totalWins, '
        'profit: ${totalProfit.toStringAsFixed(2)}, '
        'avgROI: ${avgROI.toStringAsFixed(2)}%)';
  }
}