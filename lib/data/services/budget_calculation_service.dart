// lib/data/services/budget_calculation_service.dart

import 'google_sheets_service.dart';
import '../../core/utils/date_utils.dart' as date_utils;
import '../../core/utils/number_utils.dart';

class BudgetCalculationService {
  final GoogleSheetsService _sheetsService;

  BudgetCalculationService({
    required GoogleSheetsService sheetsService,
  }) : _sheetsService = sheetsService;

  /// ✅ NEW: Tính tổng tiền dự trữ dựa trên ngày kết thúc của bảng đang tạo
  /// Logic:
  /// 1. Tìm tổng tiền tại ngày kết thúc từ các bảng còn lại
  /// 2. Nếu bảng nào không có ngày đó, lấy tổng tiền cả bảng
  /// 3. Cho bảng "Tất cả" (xsktBot1): lấy giá trị lớn nhất trong ngày (1, 2 hoặc 3 dòng)
  /// 4. Cho bảng "Xiên": tìm ngày và lấy cột F (tổng tiền), nếu không có ngày thì lấy dòng cuối
  Future<Reserved5DaysResult> calculateReservedByEndDate({
    required String targetTable,  // 'tatca', 'trung', 'bac', 'xien'
    required DateTime endDate,    // Ngày kết thúc bảng đang tạo
  }) async {
    print('📊 Calculating reserved by end date...');
    print('   Target table: $targetTable');
    print('   End date: ${date_utils.DateUtils.formatDate(endDate)}');
    
    double tatCa5Days = 0;
    double trung5Days = 0;
    double bac5Days = 0;
    double xien5Days = 0;

    try {
      final endDateStr = date_utils.DateUtils.formatDate(endDate);

      // ✅ Tính dự trữ cho các bảng KHÔNG phải bảng đang tạo
      
      // 1. Tất cả (xsktBot1) - lấy giá trị lớn nhất trong ngày kết thúc
      if (targetTable != 'tatca') {
        tatCa5Days = await _getTotalMoneyByDate(
          sheetName: 'xsktBot1',
          targetDate: endDateStr,
          columnIndex: 7,
          takeMaxIfMultiple: true,  // Lấy max vì có thể 1, 2 hoặc 3 dòng
        );
        print('   ✅ xsktBot1 (ngày $endDateStr): ${NumberUtils.formatCurrency(tatCa5Days)}');
      }

      // 2. Trung Bot - lấy tổng tiền ngày kết thúc
      if (targetTable != 'trung') {
        trung5Days = await _getTotalMoneyByDate(
          sheetName: 'trungBot',
          targetDate: endDateStr,
          columnIndex: 7,
          takeMaxIfMultiple: false,
        );
        print('   ✅ trungBot (ngày $endDateStr): ${NumberUtils.formatCurrency(trung5Days)}');
      }

      // 3. Bắc Bot - lấy tổng tiền ngày kết thúc
      if (targetTable != 'bac') {
        bac5Days = await _getTotalMoneyByDate(
          sheetName: 'bacBot',
          targetDate: endDateStr,
          columnIndex: 7,
          takeMaxIfMultiple: false,
        );
        print('   ✅ bacBot (ngày $endDateStr): ${NumberUtils.formatCurrency(bac5Days)}');
      }

      // 4. Xiên Bot - tìm ngày trong bảng, lấy cột F (tổng tiền)
      if (targetTable != 'xien') {
        xien5Days = await _getTotalMoneyByDate(
          sheetName: 'xienBot',
          targetDate: endDateStr,
          columnIndex: 5,  // Cột F (index 5) = Tổng tiền
          takeMaxIfMultiple: false,
        );
        print('   ✅ xienBot (ngày $endDateStr): ${NumberUtils.formatCurrency(xien5Days)}');
      }

      final total = tatCa5Days + trung5Days + bac5Days + xien5Days;

      print('📊 Reserved by End Date Result:');
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
      print('❌ Error calculating reserved by end date: $e');
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

  /// ✅ HELPER: Lấy tổng tiền tại ngày cụ thể từ bảng
  /// Nếu ngày không tồn tại, lấy tổng tiền cả bảng (dòng cuối cùng)
  /// Nếu có option takeMaxIfMultiple=true, lấy giá trị lớn nhất
  Future<double> _getTotalMoneyByDate({
    required String sheetName,
    required String targetDate,
    required int columnIndex,
    required bool takeMaxIfMultiple,  // true: lấy max (cho xsktBot1), false: lấy dòng cuối
  }) async {
    try {
      final rows = await _sheetsService.getAllValues(sheetName);

      if (rows.length < 4) {
        print('   ⚠️ $sheetName: Bảng trống');
        return 0;
      }

      // ✅ Tìm các dòng có ngày = targetDate
      final matchingRows = <Map<String, dynamic>>[];

      for (int i = 3; i < rows.length; i++) {
        final row = rows[i];
        
        if (row.isEmpty || row.length < 2) continue;
        
        final rowDate = row[1].toString().trim();
        
        if (rowDate == targetDate) {
          if (row.length > columnIndex) {
            final value = _parseSheetNumber(row[columnIndex]);
            matchingRows.add({
              'rowIndex': i,
              'value': value,
              'row': row,
            });
          }
        }
      }

      // ✅ Xử lý kết quả
      if (matchingRows.isEmpty) {
        print('   ⚠️ $sheetName: Ngày $targetDate không tồn tại, lấy dòng cuối cùng');
        return await _getTotalMoneyOfWholeSheet(
          sheetName: sheetName,
          columnIndex: columnIndex,
        );
      }

      // ✅ Nếu cần lấy max (cho xsktBot1 có thể 1, 2 hoặc 3 dòng)
      if (takeMaxIfMultiple && matchingRows.length > 1) {
        final maxValue = matchingRows
            .map((m) => m['value'] as double)
            .reduce((a, b) => a > b ? a : b);
        
        print('   📍 $sheetName: Ngày $targetDate - ${matchingRows.length} dòng, lấy max: ${NumberUtils.formatCurrency(maxValue)}');
        return maxValue;
      }

      // ✅ Nếu chỉ có 1 dòng, lấy dòng đó
      if (matchingRows.length == 1) {
        final value = matchingRows[0]['value'] as double;
        print('   📍 $sheetName: Ngày $targetDate - dòng ${matchingRows[0]['rowIndex'] + 1}: ${NumberUtils.formatCurrency(value)}');
        return value;
      }

      // ✅ Nếu có nhiều dòng, lấy dòng cuối cùng (giá trị lớn nhất)
      final lastValue = matchingRows.last['value'] as double;
      print('   📍 $sheetName: Ngày $targetDate - ${matchingRows.length} dòng, lấy dòng cuối: ${NumberUtils.formatCurrency(lastValue)}');
      return lastValue;

    } catch (e) {
      print('   ❌ Error reading $sheetName by date $targetDate: $e');
      return 0;
    }
  }

  /// ✅ HELPER: Lấy tổng tiền cả bảng (dòng cuối cùng có dữ liệu)
  Future<double> _getTotalMoneyOfWholeSheet({
    required String sheetName,
    required int columnIndex,
  }) async {
    try {
      final rows = await _sheetsService.getAllValues(sheetName);

      if (rows.length < 4) {
        print('   ⚠️ $sheetName: Bảng không có dữ liệu');
        return 0;
      }

      // Tìm dòng cuối cùng có dữ liệu
      for (int i = rows.length - 1; i >= 3; i--) {
        final row = rows[i];
        
        if (row.isEmpty || row[0].toString().trim().isEmpty) continue;
        if (row.length <= columnIndex) continue;
        
        final value = _parseSheetNumber(row[columnIndex]);
        print('   📍 $sheetName: Dòng cuối cùng (dòng ${i + 1}): ${NumberUtils.formatCurrency(value)}');
        return value;
      }

      print('   ⚠️ $sheetName: Không tìm thấy dòng dữ liệu');
      return 0;

    } catch (e) {
      print('   ❌ Error reading $sheetName whole sheet: $e');
      return 0;
    }
  }

  /// ✅ Calculate available budget với end date
  Future<AvailableBudgetResult> calculateAvailableBudgetByEndDate({
    required double totalCapital,
    required String targetTable,  // 'tatca', 'trung', 'bac', 'xien'
    double? configBudget,
    required DateTime endDate,    // Ngày kết thúc bảng đang tạo
  }) async {
    print('💰 Calculating available budget by end date...');
    print('   Target table: $targetTable');
    print('   End date: ${date_utils.DateUtils.formatDate(endDate)}');
    
    // ✅ STEP 1: Tính reserved dựa trên end date
    final reserved = await calculateReservedByEndDate(
      targetTable: targetTable,
      endDate: endDate,
    );
    
    if (reserved.hasError) {
      throw Exception('Lỗi tính dự trữ: ${reserved.errorMessage}');
    }

    // ✅ STEP 2: Tính tổng dự trữ (trừ đi dự trữ của bảng hiện tại nếu có)
    double totalReservedExcludingSelf = reserved.totalReserved;

    // ✅ STEP 3: Xác định budgetMax
    double budgetMax;
    
    if (targetTable.toLowerCase() == 'tatca') {
      budgetMax = totalCapital - totalReservedExcludingSelf;
      print('   Budget max (Tất cả): ${NumberUtils.formatCurrency(budgetMax)} (no config limit)');
    } else {
      if (configBudget == null) {
        throw Exception('Config budget is required for $targetTable');
      }
      
      final available = totalCapital - totalReservedExcludingSelf;
      budgetMax = available < configBudget ? available : configBudget;
      
      print('   Total capital: ${NumberUtils.formatCurrency(totalCapital)}');
      print('   Reserved: ${NumberUtils.formatCurrency(totalReservedExcludingSelf)}');
      print('   Config budget: ${NumberUtils.formatCurrency(configBudget)}');
      print('   Budget max: ${NumberUtils.formatCurrency(budgetMax)} (min of both)');
    }

    // ✅ STEP 4: Validate minimum
    const minimumRequired = 50000.0;
    final available = totalCapital - totalReservedExcludingSelf;
    
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

  /// Helper: Parse number từ Google Sheets (format VN)
  double _parseSheetNumber(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    
    String str = value.toString().trim();
    if (str.isEmpty) return 0.0;
    
    // Handle Vietnamese number format
    int dotCount = '.'.allMatches(str).length;
    int commaCount = ','.allMatches(str).length;
    
    if (dotCount > 0 && commaCount > 0) {
      str = str.replaceAll('.', '').replaceAll(',', '.');
    } else if (dotCount > 0) {
      if (dotCount > 1) {
        str = str.replaceAll('.', '');
      } else {
        final dotIndex = str.indexOf('.');
        final afterDot = str.length - dotIndex - 1;
        if (afterDot == 3) {
          str = str.replaceAll('.', '');
        }
      }
    } else if (commaCount > 0) {
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
      return 0.0;
    }
  }
}

/// Result model cho reserved
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

/// Result model cho available budget
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
    buffer.writeln('  • Vốn đang dùng:');
    buffer.writeln('    - Tất cả: ${NumberUtils.formatCurrency(reservedBreakdown.tatCaReserved)} VNĐ');
    buffer.writeln('    - Trung: ${NumberUtils.formatCurrency(reservedBreakdown.trungReserved)} VNĐ');
    buffer.writeln('    - Bắc: ${NumberUtils.formatCurrency(reservedBreakdown.bacReserved)} VNĐ');
    buffer.writeln('    - Xiên: ${NumberUtils.formatCurrency(reservedBreakdown.xienReserved)} VNĐ');
    buffer.writeln('  → Tổng vốn đang dùng: ${NumberUtils.formatCurrency(reservedBreakdown.totalReserved)} VNĐ');
    buffer.writeln('  → Vốn khả dụng: ${NumberUtils.formatCurrency(available)} VNĐ');
    buffer.writeln('');
    buffer.writeln('💰 Nhu cầu:');
    buffer.writeln('  • Cần tối thiểu: ${NumberUtils.formatCurrency(minimumRequired)} VNĐ');
    buffer.writeln('  • Còn thiếu: ${NumberUtils.formatCurrency(shortage)} VNĐ');
    buffer.writeln('');
    buffer.writeln('💡 Giải pháp:');
    buffer.writeln('  - Tăng tổng vốn thêm');
    buffer.writeln('  - Hoặc đợi đến khi một số bảng kết thúc để giải phóng vốn');
    
    return buffer.toString();
  }

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
    buffer.writeln('  - Điều chỉnh tăng budget nếu cần');
    
    return buffer.toString();
  }
}

/// Exception khi budget không đủ
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

/// Exception khi optimization thất bại
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