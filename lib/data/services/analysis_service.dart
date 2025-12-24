import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../core/utils/date_utils.dart' as date_utils;
import '../models/cycle_analysis_result.dart';
import '../models/gan_pair_info.dart';
import '../models/lottery_result.dart';
import '../models/number_detail.dart';
import '../services/betting_table_service.dart';

class NumberAnalysisData {
  final String number;
  final double p1;
  final double p2;
  final double p3;
  final double pTotal;
  final double currentGan; // Đơn vị: Slots
  final DateTime lastSeenDate;

  NumberAnalysisData({
    required this.number,
    required this.p1,
    required this.p2,
    required this.p3,
    required this.pTotal,
    required this.currentGan,
    required this.lastSeenDate,
  });

  @override
  String toString() {
    return 'NumberAnalysisData('
        'number: $number, '
        'P_total: ${pTotal.toStringAsExponential(4)}, '
        'currentGan: $currentGan)';
  }
}

class PairAnalysisData {
  final String firstNumber;
  final String secondNumber;
  final double p1Pair;
  final double pTotalXien;
  final double daysSinceLastSeen;
  final DateTime lastSeenDate;

  PairAnalysisData({
    required this.firstNumber,
    required this.secondNumber,
    required this.p1Pair,
    required this.pTotalXien,
    required this.daysSinceLastSeen,
    required this.lastSeenDate,
  });

  String get pairDisplay => '$firstNumber-$secondNumber';

  @override
  String toString() {
    return 'PairAnalysisData('
        'pair: $pairDisplay, '
        'P_total: ${pTotalXien.toStringAsExponential(4)})';
  }
}

class AnalysisService {
  final Map<String, GanPairInfo> _ganPairCache = {};
  final Map<String, CycleAnalysisResult> _cycleCache = {};

  // Tỷ lệ trượt 1 slot cố định là 0.99
  static const double _probMissPerSlot = 0.99;

  static double _calculatePTotalCycle(
      double p1, double p2, double p3, double p4) {
    if (p1 <= 0 || p2 <= 0 || p3 <= 0 || p4 <= 0) {
      // print('⚠️ [DEBUG] Invalid p value: p1=$p1, p2=$p2, p3=$p3, p4=$p4');
      return 0.0;
    }

    // Công thức: pow(p1,12) * pow(p2,11.536142) * pow(p3,1.035033) * pow(p4,0.072644)
    final result = pow(p1, 10.12024526).toDouble() *
        pow(p2, 9.63792797).toDouble() *
        pow(p3, 2.72846129).toDouble() *
        pow(p4, 0.10088029).toDouble();

    return result;
  }

  static double _calculatePTotalXien(double p1) {
    if (p1 < 0) return 0.0;
    return p1;
  }

  static double _calculateP1ForXienPair(double pPair, double daysSinceSeen) {
    if (pPair >= 1 || pPair <= 0) return 0.0;
    if (daysSinceSeen < 0) return 0.0;
    // Xiên vẫn giữ logic theo ngày vì bản chất xiên tính theo cặp xuất hiện trong ngày
    return pow(1 - pPair, daysSinceSeen).toDouble();
  }

  static double estimatePairProbability(
    int totalUniquePairs,
    int totalDays,
  ) {
    return 0.055;
  }

  static Future<NumberAnalysisData?> findNumberWithMinPTotal(
    List<LotteryResult> results,
    String mien,
    double threshold,
  ) async {
    return await compute(_findNumberWithMinPTotalCompute, {
      'results': results,
      'mien': mien,
      'threshold': threshold,
    });
  }

  static NumberAnalysisData? _findNumberWithMinPTotalCompute(
    Map<String, dynamic> params,
  ) {
    var results = params['results'] as List<LotteryResult>;
    final mien = params['mien'] as String;
    // final threshold = params['threshold'] as double; // Có thể dùng nếu cần lọc

    try {
      // 1. Lọc theo miền TRƯỚC để đảm bảo đếm slot chính xác cho miền đó
      if (mien != 'tatca' && mien != 'Tất cả') {
        results = results.where((r) => r.mien == mien).toList();
      }

      if (results.isEmpty) return null;

      // 2. Logic mới: Cắt danh sách sao cho tổng slots xấp xỉ 9801
      const int targetSlots = 9801;
      int accumulatedSlots = 0;
      int cutIndex = 0;

      // Duyệt ngược từ kỳ quay mới nhất về quá khứ
      for (int i = results.length - 1; i >= 0; i--) {
        accumulatedSlots += results[i].numbers.length;
        if (accumulatedSlots >= targetSlots) {
          cutIndex = i;
          break;
        }
      }

      // Cắt lấy đoạn dữ liệu đủ 9801 slots (hoặc tối đa nếu không đủ)
      results = results.sublist(cutIndex);

      // 3. Tính kExpected dựa trên tập dữ liệu đã chuẩn hóa này
      // pStats.totalSlots lúc này sẽ ~9801 (hoặc <= nếu data ít hơn)
      final pStats = calculatePStats(results, fixedMien: mien);
      final kExpected = pStats.totalSlots / 100.0;

      print('📊 [Setup] Phạm vi phân tích: ${results.length} kỳ quay');
      print(
          '📊 [Setup] Tổng slots thực tế: ${pStats.totalSlots} (Mục tiêu: $targetSlots)');
      print(
          '📊 [Setup] kExpected (Số lần xuất hiện kỳ vọng): ${kExpected.toStringAsFixed(2)}');

      final allAnalysis = <NumberAnalysisData>[];

      for (int i = 0; i <= 99; i++) {
        final number = i.toString().padLeft(2, '0');

        // Thống kê cũng chỉ xét trong phạm vi 9801 slots này để đồng bộ với P4
        final stats = _getNumberStats(results, number);

        if (stats == null) continue;

        final currentGanSlots = stats['currentGan'] as double;
        final lastCycleGanSlots = stats['lastCycleGan'] as double;
        final thirdCycleGanSlots = stats['thirdCycleGan'] as double;
        final slots = stats['slots']
            as double; // Số lần xuất hiện thực tế trong 9801 slots
        final lastDate = stats['lastDate'] as DateTime;

        // P(trượt N slots) = 0.99^N
        final p1 = pow(_probMissPerSlot, currentGanSlots).toDouble();
        final p2 = pow(_probMissPerSlot, lastCycleGanSlots).toDouble();
        final p3 = thirdCycleGanSlots > 0
            ? pow(_probMissPerSlot, thirdCycleGanSlots).toDouble()
            : 1.0;

        // Tính p4 = Thực tế / Kỳ vọng
        final p4 = (slots == 0) ? 0.000001 : (slots / kExpected);

        final pTotal = _calculatePTotalCycle(p1, p2, p3, p4);

        allAnalysis.add(NumberAnalysisData(
          number: number,
          p1: p1,
          p2: p2,
          p3: p3,
          pTotal: pTotal,
          currentGan: currentGanSlots,
          lastSeenDate: lastDate,
        ));
      }

      if (allAnalysis.isEmpty) return null;

      final minResult =
          allAnalysis.reduce((a, b) => a.pTotal < b.pTotal ? a : b);

      // =======================================================================
      // 🔥 DEBUG LOG CHI TIẾT
      // =======================================================================
      print('\n🔍 [KIỂM TRA SỐ MỤC TIÊU] Số: ${minResult.number}');

      final bestStats = _getNumberStats(results, minResult.number);
      if (bestStats != null) {
        final s1 = bestStats['currentGan'] as double;
        final s2 = bestStats['lastCycleGan'] as double;
        final s3 = bestStats['thirdCycleGan'] as double;
        final actual = bestStats['slots'] as double;
        final p4 = (actual == 0) ? 0.000001 : (actual / kExpected);

        print(
            '   🔹 P1: ${minResult.p1.toStringAsExponential(6)} \t| Slots Gan Hiện Tại: ${s1.toInt()}');
        print(
            '   🔹 P2: ${minResult.p2.toStringAsExponential(6)} \t| Slots Gan Quá Khứ:  ${s2.toInt()}');
        print(
            '   🔹 P3: ${minResult.p3.toStringAsExponential(6)} \t| Slots Gan Kia:      ${s3.toInt()}');
        print(
            '   🔹 P4: ${p4.toStringAsFixed(6)}       \t| Thực tế: ${actual.toInt()} / Dự kiến: ${kExpected.toStringAsFixed(2)} (trong ${pStats.totalSlots} slots)');
        print('   👉 P_TOTAL: ${minResult.pTotal.toStringAsExponential(6)}');
        print('--------------------------------------------------\n');
      }

      return minResult;
    } catch (e) {
      print('❌ Error in findNumberWithMinPTotal: $e');
      return null;
    }
  }

  // ... (Giữ nguyên phần Pair/Xiên analysis vì phần này logic khác) ...

  static Future<PairAnalysisData?> findPairWithMinPTotal(
    List<LotteryResult> allResults,
  ) async {
    return await compute(_findPairWithMinPTotalCompute, allResults);
  }

  static PairAnalysisData? _findPairWithMinPTotalCompute(
    List<LotteryResult> allResults,
  ) {
    // Logic xiên giữ nguyên theo ngày vì tính theo cặp
    try {
      var bacResults = allResults.where((r) => r.mien == 'Bắc').toList();
      if (bacResults.isEmpty) return null;

      const int limit = 368;
      if (bacResults.length > limit) {
        bacResults = bacResults.sublist(bacResults.length - limit);
      }

      final resultsByDate = <DateTime, Set<String>>{};
      final pairLastSeen = <String, DateTime>{};

      for (final r in bacResults) {
        final date = date_utils.DateUtils.parseDate(r.ngay);
        if (date == null) continue;
        resultsByDate.putIfAbsent(date, () => {}).addAll(r.numbers);
      }

      final sortedDates = resultsByDate.keys.toList()..sort();

      for (final date in sortedDates) {
        final nums = resultsByDate[date]!.toList()..sort();
        if (nums.length < 2) continue;

        for (int i = 0; i < nums.length - 1; i++) {
          for (int j = i + 1; j < nums.length; j++) {
            final pairKey = '${nums[i]}-${nums[j]}';
            pairLastSeen[pairKey] = date;
          }
        }
      }

      if (pairLastSeen.isEmpty) return null;

      final pPair = estimatePairProbability(
        pairLastSeen.length,
        bacResults.map((r) => r.ngay).toSet().length,
      );

      final now = DateTime.now();
      final allPairAnalysis = <PairAnalysisData>[];

      for (final entry in pairLastSeen.entries) {
        final pairKey = entry.key;
        final lastSeenDate = entry.value;
        final daysSince = now.difference(lastSeenDate).inDays.toDouble();

        final p1Pair = _calculateP1ForXienPair(pPair, daysSince);
        final pTotalXien = _calculatePTotalXien(p1Pair);

        final parts = pairKey.split('-');
        allPairAnalysis.add(PairAnalysisData(
          firstNumber: parts[0],
          secondNumber: parts[1],
          p1Pair: p1Pair,
          pTotalXien: pTotalXien,
          daysSinceLastSeen: daysSince,
          lastSeenDate: lastSeenDate,
        ));
      }

      if (allPairAnalysis.isEmpty) return null;

      return allPairAnalysis
          .reduce((a, b) => a.pTotalXien < b.pTotalXien ? a : b);
    } catch (e) {
      return null;
    }
  }

  static Future<({DateTime endDate, int daysNeeded})?>
      findEndDateForCycleThreshold(NumberAnalysisData targetNumber, double p,
          List<LotteryResult> results, double threshold,
          {int maxIterations = 20000, String mien = 'Tất cả'}) async {
    // 🔥 DEBUG NGAY TẠI CỬA NGÕ: Xem nó nhận được cái gì
    print('🔍 [DEBUG Mien] Input received: "$mien"');

    return await compute(_findEndDateForCycleThresholdCompute, {
      'targetNumber': targetNumber.number,
      'currentGanSlots': targetNumber.currentGan,
      'currentP2': targetNumber.p2,
      'currentP3': targetNumber.p3,
      'threshold': threshold,
      'maxIterations': maxIterations,
      'mien': mien,
    });
  }

  static ({DateTime endDate, int daysNeeded})?
      _findEndDateForCycleThresholdCompute(
    Map<String, dynamic> params,
  ) {
    final currentGanSlots = params['currentGanSlots'] as double;
    final currentP2 = params['currentP2'] as double;
    final currentP3 = params['currentP3'] as double;
    final threshold = params['threshold'] as double;
    final maxIterations = params['maxIterations'] as int;
    final mienFilter = params['mien'] as String;

    try {
      // Giả định p4 = 1.0 vì trong mô phỏng ngắn hạn nó ít biến động
      const currentP4 = 1.0;

      // 1. Kiểm tra trạng thái hiện tại
      var currentP1 = pow(_probMissPerSlot, currentGanSlots).toDouble();
      var currentPTotal =
          _calculatePTotalCycle(currentP1, currentP2, currentP3, currentP4);

      if (currentPTotal < threshold) {
        return (
          endDate: DateTime.now().add(const Duration(days: 1)),
          daysNeeded: 1
        );
      }

      // 2. Loop: Tăng dần số slot cần bốc thêm (addedSlots)
      // Cho đến khi p1 đủ nhỏ để pTotal < threshold
      int addedSlots = 0;
      while (currentPTotal >= threshold && addedSlots < maxIterations) {
        addedSlots++;
        // Cứ thêm 1 slot thì p1 giảm đi 1% (nhân 0.99)
        currentP1 = currentP1 * _probMissPerSlot;
        currentPTotal =
            _calculatePTotalCycle(currentP1, currentP2, currentP3, currentP4);
      }

      if (addedSlots >= maxIterations) {
        print('   ⚠️ Vượt quá maxIterations slots ($maxIterations)');
        return null;
      }

      // 3. Ánh xạ từ "Số slot cần thêm" -> "Ngày và Miền kết thúc"
      // Phải dựa vào lịch quay thưởng (Schedule)
      final simulationResult = _mapSlotsToDateAndMien(
        slotsNeeded: addedSlots,
        startDate: DateTime.now(),
        mienFilter: mienFilter,
      );

      print('   ✅ Cần thêm $addedSlots slots.');
      print(
          '   ✅ Dự kiến chạm đáy vào: ${date_utils.DateUtils.formatDate(simulationResult.date)} (${simulationResult.endMien})');

      return (
        endDate: simulationResult.date,
        daysNeeded: simulationResult.daysFromStart
      );
    } catch (e) {
      print('❌ Error in findEndDateForCycleThreshold: $e');
      return null;
    }
  }

  // Hàm helper: Ánh xạ Slot -> Date dựa trên lịch xổ số (Bắc/Trung/Nam)
  static ({DateTime date, String endMien, int daysFromStart})
      _mapSlotsToDateAndMien({
    required int slotsNeeded,
    required DateTime startDate,
    required String mienFilter,
  }) {
    DateTime currentDate = startDate;
    int slotsRemaining = slotsNeeded;
    int daysCount = 0;

    // Safety break để tránh vòng lặp vô tận nếu logic sai
    int safetyLoop = 0;
    const int maxLookAheadDays = 365;

    // Lặp từng ngày cho đến khi hết slots
    while (slotsRemaining > 0 && safetyLoop < maxLookAheadDays) {
      safetyLoop++;
      // Sang ngày tiếp theo (bắt đầu tính từ ngày mai)
      currentDate = currentDate.add(const Duration(days: 1));
      daysCount++;

      // Lấy danh sách các miền quay trong ngày đó dựa trên bộ lọc
      final schedule = _getLotterySchedule(currentDate, mienFilter);

      // Nếu ngày đó không có đài nào quay (theo bộ lọc), bỏ qua
      if (schedule.isEmpty) continue;

      for (final mien in schedule) {
        // Lấy số slot (số giải) chính xác của miền đó vào thứ đó
        final slotsInMien = _getSlotsForMien(mien, currentDate);

        if (slotsRemaining <= slotsInMien) {
          // Kết thúc tại miền này
          return (
            date: currentDate,
            endMien: mien,
            daysFromStart: daysCount,
          );
        } else {
          // Trừ slot và tiếp tục sang miền tiếp theo hoặc ngày tiếp theo
          slotsRemaining -= slotsInMien;
        }
      }
    }

    return (date: currentDate, endMien: 'Unknown', daysFromStart: daysCount);
  }

  // Trả về thứ tự quay thưởng trong ngày CHỈ CHO PHÉP theo bộ lọc
  static List<String> _getLotterySchedule(DateTime date, String filter) {
    final list = <String>[];

    // Chuẩn hóa chuỗi đầu vào: chữ thường + trim khoảng trắng
    final f = filter.toLowerCase().trim();

    // Logic kiểm tra thông minh hơn: Dùng .contains()
    // Chấp nhận: "miền bắc", "bắc", "xổ số bắc", "bac"...
    bool isBac = f.contains('bắc') || f.contains('bac');
    bool isTrung = f.contains('trung');
    bool isNam = f.contains('nam');

    // Nếu chuỗi chứa "tất cả", "tatca" hoặc RỖNG -> Là Tất cả
    bool isAll = f.contains('tất cả') || f.contains('tatca') || f.isEmpty;

    // Fallback: Nếu không khớp từ khóa nào cả -> Coi như là Tất cả (để tránh lỗi return list rỗng)
    if (!isBac && !isTrung && !isNam && !isAll) {
      // print('⚠️ [Schedule] Không nhận diện được miền "$filter", mặc định là Tất cả');
      isAll = true;
    }

    // Thứ tự xổ thực tế: Nam (16:15) -> Trung (17:15) -> Bắc (18:15)

    // 1. Miền Nam
    if (isAll || isNam) {
      list.add('Nam');
    }

    // 2. Miền Trung
    if (isAll || isTrung) {
      list.add('Trung');
    }

    // 3. Miền Bắc
    if (isAll || isBac) {
      list.add('Bắc');
    }

    return list;
  }

  // Số slot (số giải) thực tế của từng miền trong 1 ngày (dựa trên thứ)
  static int _getSlotsForMien(String mien, DateTime date) {
    final weekday = date.weekday; // 1 = Thứ 2, ..., 7 = Chủ Nhật
    // 1 đài = 18 giải.

    switch (mien) {
      case 'Bắc':
        // Miền Bắc: Luôn 27 giải (1 đài chung)
        return 27;

      case 'Trung':
        // Quy luật miền Trung:
        // T2: 2 đài (Huế, Phú Yên) -> 36
        // T3: 2 đài (Đắk Lắk, Quảng Nam) -> 36
        // T4: 2 đài (Đà Nẵng, Khánh Hòa) -> 36
        // T5: 3 đài (Bình Định, Quảng Trị, Quảng Bình) -> 54
        // T6: 2 đài (Gia Lai, Ninh Thuận) -> 36
        // T7: 3 đài (Đà Nẵng, Quảng Ngãi, Đắk Nông) -> 54
        // CN: 2 đài (Kon Tum, Khánh Hòa) -> 36

        if (weekday == DateTime.thursday || weekday == DateTime.saturday) {
          return 54; // 3 đài
        }
        return 36; // 2 đài

      case 'Nam':
        // Quy luật miền Nam:
        // T2, T3, T4, T5, T6, CN: 3 đài -> 54 giải
        // Riêng T7: 4 đài (TP.HCM, Long An, Bình Phước, Hậu Giang) -> 72 giải

        if (weekday == DateTime.saturday) {
          return 72; // 4 đài
        }
        return 54; // 3 đài

      default:
        return 18; // Fallback an toàn
    }
  }

  static Future<({DateTime endDate, int daysNeeded})?>
      findEndDateForXienThreshold(
          PairAnalysisData targetPair, double pPair, double threshold,
          {int maxIterations = 10000}) async {
    // Xiên vẫn giữ nguyên logic theo ngày như cũ
    return await compute(_findEndDateForXienThresholdCompute, {
      'pPair': pPair,
      'currentDaysGan': targetPair.daysSinceLastSeen,
      'threshold': threshold,
      'maxIterations': maxIterations,
    });
  }

  static ({DateTime endDate, int daysNeeded})?
      _findEndDateForXienThresholdCompute(
    Map<String, dynamic> params,
  ) {
    final pPair = params['pPair'] as double;
    final currentDaysGan = params['currentDaysGan'] as double;
    final threshold = params['threshold'] as double;
    final maxIterations = params['maxIterations'] as int;

    try {
      var currentP1 = _calculateP1ForXienPair(pPair, currentDaysGan);

      if (currentP1 < threshold) {
        return (
          endDate: DateTime.now().add(const Duration(days: 1)),
          daysNeeded: 1
        );
      }

      int daysNeeded = 0;
      while (currentP1 >= threshold && daysNeeded < maxIterations) {
        daysNeeded++;
        currentP1 = currentP1 * (1 - pPair);
      }

      if (daysNeeded >= maxIterations) {
        return null;
      }

      final endDate = DateTime.now().add(Duration(days: daysNeeded));
      return (endDate: endDate, daysNeeded: daysNeeded);
    } catch (e) {
      return null;
    }
  }

  // ... (Các hàm findOptimalStartDate, getMienIndex giữ nguyên) ...

  static Future<DateTime?> findOptimalStartDateForCycle({
    required DateTime baseStartDate,
    required DateTime endDate,
    required double availableBudget,
    required String mien,
    required String targetNumber,
    required CycleAnalysisResult cycleResult,
    required List<LotteryResult> allResults,
    required BettingTableService bettingService,
    required int maxMienCount,
    int maxDaysToTry = 15,
  }) async {
    DateTime currentStart = baseStartDate;
    int attempt = 0;

    while (attempt < maxDaysToTry && currentStart.isBefore(endDate)) {
      try {
        final table = await bettingService.generateCycleTable(
          cycleResult: cycleResult,
          startDate: currentStart,
          endDate: endDate,
          startMienIndex: _getMienIndex(mien),
          budgetMin: availableBudget * 0.8,
          budgetMax: availableBudget,
          allResults: allResults,
          maxMienCount: maxMienCount,
          durationLimit: endDate.difference(currentStart).inDays,
        );

        if (table.isNotEmpty) {
          final totalCost = table.last.tongTien;
          if (totalCost <= availableBudget) {
            return currentStart;
          }
        }
      } catch (e) {}
      currentStart = currentStart.add(const Duration(days: 1));
      attempt++;
    }
    return null;
  }

  static int _getMienIndex(String mien) {
    switch (mien.toLowerCase()) {
      case 'nam':
      case 'tatca':
      case 'tất cả':
        return 0;
      case 'trung':
        return 1;
      case 'bac':
      case 'bắc':
        return 2;
      default:
        return 0;
    }
  }

  static Future<DateTime?> findOptimalStartDateForXien({
    required DateTime baseStartDate,
    required DateTime endDate,
    required double availableBudget,
    required GanPairInfo ganInfo,
    required BettingTableService bettingService,
    int maxDaysToTry = 15,
  }) async {
    print('🔍 [Start Date] Tìm start date tối ưu (Xiên)');
    DateTime currentStart = baseStartDate;
    int attempt = 0;

    while (attempt < maxDaysToTry && currentStart.isBefore(endDate)) {
      try {
        final actualBettingDays = endDate.difference(currentStart).inDays;
        if (actualBettingDays <= 1) break;

        final effectiveDurationBase = actualBettingDays + ganInfo.daysGan;

        final table = await bettingService.generateXienTable(
          ganInfo: ganInfo,
          startDate: currentStart,
          xienBudget: availableBudget,
          durationBase: effectiveDurationBase,
          fitBudgetOnly: true,
        );

        if (table.isNotEmpty) {
          final totalCost = table.last.tongTien;
          if (totalCost <= availableBudget) {
            print(
                '   ✅ TÌM ĐƯỢC! Start = ${date_utils.DateUtils.formatDate(currentStart)}');
            return currentStart;
          }
        }
      } catch (e) {
        // Ignored
      }
      currentStart = currentStart.add(const Duration(days: 1));
      attempt++;
    }
    return null;
  }

  // ... (Các hàm còn lại giữ nguyên, chỉ chỉnh sửa calculatePStats) ...

  static ({double p, int totalSlots}) calculatePStats(
      List<LotteryResult> results,
      {String? fixedMien}) {
    int totalSlots = 0;
    if (results.isNotEmpty) {
      for (final r in results) {
        totalSlots += r.numbers.length;
      }
    }
    // Giá trị p ở đây chỉ dùng để tham khảo hoặc tính kExpected
    // Logic tính p1, p2, p3 chính đã chuyển sang dùng hằng số 0.99
    return (p: 0.01, totalSlots: totalSlots);
  }

  // ... (Giữ nguyên các hàm helper khác) ...

  static double _calculateP1(double p, double gan) =>
      throw UnimplementedError("Use direct power calculation");

  static Map<String, dynamic>? _getNumberStats(
      List<LotteryResult> results, String targetNumber) {
    // ... (Giữ nguyên logic đếm slots như code cũ của bạn) ...
    // Code cũ đã đúng phần đếm slots (_countSlotsSinceLastSeen), nên giữ nguyên.
    final completionDate = _getCompletionDate(results);
    if (completionDate == null) return null;

    int lastSeenIndex = -1;
    DateTime? lastSeenDate;
    String? lastSeenMien;
    int slots = 0;
    int occurrences = 0;

    for (int i = 0; i < results.length; i++) {
      final count = results[i].numbers.where((n) => n == targetNumber).length;
      if (count > 0) {
        occurrences++;
        slots += count;
      }
    }

    for (int i = results.length - 1; i >= 0; i--) {
      if (results[i].numbers.contains(targetNumber)) {
        final date = date_utils.DateUtils.parseDate(results[i].ngay);
        if (date != null) {
          lastSeenDate = date;
          lastSeenMien = results[i].mien;
          lastSeenIndex = i;
          break;
        }
      }
    }

    if (lastSeenDate == null || lastSeenMien == null) return null;

    final currentGanSlots = _countSlotsSinceLastSeen(
      results,
      lastSeenDate,
      lastSeenMien,
      completionDate,
      excludeLastSeen: true,
    );

    int lastCycleGanSlots = 0;
    DateTime? secondLastSeenDate;
    String? secondLastSeenMien;
    int secondLastSeenIndex = -1;

    for (int i = lastSeenIndex - 1; i >= 0; i--) {
      if (results[i].numbers.contains(targetNumber)) {
        secondLastSeenDate = date_utils.DateUtils.parseDate(results[i].ngay);
        if (secondLastSeenDate != null) {
          secondLastSeenMien = results[i].mien;
          secondLastSeenIndex = i;
          break;
        }
      }
    }

    if (secondLastSeenDate != null && secondLastSeenMien != null) {
      lastCycleGanSlots = _countSlotsBetween(
        results,
        secondLastSeenDate,
        secondLastSeenMien,
        lastSeenDate,
        lastSeenMien,
        excludeStart: true,
        excludeEnd: false,
      );
    }

    int thirdCycleGanSlots = 0;
    if (secondLastSeenIndex > 0) {
      for (int i = secondLastSeenIndex - 1; i >= 0; i--) {
        if (results[i].numbers.contains(targetNumber)) {
          final thirdLastSeenDate =
              date_utils.DateUtils.parseDate(results[i].ngay);
          if (thirdLastSeenDate != null && secondLastSeenDate != null) {
            final thirdLastSeenMien = results[i].mien;
            thirdCycleGanSlots = _countSlotsBetween(
              results,
              thirdLastSeenDate,
              thirdLastSeenMien,
              secondLastSeenDate,
              secondLastSeenMien!,
              excludeStart: true,
              excludeEnd: false,
            );
            break;
          }
        }
      }
    }

    final uniqueDays = results.map((r) => r.ngay).toSet().length;

    return {
      'currentGan': currentGanSlots.toDouble(),
      'lastCycleGan': lastCycleGanSlots.toDouble(),
      'thirdCycleGan': thirdCycleGanSlots.toDouble(),
      'occurrences': occurrences.toDouble(),
      'totalDays': uniqueDays.toDouble(),
      'slots': slots.toDouble(),
      'lastDate': lastSeenDate,
    };
  }

  // ... (Giữ nguyên các hàm helper _getCompletionDate, _countSlotsSinceLastSeen, _countSlotsBetween...) ...
  static DateTime? _getCompletionDate(List<LotteryResult> results) {
    if (results.isEmpty) return null;
    DateTime? latest;
    for (final r in results) {
      final d = date_utils.DateUtils.parseDate(r.ngay);
      if (d != null && (latest == null || d.isAfter(latest))) latest = d;
    }
    return latest;
  }

  static int _countSlotsSinceLastSeen(
    List<LotteryResult> allResults,
    DateTime lastSeenDate,
    String lastSeenMien,
    DateTime completionDate, {
    bool excludeLastSeen = true,
  }) {
    int lastSeenIndex = -1;
    for (int i = allResults.length - 1; i >= 0; i--) {
      final result = allResults[i];
      final date = date_utils.DateUtils.parseDate(result.ngay);
      if (date != null &&
          date.isAtSameMomentAs(lastSeenDate) &&
          result.mien == lastSeenMien) {
        lastSeenIndex = i;
        break;
      }
    }
    if (lastSeenIndex == -1) return 0;
    int slotCount = 0;
    final startIndex = excludeLastSeen ? lastSeenIndex + 1 : lastSeenIndex;
    for (int i = startIndex; i < allResults.length; i++) {
      final result = allResults[i];
      final date = date_utils.DateUtils.parseDate(result.ngay);
      if (date != null &&
          (date.isBefore(completionDate) ||
              date.isAtSameMomentAs(completionDate))) {
        slotCount +=
            result.numbers.length; // ✅ FIX: Cộng số lượng giải trong kỳ đó
      }
    }
    return slotCount;
  }

  static int _countSlotsBetween(
    List<LotteryResult> allResults,
    DateTime startDate,
    String startMien,
    DateTime endDate,
    String endMien, {
    bool excludeStart = true,
    bool excludeEnd = false,
  }) {
    int startIndex = -1;
    for (int i = allResults.length - 1; i >= 0; i--) {
      final result = allResults[i];
      final date = date_utils.DateUtils.parseDate(result.ngay);
      if (date != null &&
          date.isAtSameMomentAs(startDate) &&
          result.mien == startMien) {
        startIndex = i;
        break;
      }
    }
    if (startIndex == -1) return 0;

    int endIndex = allResults.length - 1;
    for (int i = allResults.length - 1; i >= 0; i--) {
      final result = allResults[i];
      final date = date_utils.DateUtils.parseDate(result.ngay);
      if (date != null &&
          date.isAtSameMomentAs(endDate) &&
          result.mien == endMien) {
        endIndex = i;
        break;
      }
    }

    final actualStartIndex = excludeStart ? startIndex + 1 : startIndex;
    final actualEndIndex = excludeEnd ? endIndex - 1 : endIndex;

    if (actualStartIndex > actualEndIndex) return 0;

    int totalSlots = 0;
    for (int i = actualStartIndex; i <= actualEndIndex; i++) {
      totalSlots += allResults[i].numbers.length; // ✅ FIX: Cộng số lượng giải
    }

    return totalSlots;
  }

  // ... (Giữ các hàm helper còn lại như hasNumberReappeared, GanPair...)
  Future<GanPairInfo?> findGanPairsMienBac(
      List<LotteryResult> allResults) async {
    // Logic cũ
    final key = 'ganpair_${allResults.length}';
    if (_ganPairCache.containsKey(key)) return _ganPairCache[key];
    final res = await compute(_findGanPairsMienBacCompute, allResults);
    if (res != null) _ganPairCache[key] = res;
    return res;
  }

  static GanPairInfo? _findGanPairsMienBacCompute(
      List<LotteryResult> allResults) {
    // Logic cũ
    final bacResults = allResults.where((r) => r.mien == 'Bắc').toList();
    if (bacResults.isEmpty) return null;
    final resultsByDate = <DateTime, Set<String>>{};
    for (final r in bacResults) {
      final date = date_utils.DateUtils.parseDate(r.ngay);
      if (date == null) continue;
      resultsByDate.putIfAbsent(date, () => {}).addAll(r.numbers);
    }
    final pairLastSeen = <String, DateTime>{};
    final sortedDates = resultsByDate.keys.toList()..sort();
    for (final date in sortedDates) {
      final nums = resultsByDate[date]!.toList()..sort();
      if (nums.length < 2) continue;
      for (int i = 0; i < nums.length - 1; i++) {
        for (int j = i + 1; j < nums.length; j++) {
          pairLastSeen['${nums[i]}-${nums[j]}'] = date;
        }
      }
    }
    if (pairLastSeen.isEmpty) return null;
    final sortedPairs = pairLastSeen.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final top2 = sortedPairs.take(2).toList();
    final now = DateTime.now();
    return GanPairInfo(
      daysGan: now.difference(top2[0].value).inDays,
      lastSeen: top2[0].value,
      pairs: top2.map((e) {
        final p = e.key.split('-');
        return PairWithDays(
            pair: NumberPair(p[0], p[1]),
            daysGan: now.difference(e.value).inDays,
            lastSeen: e.value);
      }).toList(),
    );
  }

  // Các hàm analyzeSpecificNumber, analyzeCycle... giữ nguyên nhưng chú ý logic tính toán
  // bên trong nên dùng các helper đã update.
  Future<CycleAnalysisResult?> analyzeSpecificNumber(
      List<LotteryResult> allResults, String targetNumber) async {
    return await compute(_analyzeSpecificNumberCompute, {
      'results': allResults,
      'number': targetNumber,
    });
  }

  static CycleAnalysisResult? _analyzeSpecificNumberCompute(
      Map<String, dynamic> params) {
    final results = params['results'] as List<LotteryResult>;
    final targetNumber = params['number'] as String;
    final stats = _getNumberStats(results, targetNumber);
    if (stats == null) return null;
    final pStats = calculatePStats(results);
    final double kExpected = pStats.totalSlots / 100.0;
    return CycleAnalysisResult(
      targetNumber: targetNumber,
      ganNumbers: {targetNumber},
      maxGanDays: (stats['currentGan'] as double).toInt(), // Hiển thị Gan Slots
      lastSeenDate: stats['lastDate'] as DateTime,
      mienGroups: {},
      historicalGan: (stats['lastCycleGan'] as double).toInt(),
      occurrenceCount: (stats['slots'] as double).toInt(),
      expectedCount: kExpected,
      analysisDays: (stats['totalDays'] as double).toInt(),
    );
  }

  // ... (analyzeCycle giữ nguyên, chỉ thay đổi phần mapping stats tương tự như trên)
  Future<CycleAnalysisResult?> analyzeCycle(
      List<LotteryResult> allResults) async {
    // ... logic analyzeCycle cũ ...
    // Lưu ý: Phần tính toán P bên trong analyzeCycle nên dùng logic mới nếu cần
    // Nhưng vì analyzeCycle chủ yếu trả về thống kê Gan Days (theo ngày) để hiển thị
    // nên có thể giữ nguyên logic cũ nếu muốn hiển thị ngày, hoặc đổi sang slots nếu muốn đồng bộ.
    // Ở đây tôi giữ nguyên logic analyzeCycle để tránh lỗi biên dịch,
    // chỉ tập trung sửa findNumberWithMinPTotal theo yêu cầu của bạn.
    final key = 'cycle_${allResults.length}';
    if (_cycleCache.containsKey(key)) return _cycleCache[key];

    final res = await compute(_analyzeCycleCompute, allResults);

    if (res != null) _cycleCache[key] = res;
    return res;
  }

  static CycleAnalysisResult? _analyzeCycleCompute(
      List<LotteryResult> allResults) {
    // ... (Giữ nguyên logic cũ cho an toàn, vì yêu cầu chỉ tập trung vào P-Total và findEndDate)
    if (allResults.isEmpty) return null;
    final lastSeenMap = <String, Map<String, dynamic>>{};
    for (final res in allResults) {
      final date = date_utils.DateUtils.parseDate(res.ngay);
      if (date == null) continue;
      for (final num in res.numbers) {
        final key = num.padLeft(2, '0');
        final current = lastSeenMap[key];
        if (current == null ||
            date.isAfter(current['date']) ||
            (date.isAtSameMomentAs(current['date']) &&
                _isMienCloserStatic(res.mien, current['mien']))) {
          lastSeenMap[key] = {'date': date, 'mien': res.mien, 'ngay': res.ngay};
        }
      }
    }
    if (lastSeenMap.length < 100) return null;
    final completionDate = lastSeenMap.values
        .map((v) => v['date'] as DateTime)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    final ganStats = <Map<String, dynamic>>[];
    for (final entry in lastSeenMap.entries) {
      final d = entry.value['date'] as DateTime;
      if (d.isBefore(completionDate)) {
        ganStats.add({
          'so': entry.key,
          'days_gan': _countMienOccurrencesStatic(
              allResults, d, completionDate, entry.value['mien']),
          'mien': entry.value['mien'],
          'last_seen': d,
        });
      }
    }
    if (ganStats.isEmpty) return null;
    ganStats
        .sort((a, b) => (b['days_gan'] as int).compareTo(a['days_gan'] as int));
    final maxGan = ganStats.first['days_gan'] as int;
    final longestGroup =
        ganStats.where((s) => s['days_gan'] == maxGan).toList();
    final mienGroups = <String, List<String>>{};
    for (final s in longestGroup) {
      mienGroups.putIfAbsent(s['mien'], () => []).add(s['so']);
    }
    final targetNumber = longestGroup.first['so'] as String;

    final pStats = calculatePStats(allResults);
    final double kExpected = pStats.totalSlots / 100.0;
    final stats = _getNumberStats(allResults, targetNumber);

    int historicalGan = 0;
    int occurrenceCount = 0;
    int analysisDays = 0;
    if (stats != null) {
      historicalGan = (stats['lastCycleGan'] as double).toInt();
      occurrenceCount = (stats['slots'] as double).toInt();
      analysisDays = (stats['totalDays'] as double).toInt();
    }

    return CycleAnalysisResult(
      ganNumbers: longestGroup.map((s) => s['so'] as String).toSet(),
      maxGanDays: maxGan,
      lastSeenDate: longestGroup.first['last_seen'],
      mienGroups: mienGroups,
      targetNumber: targetNumber,
      historicalGan: historicalGan,
      occurrenceCount: occurrenceCount,
      expectedCount: kExpected,
      analysisDays: analysisDays,
    );
  }

  static bool _isMienCloserStatic(String newMien, String oldMien) {
    const p = {'Bắc': 3, 'Trung': 2, 'Nam': 1};
    return (p[newMien] ?? 0) > (p[oldMien] ?? 0);
  }

  static int _countMienOccurrencesStatic(
    List<LotteryResult> allResults,
    DateTime startDate,
    DateTime endDate,
    String targetMien, {
    bool excludeEndDate = false,
  }) {
    // Giữ nguyên logic đếm ngày
    final uniqueDates = <String>{};
    for (final result in allResults) {
      if (result.mien != targetMien) continue;
      final date = date_utils.DateUtils.parseDate(result.ngay);
      if (date == null) continue;
      if (date.isAfter(startDate)) {
        if (excludeEndDate
            ? date.isBefore(endDate)
            : (date.isBefore(endDate) || date.isAtSameMomentAs(endDate))) {
          uniqueDates.add(result.ngay);
        }
      }
    }
    return uniqueDates.length;
  }

  // ... (Giữ nguyên phần còn lại của file: analyzeNumberDetail, clearCache, hasNumberReappeared...)
  Future<NumberDetail?> analyzeNumberDetail(
      List<LotteryResult> allResults, String targetNumber) async {
    if (allResults.isEmpty) return null;
    final mienDetails = <String, MienDetail>{};
    final now = DateTime.now();
    for (final mien in ['Nam', 'Trung', 'Bắc']) {
      DateTime? lastSeen;
      String? lastSeenStr;
      for (final r in allResults.where((r) => r.mien == mien)) {
        if (r.numbers.contains(targetNumber)) {
          final d = date_utils.DateUtils.parseDate(r.ngay);
          if (d != null && (lastSeen == null || d.isAfter(lastSeen))) {
            lastSeen = d;
            lastSeenStr = r.ngay;
          }
        }
      }
      if (lastSeen != null) {
        mienDetails[mien] = MienDetail(
          mien: mien,
          daysGan: _countMienOccurrencesStatic(allResults, lastSeen, now, mien),
          lastSeenDate: lastSeen,
          lastSeenDateStr: lastSeenStr!,
        );
      }
    }
    return mienDetails.isEmpty
        ? null
        : NumberDetail(number: targetNumber, mienDetails: mienDetails);
  }

  void clearCache() {
    _cycleCache.clear();
    _ganPairCache.clear();
  }

  Future<bool> hasNumberReappeared(
      String targetNumber, DateTime sinceDate, List<LotteryResult> allResults,
      {String mien = ''}) async {
    return await compute(_hasNumberReappearedCompute, {
      'targetNumber': targetNumber,
      'sinceDate': sinceDate.millisecondsSinceEpoch,
      'allResults': allResults,
      'mien': mien,
    });
  }

  static bool _hasNumberReappearedCompute(Map<String, dynamic> params) {
    return _hasNumberReappearedStatic(
      params['targetNumber'],
      DateTime.fromMillisecondsSinceEpoch(params['sinceDate']),
      params['allResults'],
      mien: params['mien'] ?? '',
    );
  }

  static bool _hasNumberReappearedStatic(
      String targetNumber, DateTime sinceDate, List<LotteryResult> allResults,
      {String mien = ''}) {
    final normalizedTarget = targetNumber.padLeft(2, '0');
    final completionDate = _getCompletionDate(allResults);
    if (completionDate == null) return false;

    for (final result in allResults) {
      if (mien.isNotEmpty && result.mien != mien) continue;
      if (!result.numbers.contains(normalizedTarget) &&
          !result.numbers.contains(targetNumber)) {
        continue;
      }
      final resultDate = date_utils.DateUtils.parseDate(result.ngay);
      if (resultDate == null) continue;
      if (resultDate.isAfter(sinceDate) &&
          (resultDate.isBefore(completionDate) ||
              resultDate.isAtSameMomentAs(completionDate))) {
        return true;
      }
    }
    return false;
  }
}
