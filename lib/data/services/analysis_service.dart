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
  final double p3; // ✅ THÊM
  final double pTotal;
  final double currentGan;
  final DateTime lastSeenDate;

  NumberAnalysisData({
    required this.number,
    required this.p1,
    required this.p2,
    required this.p3, // ✅ THÊM
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

  static double _calculatePTotalCycle(
      double p1, double p2, double p3, double p4) {
    if (p1 <= 0 || p2 <= 0 || p3 <= 0 || p4 <= 0) {
      print('⚠️ [DEBUG] Invalid p value: p1=$p1, p2=$p2, p3=$p3, p4=$p4');
      return 0.0;
    }

    // Công thức: pow(p1,12) * pow(p2,11.536142) * pow(p3,1.035033) * pow(p4,0.072644)
    final result = pow(p1, 12).toDouble() *
        pow(p2, 11.536142).toDouble() *
        pow(p3, 1.035033).toDouble() *
        pow(p4, 0.072644).toDouble();

    return result;
  }

  static double _calculatePTotalXien(double p1) {
    if (p1 < 0) return 0.0;
    return p1;
  }

  static double _calculateP1ForXienPair(double pPair, double daysSinceSeen) {
    if (pPair >= 1 || pPair <= 0) return 0.0;
    if (daysSinceSeen < 0) return 0.0;
    return pow(1 - pPair, daysSinceSeen).toDouble();
  }

  // ✅ SỬA LOGIC: Xác suất P là hằng số theo ngày, không nhân với totalDays
  // Public để ViewModel gọi được
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
    final threshold = params['threshold'] as double;

    const int limit = 368;
    if (results.length > limit) {
      results = results.sublist(results.length - limit);
    }

    try {
      if (mien != 'tatca' && mien != 'Tất cả') {
        results = results.where((r) => r.mien == mien).toList();
        if (results.isEmpty) return null;
      }

      final pStats = calculatePStats(results, fixedMien: mien);
      final p = pStats.p;
      if (p == 0) return null;

      print('📊 [DEBUG] p (xác suất nền): ${p.toStringAsExponential(6)}');
      print('📊 [DEBUG] Total slots: ${pStats.totalSlots}');

      final kExpected = pStats.totalSlots / 100.0;
      print('📊 [DEBUG] kExpected: ${kExpected.toStringAsFixed(2)}');

      final allAnalysis = <NumberAnalysisData>[];

      for (int i = 0; i <= 99; i++) {
        final number = i.toString().padLeft(2, '0');
        final stats = _getNumberStats(results, number);

        if (stats == null) continue;

        final currentGanSlots = stats['currentGan'] as double;
        final lastCycleGanSlots = stats['lastCycleGan'] as double;
        final thirdCycleGanSlots = stats['thirdCycleGan'] as double;
        final slots = stats['slots'] as double;
        final lastDate = stats['lastDate'] as DateTime;

        // ✅ Tính p1, p2, p3 theo công thức (1-p)^slots
        final p1 = _calculateP1(p, currentGanSlots);
        final p2 = _calculateP1(p, lastCycleGanSlots);
        final p3 =
            thirdCycleGanSlots > 0 ? _calculateP1(p, thirdCycleGanSlots) : 1.0;

        // Tính p4 = slots / kExpected
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

      print('📊 [Cycle Analysis] Tìm số với P_total nhỏ nhất...');
      print('   Miền: $mien, Ngưỡng: ${threshold.toStringAsExponential(4)}');

      final minResult =
          allAnalysis.reduce((a, b) => a.pTotal < b.pTotal ? a : b);

      // ✅ In chi tiết
      print('   ✅ Kết quả: Số ${minResult.number}');
      print('      Gan hiện tại (slots): ${minResult.currentGan.toInt()}');
      print(
          '      p1 = (1-p)^${minResult.currentGan.toInt()} = ${minResult.p1.toStringAsExponential(6)}');
      print('      p2 = ${minResult.p2.toStringAsExponential(6)}');
      print('      p3 = ${minResult.p3.toStringAsExponential(6)}');

      final minStats = _getNumberStats(results, minResult.number);
      if (minStats != null) {
        final slots = minStats['slots'] as double;
        final lastCycleGanSlots = minStats['lastCycleGan'] as double;
        final thirdCycleGanSlots = minStats['thirdCycleGan'] as double;
        final p4 = slots / kExpected;

        print(
            '      p4 = ${slots.toInt()}/${kExpected.toStringAsFixed(2)} = ${p4.toStringAsFixed(6)}');
        print('      Gan chu kỳ trước (slots): ${lastCycleGanSlots.toInt()}');
        print('      Gan chu kỳ thứ 3 (slots): ${thirdCycleGanSlots.toInt()}');
      }

      print(
          '      P_total = pow(p1,12) * pow(p2,11.536142) * pow(p3,1.035033) * pow(p4,0.072644)');
      print('      P_total = ${minResult.pTotal.toStringAsExponential(6)}');

      return minResult;
    } catch (e) {
      print('❌ Error in findNumberWithMinPTotal: $e');
      return null;
    }
  }

  static Future<PairAnalysisData?> findPairWithMinPTotal(
    List<LotteryResult> allResults,
  ) async {
    return await compute(_findPairWithMinPTotalCompute, allResults);
  }

  static PairAnalysisData? _findPairWithMinPTotalCompute(
    List<LotteryResult> allResults,
  ) {
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

      // ✅ Gọi hàm public mới sửa
      final pPair = estimatePairProbability(
        pairLastSeen.length,
        bacResults.map((r) => r.ngay).toSet().length,
      );

      print('📊 [Xiên Analysis] Tìm cặp với P_total nhỏ nhất...');
      print('   p_pair ước tính: ${pPair.toStringAsExponential(6)}');

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

      final minResult =
          allPairAnalysis.reduce((a, b) => a.pTotalXien < b.pTotalXien ? a : b);

      print('   ✅ Kết quả: Cặp ${minResult.pairDisplay}');
      print('      P_total: ${minResult.pTotalXien.toStringAsExponential(6)}');
      print('      Gan: ${minResult.daysSinceLastSeen.toInt()} ngày');

      return minResult;
    } catch (e) {
      print('❌ Error in findPairWithMinPTotal: $e');
      return null;
    }
  }

  static Future<({DateTime endDate, int daysNeeded})?>
      findEndDateForCycleThreshold(NumberAnalysisData targetNumber, double p,
          List<LotteryResult> results, double threshold,
          {int maxIterations = 10000}) async {
    return await compute(_findEndDateForCycleThresholdCompute, {
      'targetNumber': targetNumber.number,
      'currentP1': targetNumber.p1,
      'currentP2': targetNumber.p2,
      'currentP3': targetNumber.p3,
      'p': p,
      'results': results,
      'threshold': threshold,
      'maxIterations': maxIterations,
    });
  }

  static ({DateTime endDate, int daysNeeded})?
      _findEndDateForCycleThresholdCompute(
    Map<String, dynamic> params,
  ) {
    var currentP1 = params['currentP1'] as double;
    final currentP2 = params['currentP2'] as double; // p2 không đổi
    final currentP3 = params['currentP3'] as double; // p3 không đổi
    final p = params['p'] as double;
    final threshold = params['threshold'] as double;
    final maxIterations = params['maxIterations'] as int;

    try {
      // Tính p4 từ stats (cần truyền thêm hoặc giả định = 1.0)
      // Để đơn giản, tạm set p4 = 1.0 vì trong mô phỏng nó không thay đổi
      const currentP4 = 1.0;

      var currentPTotal =
          _calculatePTotalCycle(currentP1, currentP2, currentP3, currentP4);

      if (currentPTotal < threshold) {
        return (
          endDate: DateTime.now().add(const Duration(days: 1)),
          daysNeeded: 1
        );
      }

      int daysNeeded = 0;

      // Loop: chỉ p1 thay đổi theo (1-p)^day
      while (currentPTotal >= threshold && daysNeeded < maxIterations) {
        daysNeeded++;
        currentP1 = currentP1 * (1 - p);
        currentPTotal =
            _calculatePTotalCycle(currentP1, currentP2, currentP3, currentP4);
      }

      if (daysNeeded >= maxIterations) {
        print('   ⚠️ Vượt quá maxIterations ($maxIterations)');
        return null;
      }

      final endDate = DateTime.now().add(Duration(days: daysNeeded));

      print(
          '   ✅ Tìm được! Ngày: ${date_utils.DateUtils.formatDate(endDate)} (sau $daysNeeded ngày)');

      return (endDate: endDate, daysNeeded: daysNeeded);
    } catch (e) {
      print('❌ Error in findEndDateForCycleThreshold: $e');
      return null;
    }
  }

  static Future<({DateTime endDate, int daysNeeded})?>
      findEndDateForXienThreshold(
          PairAnalysisData targetPair, double pPair, double threshold,
          {int maxIterations = 10000}) async {
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
    final currentDaysGan =
        params['currentDaysGan'] as double; // Giữ để tham khảo
    final threshold = params['threshold'] as double;
    final maxIterations = params['maxIterations'] as int;

    try {
      // 1. Tính P1 hiện tại
      var currentP1 = _calculateP1ForXienPair(pPair, currentDaysGan);

      if (currentP1 < threshold) {
        return (
          endDate: DateTime.now().add(const Duration(days: 1)),
          daysNeeded: 1
        );
      }

      int daysNeeded = 0;

      // 2. Loop nhân (1-pPair)
      while (currentP1 >= threshold && daysNeeded < maxIterations) {
        daysNeeded++;
        currentP1 = currentP1 * (1 - pPair);
      }

      if (daysNeeded >= maxIterations) {
        return null;
      }

      // 3. Tính EndDate từ NGÀY HIỆN TẠI
      final endDate = DateTime.now().add(Duration(days: daysNeeded));

      print(
          '   ✅ Tìm được Xiên! Ngày: ${date_utils.DateUtils.formatDate(endDate)} (sau $daysNeeded ngày)');

      return (endDate: endDate, daysNeeded: daysNeeded);
    } catch (e) {
      print('❌ Error in findEndDateForXienThreshold: $e');
      return null;
    }
  }

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
    print('🔍 [Start Date] Tìm start date tối ưu (Chu kỳ)');
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
            print(
                '   ✅ TÌM ĐƯỢC! Start = ${date_utils.DateUtils.formatDate(currentStart)}');
            return currentStart;
          }
        }
      } catch (e) {
        // print('      ⚠️ Lỗi: ${e.toString().substring(0, 50)}...');
      }
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

  // Public để ViewModel gọi được
  static ({double p, int totalSlots}) calculatePStats(
      List<LotteryResult> results,
      {String? fixedMien}) {
    // 1. Tính tổng slots thực tế từ dữ liệu (để dùng cho việc tính kExpected sau này)
    int totalSlots = 0;
    if (results.isNotEmpty) {
      for (final r in results) {
        totalSlots += r.numbers.length;
      }
    }

    // 2. Tính P (Xác suất xuất hiện trong 1 ngày)
    double pValue = 0.0;

    if (fixedMien != null) {
      // 👉 HARDCODE THEO YÊU CẦU
      switch (fixedMien.toLowerCase()) {
        case 'tatca':
        case 'tất cả':
          // p tất cả là 1 - pow(0.99, 891/7)
          pValue = 1 - pow(0.99, 891.0 / 7.0).toDouble();
          break;
        case 'trung':
          // p trung là 1 - pow(0.99, 306/7)
          pValue = 1 - pow(0.99, 306.0 / 7.0).toDouble();
          break;
        case 'bắc':
        case 'bac':
          // p bắc là 1 - pow(0.99, 27)
          pValue = 1 - pow(0.99, 27).toDouble();
          break;
        default:
          // Fallback nếu không khớp key (tính toán động)
          final uniqueDates = results.map((r) => r.ngay).toSet().length;
          if (uniqueDates > 0) {
            pValue = (1 - pow(0.99, totalSlots / uniqueDates)).toDouble();
          }
      }
    } else {
      // Tính toán động như cũ nếu không có fixedMien
      final uniqueDates = results.map((r) => r.ngay).toSet().length;
      if (uniqueDates > 0) {
        pValue = (1 - pow(0.99, totalSlots / uniqueDates)).toDouble();
      }
    }

    return (p: pValue, totalSlots: totalSlots);
  }

  static double _calculateP1(double p, double gan) =>
      (p >= 1 || p <= 0) ? 0.0 : pow(1 - p, gan).toDouble();

  // ✅ SỬA LOGIC: Trả về Map<String, dynamic> và thêm 'lastDate'
  static Map<String, dynamic>? _getNumberStats(
      List<LotteryResult> results, String targetNumber) {
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

    // Tìm lần cuối xuất hiện
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

    // ✅ THAY ĐỔI: Đếm slots thay vì ngày
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

    // Tìm lần xuất hiện thứ 2 từ cuối
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

    // ✅ Tìm lần xuất hiện thứ 3 từ cuối
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

    print('🔍 [DEBUG Stats] Số $targetNumber:');
    print('   Current gan (slots): $currentGanSlots');
    print('   Last cycle gan (slots): $lastCycleGanSlots');
    print('   Third cycle gan (slots): $thirdCycleGanSlots');
    print('   Slots xuất hiện: $slots');
    print('   Số lần xuất hiện: $occurrences');

    return {
      'currentGan': currentGanSlots.toDouble(), // ✅ Giờ là slots
      'lastCycleGan': lastCycleGanSlots.toDouble(), // ✅ Giờ là slots
      'thirdCycleGan': thirdCycleGanSlots.toDouble(), // ✅ Giờ là slots
      'occurrences': occurrences.toDouble(),
      'totalDays': uniqueDays.toDouble(),
      'slots': slots.toDouble(),
      'lastDate': lastSeenDate,
    };
  }

  static DateTime? _getCompletionDate(List<LotteryResult> results) {
    if (results.isEmpty) return null;
    DateTime? latest;
    for (final r in results) {
      final d = date_utils.DateUtils.parseDate(r.ngay);
      if (d != null && (latest == null || d.isAfter(latest))) latest = d;
    }
    return latest;
  }

  Future<GanPairInfo?> findGanPairsMienBac(
      List<LotteryResult> allResults) async {
    final key = 'ganpair_${allResults.length}';
    if (_ganPairCache.containsKey(key)) return _ganPairCache[key];
    final res = await compute(_findGanPairsMienBacCompute, allResults);
    if (res != null) _ganPairCache[key] = res;
    return res;
  }

  static GanPairInfo? _findGanPairsMienBacCompute(
      List<LotteryResult> allResults) {
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

    // Tái sử dụng logic lấy thống kê chi tiết (Gan, Slots, History...)
    final stats = _getNumberStats(results, targetNumber);
    if (stats == null) return null;

    // Tính kExpected toàn cục
    final pStats = calculatePStats(results);
    final double kExpected = pStats.totalSlots / 100.0;

    return CycleAnalysisResult(
      targetNumber: targetNumber,
      ganNumbers: {targetNumber}, // Chỉ hiển thị số này
      maxGanDays: (stats['currentGan'] as double).toInt(),
      lastSeenDate: stats['lastDate'] as DateTime,
      mienGroups: {}, // Không cần thiết cho view chi tiết 1 số
      // Mapping đầy đủ chỉ số thống kê
      historicalGan: (stats['lastCycleGan'] as double).toInt(),
      occurrenceCount: (stats['slots'] as double).toInt(),
      expectedCount: kExpected,
      analysisDays: (stats['totalDays'] as double).toInt(),
    );
  }

  Future<CycleAnalysisResult?> analyzeCycle(
      List<LotteryResult> allResults) async {
    final key = 'cycle_${allResults.length}';
    if (_cycleCache.containsKey(key)) return _cycleCache[key];

    final res = await compute(_analyzeCycleCompute, allResults);

    if (res != null) _cycleCache[key] = res;
    return res;
  }

  static CycleAnalysisResult? _analyzeCycleCompute(
      List<LotteryResult> allResults) {
    if (allResults.isEmpty) return null;
    final lastSeenMap = <String, Map<String, dynamic>>{};

    // 1. Logic tìm số có ngày gan hiện tại lớn nhất (Giữ nguyên)
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

    // -------------------------------------------------------------------------
    // 🔥 SỬA ĐỔI QUAN TRỌNG: Dùng chính logic tính P để lấy chỉ số thống kê
    // -------------------------------------------------------------------------

    // 1. Tính toán P Stats toàn cục để lấy tổng Slots thực tế
    // (Giống hệt cách calculatePStats đang làm)
    final pStats = calculatePStats(allResults);
    final double kExpected = pStats.totalSlots / 100.0;

    // 2. Gọi hàm _getNumberStats để lấy dữ liệu chi tiết của số mục tiêu
    // Hàm này chính là hàm cung cấp tham số cho việc tính P1, P2, P3
    final stats = _getNumberStats(allResults, targetNumber);

    int historicalGan = 0; // Đây sẽ là lastCycleGan (Gan của chu kỳ trước)
    int occurrenceCount = 0; // slots
    int analysisDays = 0;

    if (stats != null) {
      // Mapping dữ liệu từ stats sang model
      historicalGan = (stats['lastCycleGan'] as double).toInt();
      occurrenceCount = (stats['slots'] as double).toInt();
      analysisDays = (stats['totalDays'] as double).toInt();
    }

    // -------------------------------------------------------------------------

    return CycleAnalysisResult(
      ganNumbers: longestGroup.map((s) => s['so'] as String).toSet(),
      maxGanDays: maxGan,
      lastSeenDate: longestGroup.first['last_seen'],
      mienGroups: mienGroups,
      targetNumber: targetNumber,
      // Pass các giá trị đã đồng bộ vào
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

  static int _countSlotsSinceLastSeen(
    List<LotteryResult> allResults,
    DateTime lastSeenDate,
    String lastSeenMien,
    DateTime completionDate, {
    bool excludeLastSeen = true,
  }) {
    // Tìm index của lần cuối xuất hiện
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

    // Đếm số lượt xổ từ sau vị trí đó đến completionDate
    int slotCount = 0;
    final startIndex = excludeLastSeen ? lastSeenIndex + 1 : lastSeenIndex;

    for (int i = startIndex; i < allResults.length; i++) {
      final result = allResults[i];
      final date = date_utils.DateUtils.parseDate(result.ngay);

      if (date != null &&
          (date.isBefore(completionDate) ||
              date.isAtSameMomentAs(completionDate))) {
        slotCount++;
      }
    }

    return slotCount;
  }

  // Hàm đếm slots giữa 2 mốc thời gian
  static int _countSlotsBetween(
    List<LotteryResult> allResults,
    DateTime startDate,
    String startMien,
    DateTime endDate,
    String endMien, {
    bool excludeStart = true,
    bool excludeEnd = false,
  }) {
    // Tìm index của startDate + startMien
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

    // Tìm index của endDate + endMien (hoặc cuối cùng nếu không tìm thấy)
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

    // Đếm số lượt giữa startIndex và endIndex
    final actualStartIndex = excludeStart ? startIndex + 1 : startIndex;
    final actualEndIndex = excludeEnd ? endIndex - 1 : endIndex;

    if (actualStartIndex > actualEndIndex) return 0;

    return actualEndIndex - actualStartIndex + 1;
  }
}
