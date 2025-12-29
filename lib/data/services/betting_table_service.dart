// lib/data/services/betting_table_service.dart

import 'dart:math';

import '../../core/constants/app_constants.dart';
import '../../core/utils/date_utils.dart' as date_utils;
import '../../core/utils/number_utils.dart';
import '../models/betting_row.dart';
import '../models/cycle_analysis_result.dart';
import '../models/gan_pair_info.dart';
import '../models/lottery_result.dart';

class BettingTableService {
  /// Generate Xien Table
  /// [FIX] Thêm tham số endDate để chặn đúng ngày, không bị trôi
  Future<List<BettingRow>> generateXienTable({
    required GanPairInfo ganInfo,
    required DateTime startDate,
    required DateTime endDate, // Thêm tham số này
    required double xienBudget,
    // required int durationBase, // Bỏ tham số này vì dễ gây lỗi
    bool fitBudgetOnly = false,
  }) async {
    // 1. Chuẩn hóa ngày về 00:00:00 để tính toán chính xác
    DateTime startNorm =
        DateTime(startDate.year, startDate.month, startDate.day);
    DateTime endNorm = DateTime(endDate.year, endDate.month, endDate.day);

    // 2. Tính lại số ngày thực tế nuôi
    int daysRemaining = endNorm.difference(startNorm).inDays + 1;

    if (daysRemaining <= 1) {
      // Nếu optimize xong mà ngày còn lại quá ít -> Return rỗng hoặc throw
      return [];
    }

    final capSoMucTieu = ganInfo.randomPair;
    final rawTable = <BettingRow>[];

    double tongTien = 0.0;

    // Tính profit step dựa trên số ngày thực tế còn lại
    final profitStep =
        (AppConstants.finalProfit - AppConstants.startingProfit) /
            (daysRemaining - 1);

    double tienCuocMien =
        AppConstants.startingProfit / (AppConstants.winMultiplierXien - 1);
    if (tienCuocMien.isNaN || tienCuocMien.isInfinite) {
      tienCuocMien = 100.0;
    }

    // Bước 1: Tính toán thô (Dùng vòng lặp theo daysRemaining)
    final tempRows = <Map<String, dynamic>>[];
    for (int i = 0; i < daysRemaining; i++) {
      final currentProfitTarget =
          AppConstants.startingProfit + (profitStep * i);

      if (i > 0) {
        tienCuocMien = (tongTien + currentProfitTarget) /
            (AppConstants.winMultiplierXien - 1);
        if (tienCuocMien.isNaN || tienCuocMien.isInfinite) {
          tienCuocMien = 100.0;
        }
      }

      if (tempRows.isNotEmpty) {
        final prevCuoc = tempRows.last['cuoc_mien'] as double? ?? 100.0;
        tienCuocMien = max(prevCuoc, tienCuocMien);
      }

      tienCuocMien = tienCuocMien.ceilToDouble();

      if (tienCuocMien.isFinite) {
        tongTien += tienCuocMien;
      } else {
        throw Exception('Invalid tienCuocMien: $tienCuocMien');
      }

      tempRows.add({
        'ngay': _formatDateWith2Digits(startNorm.add(Duration(days: i))),
        'cuoc_mien': tienCuocMien,
        'tong': tongTien,
      });
    }

    // Bước 2: Chuẩn hóa theo ngân sách
    final rawTotalCost = tempRows.last['tong'] as double? ?? 1.0;
    double scalingFactor = xienBudget / rawTotalCost;
    if (fitBudgetOnly && scalingFactor > 1.0) {
      scalingFactor = 1.0;
    }
    // ... (Giữ nguyên logic chuẩn hóa budget) ...
    if (rawTotalCost <= 0) {
      // Tránh crash nếu cost <= 0
      scalingFactor = 1.0;
    }

    if (scalingFactor.isNaN || scalingFactor.isInfinite || scalingFactor <= 0) {
      // Fallback an toàn thay vì throw Exception làm crash app
      scalingFactor = 1.0;
    }

    for (int i = 0; i < tempRows.length; i++) {
      final row = tempRows[i];

      double cuocMien = (row['cuoc_mien'] as double? ?? 100.0) * scalingFactor;
      cuocMien = cuocMien.ceilToDouble();
      if (cuocMien < 1000) cuocMien = 1000; // Mức cược tối thiểu an toàn

      double tongTienRow =
          i == 0 ? cuocMien : rawTable[i - 1].tongTien + cuocMien;
      double loi = (cuocMien * AppConstants.winMultiplierXien) - tongTienRow;

      rawTable.add(BettingRow.forXien(
        stt: i + 1,
        ngay: row['ngay'] as String,
        mien:
            'Bắc', // Lưu ý: Xiên thường mặc định miền Bắc, nếu cần đổi thì pass tham số
        so: capSoMucTieu.display,
        cuocMien: cuocMien,
        tongTien: tongTienRow,
        loi: loi,
      ));
    }

    print(
        '✅ Generated ${rawTable.length} xien rows (budget: ${NumberUtils.formatCurrency(xienBudget)})');
    return rawTable;
  }

  /// Generate Cycle Table
  Future<List<BettingRow>> generateCycleTable({
    required CycleAnalysisResult cycleResult,
    required DateTime startDate,
    required DateTime endDate,
    required int startMienIndex,
    required double budgetMin,
    required double budgetMax,
    required List<LotteryResult> allResults,
    required int maxMienCount,
    required int durationLimit,
  }) async {
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

  /// Generate Nam Gan Table
  Future<List<BettingRow>> generateNamGanTable({
    required CycleAnalysisResult cycleResult,
    required DateTime startDate,
    required DateTime endDate,
    required double budgetMin,
    required double budgetMax,
    required int durationLimit,
  }) async {
    return _optimizeTableSearch(
      budgetMin: budgetMin,
      budgetMax: budgetMax,
      calculator: (profitTarget, startBet) => _calculateSingleMienTable(
        targetNumber: cycleResult.targetNumber,
        mien: 'Nam',
        startDate: startDate,
        endDate: endDate,
        startBetValue: startBet,
        profitTarget: profitTarget,
        durationLimit: durationLimit,
        winMultiplier: AppConstants.namGanWinMultiplier,
      ),
      configName: "Nam Gan",
      profitSearchRange: 22,
      betSearchRange: 22,
    );
  }

  /// Generate Bac Gan Table
  Future<List<BettingRow>> generateBacGanTable({
    required CycleAnalysisResult cycleResult,
    required DateTime startDate,
    required DateTime endDate,
    required double budgetMin,
    required double budgetMax,
    required int durationLimit,
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
        durationLimit: durationLimit,
        winMultiplier: AppConstants.bacGanWinMultiplier,
      ),
      configName: "Bắc Gan",
      profitSearchRange: 22,
      betSearchRange: 22,
    );
  }

  /// Generate Trung Gan Table
  Future<List<BettingRow>> generateTrungGanTable({
    required CycleAnalysisResult cycleResult,
    required DateTime startDate,
    required DateTime endDate,
    required double budgetMin,
    required double budgetMax,
    required int durationLimit,
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
        durationLimit: durationLimit,
        winMultiplier: AppConstants.trungGanWinMultiplier,
      ),
      configName: "Trung Gan",
      profitSearchRange: 22,
      betSearchRange: 22,
    );
  }

  // --- PRIVATE METHODS ---

  Future<List<BettingRow>?> _findBestStartBet({
    required double budgetMin,
    required double budgetMax,
    required double profitTarget,
    required Future<Map<String, dynamic>> Function(double profit, double bet)
        calculator,
    required int searchRange,
  }) async {
    double lowBet = profitTarget / 3 / 50;
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
        highBet = midBet - 0.1;
      } else if (tongTien > budgetMax) {
        highBet = midBet - 0.1;
      } else {
        lowBet = midBet + 0.1;
      }
    }
    return localBestTable;
  }

  Future<List<BettingRow>> _optimizeTableSearch({
    required double budgetMin,
    required double budgetMax,
    required Future<Map<String, dynamic>> Function(double profit, double bet)
        calculator,
    required String configName,
    int profitSearchRange = 12,
    int betSearchRange = 11,
  }) async {
    // ... (Giữ nguyên logic optimize) ...
    double lowProfit = 100.0;
    double highProfit = 100000.0;
    List<BettingRow>? bestTable;

    for (int i = 0; i < profitSearchRange; i++) {
      if (highProfit < lowProfit) break;
      final midProfit = ((lowProfit + highProfit) / 2);

      final foundTable = await _findBestStartBet(
        budgetMin: budgetMin,
        budgetMax: budgetMax,
        profitTarget: midProfit,
        calculator: calculator,
        searchRange: betSearchRange,
      );

      if (foundTable != null) {
        bestTable ??= foundTable;
        final adjustedProfit = midProfit * 3.5 / 4.2;
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

    if (bestTable == null) {
      // Logic fallback khẩn cấp nếu không tìm thấy bảng tối ưu
      // Thay vì throw ngay, thử tạo bảng rẻ nhất có thể (startBet=1)
      final testResult = await calculator(50.0, 1.0);
      final actualTotal = testResult['tong_tien'] as double;

      // Chỉ throw nếu ngay cả phương án rẻ nhất cũng vượt quá budget
      if (actualTotal > budgetMax) {
        throw Exception('Không đủ vốn cho $configName!\n'
            'Max: ${NumberUtils.formatCurrency(budgetMax)}\n'
            'Cần Min: ${NumberUtils.formatCurrency(actualTotal)}');
      }
      // Nếu rẻ nhất ok (nhưng logic optimize bên trên bị miss), trả về bảng rẻ nhất này luôn
      return testResult['table'] as List<BettingRow>;
    }

    return bestTable;
  }

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

    // [FIX] Chuẩn hóa ngày về 00:00:00 để so sánh chính xác
    DateTime currentDate =
        DateTime(startDate.year, startDate.month, startDate.day);
    DateTime endNorm = DateTime(endDate.year, endDate.month, endDate.day);

    // Dùng vòng lặp vô hạn kết hợp break, an toàn hơn đếm dayCount khi skip ngày
    int loops = 0;
    while (true) {
      if (loops > 100) break; // Circuit breaker
      if (currentDate.isAfter(endNorm)) break; // [FIX] So sánh Date chuẩn xác

      final weekday = date_utils.DateUtils.getWeekday(currentDate);
      final soLo = NumberUtils.calculateSoLo(mien, weekday);

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
      currentDate = currentDate.add(const Duration(days: 1));
      loops++;
    }

    return {'table': tableData, 'tong_tien': tongTien};
  }

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

    // [FIX] Chuẩn hóa ngày
    DateTime currentDate =
        DateTime(startDate.year, startDate.month, startDate.day);
    DateTime endNorm = DateTime(endDate.year, endDate.month, endDate.day);

    int mienCount = _countTargetMienOccurrences(
      startDate: lastSeenDate,
      endDate: startDate,
      targetMien: targetMien,
      allResults: allResults,
    );

    int stt = 1;
    bool isFirstDay = true;
    const mienOrder = AppConstants.mienOrder;
    int loops = 0;

    outerLoop:
    while (mienCount < maxMienCount) {
      if (currentDate.isAfter(endNorm)) break;
      if (loops > 100) break;

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
      loops++;
    }
    return {'table': tableData, 'tong_tien': tongTien};
  }

  // ... (Giữ nguyên các hàm _calculateOneRow, _countTargetMienOccurrences, _formatDateWith2Digits) ...
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

class _RowCalculationResult {
  final BettingRow row;
  final double newTongTien;
  _RowCalculationResult(this.row, this.newTongTien);
}
