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
    required DateTime endDate,
    double xienBudget = AppConstants.targetBudgetXien,
    double? budgetMin,
    bool fitBudgetOnly = false,
  }) async {
    final startNorm = DateTime(startDate.year, startDate.month, startDate.day);

    final endNorm = DateTime(endDate.year, endDate.month, endDate.day);

    final daysRemaining = endNorm.difference(startNorm).inDays + 1;

    if (daysRemaining <= 1) {
      return [];
    }

    final effectiveBudgetMin =
        budgetMin ?? (fitBudgetOnly ? 0.0 : xienBudget * 0.77);

    return _optimizeXienByPeak(
      ganInfo: ganInfo,
      startNorm: startNorm,
      daysRemaining: daysRemaining,
      budgetMin: effectiveBudgetMin,
      budgetMax: xienBudget,
    );
  }

  List<BettingRow> _optimizeXienByPeak({
    required GanPairInfo ganInfo,
    required DateTime startNorm,
    required int daysRemaining,
    required double budgetMin,
    required double budgetMax,
  }) {
    // Peak không được thấp hơn Min/End,
    // nếu không sẽ mất hình dạng "quả đồi".
    final minPeak = max(
      AppConstants.xienProfitStepMin,
      AppConstants.xienProfitStepEnd,
    );

    // ==========================================
    // 1. Kiểm tra mức Peak thấp nhất
    // ==========================================
    final minTable = _buildXienTable(
      ganInfo,
      startNorm,
      daysRemaining,
      minPeak,
    );

    final minTotal = minTable.last.tongTien;

    if (minTotal > budgetMax) {
      throw Exception(
        'Không đủ vốn cho Xiên!\n'
        'Ngân sách tối đa: '
        '${NumberUtils.formatCurrency(budgetMax)}\n'
        'Vốn tối thiểu cần: '
        '${NumberUtils.formatCurrency(minTotal)}',
      );
    }

    // ==========================================
    // 2. Peak mặc định do bạn cấu hình
    // ==========================================
    double lowPeak = minPeak;

    double highPeak = max(
      AppConstants.xienProfitStepPeak,
      minPeak,
    );

    List<BettingRow> bestTable = minTable;
    double bestTotal = minTotal;
    double bestPeak = minPeak;

    // ==========================================
    // 3. Nếu Peak mặc định vẫn chưa dùng đủ vốn
    //    => tăng Peak dần
    //
    // Mục tiêu:
    // tìm highPeak sao cho total > budgetMax.
    // Sau đó mới binary search ở giữa.
    // ==========================================
    for (int i = 0; i < 30; i++) {
      final table = _buildXienTable(
        ganInfo,
        startNorm,
        daysRemaining,
        highPeak,
      );

      final total = table.last.tongTien;

      if (total <= budgetMax) {
        lowPeak = highPeak;

        // Đây là nghiệm hợp lệ tốt hơn
        if (total > bestTotal) {
          bestTable = table;
          bestTotal = total;
          bestPeak = highPeak;
        }

        // Còn dư vốn => tăng Peak
        highPeak *= 2;
      } else {
        // Đã vượt vốn => có khoảng để binary search
        break;
      }
    }

    // ==========================================
    // 4. Binary Search effectivePeak
    // ==========================================
    for (int i = 0; i < 60; i++) {
      if ((highPeak - lowPeak).abs() < 0.01) {
        break;
      }

      final midPeak = (lowPeak + highPeak) / 2;

      final table = _buildXienTable(
        ganInfo,
        startNorm,
        daysRemaining,
        midPeak,
      );

      final total = table.last.tongTien;

      if (total <= budgetMax) {
        // Không vượt ngân sách.
        // Có thể tăng Peak tiếp.
        lowPeak = midPeak;

        if (total > bestTotal) {
          bestTable = table;
          bestTotal = total;
          bestPeak = midPeak;
        }
      } else {
        // Vượt ngân sách => giảm Peak
        highPeak = midPeak;
      }
    }

    print(
      '✅ XIÊN OPTIMIZED\n'
      'Peak gốc     : ${AppConstants.xienProfitStepPeak}\n'
      'Peak thực tế : ${bestPeak.toStringAsFixed(2)}\n'
      'Budget Min   : ${NumberUtils.formatCurrency(budgetMin)}\n'
      'Budget Max   : ${NumberUtils.formatCurrency(budgetMax)}\n'
      'Tổng vốn     : ${NumberUtils.formatCurrency(bestTotal)}',
    );

    // Nếu tổng cuối vẫn thấp hơn budgetMin,
    // nghĩa là do bước cược nguyên / ceil khiến không có nghiệm đẹp
    // trong vùng mong muốn.
    if (bestTotal < budgetMin) {
      print(
        '⚠️ Tổng vốn Xiên '
        '${NumberUtils.formatCurrency(bestTotal)} '
        'thấp hơn budgetMin '
        '${NumberUtils.formatCurrency(budgetMin)}',
      );
    }

    return bestTable;
  }

  List<double> _calculateXienProfitSteps({
    required int daysRemaining,
    required double effectivePeak,
  }) {
    final steps = List<double>.filled(daysRemaining, 0.0);

    if (daysRemaining <= 1) {
      return steps;
    }

    final lastIndex = daysRemaining - 1;

    // ==========================================
    // Peak nằm ở 1/8 toàn bộ thời gian
    // ==========================================
    final peakIndex = (lastIndex / 8).round().clamp(1, lastIndex);

    // ==========================================
    // PHA 1:
    // 1/8 đầu
    //
    // Step:
    // Min -> Peak
    // ==========================================
    for (int i = 1; i <= peakIndex; i++) {
      final fraction = peakIndex == 1 ? 1.0 : (i - 1) / (peakIndex - 1);

      steps[i] = AppConstants.xienProfitStepMin +
          (effectivePeak - AppConstants.xienProfitStepMin) * fraction;
    }

    // ==========================================
    // PHA 2:
    // 7/8 sau
    //
    // Step:
    // Peak -> End
    // ==========================================
    final remainingSteps = lastIndex - peakIndex;

    for (int i = peakIndex + 1; i <= lastIndex; i++) {
      final fraction =
          remainingSteps == 0 ? 1.0 : (i - peakIndex) / remainingSteps;

      steps[i] = effectivePeak -
          (effectivePeak - AppConstants.xienProfitStepEnd) * fraction;
    }

    return steps;
  }

  List<BettingRow> _buildXienTable(
    GanPairInfo ganInfo,
    DateTime startNorm,
    int daysRemaining,
    double effectivePeak,
  ) {
    final capSo = ganInfo.randomPair;

    final table = <BettingRow>[];

    final profitSteps = _calculateXienProfitSteps(
      daysRemaining: daysRemaining,
      effectivePeak: effectivePeak,
    );

    double tongTien = 0.0;
    double? prevBet;

    // Ngày đầu tiên dùng startingProfit
    double runningProfitTarget = AppConstants.startingProfit;

    for (int i = 0; i < daysRemaining; i++) {
      // Ngày đầu giữ startingProfit.
      //
      // Từ ngày thứ 2 trở đi:
      // target += step của ngày đó.
      if (i > 0) {
        runningProfitTarget += profitSteps[i];
      }

      final target = runningProfitTarget;

      // ==========================================
      // Tiền cược cần để:
      //
      // bet * multiplier
      // - tongTien cũ
      // - bet
      // = target profit
      //
      // =>
      //
      // bet =
      // (tongTien + target)
      // / (multiplier - 1)
      // ==========================================
      double bet = (tongTien + target) / (AppConstants.winMultiplierXien - 1);

      if (bet.isNaN || bet.isInfinite) {
        bet = 1;
      }

      // Không cho cược ngày sau thấp hơn ngày trước
      if (prevBet != null) {
        bet = max(
          prevBet,
          bet,
        );
      }

      bet = bet.ceilToDouble();

      if (bet < 1) {
        bet = 1;
      }

      // ==========================================
      // Safety check:
      // luôn đảm bảo ít nhất hòa vốn + 1
      // ==========================================
      final minBreakEven = tongTien / (AppConstants.winMultiplierXien - 1);

      if (bet <= minBreakEven) {
        bet = ((tongTien + 1.0) / (AppConstants.winMultiplierXien - 1))
            .ceilToDouble();

        if (bet < 1) {
          bet = 1;
        }
      }

      final newTong = tongTien + bet;

      final actualProfit = (bet * AppConstants.winMultiplierXien) - newTong;

      table.add(
        BettingRow.forXien(
          stt: i + 1,
          ngay: _formatDateWith2Digits(
            startNorm.add(
              Duration(days: i),
            ),
          ),
          mien: 'Bắc',
          so: capSo.display,
          cuocMien: bet,
          tongTien: newTong,
          loi: actualProfit,
        ),
      );

      tongTien = newTong;
      prevBet = bet;
    }

    return table;
  }

  /// Generate Cycle Table
  Future<List<BettingRow>> generateCycleTable({
    required CycleAnalysisResult cycleResult,
    required DateTime startDate,
    required DateTime endDate,
    required String endMien,
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
        endMien: endMien,
        startMienIndex: startMienIndex,
        startBetValue: startBet,
        profitTarget: profitTarget,
        lastSeenDate: cycleResult.lastSeenDate,
        allResults: allResults,
        maxMienCount: maxMienCount,
      ),
      configName: "Cycle Table",
      // ✅ Cycle biến động vốn rất mạnh (3 miền/ngày) nên cần dò kỹ hơn nhiều
      profitSearchRange: 30,
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
      profitSearchRange: 25,
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
      profitSearchRange: 25,
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
      profitSearchRange: 25,
    );
  }

  // --- PRIVATE METHODS ---

  /// ✅ [ĐÃ SỬA] Chỉ còn dò theo profitTarget (bisection), không dò startBet nữa,
  /// vì dòng 1 giờ được tính thẳng theo target (0.67 * profitTarget) thay vì
  /// max(startBetValue, requiredBet) — startBetValue không còn ảnh hưởng kết quả.
  ///
  /// ✅ Tự động "nới" highProfit khi chưa tìm được cấu hình đạt budgetMin trong
  /// biên hiện tại, thay vì bỏ budgetMin. Đảm bảo luôn dò ra nghiệm nếu nó tồn tại.
  Future<List<BettingRow>> _optimizeTableSearch({
    required double budgetMin,
    required double budgetMax,
    required Future<Map<String, dynamic>> Function(double profit, double bet)
        calculator,
    required String configName,
    int profitSearchRange = 30,
    int maxExpandAttempts = 6,
  }) async {
    List<BettingRow>? bestTable;
    double highProfit = budgetMax / 2;

    for (int expand = 0;
        expand < maxExpandAttempts && bestTable == null;
        expand++) {
      double lowProfit = 10.0;
      double localHigh = highProfit;

      for (int i = 0; i < profitSearchRange; i++) {
        if (localHigh < lowProfit) break;
        final midProfit = (lowProfit + localHigh) / 2;

        // bet không còn ý nghĩa với dòng 1 nữa (đã cố định theo target),
        // vẫn truyền 0 để giữ nguyên chữ ký calculator hiện có.
        final result = await calculator(midProfit, 0);
        final tongTien = result['tong_tien'] as double;
        final table = result['table'] as List<BettingRow>;

        if (tongTien >= budgetMin && tongTien <= budgetMax) {
          bestTable = table;
          // Đã thỏa mãn -> tham lam thử target cao hơn để tiêu hết tiền
          lowProfit = midProfit + 1;
        } else if (tongTien > budgetMax) {
          localHigh = midProfit - 1;
        } else {
          // tongTien < budgetMin -> tăng target
          lowProfit = midProfit + 1;
        }
      }

      if (bestTable == null) {
        // Chưa chạm được budgetMin trong biên hiện tại -> nới rộng rồi dò lại
        highProfit *= 2;
        print('⚠️ [$configName] Chưa đạt budgetMin trong biên hiện tại, '
            'nới highProfit lên ${highProfit.toStringAsFixed(0)} và thử lại '
            '(lần ${expand + 1}/$maxExpandAttempts)...');
      }
    }

    if (bestTable == null) {
      // Fallback: Thử mức thấp nhất có thể
      final testResult = await calculator(10.0, 1);
      final actualTotal = testResult['tong_tien'] as double;

      if (actualTotal > budgetMax) {
        throw Exception('Không đủ vốn cho $configName!\n'
            'Max: ${NumberUtils.formatCurrency(budgetMax)}\n'
            'Cần Min: ${NumberUtils.formatCurrency(actualTotal)}');
      }
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

    DateTime currentDate =
        DateTime(startDate.year, startDate.month, startDate.day);
    DateTime endNorm = DateTime(endDate.year, endDate.month, endDate.day);

    int loops = 0;
    while (true) {
      if (loops > 100) break;
      if (currentDate.isAfter(endNorm)) break;

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
    required String endMien, // 👈 THÊM
    required int startMienIndex,
    required double startBetValue,
    required double profitTarget,
    required DateTime lastSeenDate,
    required List<LotteryResult> allResults,
    required int maxMienCount,
  }) async {
    final tableData = <BettingRow>[];
    double tongTien = 0.0;

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
    const mienOrder = AppConstants.mienOrder; // ['Nam', 'Trung', 'Bắc']
    final mOrder = {'Nam': 1, 'Trung': 2, 'Bắc': 3};
    int targetEndMienVal = mOrder[endMien] ?? 3;

    int loops = 0;
    outerLoop:
    while (mienCount < maxMienCount) {
      if (currentDate.isAfter(endNorm)) break;
      if (loops > 100) break;

      final initialMienIdx = isFirstDay ? startMienIndex : 0;
      final weekday = date_utils.DateUtils.getWeekday(currentDate);

      for (int i = initialMienIdx; i < mienOrder.length; i++) {
        final mien = mienOrder[i];
        int currentMienVal = mOrder[mien] ?? 0;

        // 🛑 ĐIỀU KIỆN DỪNG 1: Nếu là ngày cuối và đã vượt quá miền kết thúc
        if (currentDate.isAtSameMomentAs(endNorm) &&
            currentMienVal > targetEndMienVal) {
          break outerLoop;
        }

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
        }

        // 🛑 ĐIỀU KIỆN DỪNG 2: Đã đủ số chu kỳ mục tiêu
        if (mienCount >= maxMienCount) break outerLoop;

        // 🛑 ĐIỀU KIỆN DỪNG 3: Chạm đúng ngày và miền kết thúc
        if (currentDate.isAtSameMomentAs(endNorm) && mien == endMien) {
          break outerLoop;
        }
      }
      isFirstDay = false;
      currentDate = currentDate.add(const Duration(days: 1));
      loops++;
    }
    return {'table': tableData, 'tong_tien': tongTien};
  }

  /// ✅ [ĐÃ SỬA] Dòng 1: lấy ĐÚNG theo target đã giảm còn 0.67 lần —
  /// không còn max/min với startBetValue nữa (startBetValue chỉ giữ lại
  /// trong chữ ký để tương thích, không dùng tới ở dòng 1).
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
    // [LOGIC] Soft Start cho Dòng 1
    // Dòng 1: chỉ yêu cầu đạt 67% lợi nhuận mục tiêu để giảm tải vốn
    // Các dòng sau: yêu cầu 100% lợi nhuận mục tiêu
    double currentProfitTarget = profitTarget;
    if (prevTable.isEmpty) {
      currentProfitTarget = profitTarget * 0.67;
    }

    // Tính mức cược cần thiết với target (đã điều chỉnh)
    final requiredBet =
        (prevTongTien + currentProfitTarget) / (winMultiplier - soLo);

    double tienCuoc1So;

    if (prevTable.isEmpty) {
      // ✅ Dòng 1: lấy đúng theo target 0.67 — không max/min với startBetValue
      tienCuoc1So = requiredBet;
    } else {
      // Các dòng sau: Martingale như cũ
      final lastBet = prevTable.last.cuocSo;
      tienCuoc1So = max(lastBet, requiredBet);
    }

    tienCuoc1So = tienCuoc1So.ceilToDouble();
    if (tienCuoc1So < 1) tienCuoc1So = 1; // an toàn, tránh cược 0 hoặc âm

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
