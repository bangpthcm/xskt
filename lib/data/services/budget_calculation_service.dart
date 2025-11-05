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
    
    double tatCa5Days = 0;
    double trung5Days = 0;
    double bac5Days = 0;
    double xien5Days = 0;

    try {
      // 1. Tất cả (xsktBot1)
      tatCa5Days = await _getTotalMoneyAt5thRow(
        sheetName: 'xsktBot1',
        columnIndex: 7,  // "Tổng tiền" ở cột H (index 7)
      );

      // 2. Trung Bot
      trung5Days = await _getTotalMoneyAt5thRow(
        sheetName: 'trungBot',
        columnIndex: 7,
      );

      // 3. Bắc Bot
      bac5Days = await _getTotalMoneyAt5thRow(
        sheetName: 'bacBot',
        columnIndex: 7,
      );

      // 4. Xiên Bot
      xien5Days = await _getTotalMoneyAt5thRow(
        sheetName: 'xienBot',
        columnIndex: 5,  // "Tổng tiền" ở cột F (index 5) cho Xiên
      );

      final total = tatCa5Days + trung5Days + bac5Days + xien5Days;

      print('📊 5 Days Reserved Result:');
      print('   Tất cả: ${NumberUtils.formatCurrency(tatCa5Days)} VNĐ');
      print('   Trung:  ${NumberUtils.formatCurrency(trung5Days)} VNĐ');
      print('   Bắc:    ${NumberUtils.formatCurrency(bac5Days)} VNĐ');
      print('   Xiên:   ${NumberUtils.formatCurrency(xien5Days)} VNĐ');
      print('   Total:  ${NumberUtils.formatCurrency(total)} VNĐ');

      return Reserved5DaysResult(
        tatCaReserved: tatCa5Days,
        trungReserved: trung5Days,
        bacReserved: bac5Days,
        xienReserved: xien5Days,
        totalReserved: total,
      );

    } catch (e) {
      print('❌ Error calculating 5 days reserved: $e');
      return Reserved5DaysResult(
        tatCaReserved: 0,
        trungReserved: 0,
        bacReserved: 0,
        xienReserved: 0,
        totalReserved: 0,
        hasError: true,
        errorMessage: e.toString(),
      );
    }
  }

  /// ✅ NEW: Tính budget khả dụng cho một bảng cụ thể
  Future<AvailableBudgetResult> calculateAvailableBudget({
    required double totalCapital,
    required String targetTable,  // 'tatca', 'trung', 'bac', 'xien'
    double? configBudget,  // null nếu là bảng "Tất cả"
  }) async {
    print('💰 Calculating available budget for: $targetTable');
    
    // STEP 1: Tính 5 ngày dự trữ
    final reserved = await calculate5DaysReserved();
    
    if (reserved.hasError) {
      throw Exception('Lỗi tính dự trữ: ${reserved.errorMessage}');
    }

    // STEP 2: Tính available (trừ đi dự trữ của CHÍNH BẢNG này nếu đang có)
    double totalReservedExcludingSelf = reserved.totalReserved;
    
    switch (targetTable.toLowerCase()) {
      case 'tatca':
        totalReservedExcludingSelf -= reserved.tatCaReserved;
        break;
      case 'trung':
        totalReservedExcludingSelf -= reserved.trungReserved;
        break;
      case 'bac':
        totalReservedExcludingSelf -= reserved.bacReserved;
        break;
      case 'xien':
        totalReservedExcludingSelf -= reserved.xienReserved;
        break;
    }

    final available = totalCapital - totalReservedExcludingSelf;

    print('   Total capital: ${NumberUtils.formatCurrency(totalCapital)}');
    print('   Reserved (excluding self): ${NumberUtils.formatCurrency(totalReservedExcludingSelf)}');
    print('   Available: ${NumberUtils.formatCurrency(available)}');

    // STEP 3: Xác định budgetMax
    double budgetMax;
    
    if (targetTable.toLowerCase() == 'tatca') {
      // Bảng "Tất cả" không so sánh config
      budgetMax = available;
      print('   Budget max (Tất cả): ${NumberUtils.formatCurrency(budgetMax)} (no config limit)');
    } else {
      if (configBudget == null) {
        throw Exception('Config budget is required for $targetTable');
      }
      // Các bảng khác: lấy min(config, available)
      budgetMax = available < configBudget ? available : configBudget;
      print('   Config budget: ${NumberUtils.formatCurrency(configBudget)}');
      print('   Budget max: ${NumberUtils.formatCurrency(budgetMax)} (min of both)');
    }

    // STEP 4: Validate minimum
    const minimumRequired = 50000.0;
    if (available < minimumRequired) {
      throw BudgetInsufficientException(
        tableName: targetTable,
        budgetResult: AvailableBudgetResult(
          totalCapital: totalCapital,
          reservedBreakdown: reserved,
          available: available,
          budgetMax: budgetMax,
          configBudget: configBudget,
        ),
        minimumRequired: minimumRequired,
      );
    }

    return AvailableBudgetResult(
      totalCapital: totalCapital,
      reservedBreakdown: reserved,
      available: available,
      budgetMax: budgetMax,
      configBudget: configBudget,
    );
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

      // Lấy dòng thứ 5
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
}

/// Result model cho 5 days reserved
class Reserved5DaysResult {
  final double tatCaReserved;
  final double trungReserved;
  final double bacReserved;
  final double xienReserved;
  final double totalReserved;
  final bool hasError;
  final String? errorMessage;

  Reserved5DaysResult({
    required this.tatCaReserved,
    required this.trungReserved,
    required this.bacReserved,
    required this.xienReserved,
    required this.totalReserved,
    this.hasError = false,
    this.errorMessage,
  });

  bool get isValid => !hasError && totalReserved >= 0;
}

/// ✅ NEW: Result model cho available budget
class AvailableBudgetResult {
  final double totalCapital;
  final Reserved5DaysResult reservedBreakdown;
  final double available;
  final double budgetMax;
  final double? configBudget;

  AvailableBudgetResult({
    required this.totalCapital,
    required this.reservedBreakdown,
    required this.available,
    required this.budgetMax,
    this.configBudget,
  });

  /// Helper: Tạo error message chi tiết khi budget không đủ
  String getDetailedErrorMessage({
    required String tableName,
    required double minimumRequired,
  }) {
    final shortage = minimumRequired - available;
    
    final buffer = StringBuffer();
    buffer.writeln('Không đủ vốn để tạo bảng $tableName!');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('📊 Phân tích:');
    buffer.writeln('  • Tổng vốn: ${NumberUtils.formatCurrency(totalCapital)} VNĐ');
    buffer.writeln('  • Đã dự trữ 5 ngày:');
    buffer.writeln('    - Tất cả: ${NumberUtils.formatCurrency(reservedBreakdown.tatCaReserved)} VNĐ');
    buffer.writeln('    - Trung: ${NumberUtils.formatCurrency(reservedBreakdown.trungReserved)} VNĐ');
    buffer.writeln('    - Bắc: ${NumberUtils.formatCurrency(reservedBreakdown.bacReserved)} VNĐ');
    buffer.writeln('    - Xiên: ${NumberUtils.formatCurrency(reservedBreakdown.xienReserved)} VNĐ');
    buffer.writeln('  → Tổng dự trữ: ${NumberUtils.formatCurrency(reservedBreakdown.totalReserved)} VNĐ');
    buffer.writeln('  → Vốn khả dụng: ${NumberUtils.formatCurrency(available)} VNĐ');
    buffer.writeln('');
    buffer.writeln('💰 Nhu cầu:');
    buffer.writeln('  • Cần tối thiểu: ${NumberUtils.formatCurrency(minimumRequired)} VNĐ');
    buffer.writeln('  • Còn thiếu: ${NumberUtils.formatCurrency(shortage)} VNĐ');
    buffer.writeln('');
    buffer.writeln('💡 Giải pháp:');
    buffer.writeln('  - Tăng tổng vốn thêm ${NumberUtils.formatCurrency(shortage)} VNĐ');
    buffer.writeln('  - Hoặc xóa/giảm budget các bảng khác');
    
    return buffer.toString();
  }

  /// Helper: Tạo error message khi generate thất bại
  String getOptimizationFailedMessage({
    required String tableName,
    required double estimatedTotal,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('Không thể tạo bảng cược $tableName!');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('💰 Thông tin:');
    buffer.writeln('  • Budget khả dụng: ${NumberUtils.formatCurrency(budgetMax)} VNĐ');
    buffer.writeln('  • Tổng tiền ước tính: ${NumberUtils.formatCurrency(estimatedTotal)} VNĐ');
    buffer.writeln('');
    buffer.writeln('⚠️ Nguyên nhân:');
    buffer.writeln('  Thuật toán tối ưu không tìm được cấu hình');
    buffer.writeln('  phù hợp trong khoảng budget cho phép.');
    buffer.writeln('');
    buffer.writeln('💡 Giải pháp:');
    buffer.writeln('  - Thử lại (có thể do điều kiện biên)');
    buffer.writeln('  - Điều chỉnh tăng budget nếu cần');
    
    return buffer.toString();
  }
}

/// ✅ NEW: Exception khi budget không đủ
class BudgetInsufficientException implements Exception {
  final String tableName;
  final AvailableBudgetResult budgetResult;
  final double minimumRequired;

  BudgetInsufficientException({
    required this.tableName,
    required this.budgetResult,
    required this.minimumRequired,
  });

  @override
  String toString() {
    return budgetResult.getDetailedErrorMessage(
      tableName: tableName,
      minimumRequired: minimumRequired,
    );
  }
}

/// ✅ NEW: Exception khi optimization thất bại
class OptimizationFailedException implements Exception {
  final String tableName;
  final AvailableBudgetResult budgetResult;
  final double estimatedTotal;

  OptimizationFailedException({
    required this.tableName,
    required this.budgetResult,
    required this.estimatedTotal,
  });

  @override
  String toString() {
    return budgetResult.getOptimizationFailedMessage(
      tableName: tableName,
      estimatedTotal: estimatedTotal,
    );
  }
}