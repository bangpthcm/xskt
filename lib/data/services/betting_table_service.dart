// lib/data/services/betting_table_service.dart

import 'dart:math';
import '../models/betting_row.dart';
import '../models/gan_pair_info.dart';
import '../models/cycle_analysis_result.dart';
import '../../core/utils/date_utils.dart' as date_utils;
import '../../core/utils/number_utils.dart';
import '../models/lottery_result.dart';
import '../../core/constants/app_constants.dart';

class BettingTableService {
  /// Generate Xien Table
  Future<List<BettingRow>> generateXienTable({
    required GanPairInfo ganInfo,
    required DateTime startDate,
    required double xienBudget,
  }) async {
    final soNgayGan = ganInfo.daysGan;
    final durationDays = AppConstants.durationBaseXien - soNgayGan;

    if (durationDays <= 1) {
      throw Exception('Số ngày gan quá lớn: $soNgayGan (cần < ${AppConstants.durationBaseXien})');
    }

    final capSoMucTieu = ganInfo.randomPair;
    final rawTable = <BettingRow>[];
    
    double tongTien = 0.0;
    final profitStep = (AppConstants.finalProfit - AppConstants.startingProfit) / (durationDays - 1);
    
    // ✅ FIX: Khởi tạo tienCuocMien an toàn
    double tienCuocMien = AppConstants.startingProfit / (AppConstants.winMultiplierXien - 1);
    if (tienCuocMien.isNaN || tienCuocMien.isInfinite) {
      tienCuocMien = 100.0;
    }

    // Bước 1: Tính toán thô
    final tempRows = <Map<String, dynamic>>[];
    for (int i = 0; i < durationDays; i++) {
      final currentProfitTarget = AppConstants.startingProfit + (profitStep * i);
      
      if (i > 0) {
        tienCuocMien = (tongTien + currentProfitTarget) / (AppConstants.winMultiplierXien - 1);
        // ✅ FIX: Kiểm tra NaN/Infinity
        if (tienCuocMien.isNaN || tienCuocMien.isInfinite) {
          tienCuocMien = 100.0;
        }
      }
      
      if (tempRows.isNotEmpty) {
        final prevCuoc = tempRows.last['cuoc_mien'] as double? ?? 100.0;
        tienCuocMien = max(prevCuoc, tienCuocMien);
      }
      
      tienCuocMien = tienCuocMien.ceilToDouble();
      
      // ✅ FIX: Kiểm tra trước khi cộng
      if (tienCuocMien.isFinite) {
        tongTien += tienCuocMien;
      } else {
        throw Exception('Invalid tienCuocMien: $tienCuocMien');
      }
      
      tempRows.add({
        'ngay': _formatDateWith2Digits(startDate.add(Duration(days: i))),
        'cuoc_mien': tienCuocMien,
        'tong': tongTien,
      });
    }

    // Bước 2: Chuẩn hóa theo ngân sách (Scaling)
    final rawTotalCost = tempRows.last['tong'] as double? ?? 1.0;
    if (rawTotalCost <= 0) {
      throw Exception('Tổng tiền tính toán không hợp lệ: $rawTotalCost');
    }
    
    final scalingFactor = xienBudget / rawTotalCost;
    
    // ✅ FIX: Kiểm tra scaling factor
    if (scalingFactor.isNaN || scalingFactor.isInfinite || scalingFactor <= 0) {
      throw Exception('Invalid scaling factor: $scalingFactor (budget: $xienBudget, cost: $rawTotalCost)');
    }

    for (int i = 0; i < tempRows.length; i++) {
      final row = tempRows[i];
      
      double cuocMien = (row['cuoc_mien'] as double? ?? 100.0) * scalingFactor;
      cuocMien = cuocMien.ceilToDouble();
      
      // ✅ FIX: Kiểm tra cuocMien
      if (!cuocMien.isFinite) {
        throw Exception('Invalid cuocMien at row $i: $cuocMien');
      }
      
      double tongTienRow = i == 0 ? cuocMien : rawTable[i-1].tongTien + cuocMien;
      double loi = (cuocMien * AppConstants.winMultiplierXien) - tongTienRow;
      
      // ✅ FIX: Kiểm tra tất cả giá trị
      if (!tongTienRow.isFinite || !loi.isFinite) {
        throw Exception('Invalid values at row $i: tongTien=$tongTienRow, loi=$loi');
      }
      
      rawTable.add(BettingRow.forXien(
        stt: i + 1,
        ngay: row['ngay'] as String,
        mien: 'Bắc',
        so: capSoMucTieu.display,
        cuocMien: cuocMien,
        tongTien: tongTienRow,
        loi: loi,
      ));
    }
    
    print('✅ Generated ${rawTable.length} xien rows (budget: ${NumberUtils.formatCurrency(xienBudget)})');
    return rawTable;
  }

  /// Generate Cycle Table (Sử dụng hàm tối ưu chung)
  Future<List<BettingRow>> generateCycleTable({
    required CycleAnalysisResult cycleResult,
    required DateTime startDate,
    required DateTime endDate,
    required int startMienIndex,
    required double budgetMin,
    required double budgetMax,
    required List<LotteryResult> allResults,
    required int maxMienCount, 
  }) async {
    // Xác định miền mục tiêu
    String targetMien = 'Nam';
    for (final entry in cycleResult.mienGroups.entries) {
      if (entry.value.contains(cycleResult.targetNumber)) {
        targetMien = entry.key;
        break;
      }
    }

    return _optimizeTableSearch(
      budgetMin: budgetMin,
      budgetMax: budgetMax,
      calculator: (profitTarget, startBet) => _calculateCycleTableInternal(
        targetNumber: cycleResult.targetNumber,
        targetMien: targetMien,
        startDate: startDate,
        endDate: endDate,
        startMienIndex: startMienIndex,
        startBetValue: startBet,
        profitTarget: profitTarget,
        lastSeenDate: cycleResult.lastSeenDate,
        allResults: allResults,
        maxMienCount: maxMienCount,
      ),
      configName: "Cycle Table",
    );
  }

  // generateBacGanTable
  Future<List<BettingRow>> generateBacGanTable({
    required CycleAnalysisResult cycleResult,
    required DateTime startDate,
    required DateTime endDate,
    required double budgetMin,
    required double budgetMax,
  }) async {
    return _optimizeTableSearch(
      budgetMin: budgetMin,
      budgetMax: budgetMax,
      calculator: (profitTarget, startBet) => _calculateSingleMienTable(
        targetNumber: cycleResult.targetNumber,
        mien: 'Bắc',
        startDate: startDate,
        endDate: endDate,
        startBetValue: startBet,
        profitTarget: profitTarget,
        durationLimit: AppConstants.durationBaseBac,  // ✅ Dùng constant
        winMultiplier: AppConstants.bacGanWinMultiplier,
      ),
      configName: "Bắc Gan",
      profitSearchRange: 22,
      betSearchRange: 22,
    );
  }

  // generateTrungGanTable
  Future<List<BettingRow>> generateTrungGanTable({
    required CycleAnalysisResult cycleResult,
    required DateTime startDate,
    required DateTime endDate,
    required double budgetMin,
    required double budgetMax,
  }) async {
    return _optimizeTableSearch(
      budgetMin: budgetMin,
      budgetMax: budgetMax,
      calculator: (profitTarget, startBet) => _calculateSingleMienTable(
        targetNumber: cycleResult.targetNumber,
        mien: 'Trung',
        startDate: startDate,
        endDate: endDate,
        startBetValue: startBet,
        profitTarget: profitTarget,
        durationLimit: AppConstants.durationBaseTrung,  // ✅ Dùng constant
        winMultiplier: AppConstants.trungGanWinMultiplier,
      ),
      configName: "Trung Gan",
      profitSearchRange: 22,
      betSearchRange: 22,
    );
  }

  Future<List<BettingRow>> _optimizeTableSearch({
    required double budgetMin,
    required double budgetMax,
    required Future<Map<String, dynamic>> Function(double profit, double bet) calculator,
    required String configName,
    int profitSearchRange = 12,
    int betSearchRange = 11,
  }) async {
    double lowProfit = 100.0;
    double highProfit = 100000.0;
    List<BettingRow>? bestTable;

    // Vòng lặp 1: Tìm Profit Target phù hợp
    for (int i = 0; i < profitSearchRange; i++) {
      if (highProfit < lowProfit) break;
      final midProfit = ((lowProfit + highProfit) / 2);

      // Tìm StartBet tốt nhất cho Profit này
      final foundTable = await _findBestStartBet(
        budgetMin: budgetMin,
        budgetMax: budgetMax,
        profitTarget: midProfit,
        calculator: calculator,
        searchRange: betSearchRange,
      );

      if (foundTable != null) {
        bestTable ??= foundTable;
        
        // Thử tinh chỉnh lợi nhuận một chút để tối ưu hơn
        final adjustedProfit = midProfit * 3.5 / 4.2; // Giữ logic cũ của bạn
        final optimizedTable = await _findBestStartBet(
          budgetMin: budgetMin,
          budgetMax: budgetMax,
          profitTarget: adjustedProfit,
          calculator: calculator,
          searchRange: betSearchRange,
        );

        if (optimizedTable != null) bestTable = optimizedTable;
        
        lowProfit = midProfit + 1;
      } else {
        highProfit = midProfit - 1;
      }
    }

    // Xử lý khi không tìm thấy bảng (Error handling)
    if (bestTable == null) {
      // Chạy thử 1 lần với tham số cơ bản để lấy số tiền thực tế báo lỗi
      final testResult = await calculator(100.0, 1.0);
      final actualTotal = testResult['tong_tien'] as double;

      if (actualTotal > budgetMax) {
        throw Exception(
          'Không thể tạo bảng $configName!\n'
          'Ngân sách tối đa: ${NumberUtils.formatCurrency(budgetMax)} VNĐ\n'
          'Cần tối thiểu: ${NumberUtils.formatCurrency(actualTotal)} VNĐ\n'
          'Thiếu: ${NumberUtils.formatCurrency(actualTotal - budgetMax)} VNĐ'
        );
      } else {
        throw Exception(
          'Lỗi tạo bảng $configName!\n'
          'Ngân sách: ${NumberUtils.formatCurrency(budgetMax)} VNĐ\n'
          'Không tìm được cấu hình tối ưu. Vui lòng thử lại.'
        );
      }
    }

    return bestTable;
  }

  /// Hàm tìm StartBet (Vòng lặp con bên trong)
  Future<List<BettingRow>?> _findBestStartBet({
    required double budgetMin,
    required double budgetMax,
    required double profitTarget,
    required Future<Map<String, dynamic>> Function(double profit, double bet) calculator,
    required int searchRange,
  }) async {
    double lowBet = profitTarget / 3 / 50; // Ước lượng
    if (lowBet < 0.5) lowBet = 0.5;
    double highBet = 2000.0;
    List<BettingRow>? localBestTable;

    for (int i = 0; i < searchRange; i++) {
      if (highBet < lowBet) break;
      double midBet = ((lowBet + highBet) / 2);
      if (midBet < 0.5) midBet = 0.5;

      final result = await calculator(profitTarget, midBet);
      final tongTien = result['tong_tien'] as double;
      final table = result['table'] as List<BettingRow>;

      if (tongTien >= budgetMin && tongTien <= budgetMax) {
        localBestTable = table;
        highBet = midBet - 0.1; // Cố gắng giảm cược để tiết kiệm
      } else if (tongTien > budgetMax) {
        highBet = midBet - 0.1;
      } else {
        lowBet = midBet + 0.1;
      }
    }
    return localBestTable;
  }

  /// Logic tính toán bảng cho Single Mien (Bắc Gan / Trung Gan)
  Future<Map<String, dynamic>> _calculateSingleMienTable({
    required String targetNumber,
    required String mien,
    required DateTime startDate,
    required DateTime endDate,
    required double startBetValue,
    required double profitTarget,
    required int durationLimit,
    required int winMultiplier,
  }) async {
    final tableData = <BettingRow>[];
    double tongTien = 0.0;
    int stt = 1;
    DateTime currentDate = startDate;
    int dayCount = 0;

    while (dayCount < durationLimit && currentDate.isBefore(endDate.add(const Duration(days: 1)))) {
      final weekday = date_utils.DateUtils.getWeekday(currentDate);
      final soLo = NumberUtils.calculateSoLo(mien, weekday);

      // Skip nếu số lô quá nhiều (lợi nhuận âm)
      if (winMultiplier - soLo <= 0) {
        currentDate = currentDate.add(const Duration(days: 1));
        continue;
      }

      final rowData = _calculateOneRow(
        stt: stt++,
        currentDate: currentDate,
        mien: mien,
        targetNumber: targetNumber,
        soLo: soLo,
        profitTarget: profitTarget,
        startBetValue: startBetValue,
        prevTongTien: tongTien,
        prevTable: tableData,
        winMultiplier: winMultiplier,
      );

      tableData.add(rowData.row);
      tongTien = rowData.newTongTien;

      dayCount++;
      currentDate = currentDate.add(const Duration(days: 1));
    }

    return {'table': tableData, 'tong_tien': tongTien};
  }

  /// Logic tính toán bảng cho Cycle (Xoay vòng miền)
  Future<Map<String, dynamic>> _calculateCycleTableInternal({
    required String targetNumber,
    required String targetMien,
    required DateTime startDate,
    required DateTime endDate,
    required int startMienIndex,
    required double startBetValue,
    required double profitTarget,
    required DateTime lastSeenDate,
    required List<LotteryResult> allResults,
    required int maxMienCount,
  }) async {
    final tableData = <BettingRow>[];
    double tongTien = 0.0;
    
    // Đếm số lần quay của targetMien
    int mienCount = _countTargetMienOccurrences(
      startDate: lastSeenDate,
      endDate: startDate,
      targetMien: targetMien,
      allResults: allResults,
    );
    
    int stt = 1;
    DateTime currentDate = startDate;
    bool isFirstDay = true;
    const mienOrder = AppConstants.mienOrder; // ['Nam', 'Trung', 'Bắc']

    outerLoop:
    while (mienCount < maxMienCount && currentDate.isBefore(endDate.add(const Duration(days: 1)))) {
      final initialMienIdx = isFirstDay ? startMienIndex : 0;
      final weekday = date_utils.DateUtils.getWeekday(currentDate);

      for (int i = initialMienIdx; i < mienOrder.length; i++) {
        final mien = mienOrder[i];
        final soLo = NumberUtils.calculateSoLo(mien, weekday);

        if (AppConstants.winMultiplier - soLo <= 0) continue;

        final rowData = _calculateOneRow(
          stt: stt++,
          currentDate: currentDate,
          mien: mien,
          targetNumber: targetNumber,
          soLo: soLo,
          profitTarget: profitTarget,
          startBetValue: startBetValue,
          prevTongTien: tongTien,
          prevTable: tableData,
          winMultiplier: AppConstants.winMultiplier,
        );

        tableData.add(rowData.row);
        tongTien = rowData.newTongTien;

        if (mien == targetMien) {
          mienCount++;
          if (mienCount >= maxMienCount) break outerLoop;
        }
      }
      isFirstDay = false;
      currentDate = currentDate.add(const Duration(days: 1));
    }
    return {'table': tableData, 'tong_tien': tongTien};
  }

  /// Hàm tính toán chi tiết 1 dòng (Common Row Calculation)
  _RowCalculationResult _calculateOneRow({
    required int stt,
    required DateTime currentDate,
    required String mien,
    required String targetNumber,
    required int soLo,
    required double profitTarget,
    required double startBetValue,
    required double prevTongTien,
    required List<BettingRow> prevTable,
    required int winMultiplier,
  }) {
    final requiredBet = (prevTongTien + profitTarget) / (winMultiplier - soLo);
    
    double tienCuoc1So = startBetValue;
    if (prevTable.isNotEmpty) {
      final lastBet = prevTable.last.cuocSo;
      tienCuoc1So = max(lastBet, requiredBet);
    }
    tienCuoc1So = tienCuoc1So.ceilToDouble();

    final tienCuocMien = tienCuoc1So * soLo;
    final newTongTien = prevTongTien + tienCuocMien;
    final tienLoi1So = (tienCuoc1So * winMultiplier) - newTongTien;
    final tienLoi2So = (tienCuoc1So * winMultiplier * 2) - newTongTien;

    final row = BettingRow.forCycle(
      stt: stt,
      ngay: _formatDateWith2Digits(currentDate),
      mien: mien,
      so: targetNumber,
      soLo: soLo,
      cuocSo: tienCuoc1So,
      cuocMien: tienCuocMien,
      tongTien: newTongTien,
      loi1So: tienLoi1So,
      loi2So: tienLoi2So,
    );

    return _RowCalculationResult(row, newTongTien);
  }

  int _countTargetMienOccurrences({
    required DateTime startDate,
    required DateTime endDate,
    required String targetMien,
    required List<LotteryResult> allResults,
  }) {
    final uniqueDates = <String>{};
    for (final result in allResults) {
      final date = date_utils.DateUtils.parseDate(result.ngay);
      if (date == null) continue;
      if (date.isAfter(startDate) && 
          (date.isBefore(endDate) || date.isAtSameMomentAs(endDate)) &&
          result.mien == targetMien) {
        uniqueDates.add(result.ngay);
      }
    }
    return uniqueDates.length;
  }

  String _formatDateWith2Digits(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }
}

// Helper class nội bộ để trả về dữ liệu từ hàm tính dòng
class _RowCalculationResult {
  final BettingRow row;
  final double newTongTien;
  _RowCalculationResult(this.row, this.newTongTien);
}