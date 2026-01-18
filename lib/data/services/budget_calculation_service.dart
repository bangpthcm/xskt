// lib/data/services/budget_calculation_service.dart

import '../../core/utils/date_utils.dart' as date_utils;
import '../../core/utils/number_utils.dart';
import 'google_sheets_service.dart';

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
    required String targetTable,
    required DateTime endDate,
    required String endMien,
  }) async {
    double tatCaReserved = 0;
    double namReserved = 0; // ✅ MỚI
    double trungReserved = 0;
    double bacReserved = 0;
    double xienReserved = 0;

    final endDateStr = date_utils.DateUtils.formatDate(endDate);

    // 1. Tất cả (xsktBot1)
    if (targetTable != 'tatca' && targetTable != 'xsktBot1') {
      tatCaReserved = await _getTotalMoneyByDate(
        sheetName: 'xsktBot1',
        targetDate: endDateStr,
        targetMien: endMien,
        columnIndex: 7,
      );
    }

    // ✅ 2. Miền Nam (namBot) - Cột H (index 7)
    if (targetTable != 'nam' && targetTable != 'namBot') {
      namReserved = await _getTotalMoneyByDate(
        sheetName: 'namBot',
        targetDate: endDateStr,
        targetMien: endMien,
        columnIndex: 7,
      );
    }

    // 3. Trung Bot
    if (targetTable != 'trung' && targetTable != 'trungBot') {
      trungReserved = await _getTotalMoneyByDate(
        sheetName: 'trungBot',
        targetDate: endDateStr,
        targetMien: endMien,
        columnIndex: 7,
      );
    }

    // 4. Bắc Bot
    if (targetTable != 'bac' && targetTable != 'bacBot') {
      bacReserved = await _getTotalMoneyByDate(
        sheetName: 'bacBot',
        targetDate: endDateStr,
        targetMien: endMien,
        columnIndex: 7,
      );
    }

    // 5. Xiên Bot
    if (targetTable != 'xien' && targetTable != 'xienBot') {
      xienReserved = await _getTotalMoneyByDate(
        sheetName: 'xienBot',
        targetDate: endDateStr,
        targetMien: endMien,
        columnIndex: 5,
      );
    }

    final total = tatCaReserved +
        namReserved +
        trungReserved +
        bacReserved +
        xienReserved;
    return Reserved5DaysResult(
      tatCaReserved: tatCaReserved,
      namReserved: namReserved, // ✅ MỚI
      trungReserved: trungReserved,
      bacReserved: bacReserved,
      xienReserved: xienReserved,
      totalReserved: total,
    );
  }

  /// ✅ HELPER: Lấy tổng tiền tại ngày cụ thể từ bảng
  /// Nếu ngày không tồn tại, lấy tổng tiền cả bảng (dòng cuối cùng)
  /// Nếu có option takeMaxIfMultiple=true, lấy giá trị lớn nhất
  Future<double> _getTotalMoneyByDate({
    required String sheetName,
    required String targetDate,
    required String targetMien,
    required int columnIndex,
  }) async {
    try {
      final rows = await _sheetsService.getAllValues(sheetName);
      if (rows.length < 4) return 0;

      DateTime? targetDt = date_utils.DateUtils.parseDate(targetDate);
      if (targetDt == null) return 0;

      final mienOrder = {'Nam': 1, 'Trung': 2, 'Bắc': 3};
      int targetMienVal = mienOrder[targetMien] ?? 3;

      double lastValidValue = 0;

      for (int i = 3; i < rows.length; i++) {
        final row = rows[i];
        if (row.length < 3) continue;

        DateTime? rowDt = date_utils.DateUtils.parseDate(row[1].toString());
        if (rowDt == null) continue;

        String rowMien = row[2].toString().trim();
        int rowMienVal = mienOrder[rowMien] ?? 0;

        if (rowDt.isBefore(targetDt) ||
            (rowDt.isAtSameMomentAs(targetDt) && rowMienVal <= targetMienVal)) {
          if (row.length > columnIndex) {
            lastValidValue = _parseSheetNumber(row[columnIndex]);
          }
        } else {
          break;
        }
      }
      return lastValidValue;
    } catch (e) {
      return 0;
    }
  }

  /// ✅ Calculate available budget với end date
  Future<AvailableBudgetResult> calculateAvailableBudgetByEndDate({
    required double totalCapital,
    required String targetTable,
    double? configBudget,
    required DateTime endDate,
    required String endMien,
  }) async {
    final reserved = await calculateReservedByEndDate(
      targetTable: targetTable,
      endDate: endDate,
      endMien: endMien,
    );

    double available = totalCapital - reserved.totalReserved;
    double budgetMax;

    if (targetTable.toLowerCase() == 'tatca' || targetTable == 'xsktBot1') {
      budgetMax = available;
    } else {
      if (configBudget == null) throw Exception('Yêu cầu Config Budget');
      budgetMax = available < configBudget ? available : configBudget;
    }

    return AvailableBudgetResult(
      totalCapital: totalCapital,
      reservedBreakdown: reserved,
      available: available,
      budgetMax: budgetMax,
      configBudget: configBudget,
    );
  }

  Future<AvailableBudgetResult> calculateAvailableBudgetFromData({
    required double totalCapital,
    required String targetTable,
    double? configBudget,
    required DateTime endDate,
    required String endMien, // 👈 THÊM
    required Map<String, List<List<dynamic>>> allSheetsData,
  }) async {
    // 1. Tính số tiền bị giữ (Reserved) dựa trên data RAM
    final reserved = _calculateReservedInternal(
      targetTable: targetTable,
      endDate: endDate,
      endMien: endMien, // 👈 THÊM
      data: allSheetsData,
    );

    double totalReservedExcludingSelf = reserved.totalReserved;
    double budgetMax;

    if (targetTable.toLowerCase() == 'tatca' || targetTable == 'xsktbot1') {
      budgetMax = totalCapital - totalReservedExcludingSelf;
    } else {
      if (configBudget == null) throw Exception('Config budget required');
      final available = totalCapital - totalReservedExcludingSelf;
      budgetMax = available < configBudget ? available : configBudget;
    }

    final available = totalCapital - totalReservedExcludingSelf;

    return AvailableBudgetResult(
      totalCapital: totalCapital,
      reservedBreakdown: reserved,
      available: available,
      budgetMax: budgetMax,
      configBudget: configBudget,
    );
  }

  // ✅ HÀM HELPER: Đọc dữ liệu từ RAM để tính tiền
  Reserved5DaysResult _calculateReservedInternal({
    required String targetTable,
    required DateTime endDate,
    required String endMien,
    required Map<String, List<List<dynamic>>> data,
  }) {
    final mienOrder = {'Nam': 1, 'Trung': 2, 'Bắc': 3};
    int targetMienVal = mienOrder[endMien] ?? 3;

    double getMoney(String key, int colIdx) {
      String sheetName = switch (key) {
        'tatca' || 'xsktBot1' => 'xsktBot1',
        'nam' || 'namBot' => 'namBot', // ✅ MỚI
        'trung' || 'trungBot' => 'trungBot',
        'bac' || 'bacBot' => 'bacBot',
        'xien' || 'xienBot' => 'xienBot',
        _ => key
      };

      if (targetTable == key || targetTable == sheetName) return 0;

      final rows = data[sheetName];
      if (rows == null || rows.length < 4) return 0;

      double lastValue = 0;
      for (int i = 3; i < rows.length; i++) {
        final row = rows[i];
        if (row.length < 3) continue;

        DateTime? rowDt = date_utils.DateUtils.parseDate(row[1].toString());
        int rowMienVal = mienOrder[row[2].toString().trim()] ?? 0;

        if (rowDt == null) continue;

        if (rowDt.isBefore(endDate) ||
            (rowDt.isAtSameMomentAs(endDate) && rowMienVal <= targetMienVal)) {
          if (row.length > colIdx) lastValue = _parseSheetNumber(row[colIdx]);
        } else {
          break;
        }
      }
      return lastValue;
    }

    final tatCa = getMoney('tatca', 7);
    final nam = getMoney('nam', 7); // ✅ MỚI
    final trung = getMoney('trung', 7);
    final bac = getMoney('bac', 7);
    final xien = getMoney('xien', 5);

    return Reserved5DaysResult(
      tatCaReserved: tatCa,
      namReserved: nam, // ✅ MỚI
      trungReserved: trung,
      bacReserved: bac,
      xienReserved: xien,
      totalReserved: tatCa + nam + trung + bac + xien,
    );
  }

  /// Helper: Parse number từ Google Sheets (format VN)
  double _parseSheetNumber(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    String str = value.toString().trim();
    if (str.isEmpty) return 0.0;

    // Xử lý định dạng VN (chấm ngăn cách nghìn, phẩy thập phân)
    if (str.contains('.') && str.contains(',')) {
      str = str.replaceAll('.', '').replaceAll(',', '.');
    } else if (str.contains(',')) {
      // Nếu chỉ có dấu phẩy, kiểm tra xem là thập phân hay ngăn nghìn
      final parts = str.split(',');
      if (parts.last.length <= 2)
        str = str.replaceAll(',', '.');
      else
        str = str.replaceAll(',', '');
    } else if (str.contains('.')) {
      // Nếu chỉ có dấu chấm, kiểm tra xem là ngăn nghìn hay thập phân
      final parts = str.split('.');
      if (parts.last.length == 3) str = str.replaceAll('.', '');
    }

    str = str.replaceAll(' ', '');
    try {
      return double.parse(str);
    } catch (e) {
      return 0.0;
    }
  }
}

class Reserved5DaysResult {
  final double tatCaReserved;
  final double namReserved; // ✅ MỚI
  final double trungReserved;
  final double bacReserved;
  final double xienReserved;
  final double totalReserved;
  final bool hasError;
  final String? errorMessage;

  Reserved5DaysResult({
    required this.tatCaReserved,
    required this.namReserved, // ✅ MỚI
    required this.trungReserved,
    required this.bacReserved,
    required this.xienReserved,
    required this.totalReserved,
    this.hasError = false,
    this.errorMessage,
  });

  bool get isValid => !hasError && totalReserved >= 0;
}

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
    buffer.writeln('📊 Phân tích:');
    buffer.writeln(
        '  • Tổng vốn: ${NumberUtils.formatCurrency(totalCapital)} VNĐ');
    buffer.writeln('  • Vốn đang dùng:');
    buffer.writeln(
        '    - Tất cả: ${NumberUtils.formatCurrency(reservedBreakdown.tatCaReserved)} VNĐ');
    buffer.writeln(
        '    - Nam: ${NumberUtils.formatCurrency(reservedBreakdown.namReserved)} VNĐ'); // ✅ MỚI
    buffer.writeln(
        '    - Trung: ${NumberUtils.formatCurrency(reservedBreakdown.trungReserved)} VNĐ');
    buffer.writeln(
        '    - Bắc: ${NumberUtils.formatCurrency(reservedBreakdown.bacReserved)} VNĐ');
    buffer.writeln(
        '    - Xiên: ${NumberUtils.formatCurrency(reservedBreakdown.xienReserved)} VNĐ');
    buffer.writeln(
        '  → Tổng vốn đang dùng: ${NumberUtils.formatCurrency(reservedBreakdown.totalReserved)} VNĐ');
    buffer.writeln(
        '  → Vốn khả dụng: ${NumberUtils.formatCurrency(available)} VNĐ');
    buffer.writeln(
        '\n💰 Nhu cầu: ${NumberUtils.formatCurrency(minimumRequired)} VNĐ');
    buffer
        .writeln('  • Còn thiếu: ${NumberUtils.formatCurrency(shortage)} VNĐ');
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
    buffer.writeln(
        '  • Budget khả dụng: ${NumberUtils.formatCurrency(budgetMax)} VNĐ');
    buffer.writeln(
        '  • Tổng tiền ước tính: ${NumberUtils.formatCurrency(estimatedTotal)} VNĐ');
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
