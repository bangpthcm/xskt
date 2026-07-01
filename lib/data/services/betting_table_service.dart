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
  /// [UPDATED] Cho phép cược nhỏ nhất là 1đ để phù hợp với ngân sách siêu nhỏ
  Future<List<BettingRow>> generateXienTable({
    required GanPairInfo ganInfo,
    required DateTime startDate,
    required DateTime endDate,
    required double xienBudget,
    bool fitBudgetOnly = false,
  }) async {
    // 1. Chuẩn hóa ngày
    DateTime startNorm =
        DateTime(startDate.year, startDate.month, startDate.day);
    DateTime endNorm = DateTime(endDate.year, endDate.month, endDate.day);

    // 2. Tính số ngày nuôi
    int daysRemaining = endNorm.difference(startNorm).inDays + 1;

    if (daysRemaining <= 1) {
      return [];
    }

    final capSoMucTieu = ganInfo.randomPair;
    final rawTable = <BettingRow>[];

    double tongTien = 0.0;

    // Tính profit step
    final profitStep =
        (AppConstants.finalProfit - AppConstants.startingProfit) /
            (daysRemaining - 1);

    double tienCuocMien =
        AppConstants.startingProfit / (AppConstants.winMultiplierXien - 1);

    if (tienCuocMien.isNaN || tienCuocMien.isInfinite) {
      tienCuocMien = 100.0;
    }

    // Bước 1: Tính toán thô
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
        tienCuocMien = 100; // Fallback nhỏ
        tongTien += tienCuocMien;
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

    if (rawTotalCost <= 0) scalingFactor = 1.0;
    if (scalingFactor.isNaN || scalingFactor.isInfinite || scalingFactor <= 0) {
      scalingFactor = 1.0;
    }

    // Bước 3: Tạo bảng chi tiết & Đảm bảo lợi nhuận dương
    for (int i = 0; i < tempRows.length; i++) {
      final row = tempRows[i];

      // a. Scale theo ngân sách
      double cuocMien = (row['cuoc_mien'] as double? ?? 100.0) * scalingFactor;
      cuocMien = cuocMien.ceilToDouble();

      // b. Lấy tổng tiền tích lũy của các ngày trước
      double prevTotal = i == 0 ? 0 : rawTable[i - 1].tongTien;

      // c. [QUAN TRỌNG] Ép Min Bet là 1đ (thay vì 1000đ)
      if (cuocMien < 1) cuocMien = 1;

      // d. Kiểm tra điểm hòa vốn (Break-even check)
      // Cược * (Multiplier - 1) > Vốn cũ
      double minBetToBreakEven =
          prevTotal / (AppConstants.winMultiplierXien - 1);

      // Nếu cược hiện tại vẫn lỗ hoặc hòa -> Tăng cược lên
      if (cuocMien <= minBetToBreakEven) {
        // Tăng thêm để có lời tối thiểu 1đ
        double targetProfit = 1.0;
        cuocMien =
            (prevTotal + targetProfit) / (AppConstants.winMultiplierXien - 1);
        cuocMien = cuocMien.ceilToDouble();

        if (cuocMien < 1) cuocMien = 1;
      }

      // e. Tính toán lại tổng và lợi nhuận
      double tongTienRow = prevTotal + cuocMien;
      double loi = (cuocMien * AppConstants.winMultiplierXien) - tongTienRow;

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
      // ✅ CẬP NHẬT QUAN TRỌNG: Tăng range tìm kiếm cho Cycle
      // Cycle biến động vốn rất mạnh (3 miền/ngày) nên cần dò kỹ hơn nhiều
      profitSearchRange: 22,
      betSearchRange: 22,
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
      profitSearchRange: 11,
      betSearchRange: 11,
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
      profitSearchRange: 11,
      betSearchRange: 11,
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
      profitSearchRange: 11,
      betSearchRange: 11,
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
    // [FIX 1] Dynamic High Bet: Cho phép cược khởi điểm lớn (ví dụ tối đa 1/200 ngân sách)
    // Thay vì cố định 2000, ta để nó linh hoạt theo túi tiền.
    double highBet = budgetMax / 200;
    if (highBet < 2000) highBet = 2000; // Tối thiểu vẫn cho range rộng một chút

    // Low Bet khởi tạo thông minh hơn
    double lowBet = 1.0;

    List<BettingRow>? localBestTable;

    for (int i = 0; i < searchRange; i++) {
      if (highBet < lowBet) break;

      double midBet = ((lowBet + highBet) / 2);
      if (midBet < 1) midBet = 1;

      final result = await calculator(profitTarget, midBet);
      final tongTien = result['tong_tien'] as double;
      final table = result['table'] as List<BettingRow>;

      // [FIX 2] Logic tìm kiếm: Ưu tiên cược TO (hướng lên trên)
      if (tongTien >= budgetMin && tongTien <= budgetMax) {
        localBestTable = table;
        // Đã tìm thấy mức thỏa mãn -> Thử tìm mức cao hơn nữa xem có được không
        lowBet = midBet + 1;
      } else if (tongTien > budgetMax) {
        // Quá ngân sách -> Phải giảm cược
        highBet = midBet - 1;
      } else {
        // Dưới ngân sách tối thiểu -> Phải tăng cược
        lowBet = midBet + 1;
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
    int betSearchRange = 12, // Tăng độ chính xác tìm kiếm Bet
  }) async {
    double lowProfit = 10.0;

    // [FIX 3] Dynamic High Profit: Phá bỏ giới hạn 100k.
    // Cho phép lãi mục tiêu lên tới 50% tổng vốn (hoặc con số hợp lý với bạn)
    double highProfit = budgetMax / 2;

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
        // [FIX 4] Luôn cập nhật bảng mới nhất (vì nó có Profit cao hơn bảng cũ)
        bestTable = foundTable;

        // Tìm thấy cấu hình ngon -> Tham lam thử Profit cao hơn nữa để tiêu hết tiền
        lowProfit = midProfit + 1;
      } else {
        // Không tìm thấy -> Giảm Profit xuống
        highProfit = midProfit - 1;
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
    // [LOGIC MỚI] Soft Start cho Dòng 1
    // Nếu là dòng 1: Chỉ yêu cầu đạt 60% lợi nhuận mục tiêu để giảm tải vốn
    // Các dòng sau: Yêu cầu 100% lợi nhuận mục tiêu
    double currentProfitTarget = profitTarget;
    if (prevTable.isEmpty) {
      currentProfitTarget =
          profitTarget * 0.67; // Giảm nhẹ kỳ vọng dòng 1 xuống 60%
    }

    // Tính mức cược cần thiết với target (đã điều chỉnh)
    final requiredBet =
        (prevTongTien + currentProfitTarget) / (winMultiplier - soLo);

    double tienCuoc1So;

    if (prevTable.isEmpty) {
      // Dòng 1: Lấy MAX để đảm bảo cược không quá bé, nhưng cũng không quá lớn
      tienCuoc1So = max(startBetValue, requiredBet);
    } else {
      // Các dòng sau: Martingale như cũ
      final lastBet = prevTable.last.cuocSo;
      tienCuoc1So = max(lastBet, requiredBet);
    }

    tienCuoc1So = tienCuoc1So.ceilToDouble();

    // ... (Phần code tính toán bên dưới giữ nguyên) ...
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
