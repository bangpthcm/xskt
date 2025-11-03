// lib/data/services/budget_calculation_service.dart

import 'google_sheets_service.dart';
import '../../core/utils/number_utils.dart';

class BudgetCalculationService {
  final GoogleSheetsService _sheetsService;

  BudgetCalculationService({
    required GoogleSheetsService sheetsService,
  }) : _sheetsService = sheetsService;

  /// Tính tổng tiền dự trữ cho 5 ngày tiếp theo
  /// (Lấy giá trị "Tổng tiền" ở dòng thứ 5 của mỗi bảng)
  Future<Reserved5DaysResult> calculate5DaysReserved() async {
    print('📊 Calculating 5 days reserved...');
    
    double trung5Days = 0;
    double bac5Days = 0;
    double xien5Days = 0;

    try {
      // 1. Trung Bot
      trung5Days = await _getTotalMoneyAt5thRow(
        sheetName: 'trungBot',
        columnIndex: 7,  // "Tổng tiền" ở cột H (index 7)
      );

      // 2. Bắc Bot
      bac5Days = await _getTotalMoneyAt5thRow(
        sheetName: 'bacBot',
        columnIndex: 7,  // "Tổng tiền" ở cột H (index 7)
      );

      // 3. Xiên Bot
      xien5Days = await _getTotalMoneyAt5thRow(
        sheetName: 'xienBot',
        columnIndex: 5,  // "Tổng tiền" ở cột F (index 5) cho Xiên
      );

      final total = trung5Days + bac5Days + xien5Days;

      print('📊 5 Days Reserved Result:');
      print('   Trung: ${NumberUtils.formatCurrency(trung5Days)} VNĐ');
      print('   Bắc:   ${NumberUtils.formatCurrency(bac5Days)} VNĐ');
      print('   Xiên:  ${NumberUtils.formatCurrency(xien5Days)} VNĐ');
      print('   Total: ${NumberUtils.formatCurrency(total)} VNĐ');

      return Reserved5DaysResult(
        trungReserved: trung5Days,
        bacReserved: bac5Days,
        xienReserved: xien5Days,
        totalReserved: total,
      );

    } catch (e) {
      print('❌ Error calculating 5 days reserved: $e');
      return Reserved5DaysResult(
        trungReserved: 0,
        bacReserved: 0,
        xienReserved: 0,
        totalReserved: 0,
        hasError: true,
        errorMessage: e.toString(),
      );
    }
  }

  /// Helper: Lấy giá trị "Tổng tiền" ở dòng thứ 5 của một bảng
  Future<double> _getTotalMoneyAt5thRow({
    required String sheetName,
    required int columnIndex,
  }) async {
    try {
      final rows = await _sheetsService.getAllValues(sheetName);

      // Structure: 
      // Row 0: Metadata header
      // Row 1: Empty or metadata
      // Row 2: Column headers (STT, Ngày, Miền, ...)
      // Row 3: Data row 1
      // Row 4: Data row 2
      // Row 5: Data row 3
      // Row 6: Data row 4
      // Row 7: Data row 5  ← Dòng thứ 5
      // Row 8: Data row 6

      // ✅ Dòng thứ 5 của data = index 7 (0-based)
      const targetRowIndex = 7;

      if (rows.length < targetRowIndex + 1) {
        // Bảng có ít hơn 5 dòng data
        if (rows.length > 3) {
          // Lấy dòng cuối cùng
          final lastRowIndex = rows.length - 1;
          final lastRow = rows[lastRowIndex];
          
          if (lastRow.length > columnIndex) {
            final value = _parseSheetNumber(lastRow[columnIndex]);
            print('   $sheetName: Chỉ có ${rows.length - 3} dòng, lấy dòng cuối = ${NumberUtils.formatCurrency(value)}');
            return value;
          }
        }
        
        print('   $sheetName: Bảng trống hoặc không đủ dữ liệu');
        return 0;
      }

      // ✅ Lấy dòng thứ 5
      final row5 = rows[targetRowIndex];
      
      if (row5.length <= columnIndex) {
        print('   $sheetName: Dòng thứ 5 không có cột index $columnIndex');
        return 0;
      }

      final value = _parseSheetNumber(row5[columnIndex]);
      print('   $sheetName: Dòng thứ 5 = ${NumberUtils.formatCurrency(value)}');
      
      return value;

    } catch (e) {
      print('   ❌ Error reading $sheetName: $e');
      return 0;
    }
  }

  /// Helper: Parse number từ Google Sheets (format VN)
  double _parseSheetNumber(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    
    String str = value.toString().trim();
    if (str.isEmpty) return 0.0;
    
    // Handle Vietnamese number format (dot as thousands separator)
    int dotCount = '.'.allMatches(str).length;
    int commaCount = ','.allMatches(str).length;
    
    // CASE 1: Both dot and comma
    if (dotCount > 0 && commaCount > 0) {
      str = str.replaceAll('.', '').replaceAll(',', '.');
    }
    // CASE 2: Only dots
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
    // CASE 3: Only commas
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
      print('   ⚠️ Parse error for "$value": $e');
      return 0.0;
    }
  }

  /// Tính budget khả dụng cho "Tất cả"
  Future<double> calculateTatCaBudget(double totalCapital) async {
    final reserved = await calculate5DaysReserved();
    final available = totalCapital - reserved.totalReserved;
    
    print('💰 Tất cả Budget Calculation:');
    print('   Total Capital: ${NumberUtils.formatCurrency(totalCapital)}');
    print('   Reserved (5 days): ${NumberUtils.formatCurrency(reserved.totalReserved)}');
    print('   Available: ${NumberUtils.formatCurrency(available)}');
    
    return available > 0 ? available : 0;
  }
}

/// Result model cho 5 days reserved
class Reserved5DaysResult {
  final double trungReserved;
  final double bacReserved;
  final double xienReserved;
  final double totalReserved;
  final bool hasError;
  final String? errorMessage;

  Reserved5DaysResult({
    required this.trungReserved,
    required this.bacReserved,
    required this.xienReserved,
    required this.totalReserved,
    this.hasError = false,
    this.errorMessage,
  });

  bool get isValid => !hasError && totalReserved >= 0;
}