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
  Future<List<BettingRow>> generateXienTable({
    required GanPairInfo ganInfo,
    required DateTime startDate,
    required double xienBudget,
    required int durationBase,
    bool fitBudgetOnly = false,
  }) async {
    final soNgayGan = ganInfo.daysGan;
    final durationDays = durationBase - soNgayGan;

    if (durationDays <= 1) {
      throw Exception('Số ngày gan quá lớn: $soNgayGan (cần < $durationBase)');
    }

    final capSoMucTieu = ganInfo.randomPair;
    final rawTable = <BettingRow>[];

    double tongTien = 0.0;
    final profitStep =
        (AppConstants.finalProfit - AppConstants.startingProfit) /
            (durationDays - 1);

    double tienCuocMien =
        AppConstants.startingProfit / (AppConstants.winMultiplierXien - 1);
    if (tienCuocMien.isNaN || tienCuocMien.isInfinite) {
      tienCuocMien = 100.0;
    }

    // Bước 1: Tính toán thô
    final tempRows = <Map<String, dynamic>>[];
    for (int i = 0; i < durationDays; i++) {
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
        'ngay': _formatDateWith2Digits(startDate.add(Duration(days: i))),
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
    if (rawTotalCost <= 0) {
      throw Exception('Tổng tiền tính toán không hợp lệ: $rawTotalCost');
    }

    if (scalingFactor.isNaN || scalingFactor.isInfinite || scalingFactor <= 0) {
      throw Exception(
          'Invalid scaling factor: $scalingFactor (budget: $xienBudget, cost: $rawTotalCost)');
    }

    for (int i = 0; i < tempRows.length; i++) {
      final row = tempRows[i];

      double cuocMien = (row['cuoc_mien'] as double? ?? 100.0) * scalingFactor;
      cuocMien = cuocMien.ceilToDouble();

      if (!cuocMien.isFinite) {
        throw Exception('Invalid cuocMien at row $i: $cuocMien');
      }

      double tongTienRow =
          i == 0 ? cuocMien : rawTable[i - 1].tongTien + cuocMien;
      double loi = (cuocMien * AppConstants.winMultiplierXien) - tongTienRow;

      if (!tongTienRow.isFinite || !loi.isFinite) {
        throw Exception(
            'Invalid values at row $i: tongTien=$tongTienRow, loi=$loi');
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

    print(
        '✅ Generated ${rawTable.length} xien rows (budget: ${NumberUtils.formatCurrency(xienBudget)})');
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

  Future<List<BettingRow>> _optimizeTableSearch({
    required double budgetMin,
    required double budgetMax,
    required Future<Map<String, dynamic>> Function(double profit, double bet)
        calculator,
    required String configName,
    int profitSearchRange = 12,
    int betSearchRange = 11,
  }) async {
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
      final testResult = await calculator(100.0, 1.0);
      final actualTotal = testResult['tong_tien'] as double;

      if (actualTotal > budgetMax) {
        throw Exception('Không thể tạo bảng $configName!\n'
            'Ngân sách tối đa: ${NumberUtils.formatCurrency(budgetMax)} VNĐ\n'
            'Cần tối thiểu: ${NumberUtils.formatCurrency(actualTotal)} VNĐ\n'
            'Thiếu: ${NumberUtils.formatCurrency(actualTotal - budgetMax)} VNĐ');
      } else {
        throw Exception('Lỗi tạo bảng $configName!\n'
            'Ngân sách: ${NumberUtils.formatCurrency(budgetMax)} VNĐ\n'
            'Không tìm được cấu hình tối ưu. Vui lòng thử lại.');
      }
    }

    return bestTable;
  }

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

    while (dayCount < durationLimit &&
        currentDate.isBefore(endDate.add(const Duration(days: 1)))) {
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

      dayCount++;
      currentDate = currentDate.add(const Duration(days: 1));
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

    int mienCount = _countTargetMienOccurrences(
      startDate: lastSeenDate,
      endDate: startDate,
      targetMien: targetMien,
      allResults: allResults,
    );

    int stt = 1;
    DateTime currentDate = startDate;
    bool isFirstDay = true;
    const mienOrder = AppConstants.mienOrder;

    outerLoop:
    while (mienCount < maxMienCount &&
        currentDate.isBefore(endDate.add(const Duration(days: 1)))) {
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

  // ✅ CẬP NHẬT: Thêm tham số anchorDate và anchorMienIndex
  Future<String?> findOptimalStartDateForRebetting({
    required DateTime endDate,
    required double budgetMin,
    required double budgetMax,
    required String mien,
    required String soMucTieu,
    double profitTarget = 100.0,
    DateTime? anchorDate,
    int? anchorMienIndex,
  }) async {
    print('🔍 Finding optimal start date for Rebetting...');
    print('   End date: ${_formatDateWith2Digits(endDate)}');
    print(
        '   Budget: ${NumberUtils.formatCurrency(budgetMin)} - ${NumberUtils.formatCurrency(budgetMax)}');

    try {
      DateTime currentDate = endDate;
      String? bestStartDate;

      // Thử từ endDate đi lùi tối đa 60 ngày
      for (int dayOffset = 0; dayOffset < 60; dayOffset++) {
        currentDate = endDate.subtract(Duration(days: dayOffset));

        List<BettingRow> tempTable;

        // ✅ LOGIC PHÂN NHÁNH: Xử lý riêng cho "Tất cả" và các miền cụ thể
        if (mien == 'Tất cả' || mien == 'Mixed' || mien == 'tatCa') {
          if (anchorDate == null || anchorMienIndex == null) {
            print('   ⚠️ Warning: Missing anchor data for mixed rebetting');
            // Fallback nếu thiếu anchor (mặc định start index 0)
            tempTable = await _calculateCycleTableForRebetting(
              targetNumber: soMucTieu,
              startDate: currentDate,
              endDate: endDate,
              startMienIndex: 0,
              startBetValue: 1.0,
              profitTarget: 100.0,
            );
          } else {
            // ✅ Tính toán Start Index chính xác dựa trên Anchor
            final diffDays = currentDate.difference(anchorDate).inDays;
            // Modulo có thể ra số âm, cần xử lý: ((a % n) + n) % n
            final rawIdx = (anchorMienIndex + diffDays) % 3;
            final startMienIdx = (rawIdx + 3) % 3;

            tempTable = await _calculateCycleTableForRebetting(
              targetNumber: soMucTieu,
              startDate: currentDate,
              endDate: endDate,
              startMienIndex: startMienIdx,
              startBetValue: 1.0,
              profitTarget: 100.0,
            );
          }
        } else {
          // Logic cũ cho miền cụ thể
          final weekday = date_utils.DateUtils.getWeekday(currentDate);
          final soLo = NumberUtils.calculateSoLo(mien, weekday);

          if (AppConstants.winMultiplier - soLo <= 0) {
            continue;
          }

          tempTable = await _calculateSingleMienTableForRebetting(
            targetNumber: soMucTieu,
            mien: mien,
            startDate: currentDate,
            endDate: endDate,
            startBetValue: 1.0,
            profitTarget: 100.0,
            winMultiplier: AppConstants.winMultiplier,
          );
        }

        if (tempTable.isEmpty) {
          continue;
        }

        final totalMoney = tempTable.last.tongTien;

        if (totalMoney >= budgetMin && totalMoney <= budgetMax) {
          bestStartDate = _formatDateWith2Digits(currentDate);
          print(
              '   ✅ Found start date: $bestStartDate (total: ${NumberUtils.formatCurrency(totalMoney)})');
          return bestStartDate;
        }

        if (totalMoney > budgetMax * 1.5) {
          print(
              '   ⏭️  Day $dayOffset: total ${NumberUtils.formatCurrency(totalMoney)} > budget, stopping');
          break;
        }
      }

      print('   ❌ Could not find suitable start date');
      return null;
    } catch (e) {
      print('   ❌ Error finding start date: $e');
      return null;
    }
  }

  /// ✅ MỚI: Tính table cho Rebetting kiểu "Tất cả" (Cycle)
  Future<List<BettingRow>> _calculateCycleTableForRebetting({
    required String targetNumber,
    required DateTime startDate,
    required DateTime endDate,
    required int startMienIndex,
    required double startBetValue,
    required double profitTarget,
  }) async {
    final tableData = <BettingRow>[];
    double tongTien = 0.0;
    int stt = 1;
    DateTime currentDate = startDate;
    bool isFirstDay = true;
    const mienOrder = AppConstants.mienOrder; // ['Nam', 'Trung', 'Bắc']

    while (currentDate.isBefore(endDate.add(const Duration(days: 1)))) {
      final initialMienIdx = isFirstDay ? startMienIndex : 0;
      final weekday = date_utils.DateUtils.getWeekday(currentDate);

      for (int i = initialMienIdx; i < mienOrder.length; i++) {
        final mien = mienOrder[i];
        final soLo = NumberUtils.calculateSoLo(mien, weekday);

        if (AppConstants.winMultiplier - soLo <= 0) continue;

        final requiredBet =
            (tongTien + profitTarget) / (AppConstants.winMultiplier - soLo);
        double tienCuoc1So = startBetValue;

        if (tableData.isNotEmpty) {
          // Đảm bảo cược tăng hoặc giữ, không giảm quá sâu (logic simple profit)
          tienCuoc1So = tienCuoc1So > requiredBet ? tienCuoc1So : requiredBet;
        }
        tienCuoc1So = tienCuoc1So.ceilToDouble();

        final tienCuocMien = tienCuoc1So * soLo;
        final newTongTien = tongTien + tienCuocMien;
        final tienLoi1So =
            (tienCuoc1So * AppConstants.winMultiplier) - newTongTien;
        final tienLoi2So =
            (tienCuoc1So * AppConstants.winMultiplier * 2) - newTongTien;

        tableData.add(BettingRow.forCycle(
          stt: stt++,
          ngay: _formatDateWith2Digits(currentDate),
          mien: mien,
          so: targetNumber,
          soLo: soLo,
          cuocSo: tienCuoc1So,
          cuocMien: tienCuocMien,
          tongTien: newTongTien,
          loi1So: tienLoi1So,
          loi2So: tienLoi2So,
        ));

        tongTien = newTongTien;
      }
      isFirstDay = false;
      currentDate = currentDate.add(const Duration(days: 1));
    }
    return tableData;
  }

  /// Helper: Tính table cho Rebetting (Single Mien)
  Future<List<BettingRow>> _calculateSingleMienTableForRebetting({
    required String targetNumber,
    required String mien,
    required DateTime startDate,
    required DateTime endDate,
    required double startBetValue,
    required double profitTarget,
    required int winMultiplier,
  }) async {
    final tableData = <BettingRow>[];
    double tongTien = 0.0;
    int stt = 1;
    DateTime currentDate = startDate;

    while (currentDate.isBefore(endDate.add(const Duration(days: 1)))) {
      final weekday = date_utils.DateUtils.getWeekday(currentDate);
      final soLo = NumberUtils.calculateSoLo(mien, weekday);

      if (winMultiplier - soLo <= 0) {
        currentDate = currentDate.add(const Duration(days: 1));
        continue;
      }

      final requiredBet = (tongTien + profitTarget) / (winMultiplier - soLo);
      double tienCuoc1So = startBetValue;

      if (tableData.isNotEmpty) {
        tienCuoc1So = tienCuoc1So > requiredBet ? tienCuoc1So : requiredBet;
      }
      tienCuoc1So = tienCuoc1So.ceilToDouble();

      final tienCuocMien = tienCuoc1So * soLo;
      final newTongTien = tongTien + tienCuocMien;
      final tienLoi1So = (tienCuoc1So * winMultiplier) - newTongTien;
      final tienLoi2So = (tienCuoc1So * winMultiplier * 2) - newTongTien;

      tableData.add(BettingRow.forCycle(
        stt: stt++,
        ngay: _formatDateWith2Digits(currentDate),
        mien: mien,
        so: targetNumber,
        soLo: soLo,
        cuocSo: tienCuoc1So,
        cuocMien: tienCuocMien,
        tongTien: newTongTien,
        loi1So: tienLoi1So,
        loi2So: tienLoi2So,
      ));

      tongTien = newTongTien;
      currentDate = currentDate.add(const Duration(days: 1));
    }

    return tableData;
  }
}

class _RowCalculationResult {
  final BettingRow row;
  final double newTongTien;
  _RowCalculationResult(this.row, this.newTongTien);
}
