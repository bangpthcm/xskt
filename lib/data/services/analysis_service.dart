// lib/data/services/analysis_service.dart
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../core/utils/date_utils.dart' as date_utils;
import '../models/cycle_analysis_result.dart';
import '../models/gan_pair_info.dart';
import '../models/lottery_result.dart';
import '../models/number_detail.dart';
import '../services/betting_table_service.dart';

/// Model chứa kết quả phân tích theo chuẩn Logarithm và Cumulative
class NumberAnalysisData {
  final String number;
  final double lnP1;
  final double lnP2;
  final double lnP3;
  final double lnP4;
  final double lnPTotal; // ln(P_TOTAL)
  final double currentGan; // Gap thực tế (x)
  final double lastCycleGan; // Gap quá khứ (y)
  final DateTime lastSeenDate;
  final int totalSlotsActual; // Tổng slots thực tế sau khi trim
  final double cntReal; // Số nháy thực tế
  final double cntTheory; // Số nháy lý thuyết

  NumberAnalysisData({
    required this.number,
    required this.lnP1,
    required this.lnP2,
    required this.lnP3,
    required this.lnP4,
    required this.lnPTotal,
    required this.currentGan,
    required this.lastCycleGan,
    required this.lastSeenDate,
    required this.totalSlotsActual,
    required this.cntReal,
    required this.cntTheory,
  });

  @override
  String toString() {
    return 'NumberAnalysisData('
        'number: $number, '
        'lnPTotal: ${lnPTotal.toStringAsFixed(4)}, '
        'currentGan: $currentGan)';
  }
}

class PairAnalysisData {
  final String firstNumber;
  final String secondNumber;
  final double lnP1Pair;
  final double lnPTotalXien;
  final double daysSinceLastSeen;
  final DateTime lastSeenDate;

  PairAnalysisData({
    required this.firstNumber,
    required this.secondNumber,
    required this.lnP1Pair,
    required this.lnPTotalXien,
    required this.daysSinceLastSeen,
    required this.lastSeenDate,
  });

  String get pairDisplay => '$firstNumber-$secondNumber';

  @override
  String toString() {
    return 'PairAnalysisData('
        'pair: $pairDisplay, '
        'lnPTotal: ${lnPTotalXien.toStringAsFixed(4)})';
  }
}

class AnalysisService {
  final Map<String, GanPairInfo> _ganPairCache = {};
  final Map<String, CycleAnalysisResult> _cycleCache = {};

  // --- HẰNG SỐ CẤU HÌNH ---
  static const double WINDOW_FREQ_SLOTS = 11816.0;

  static const double P_INDIV = 0.01;
  static final double LN_P_INDIV = log(P_INDIV);
  static final double LN_BASE = log(max(1.0 - P_INDIV, 1e-12));

  // --- CẤU HÌNH TRỌNG SỐ (WEIGHTS) ĐỘNG ---
  static ({double w1, double w2, double w3}) _getWeights(String mienScope) {
    final s = mienScope.toLowerCase();

    // 1. Nam
    if (s.contains('nam')) {
      return (w1: 2.555092079, w2: 2.293394751, w3: 2.214243472);
    }
    // 2. Trung
    if (s.contains('trung')) {
      return (w1: 2.409136838, w2: 2.413419441, w3: 2.20958825);
    }
    // 3. Bắc
    if (s.contains('bắc') || s.contains('bac')) {
      return (w1: 1.22222222, w2: 1.21666789, w3: 1.2054321);
    }

    // ✅ 4. XIÊN - TRỌNG SỐ RIÊNG
    if (s.contains('xien') || s.contains('xiên')) {
      return (w1: 9.42822302, w2: 2.71988714, w3: 4.10588736);
    }

    // 5. Mặc định (Tất cả / Cycle)
    return (w1: 11.02681365, w2: 10.88648246, w3: 2.182246245);
  }

  // ---------------------------------------------------------------------------
  // Helpers: Slot counting with "shifted boundary" logic (Nam -> Trung -> Bắc)
  // ---------------------------------------------------------------------------

  static int? _nextIndex(int i, int len) => (i + 1 < len) ? (i + 1) : null;
  static int? _prevIndex(int i) => (i - 1 >= 0) ? (i - 1) : null;

  static int? _startIndexAfterHit(int hitIdx, int len) =>
      _nextIndex(hitIdx, len);
  static int? _endIndexBeforeHit(int hitIdx) => _prevIndex(hitIdx);

  // Slots = cum[end] - cum[start-1]
  static int _slotsBetween(List<int> cumList, int? startIdx, int? endIdx) {
    if (cumList.isEmpty) return 0;
    if (startIdx == null || endIdx == null) return 0;
    if (startIdx > endIdx) return 0;

    final beforeStart = (startIdx > 0) ? cumList[startIdx - 1] : 0;
    return cumList[endIdx] - beforeStart;
  }

  static ({int x, int y, int z}) _computeXYZShifted(
    List<int> hitIndices,
    List<int> cumList,
  ) {
    if (cumList.isEmpty) return (x: 0, y: 0, z: 0);

    final len = cumList.length;
    final totalSlots = cumList.last;

    if (hitIndices.isEmpty) {
      // Không nổ trong window
      return (x: totalSlots, y: 0, z: 0);
    }

    // x: từ sau hit cuối -> hết window
    final last = hitIndices.last;
    final xStart = _startIndexAfterHit(last, len);
    final x = _slotsBetween(cumList, xStart, len - 1);

    // y: giữa hit gần nhất và hit trước đó (dịch mốc)
    int y = 0;
    if (hitIndices.length >= 2) {
      final prev = hitIndices[hitIndices.length - 2];
      final yStart = _startIndexAfterHit(prev, len);
      final yEnd = _endIndexBeforeHit(last);
      y = _slotsBetween(cumList, yStart, yEnd);
    }

    // z: giữa hit thứ 3 gần nhất và hit thứ 2 gần nhất (dịch mốc)
    int z = 0;
    if (hitIndices.length >= 3) {
      final prev2 = hitIndices[hitIndices.length - 3];
      final prev = hitIndices[hitIndices.length - 2];
      final zStart = _startIndexAfterHit(prev2, len);
      final zEnd = _endIndexBeforeHit(prev);
      z = _slotsBetween(cumList, zStart, zEnd);
    }

    return (x: x, y: y, z: z);
  }

  // --- SORTING HELPERS ---
  static int _getRegionPriority(String mien) {
    final s = mien.toLowerCase();
    if (s.contains('nam')) return 1;
    if (s.contains('trung')) return 2;
    if (s.contains('bắc') || s.contains('bac')) return 3;
    return 9;
  }

  static int _compareSessions(LotteryResult a, LotteryResult b) {
    // 1. So sánh ngày
    final dateA = date_utils.DateUtils.parseDate(a.ngay) ?? DateTime(1970);
    final dateB = date_utils.DateUtils.parseDate(b.ngay) ?? DateTime(1970);
    int dateComp = dateA.compareTo(dateB);
    if (dateComp != 0) return dateComp;

    // 2. So sánh ưu tiên miền (Nam -> Trung -> Bắc)
    return _getRegionPriority(a.mien).compareTo(_getRegionPriority(b.mien));
  }

  static List<LotteryResult> _mergeToDailyRegionSessions(
      List<LotteryResult> input) {
    final Map<String, LotteryResult> merged = {};

    for (final r in input) {
      final date = date_utils.DateUtils.parseDate(r.ngay);
      if (date == null) continue;
      final dateKey = DateTime(date.year, date.month, date.day);
      final prio = _getRegionPriority(r.mien);
      final key = '${dateKey.toIso8601String()}|$prio';

      if (!merged.containsKey(key)) {
        merged[key] = LotteryResult(
          ngay: r.ngay,
          mien: r.mien,
          tinh: r.tinh,
          numbers: <String>[...r.numbers],
        );
      } else {
        merged[key]!.numbers.addAll(r.numbers);
      }
    }

    final sessions = merged.values.toList();
    sessions.sort(_compareSessions);
    return sessions;
  }

  // --- MAIN LOGIC: TÌM SỐ VỚI MIN LOG P ---
  static Future<NumberAnalysisData?> findNumberWithMinPTotal(
    List<LotteryResult> results,
    String mien,
    double lnThreshold,
  ) async {
    return await compute(_findNumberWithMinPTotalCompute, {
      'results': results,
      'mien': mien,
      'lnThreshold': lnThreshold,
    });
  }

  static NumberAnalysisData? _findNumberWithMinPTotalCompute(
    Map<String, dynamic> params,
  ) {
    var rawResults = params['results'] as List<LotteryResult>;
    final mienScope = params['mien'] as String;

    try {
      // 0. Lấy trọng số (Weights)
      final weights = _getWeights(mienScope);
      final w1 = weights.w1;
      final w2 = weights.w2;
      final w3 = weights.w3;

      // 1. Filter Scope (Lọc miền)
      List<LotteryResult> scopedResults;
      if (mienScope.toLowerCase().contains('tất cả') ||
          mienScope == 'tatca' ||
          mienScope == 'ALL' ||
          mienScope == 'Tất cả') {
        scopedResults = List.from(rawResults);
      } else {
        scopedResults =
            rawResults.where((r) => r.mien.contains(mienScope)).toList();
      }

      // 2. Sort & Merge Sessions
      scopedResults = _mergeToDailyRegionSessions(scopedResults);

      if (scopedResults.isEmpty) return null;

      // 3. Trim (Cắt dữ liệu)
      int accumulated = 0;
      int cutIndex = 0;
      for (int i = scopedResults.length - 1; i >= 0; i--) {
        accumulated += scopedResults[i].numbers.length;
        if (accumulated >= WINDOW_FREQ_SLOTS.toInt()) {
          cutIndex = i;
          break;
        }
      }

      final finalSessions = scopedResults.sublist(cutIndex);

      // 4. Build Cumulative List
      List<int> cumList = [];
      int runningSum = 0;
      for (var session in finalSessions) {
        runningSum += session.numbers.length;
        cumList.add(runningSum);
      }
      final int totalSlotsActual = runningSum;

      final allAnalysis = <NumberAnalysisData>[];

      // 5. Tính toán cho từng số (00-99)
      for (int i = 0; i <= 99; i++) {
        final number = i.toString().padLeft(2, '0');

        List<int> hitIndices = [];
        int cntRealInt = 0;

        for (int sIdx = 0; sIdx < finalSessions.length; sIdx++) {
          int countInSession =
              finalSessions[sIdx].numbers.where((n) => n == number).length;
          if (countInSession > 0) {
            hitIndices.add(sIdx);
            cntRealInt += countInSession;
          }
        }

        // --- TÍNH TOÁN METRICS (Gap x, y, z) ---
        final xyz = _computeXYZShifted(hitIndices, cumList);
        final double x = xyz.x.toDouble();
        final double y = xyz.y.toDouble();
        final double z = xyz.z.toDouble();

        // --- TÍNH P1, P2, P3 ---
        final lnP1 = x * LN_BASE;
        final lnP2 = y * LN_BASE;
        final lnP3 = z * LN_BASE;

        const double lnP4 = 0.0;
        final double cntReal = cntRealInt.toDouble();
        const double cntTheory = 0.0; // Placeholder

        // --- TÍNH P_TOTAL (Log) VỚI TRỌNG SỐ ĐỘNG ---
        final lnPTotal =
            (2.0 * LN_P_INDIV) + (w1 * lnP1) + (w2 * lnP2) + (w3 * lnP3);

        allAnalysis.add(NumberAnalysisData(
          number: number,
          lnP1: lnP1,
          lnP2: lnP2,
          lnP3: lnP3,
          lnP4: lnP4,
          lnPTotal: lnPTotal,
          currentGan: x,
          lastCycleGan: y,
          lastSeenDate: finalSessions.isNotEmpty
              ? date_utils.DateUtils.parseDate(finalSessions.last.ngay) ??
                  DateTime.now()
              : DateTime.now(),
          totalSlotsActual: totalSlotsActual,
          cntReal: cntReal,
          cntTheory: cntTheory,
        ));
      }

      if (allAnalysis.isEmpty) return null;

      // Tìm min
      final minResult =
          allAnalysis.reduce((a, b) => a.lnPTotal < b.lnPTotal ? a : b);

      // --- DEBUG LOGGING ---
      print('\n🔍 [MIN LOG P] Scope: $mienScope');
      print('   ⚖️ Weights Applied: W1=$w1, W2=$w2, W3=$w3');
      print('   🎯 Số: ${minResult.number}');
      print(
          '   📊 Tổng Slots: ${minResult.totalSlotsActual} (Target: ${WINDOW_FREQ_SLOTS.toInt()})');
      print(
          '   🔹 P1 (Gan hiện tại): ${minResult.lnP1.toStringAsFixed(4)} | Slots: ${minResult.currentGan}');
      print(
          '   🔹 P2 (Gan quá khứ): ${minResult.lnP2.toStringAsFixed(4)} | Slots: ${minResult.lastCycleGan}');
      print(
          '   🔹 P3 (Gan kìa):     ${minResult.lnP3.toStringAsFixed(4)} | Slots: ${minResult.lnP3 / LN_BASE}');
      print('   👉 LN_TOTAL: ${minResult.lnPTotal.toStringAsFixed(4)}');
      print('--------------------------------------------------\n');

      return minResult;
    } catch (e, stack) {
      print('❌ Error in findNumberWithMinPTotal: $e');
      print(stack);
      return null;
    }
  }

  // --- HÀM THỐNG KÊ CHI TIẾT (DÙNG CHO UI) ---
  static Map<String, dynamic>? _getNumberStats(
      List<LotteryResult> rawResults, String targetNumber) {
    var results =
        _mergeToDailyRegionSessions(List<LotteryResult>.from(rawResults));

    List<int> cumList = [];
    int runningSum = 0;
    List<int> hitIndices = [];
    int occurrences = 0;

    for (int i = 0; i < results.length; i++) {
      runningSum += results[i].numbers.length;
      cumList.add(runningSum);
      int count = results[i].numbers.where((n) => n == targetNumber).length;
      if (count > 0) {
        hitIndices.add(i);
        occurrences += count;
      }
    }

    if (hitIndices.isEmpty) return null;

    // ignore: unused_local_variable
    final int totalSlots = cumList.last;
    int lastIdx = hitIndices.last;

    final xyz = _computeXYZShifted(hitIndices, cumList);

    final double currentGan = xyz.x.toDouble();
    final double lastCycleGan = xyz.y.toDouble();
    final double thirdCycleGan = xyz.z.toDouble();

    final lastDate = date_utils.DateUtils.parseDate(results[lastIdx].ngay);
    final uniqueDays = results.map((r) => r.ngay).toSet().length;

    return {
      'currentGan': currentGan,
      'lastCycleGan': lastCycleGan,
      'thirdCycleGan': thirdCycleGan,
      'occurrences': occurrences.toDouble(),
      'totalDays': uniqueDays.toDouble(),
      'slots': occurrences.toDouble(),
      'lastDate': lastDate,
    };
  }

  // --- TÌM NGÀY KẾT THÚC (LOGARITHM SIMULATION) ---
  static Future<({DateTime endDate, int daysNeeded})?>
      findEndDateForCycleThreshold(NumberAnalysisData targetNumber,
          double pUnused, List<LotteryResult> results, double lnThreshold,
          {int maxIterations = 20000, String mien = 'Tất cả'}) async {
    return await compute(_findEndDateForCycleThresholdCompute, {
      'currentLnP1': targetNumber.lnP1,
      'currentLnP2': targetNumber.lnP2,
      'currentLnP3': targetNumber.lnP3,
      'currentLnP4': targetNumber.lnP4,
      'lnThreshold': lnThreshold,
      'maxIterations': maxIterations,
      'mien': mien,
    });
  }

  static ({DateTime endDate, int daysNeeded})?
      _findEndDateForCycleThresholdCompute(
    Map<String, dynamic> params,
  ) {
    var currentLnP1 = params['currentLnP1'] as double;
    final currentLnP2 = params['currentLnP2'] as double;
    final currentLnP3 = params['currentLnP3'] as double;
    final lnThreshold = params['lnThreshold'] as double;
    final maxIterations = params['maxIterations'] as int;
    final mienFilter = params['mien'] as String;

    try {
      // 0. Lấy trọng số
      final weights = _getWeights(mienFilter);
      final w1 = weights.w1;
      final w2 = weights.w2;
      final w3 = weights.w3;

      // 1. Tính P_Total hiện tại
      final currentLnPTotal = (2.0 * LN_P_INDIV) +
          (w1 * currentLnP1) +
          (w2 * currentLnP2) +
          (w3 * currentLnP3);

      if (currentLnPTotal < lnThreshold) {
        return (
          endDate: DateTime.now().add(const Duration(days: 1)),
          daysNeeded: 1
        );
      }

      // 2. Tính Delta cần giảm
      // addedSlots > (lnThreshold - currentLnPTotal) / (w1 * LN_BASE)
      final double denominator = w1 * LN_BASE;
      if (denominator == 0) return null;

      final double gapNeeded = lnThreshold - currentLnPTotal;
      final double slotsNeededDouble = gapNeeded / denominator;

      int addedSlots = slotsNeededDouble.ceil();

      if (addedSlots <= 0) addedSlots = 1;
      if (addedSlots > maxIterations) return null;

      final simulationResult = _mapSlotsToDateAndMien(
        slotsNeeded: addedSlots,
        startDate: DateTime.now(),
        mienFilter: mienFilter,
      );

      return (
        endDate: simulationResult.date,
        daysNeeded: simulationResult.daysFromStart
      );
    } catch (e) {
      return null;
    }
  }

  // --- PHÂN TÍCH XIÊN (LOG) ---
  static Future<PairAnalysisData?> findPairWithMinPTotal(
    List<LotteryResult> allResults,
  ) async {
    return await compute(_findPairWithMinPTotalCompute, allResults);
  }

  static PairAnalysisData? _findPairWithMinPTotalCompute(
    List<LotteryResult> allResults,
  ) {
    try {
      // ✅ BƯỚC 1: Lấy trọng số riêng cho Xiên
      final weights = _getWeights('xien');
      final w1 = weights.w1;
      final w2 = weights.w2;
      final w3 = weights.w3;

      print('\n🔍 [XIEN ANALYSIS] Using Xien-specific weights:');
      print('   W1=$w1, W2=$w2, W3=$w3');

      var bacResults = allResults.where((r) => r.mien == 'Bắc').toList();
      if (bacResults.isEmpty) return null;

      // Trim to last 368 days
      const int limit = 368;
      if (bacResults.length > limit) {
        bacResults = bacResults.sublist(bacResults.length - limit);
      }

      // ✅ BƯỚC 2: Build cumulative slots list (giống Cycle)
      List<int> cumList = [];
      int runningSum = 0;
      for (var result in bacResults) {
        runningSum += result.numbers.length;
        cumList.add(runningSum);
      }

      final totalSlots = cumList.isEmpty ? 0 : cumList.last;
      print('   📊 Total slots in window: $totalSlots');

      // ✅ BƯỚC 3: Track hit indices cho từng cặp số
      final pairHitIndices = <String, List<int>>{};
      final pairLastSeen = <String, DateTime>{};

      for (int idx = 0; idx < bacResults.length; idx++) {
        final result = bacResults[idx];
        final date = date_utils.DateUtils.parseDate(result.ngay);
        if (date == null) continue;

        final nums = result.numbers.toList()..sort();
        if (nums.length < 2) continue;

        // Generate all pairs in this session
        for (int i = 0; i < nums.length - 1; i++) {
          for (int j = i + 1; j < nums.length; j++) {
            final pairKey = '${nums[i]}-${nums[j]}';

            // Track hit index (only add if new or different from last)
            if (!pairHitIndices.containsKey(pairKey)) {
              pairHitIndices[pairKey] = [];
            }
            if (pairHitIndices[pairKey]!.isEmpty ||
                pairHitIndices[pairKey]!.last != idx) {
              pairHitIndices[pairKey]!.add(idx);
            }

            // Track last seen date
            if (!pairLastSeen.containsKey(pairKey) ||
                date.isAfter(pairLastSeen[pairKey]!)) {
              pairLastSeen[pairKey] = date;
            }
          }
        }
      }

      if (pairLastSeen.isEmpty) return null;

      final now = DateTime.now();
      final allPairAnalysis = <PairAnalysisData>[];

      print('   🔢 Analyzing ${pairLastSeen.length} unique pairs...');

      // ✅ BƯỚC 4: Tính toán cho từng cặp số
      for (final pairKey in pairLastSeen.keys) {
        final lastSeenDate = pairLastSeen[pairKey]!;
        final hitIndices = pairHitIndices[pairKey] ?? [];

        if (hitIndices.isEmpty) continue;

        // ✅ Calculate x, y, z using shifted boundary logic (GIỐNG CYCLE)
        final xyz = _computeXYZShifted(hitIndices, cumList);
        final double x = xyz.x.toDouble();
        final double y = xyz.y.toDouble();
        final double z = xyz.z.toDouble();

        // ✅ Calculate ln probabilities
        final lnP1 = x * LN_BASE;
        final lnP2 = y * LN_BASE;
        final lnP3 = z * LN_BASE;

        // ✅ Calculate P_total with Xien-specific weights
        final lnPTotalXien =
            (2.0 * LN_P_INDIV) + (w1 * lnP1) + (w2 * lnP2) + (w3 * lnP3);

        final parts = pairKey.split('-');
        allPairAnalysis.add(PairAnalysisData(
          firstNumber: parts[0],
          secondNumber: parts[1],
          lnP1Pair: lnP1,
          lnPTotalXien: lnPTotalXien,
          daysSinceLastSeen: now.difference(lastSeenDate).inDays.toDouble(),
          lastSeenDate: lastSeenDate,
        ));
      }

      if (allPairAnalysis.isEmpty) return null;

      // ✅ BƯỚC 5: Tìm cặp có P_total nhỏ nhất
      final minResult = allPairAnalysis
          .reduce((a, b) => a.lnPTotalXien < b.lnPTotalXien ? a : b);

      // ✅ DEBUG LOGGING
      print('\n🎯 [XIEN MIN P_TOTAL RESULT]');
      print('   Cặp số: ${minResult.pairDisplay}');
      print('   🔹 P1 (Current gap): ${minResult.lnP1Pair.toStringAsFixed(4)}');
      print('   🔹 LN_TOTAL: ${minResult.lnPTotalXien.toStringAsFixed(4)}');
      print('   Days since last: ${minResult.daysSinceLastSeen.toInt()} days');
      print('--------------------------------------------------\n');

      return minResult;
    } catch (e, stack) {
      print('❌ Error in _findPairWithMinPTotalCompute: $e');
      print(stack);
      return null;
    }
  }

  // --- CÁC HÀM HELPER & KHÔI PHỤC ---

  static double estimatePairProbability(int totalUniquePairs, int totalDays) {
    return 0.055;
  }

  static ({DateTime date, String endMien, int daysFromStart})
      _mapSlotsToDateAndMien({
    required int slotsNeeded,
    required DateTime startDate,
    required String mienFilter,
  }) {
    DateTime currentDate = startDate;
    int slotsRemaining = slotsNeeded;
    int daysCount = 0;
    int safetyLoop = 0;
    const int maxLookAheadDays = 365;

    while (slotsRemaining > 0 && safetyLoop < maxLookAheadDays) {
      safetyLoop++;
      currentDate = currentDate.add(const Duration(days: 1));
      daysCount++;
      final schedule = _getLotterySchedule(currentDate, mienFilter);
      if (schedule.isEmpty) continue;

      for (final mien in schedule) {
        final slotsInMien = _getSlotsForMien(mien, currentDate);
        if (slotsRemaining <= slotsInMien) {
          return (date: currentDate, endMien: mien, daysFromStart: daysCount);
        } else {
          slotsRemaining -= slotsInMien;
        }
      }
    }
    return (date: currentDate, endMien: 'Unknown', daysFromStart: daysCount);
  }

  static List<String> _getLotterySchedule(DateTime date, String filter) {
    final list = <String>[];
    final f = filter.toLowerCase().trim();
    bool isBac = f.contains('bắc') || f.contains('bac');
    bool isTrung = f.contains('trung');
    bool isNam = f.contains('nam');
    bool isAll =
        f.contains('tất cả') || f.contains('tatca') || f.isEmpty || f == 'all';
    if (!isBac && !isTrung && !isNam && !isAll) isAll = true;

    if (isAll || isNam) list.add('Nam');
    if (isAll || isTrung) list.add('Trung');
    if (isAll || isBac) list.add('Bắc');
    return list;
  }

  static int _getSlotsForMien(String mien, DateTime date) {
    final weekday = date.weekday;
    switch (mien) {
      case 'Trung':
        if (weekday == DateTime.thursday ||
            weekday == DateTime.saturday ||
            weekday == DateTime.sunday) {
          return 54;
        }
        return 36;
      case 'Nam':
        if (weekday == DateTime.saturday) return 72;
        if (weekday == DateTime.tuesday) return 36;
        return 54;
      default:
        return 27;
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
    DateTime currentStart = baseStartDate;
    int attempt = 0;

    final mienLower = mien.toLowerCase();
    final isNam = mienLower.contains('nam');
    final isTrung = mienLower.contains('trung');
    final isBac = mienLower.contains('bắc') || mienLower.contains('bac');

    while (attempt < maxDaysToTry && currentStart.isBefore(endDate)) {
      await Future.delayed(Duration.zero);
      final durationLimit = endDate.difference(currentStart).inDays;

      if (durationLimit <= 0) {
        currentStart = currentStart.add(const Duration(days: 1));
        attempt++;
        continue;
      }

      double totalCost = 0;
      try {
        if (isNam) {
          final table = await bettingService.generateNamGanTable(
            cycleResult: cycleResult,
            startDate: currentStart,
            endDate: endDate,
            budgetMin: availableBudget * 0.8,
            budgetMax: availableBudget,
            durationLimit: durationLimit,
          );
          if (table.isNotEmpty) totalCost = table.last.tongTien;
        } else if (isTrung) {
          final table = await bettingService.generateTrungGanTable(
            cycleResult: cycleResult,
            startDate: currentStart,
            endDate: endDate,
            budgetMin: availableBudget * 0.8,
            budgetMax: availableBudget,
            durationLimit: durationLimit,
          );
          if (table.isNotEmpty) totalCost = table.last.tongTien;
        } else if (isBac) {
          final table = await bettingService.generateBacGanTable(
            cycleResult: cycleResult,
            startDate: currentStart,
            endDate: endDate,
            budgetMin: availableBudget * 0.8,
            budgetMax: availableBudget,
            durationLimit: durationLimit,
          );
          if (table.isNotEmpty) totalCost = table.last.tongTien;
        } else {
          final table = await bettingService.generateCycleTable(
            cycleResult: cycleResult,
            startDate: currentStart,
            endDate: endDate,
            startMienIndex: _getMienIndex(mien),
            budgetMin: availableBudget * 0.8,
            budgetMax: availableBudget,
            allResults: allResults,
            maxMienCount: maxMienCount,
            durationLimit: durationLimit,
          );
          if (table.isNotEmpty) totalCost = table.last.tongTien;
        }

        if (totalCost > 0 && totalCost <= availableBudget) {
          return currentStart;
        }
      } catch (e) {
        // Log error if needed
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
    DateTime currentStart = baseStartDate;
    int attempt = 0;
    while (attempt < maxDaysToTry && currentStart.isBefore(endDate)) {
      try {
        final actualBettingDays = endDate.difference(currentStart).inDays;
        if (actualBettingDays <= 1) break;
        final table = await bettingService.generateXienTable(
          ganInfo: ganInfo,
          startDate: currentStart,
          xienBudget: availableBudget,
          endDate: endDate,
          fitBudgetOnly: true,
        );
        if (table.isNotEmpty) {
          final totalCost = table.last.tongTien;
          if (totalCost <= availableBudget) return currentStart;
        }
      } catch (e) {}
      currentStart = currentStart.add(const Duration(days: 1));
      attempt++;
    }
    return null;
  }

  static ({double p, int totalSlots}) calculatePStats(
      List<LotteryResult> results,
      {String? fixedMien}) {
    int totalSlots = 0;
    if (results.isNotEmpty) {
      for (final r in results) {
        totalSlots += r.numbers.length;
      }
    }
    return (p: 0.01, totalSlots: totalSlots);
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
    final stats = _getNumberStats(results, targetNumber);
    if (stats == null) return null;
    final pStats = calculatePStats(results);
    final double kExpected = pStats.totalSlots / 100.0;
    return CycleAnalysisResult(
      targetNumber: targetNumber,
      ganNumbers: {targetNumber},
      maxGanDays: (stats['currentGan'] as double).toInt(),
      lastSeenDate: stats['lastDate'] as DateTime,
      mienGroups: {},
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

  static DateTime? _getCompletionDate(List<LotteryResult> results) {
    if (results.isEmpty) return null;
    DateTime? latest;
    for (final r in results) {
      final d = date_utils.DateUtils.parseDate(r.ngay);
      if (d != null && (latest == null || d.isAfter(latest))) latest = d;
    }
    return latest;
  }

  static Future<({DateTime endDate, int daysNeeded})?>
      findEndDateForXienThreshold(
    PairAnalysisData targetPair,
    double pUnused, // Deprecated, giữ lại để tương thích API
    double lnThreshold, {
    int maxIterations = 10000,
  }) async {
    return await compute(_findEndDateForXienThresholdCompute, {
      'currentLnP1': targetPair.lnP1Pair,
      'currentLnPTotal': targetPair.lnPTotalXien, // ✅ Pass full P_total
      'lnThreshold': lnThreshold,
      'maxIterations': maxIterations,
    });
  }

  static ({DateTime endDate, int daysNeeded})?
      _findEndDateForXienThresholdCompute(
    Map<String, dynamic> params,
  ) {
    // ✅ Lấy trọng số Xiên
    final weights = _getWeights('xien');
    final w1 = weights.w1;

    final currentLnP1 = params['currentLnP1'] as double?;
    final currentLnPTotal =
        params['currentLnPTotal'] as double?; // ✅ Sử dụng P_total đã tính
    final lnThreshold = params['lnThreshold'] as double;
    final maxIterations = params['maxIterations'] as int;

    try {
      // ✅ Sử dụng P_total đã được tính từ phân tích (bao gồm P1, P2, P3)
      final lnPTotal = currentLnPTotal ??
          ((currentLnP1 != null)
              ? ((2.0 * LN_P_INDIV) + (w1 * currentLnP1))
              : 0.0);

      print('\n🔍 [XIEN END DATE CALC]');
      print('   Current P_total: ${lnPTotal.toStringAsFixed(4)}');
      print('   Threshold: ${lnThreshold.toStringAsFixed(4)}');

      if (lnPTotal < lnThreshold) {
        print('   ✅ Already below threshold!');
        return (
          endDate: DateTime.now().add(const Duration(days: 1)),
          daysNeeded: 1
        );
      }

      // Tính slots cần thêm để đạt threshold
      final double denominator = w1 * LN_BASE;
      if (denominator == 0) return null;

      final double gapNeeded = lnThreshold - lnPTotal;
      final double slotsNeededDouble = gapNeeded / denominator;

      int addedSlots = slotsNeededDouble.ceil();
      if (addedSlots <= 0) addedSlots = 1;
      if (addedSlots > maxIterations) {
        print('   ⚠️ Exceeded max iterations');
        return null;
      }

      // Map slots to date (Bắc only, 27 slots/day)
      final daysNeeded = (addedSlots / 27).ceil();
      final endDate = DateTime.now().add(Duration(days: daysNeeded));

      print('   📅 Days needed: $daysNeeded');
      print('   🏁 End date: ${date_utils.DateUtils.formatDate(endDate)}');

      return (endDate: endDate, daysNeeded: daysNeeded);
    } catch (e) {
      print('   ❌ Error: $e');
      return null;
    }
  }

  // --- LẤY DỮ LIỆU PHÂN TÍCH CHO 1 SỐ CỤ THỂ (Dùng Weights) ---
  static Future<NumberAnalysisData?> getAnalysisData(
    String targetNumber,
    List<LotteryResult> results,
    String mien,
  ) async {
    return await compute(_getAnalysisDataCompute, {
      'number': targetNumber,
      'results': results,
      'mien': mien,
    });
  }

  static NumberAnalysisData? _getAnalysisDataCompute(
      Map<String, dynamic> params) {
    final targetNumber = params['number'] as String;
    var rawResults = params['results'] as List<LotteryResult>;
    final mienScope = params['mien'] as String;

    try {
      // 0. Lấy trọng số
      final weights = _getWeights(mienScope);
      final w1 = weights.w1;
      final w2 = weights.w2;
      final w3 = weights.w3;

      // 1. Filter & Merge
      List<LotteryResult> scopedResults;
      if (mienScope.toLowerCase().contains('tất cả') ||
          mienScope == 'tatca' ||
          mienScope == 'ALL') {
        scopedResults = List.from(rawResults);
      } else {
        scopedResults =
            rawResults.where((r) => r.mien.contains(mienScope)).toList();
      }
      scopedResults = _mergeToDailyRegionSessions(scopedResults);

      if (scopedResults.isEmpty) return null;

      // 2. Trim
      int accumulated = 0;
      int cutIndex = 0;
      for (int i = scopedResults.length - 1; i >= 0; i--) {
        accumulated += scopedResults[i].numbers.length;
        if (accumulated >= WINDOW_FREQ_SLOTS.toInt()) {
          cutIndex = i;
          break;
        }
      }
      final finalSessions = scopedResults.sublist(cutIndex);

      // 3. Calc Stats
      List<int> cumList = [];
      int runningSum = 0;
      for (var session in finalSessions) {
        runningSum += session.numbers.length;
        cumList.add(runningSum);
      }
      final int totalSlotsActual = runningSum;

      List<int> hitIndices = [];
      int cntRealInt = 0;
      for (int sIdx = 0; sIdx < finalSessions.length; sIdx++) {
        int countInSession =
            finalSessions[sIdx].numbers.where((n) => n == targetNumber).length;
        if (countInSession > 0) {
          hitIndices.add(sIdx);
          cntRealInt += countInSession;
        }
      }

      final xyz = _computeXYZShifted(hitIndices, cumList);
      final double x = xyz.x.toDouble();
      final double y = xyz.y.toDouble();
      final double z = xyz.z.toDouble();

      final lnP1 = x * LN_BASE;
      final lnP2 = y * LN_BASE;
      final lnP3 = z * LN_BASE;
      const double lnP4 = 0.0;

      // Áp dụng trọng số động
      final lnPTotal =
          (2.0 * LN_P_INDIV) + (w1 * lnP1) + (w2 * lnP2) + (w3 * lnP3);

      return NumberAnalysisData(
        number: targetNumber,
        lnP1: lnP1,
        lnP2: lnP2,
        lnP3: lnP3,
        lnP4: lnP4,
        lnPTotal: lnPTotal,
        currentGan: x,
        lastCycleGan: y,
        lastSeenDate: finalSessions.isNotEmpty
            ? date_utils.DateUtils.parseDate(finalSessions.last.ngay) ??
                DateTime.now()
            : DateTime.now(),
        totalSlotsActual: totalSlotsActual,
        cntReal: cntRealInt.toDouble(),
        cntTheory: 0.0,
      );
    } catch (e) {
      return null;
    }
  }
}
