// lib/data/services/auto_check_service.dart

import '../models/lottery_result.dart';
import '../models/betting_row.dart';
import '../models/cycle_win_history.dart';
import '../models/xien_win_history.dart';
import '../models/gan_pair_info.dart';
import '../models/win_result.dart';
import 'win_calculation_service.dart';
import 'win_tracking_service.dart';
import 'google_sheets_service.dart';
import 'telegram_service.dart';
import '../../core/utils/date_utils.dart' as date_utils;
import 'backfill_service.dart';
import 'rss_parser_service.dart';

class AutoCheckService {
  final WinCalculationService _winCalcService;
  final WinTrackingService _trackingService;
  final GoogleSheetsService _sheetsService;
  final TelegramService _telegramService;
  final BackfillService _backfillService;  // ✅ THÊM

  AutoCheckService({
    required WinCalculationService winCalcService,
    required WinTrackingService trackingService,
    required GoogleSheetsService sheetsService,
    required TelegramService telegramService,
    required BackfillService backfillService,  // ✅ THÊM
  })  : _winCalcService = winCalcService,
        _trackingService = trackingService,
        _sheetsService = sheetsService,
        _telegramService = telegramService,
        _backfillService = backfillService;  // ✅ THÊM

  /// Kiểm tra kết quả hàng ngày
  Future<CheckDailyResult> checkDailyResults({
    String? specificDate,
  }) async {
    print('🔍 ============ STARTING DAILY CHECK ============');
    
    // ✅ BƯỚC 0: BACKFILL DỮ LIỆU TRƯỚC
    print('🔄 Step 0: Backfilling data from RSS...');
    try {
      final backfillResult = await _backfillService.syncAllFromRSS();
      print('📊 Backfill result: ${backfillResult.message}');
      
      if (backfillResult.hasError) {
        print('⚠️ Backfill had errors but continuing check...');
      }
    } catch (backfillError) {
      print('⚠️ Backfill failed: $backfillError');
      print('   Continuing with existing data...');
    }
    
    final checkDate = specificDate ?? 
        date_utils.DateUtils.formatDate(
          DateTime.now().subtract(const Duration(days: 1))
        );
    
    print('📅 Check date: $checkDate');
    
    int cycleWins = 0;
    int xienWins = 0;
    final messages = <String>[];

    try {
      // 1. Kiểm tra chu kỳ
      final cycleResult = await _checkCycleTable(checkDate);
      cycleWins = cycleResult.winsCount;
      messages.addAll(cycleResult.messages);
      
      // 2. Kiểm tra xiên
      final xienResult = await _checkXienTable(checkDate);
      xienWins = xienResult.winsCount;
      messages.addAll(xienResult.messages);
      
      print('✅ ============ DAILY CHECK COMPLETED ============');
      print('   Cycle wins: $cycleWins');
      print('   Xien wins: $xienWins');
      
      return CheckDailyResult(
        success: true,
        cycleWins: cycleWins,
        xienWins: xienWins,
        messages: messages,
      );
      
    } catch (e) {
      print('❌ Error during daily check: $e');
      return CheckDailyResult(
        success: false,
        cycleWins: cycleWins,
        xienWins: xienWins,
        messages: ['Lỗi kiểm tra: $e'],
      );
    }
  }

  /// Kiểm tra bảng chu kỳ
  Future<_CheckResult> _checkCycleTable(String checkDate) async {
    print('\n📊 ========== CHECKING CYCLE TABLE ==========');
    
    final pendingDates = await _trackingService.getCyclePendingCheckDates();
    
    if (!pendingDates.contains(checkDate)) {
      print('⏭️ No pending cycle bets for $checkDate');
      return _CheckResult(winsCount: 0, messages: []);
    }

    final allResults = await _loadAllResults();
    final bettingTableData = await _sheetsService.getAllValues('xsktBot1');
    
    if (bettingTableData.length < 4) {
      print('⚠️ No betting data in cycle table');
      return _CheckResult(winsCount: 0, messages: []);
    }

    final metadata = bettingTableData[0];
    final startDate = metadata.length > 1 ? metadata[1].toString() : '';
    final targetNumber = metadata.length > 3 ? metadata[3].toString() : '';

    print('🎯 Target number: $targetNumber');
    print('📅 Start date: $startDate');

    int winsCount = 0;
    final messages = <String>[];
    
    // ✅ ADD: Flag để track đã tìm thấy WIN chưa
    bool foundWinForDate = false;
    WinResult? firstWinResult;
    int firstWinRowIndex = -1;

    // Duyệt qua các dòng
    for (int i = 3; i < bettingTableData.length; i++) {
      final row = bettingTableData[i];
      
      if (row.isEmpty || row[0].toString().trim().isEmpty) continue;
      
      final rowDate = row[1].toString();
      if (rowDate != checkDate) continue;
      
      final checked = row.length > 10 
          ? row[10].toString().toUpperCase() == 'TRUE' 
          : false;
      
      if (checked) {
        print('⏭️ Row ${i+1} already checked');
        continue;
      }

      // ✅ CRITICAL: Nếu đã tìm thấy WIN cho ngày này rồi
      // Chỉ cần đánh dấu các rows còn lại là WIN, không lưu history nữa
      if (foundWinForDate && firstWinResult != null) {
        print('⏭️ Row ${i+1}: Already found WIN for $checkDate, just marking...');
        
        final bettingRow = _parseCycleBettingRow(row);
        
        // Chỉ update status, KHÔNG lưu history
        await _trackingService.updateCycleBettingStatus(
          rowNumber: i + 1,
          checked: true,
          result: 'WIN',
          winDate: checkDate,
          winMien: firstWinResult.winningMien,
          actualProfit: firstWinResult.profit,
        );
        
        continue;  // ✅ Bỏ qua, không check nữa
      }

      // Parse betting row
      final bettingRow = _parseCycleBettingRow(row);
      
      // Tính toán win
      final winResult = await _winCalcService.calculateCycleWin(
        targetNumber: targetNumber,
        checkDate: checkDate,
        allResults: allResults,
        totalBet: bettingRow.tongTien,
        betPerNumber: bettingRow.cuocSo,
      );

      if (winResult != null && winResult.isWin) {
        winsCount++;
        print('🎉 WIN FOUND! Row ${i+1}');
        
        // ✅ CRITICAL: Chỉ lưu history cho lần WIN đầu tiên
        if (!foundWinForDate) {
          foundWinForDate = true;
          firstWinResult = winResult;
          firstWinRowIndex = i;
          
          // Lưu lịch sử (CHỈ 1 LẦN)
          final history = CycleWinHistory(
            stt: 0,
            ngayKiemTra: date_utils.DateUtils.formatDate(DateTime.now()),
            soMucTieu: targetNumber,
            ngayBatDau: startDate,
            ngayTrung: checkDate,
            mienTrung: winResult.winningMien,
            soLanTrung: winResult.occurrences,
            cacTinhTrung: winResult.provincesDisplay,
            tienCuocSo: bettingRow.cuocSo,
            tongTienCuoc: bettingRow.tongTien,
            tienVe: winResult.totalReturn,
            loiLo: winResult.profit,
            roi: winResult.roi,
            soNgayCuoc: _winCalcService.calculateDaysBetween(startDate, checkDate),
            trangThai: 'WIN',
            ghiChu: 'Tự động phát hiện',
          );
          
          await _trackingService.saveCycleWinHistory(history);
          
          // Tạo message
          final message = '🎉 CHU KỲ TRÚNG!\n'
              'Số: $targetNumber\n'
              'Ngày: $checkDate\n'
              'Miền: ${winResult.winningMien}\n'
              'Lần: ${winResult.occurrences}x\n'
              'Lời: ${winResult.profit.toStringAsFixed(0)} VNĐ\n'
              'ROI: ${winResult.roi.toStringAsFixed(2)}%';
          
          messages.add(message);
          
          // Gửi Telegram
          try {
            await _telegramService.sendMessage(message);
          } catch (e) {
            print('⚠️ Failed to send Telegram: $e');
          }
        }
        
        // Cập nhật bảng cược
        await _trackingService.updateCycleBettingStatus(
          rowNumber: i + 1,
          checked: true,
          result: 'WIN',
          winDate: checkDate,
          winMien: winResult.winningMien,
          actualProfit: winResult.profit,
        );
        
      } else {
        // Đánh dấu đã check nhưng chưa trúng
        await _trackingService.updateCycleBettingStatus(
          rowNumber: i + 1,
          checked: true,
          result: 'PENDING',
        );
      }
    }

    return _CheckResult(winsCount: winsCount, messages: messages);
  }

  /// Kiểm tra bảng xiên
  Future<_CheckResult> _checkXienTable(String checkDate) async {
    print('\n📊 ========== CHECKING XIEN TABLE ==========');
    
    final pendingDates = await _trackingService.getXienPendingCheckDates();
    
    if (!pendingDates.contains(checkDate)) {
      print('⏭️ No pending xien bets for $checkDate');
      return _CheckResult(winsCount: 0, messages: []);
    }

    final allResults = await _loadAllResults();
    final bettingTableData = await _sheetsService.getAllValues('xienBot');
    
    if (bettingTableData.length < 4) {
      print('⚠️ No betting data in xien table');
      return _CheckResult(winsCount: 0, messages: []);
    }

    final metadata = bettingTableData[0];
    final startDate = metadata.length > 1 ? metadata[1].toString() : '';
    final pairStr = metadata.length > 3 ? metadata[3].toString() : '';
    
    final pairParts = pairStr.split('-');
    if (pairParts.length != 2) {
      print('⚠️ Invalid pair format: $pairStr');
      return _CheckResult(winsCount: 0, messages: []);
    }
    
    final targetPair = NumberPair(pairParts[0], pairParts[1]);

    print('🎯 Target pair: ${targetPair.display}');
    print('📅 Start date: $startDate');

    int winsCount = 0;
    final messages = <String>[];
    
    // ✅ ADD: Flag cho xien
    bool foundWinForDate = false;
    WinResult? firstWinResult;

    for (int i = 3; i < bettingTableData.length; i++) {
      final row = bettingTableData[i];
      
      if (row.isEmpty || row[0].toString().trim().isEmpty) continue;
      
      final rowDate = row[1].toString();
      if (rowDate != checkDate) continue;
      
      final checked = row.length > 7 
          ? row[7].toString().toUpperCase() == 'TRUE' 
          : false;
      
      if (checked) {
        print('⏭️ Row ${i+1} already checked');
        continue;
      }

      // ✅ CRITICAL: Nếu đã tìm thấy WIN rồi
      if (foundWinForDate && firstWinResult != null) {
        print('⏭️ Row ${i+1}: Already found WIN for $checkDate, just marking...');
        
        await _trackingService.updateXienBettingStatus(
          rowNumber: i + 1,
          checked: true,
          result: 'WIN',
          winDate: checkDate,
          actualProfit: firstWinResult.profit,
        );
        
        continue;
      }

      final bettingRow = _parseXienBettingRow(row);
      
      final winResult = await _winCalcService.calculateXienWin(
        targetPair: targetPair,
        checkDate: checkDate,
        allResults: allResults,
        totalBet: bettingRow.tongTien,
        betPerMien: bettingRow.cuocMien,
      );

      if (winResult != null && winResult.isWin) {
        winsCount++;
        print('🎉 WIN FOUND! Row ${i+1}');
        
        // ✅ CRITICAL: Chỉ lưu lần đầu
        if (!foundWinForDate) {
          foundWinForDate = true;
          firstWinResult = winResult;
          
          final history = XienWinHistory(
            stt: 0,
            ngayKiemTra: date_utils.DateUtils.formatDate(DateTime.now()),
            capSoMucTieu: targetPair.display,
            ngayBatDau: startDate,
            ngayTrung: checkDate,
            mienTrung: 'Bắc',
            soLanTrungCap: winResult.occurrences,
            chiTietTrung: 'Cặp xuất hiện ${winResult.occurrences} lần',
            tienCuocMien: bettingRow.cuocMien,
            tongTienCuoc: bettingRow.tongTien,
            tienVe: winResult.totalReturn,
            loiLo: winResult.profit,
            roi: winResult.roi,
            soNgayCuoc: _winCalcService.calculateDaysBetween(startDate, checkDate),
            trangThai: 'WIN',
            ghiChu: 'Tự động phát hiện',
          );
          
          await _trackingService.saveXienWinHistory(history);
          
          final message = '🎉 XIÊN TRÚNG!\n'
              'Cặp: ${targetPair.display}\n'
              'Ngày: $checkDate\n'
              'Lần: ${winResult.occurrences}x\n'
              'Lời: ${winResult.profit.toStringAsFixed(0)} VNĐ\n'
              'ROI: ${winResult.roi.toStringAsFixed(2)}%';
          
          messages.add(message);
          
          try {
            await _telegramService.sendMessage(message);
          } catch (e) {
            print('⚠️ Failed to send Telegram: $e');
          }
        }
        
        await _trackingService.updateXienBettingStatus(
          rowNumber: i + 1,
          checked: true,
          result: 'WIN',
          winDate: checkDate,
          actualProfit: winResult.profit,
        );
        
      } else {
        await _trackingService.updateXienBettingStatus(
          rowNumber: i + 1,
          checked: true,
          result: 'PENDING',
        );
      }
    }

    return _CheckResult(winsCount: winsCount, messages: messages);
  }

  /// Load all KQXS results
  Future<List<LotteryResult>> _loadAllResults() async {
    final values = await _sheetsService.getAllValues('KQXS');
    
    final results = <LotteryResult>[];
    for (int i = 1; i < values.length; i++) {
      try {
        results.add(LotteryResult.fromSheetRow(values[i]));
      } catch (e) {
        // Skip invalid rows
      }
    }
    
    return results;
  }

/// Parse cycle betting row
  BettingRow _parseCycleBettingRow(List<dynamic> row) {
    return BettingRow.forCycle(
      stt: int.parse(row[0].toString()),
      ngay: row[1].toString(),
      mien: row[2].toString(),
      so: row[3].toString(),
      soLo: _parseNumber(row[4]).round(),
      cuocSo: _parseNumber(row[5]),
      cuocMien: _parseNumber(row[6]),
      tongTien: _parseNumber(row[7]),
      loi1So: _parseNumber(row[8]),
      loi2So: _parseNumber(row[9]),
    );
  }

  /// Parse xien betting row
  BettingRow _parseXienBettingRow(List<dynamic> row) {
    return BettingRow.forXien(
      stt: int.parse(row[0].toString()),
      ngay: row[1].toString(),
      mien: row[2].toString(),
      so: row[3].toString(),
      cuocMien: _parseNumber(row[4]),
      tongTien: _parseNumber(row[5]),
      loi: _parseNumber(row[6]),
    );
  }

  /// Parse number from sheet
  /// ✅ Parse number từ Google Sheets (format VN: dấu chấm = nghìn)
  double _parseNumber(dynamic value) {
    if (value == null) return 0.0;
    
    // Nếu đã là number, return luôn
    if (value is num) return value.toDouble();
    
    String str = value.toString().trim();
    
    if (str.isEmpty) return 0.0;
    
    // ✅ LOGIC MỚI: Xử lý format VN
    // Format VN: 3.762 = 3762 (dấu chấm là phân cách nghìn)
    // Format VN: 3.762,50 = 3762.50 (dấu chấm = nghìn, dấu phẩy = thập phân)
    
    int dotCount = '.'.allMatches(str).length;
    int commaCount = ','.allMatches(str).length;
    
    print('   🔢 Parsing: "$str" (dots: $dotCount, commas: $commaCount)');
    
    // CASE 1: Có cả chấm VÀ phẩy → Format VN: 1.234.567,89
    if (dotCount > 0 && commaCount > 0) {
      // Xóa dấu chấm (phân cách nghìn)
      // Đổi dấu phẩy thành dấu chấm (thập phân)
      str = str.replaceAll('.', '').replaceAll(',', '.');
      print('   → Case 1 (dot+comma): "$str"');
    }
    // CASE 2: Chỉ có dấu chấm
    else if (dotCount > 0) {
      // CASE 2A: Nhiều dấu chấm → Chắc chắn là phân cách nghìn
      // VD: 1.234.567
      if (dotCount > 1) {
        str = str.replaceAll('.', '');
        print('   → Case 2A (multiple dots): "$str"');
      }
      // CASE 2B: Chỉ 1 dấu chấm
      else {
        final dotIndex = str.indexOf('.');
        final afterDot = str.length - dotIndex - 1;
        
        // Nếu sau dấu chấm có 3 chữ số → Phân cách nghìn
        // VD: 3.762 = 3762
        if (afterDot == 3) {
          str = str.replaceAll('.', '');
          print('   → Case 2B (dot as thousands): "$str"');
        }
        // Nếu sau dấu chấm có 1-2 chữ số → Thập phân
        // VD: 3.5 hoặc 3.50
        else if (afterDot <= 2) {
          // Giữ nguyên
          print('   → Case 2C (dot as decimal): "$str"');
        }
        // Trường hợp khác: Xóa dấu chấm để an toàn
        else {
          str = str.replaceAll('.', '');
          print('   → Case 2D (remove dot): "$str"');
        }
      }
    }
    // CASE 3: Chỉ có dấu phẩy
    else if (commaCount > 0) {
      // CASE 3A: Nhiều dấu phẩy → Phân cách nghìn (format US)
      if (commaCount > 1) {
        str = str.replaceAll(',', '');
        print('   → Case 3A (multiple commas): "$str"');
      }
      // CASE 3B: 1 dấu phẩy
      else {
        final commaIndex = str.indexOf(',');
        final afterComma = str.length - commaIndex - 1;
        
        // Nếu sau dấu phẩy có 1-2 chữ số → Thập phân (VN)
        // VD: 3,50
        if (afterComma <= 2) {
          str = str.replaceAll(',', '.');
          print('   → Case 3B (comma as decimal): "$str"');
        }
        // Nếu sau dấu phẩy có 3 chữ số → Phân cách nghìn (US)
        // VD: 3,762
        else if (afterComma == 3) {
          str = str.replaceAll(',', '');
          print('   → Case 3C (comma as thousands): "$str"');
        }
        // Trường hợp khác: Xóa phẩy
        else {
          str = str.replaceAll(',', '');
          print('   → Case 3D (remove comma): "$str"');
        }
      }
    }
    // CASE 4: Không có dấu gì → Số nguyên
    else {
      print('   → Case 4 (plain number): "$str"');
    }
    
    // Remove spaces
    str = str.replaceAll(' ', '');
    
    try {
      final result = double.parse(str);
      print('   ✅ Parsed result: $result');
      return result;
    } catch (e) {
      print('   ❌ Parse error: $e, returning 0');
      return 0.0;
    }
  }
}

// Helper classes
class CheckDailyResult {
  final bool success;
  final int cycleWins;
  final int xienWins;
  final List<String> messages;

  CheckDailyResult({
    required this.success,
    required this.cycleWins,
    required this.xienWins,
    required this.messages,
  });
}

class _CheckResult {
  final int winsCount;
  final List<String> messages;

  _CheckResult({
    required this.winsCount,
    required this.messages,
  });
}