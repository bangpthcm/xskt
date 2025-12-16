import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../core/utils/date_utils.dart' as date_utils;
import '../models/app_config.dart';
import '../models/cycle_analysis_result.dart';
import '../models/gan_pair_info.dart';
import '../models/lottery_result.dart';
import '../models/number_detail.dart';
import '../models/probability_config.dart';
import '../models/rebetting_candidate.dart';
import '../models/rebetting_summary.dart';
import 'betting_table_service.dart';

class AnalysisService {
  final Map<String, GanPairInfo> _ganPairCache = {};
  final Map<String, CycleAnalysisResult> _cycleCache = {};

  // =====================================================================
  // ⚡ PROBABILITY MODE METHODS
  // =====================================================================

  Future<ProbabilityAnalysisResult?> analyzeProbabilityMode(
    List<LotteryResult> allResults,
    String mien,
    double threshold,
  ) async {
    final filteredResults = (mien == 'Tất cả')
        ? allResults
        : allResults.where((r) => r.mien == mien).toList();

    if (filteredResults.isEmpty) return null;

    return await compute(_analyzeProbabilityCompute, {
      'results': filteredResults,
      'mien': mien,
      'threshold': threshold,
    });
  }

  static ProbabilityAnalysisResult? _analyzeProbabilityCompute(
      Map<String, dynamic> params) {
    var results = params['results'] as List<LotteryResult>;
    final mien = params['mien'] as String;
    final threshold = params['threshold'] as double;

    const int limit = 368;
    if (results.length > limit)
      results = results.sublist(results.length - limit);

    try {
      // 1. TÍNH P
      final pStats = _calculatePStats(results);
      final p = pStats.p;
      final kExpected = pStats.totalSlots / 100.0;

      if (p == 0) return null;

      final allProbabilities = <String, Map<String, double>>{};

      for (int i = 0; i <= 99; i++) {
        final number = i.toString().padLeft(2, '0');
        final stats = _getNumberStats(results, number);

        if (stats == null) continue;

        final currentGan = stats['currentGan']!;
        final lastCycleGan = stats['lastCycleGan']!;
        final slots = stats['slots']!;

        final p1 = _calculateP1(p, currentGan);
        final p2 = _calculateP2(p, lastCycleGan, currentGan);
        final p3 = (slots == 0) ? 0.000001 : (slots / kExpected);
        final pTotal = p1 * p2 * p3;

        allProbabilities[number] = {
          'p1': p1,
          'p2': p2,
          'p3': p3,
          'pTotal': pTotal,
          'currentGan': currentGan,
          'lastCycleGan': lastCycleGan,
        };
      }

      if (allProbabilities.isEmpty) return null;

      // 3. TÌM MIN P_TOTAL
      final bestEntry = allProbabilities.entries
          .reduce((a, b) => a.value['pTotal']! < b.value['pTotal']! ? a : b);

      final bestNumber = bestEntry.key;
      final bestData = bestEntry.value;
      final minProb = bestData['pTotal']!;

      // 4. SIMULATION
      int simulatedGanDays = bestData['currentGan']!.toInt();
      double simulatedPTotal = minProb;
      int daysNeeded = 0;
      const maxIterations = 10000;

      while (simulatedPTotal >= threshold && daysNeeded < maxIterations) {
        simulatedGanDays++;
        daysNeeded++;
        simulatedPTotal = _calculateP1(p, simulatedGanDays.toDouble()) *
            _calculateP2(
                p, bestData['lastCycleGan']!, simulatedGanDays.toDouble()) *
            bestData['p3']!;
      }

      final projectedEndDate = DateTime.now().add(Duration(days: daysNeeded));

      return ProbabilityAnalysisResult(
        targetNumber: bestNumber,
        currentProbability: minProb,
        currentGanDays: bestData['currentGan']!.toInt(),
        projectedEndDate: projectedEndDate,
        entryDate: projectedEndDate,
        additionalDaysNeeded: daysNeeded,
        probabilities: {
          'P1': bestData['p1']!,
          'P2': bestData['p2']!,
          'P3': bestData['p3']!,
          'P_total': minProb,
        },
        mien: mien,
      );
    } catch (e) {
      print('❌ [Probability] Error: $e');
      return null;
    }
  }

  // =====================================================================
  // 🔧 HELPER METHODS (Optimized)
  // =====================================================================

  static ({double p, int totalSlots}) _calculatePStats(
      List<LotteryResult> results) {
    if (results.isEmpty) return (p: 0.0, totalSlots: 0);
    final uniqueDates = <String>{};
    int totalSlots = 0;
    for (final r in results) {
      uniqueDates.add(r.ngay);
      totalSlots += r.numbers.length;
    }
    final totalDays = uniqueDates.length;
    if (totalDays == 0) return (p: 0.0, totalSlots: totalSlots);
    return (
      p: (1 - pow(0.99, totalSlots / totalDays)).toDouble(),
      totalSlots: totalSlots
    );
  }

  // Rút gọn hàm tính toán
  static double _calculateP1(double p, double gan) =>
      (p >= 1 || p <= 0) ? 0.0 : pow(1 - p, gan).toDouble();
  static double _calculateP2(double p, double lastGan, double curGan) =>
      (p >= 1 || p <= 0)
          ? 0.0
          : (pow(1 - p, lastGan) * p * pow(1 - p, curGan)).toDouble();

  // Optimized getNumberStats: Giảm bớt loop
  static Map<String, double>? _getNumberStats(
      List<LotteryResult> results, String targetNumber) {
    final completionDate = _getCompletionDate(results);
    if (completionDate == null) return null;

    int lastSeenIndex = -1;
    DateTime? lastSeenDate;
    String? lastSeenMien;
    int slots = 0;
    int occurrences = 0;

    // Duyệt 1 lần để tính slots và tìm lastSeen
    for (int i = 0; i < results.length; i++) {
      final count = results[i].numbers.where((n) => n == targetNumber).length;
      if (count > 0) {
        occurrences++;
        slots += count;
        // Cập nhật lastSeen (giả sử list sort theo thời gian tăng dần, nếu giảm dần thì logic ngược lại)
        // Dựa vào code cũ: loop ngược tìm lastSeen -> list input có vẻ theo thứ tự thời gian.
        // Tuy nhiên code cũ loop (results.length - 1 -> 0) để tìm lastSeen.
      }
    }

    // Tìm lastSeenIndex chính xác như code cũ (từ cuối về đầu)
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

    final currentGan = _countMienOccurrencesStatic(
        results, lastSeenDate, completionDate, lastSeenMien,
        excludeEndDate: false);

    int lastCycleGan = 0;
    DateTime? secondLastSeenDate;

    // Tìm áp chót
    for (int i = lastSeenIndex - 1; i >= 0; i--) {
      if (results[i].numbers.contains(targetNumber)) {
        secondLastSeenDate = date_utils.DateUtils.parseDate(results[i].ngay);
        if (secondLastSeenDate != null) break;
      }
    }

    if (secondLastSeenDate != null) {
      lastCycleGan = _countMienOccurrencesStatic(
          results, secondLastSeenDate, lastSeenDate, lastSeenMien,
          excludeEndDate: true);
    }

    // Đếm unique days
    final uniqueDays = results.map((r) => r.ngay).toSet().length;

    return {
      'currentGan': currentGan.toDouble(),
      'lastCycleGan': lastCycleGan.toDouble(),
      'occurrences': occurrences.toDouble(),
      'totalDays': uniqueDays.toDouble(),
      'slots': slots.toDouble(),
    };
  }

  // =======================================================================
  // ⚡ STATIC METHODS (Computation)
  // =======================================================================

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
    // Logic giữ nguyên, chỉ rút gọn cú pháp
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

    // Tối ưu loop
    for (final res in allResults) {
      final date = date_utils.DateUtils.parseDate(res.ngay);
      if (date == null) continue;

      for (final num in res.numbers) {
        final key = num.padLeft(2, '0');
        final current = lastSeenMap[key];

        // Logic ưu tiên ngày mới hơn hoặc cùng ngày nhưng ưu tiên Miền
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

    return CycleAnalysisResult(
      ganNumbers: longestGroup.map((s) => s['so'] as String).toSet(),
      maxGanDays: maxGan,
      lastSeenDate: longestGroup.first['last_seen'],
      mienGroups: mienGroups,
      targetNumber: longestGroup.first['so'],
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
    // Tối ưu: Kiểm tra String (Mien) TRƯỚC khi parse Date
    for (final result in allResults) {
      if (result.mien != targetMien) continue; // Skip sai miền ngay lập tức

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

  // =======================================================================
  // 🔍 REBETTING & INSTANCE METHODS
  // =======================================================================

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

  // ✅ OPTIMIZED CRITICAL FUNCTION
  static bool _hasNumberReappearedStatic(
      String targetNumber, DateTime sinceDate, List<LotteryResult> allResults,
      {String mien = ''}) {
    final normalizedTarget = targetNumber.padLeft(2, '0');
    final completionDate = _getCompletionDate(allResults);
    if (completionDate == null) return false;

    // Tối ưu: Kiểm tra điều kiện String (Mien, Number) TRƯỚC khi parse Date
    for (final result in allResults) {
      // 1. Check Miền (String compare - rẻ)
      if (mien.isNotEmpty && result.mien != mien) continue;

      // 2. Check Number (List contains - rẻ hơn Parse Date)
      // Check cả 2 format để chắc chắn
      if (!result.numbers.contains(normalizedTarget) &&
          !result.numbers.contains(targetNumber)) continue;

      // 3. Mới Parse Date (đắt nhất)
      final resultDate = date_utils.DateUtils.parseDate(result.ngay);
      if (resultDate == null) continue;

      // 4. Check Range
      if (resultDate.isAfter(sinceDate) &&
          (resultDate.isBefore(completionDate) ||
              resultDate.isAtSameMomentAs(completionDate))) {
        return true;
      }
    }
    return false;
  }

  Future<RebettingResult> calculateRebetting({
    required List<LotteryResult> allResults,
    required AppConfig config,
    required BettingTableService bettingService,
    // ❌ ĐÃ XÓA: Không cần truyền các list history cũ nữa
  }) async {
    print('🔄 Bắt đầu tính Rebetting (Quét 00-99 theo logic P2)...');

    // Sử dụng compute để không chặn UI khi quét số liệu lớn
    final result = await compute(_calculateRebettingCompute, {
      'allResults': allResults,
      'config': config,
    });

    return result;
  }

  /// Static method chạy trong Isolate
  static RebettingResult _calculateRebettingCompute(
      Map<String, dynamic> params) {
    final allResults = params['allResults'] as List<LotteryResult>;
    final config = params['config'] as AppConfig;

    // Helper function để xử lý từng miền
    Map<String, dynamic> processMien(
        String mienLabel, String mienFilter, int threshold) {
      final candidates = <RebettingCandidate>[];

      // Lọc dữ liệu theo miền (nếu không phải 'Tất cả')
      final mienResults = (mienFilter == 'Mixed')
          ? allResults
          : allResults.where((r) => r.mien == mienFilter).toList();

      if (mienResults.isEmpty) {
        return {'candidates': [], 'selected': null, 'total': 0};
      }

      // 🔄 VÒNG LẶP QUÉT 00-99
      for (int i = 0; i < 100; i++) {
        final number = i.toString().padLeft(2, '0');

        // 1. Lấy thống kê (Logic P2: Current Gan & Last Cycle Gan)
        // Lưu ý: Hàm _getNumberStats đã được tối ưu ở bước trước
        final stats = _getNumberStats(mienResults, number);

        if (stats == null) continue; // Số chưa từng xuất hiện -> Bỏ qua

        final currentGan = stats['currentGan'] as double; // Gan hiện tại
        final lastCycleGan =
            stats['lastCycleGan'] as double; // Gan cũ (chu kỳ trước)

        // Lấy ngày tháng để hiển thị (Cần cast về DateTime từ dynamic map nếu _getNumberStats trả về)
        // Để tối ưu, tôi sẽ trích xuất ngày trực tiếp từ _getNumberStats logic bên dưới hoặc gọi lại nhẹ nhàng.
        // Tuy nhiên, để clean, ta giả định _getNumberStats trả về đủ info.
        // NẾU _getNumberStats chỉ trả về double, ta cần sửa lại nó một chút hoặc tìm lại ngày ở đây.
        // 👇 ĐỂ GIỮ NGUYÊN STRUCUTRE CŨ, tôi sẽ tìm lại ngày nhanh nhất có thể:

        // (Logic tìm ngày last seen - cực nhanh vì đã filter số)
        DateTime? lastSeenDate;
        // DateTime? prevLastSeenDate; // Nếu cần ngày bắt đầu của gan cũ

        // Tìm lần xuất hiện cuối cùng
        for (final res in mienResults.reversed) {
          if (res.numbers.contains(number)) {
            lastSeenDate = date_utils.DateUtils.parseDate(res.ngay);
            break;
          }
        }

        if (lastSeenDate == null) continue;

        // 2. Tính toán Duration theo công thức cũ
        // rebettingDuration = (2.4 * threshold) - Gan Cũ
        final rebettingDuration = ((2.4 * threshold) - lastCycleGan).round();

        // 3. Filter theo điều kiện Duration
        if (rebettingDuration <= 0) continue;

        // 4. Tạo ứng viên
        candidates.add(RebettingCandidate(
          soMucTieu: number,
          mienTrung: mienLabel,
          // Các trường ngày tháng này mang tính tham khảo hiển thị
          ngayBatDauCu: '', // Không quan trọng với logic mới
          ngayTrungCu: date_utils.DateUtils.formatDate(
              lastSeenDate), // Ngày trúng cuối cùng
          soNgayGanCu: lastCycleGan.toInt(), // Gan của chu kỳ trước
          soNgayGanMoi: currentGan.toInt(), // Gan hiện tại
          rebettingDuration: rebettingDuration,
          ngayCoTheVao: '', // Sẽ tính sau
        ));
      }

      // Chọn số có duration nhỏ nhất (Ưu tiên Gan Cũ Lớn)
      RebettingCandidate? selected;
      if (candidates.isNotEmpty) {
        selected = candidates.reduce(
            (a, b) => a.rebettingDuration < b.rebettingDuration ? a : b);
      }

      return {
        'candidates': candidates,
        'selected': selected,
        'total': candidates.length,
      };
    }

    // Thực thi cho 4 loại cấu hình
    final tatCa =
        processMien('Tất cả', 'Mixed', config.duration.thresholdCycleDuration);
    final nam =
        processMien('Nam', 'Nam', config.duration.thresholdCycleDuration);
    final trung =
        processMien('Trung', 'Trung', config.duration.thresholdTrungDuration);
    final bac = processMien('Bắc', 'Bắc', config.duration.thresholdBacDuration);

    // Đóng gói kết quả
    final summaries = <String, RebettingSummary?>{
      'tatCa': tatCa['selected'] != null
          ? RebettingSummary(
              mien: 'Tất cả', ngayCoTheVao: '', totalCandidates: tatCa['total'])
          : null,
      'nam': nam['selected'] != null
          ? RebettingSummary(
              mien: 'Nam', ngayCoTheVao: '', totalCandidates: nam['total'])
          : null,
      'trung': trung['selected'] != null
          ? RebettingSummary(
              mien: 'Trung', ngayCoTheVao: '', totalCandidates: trung['total'])
          : null,
      'bac': bac['selected'] != null
          ? RebettingSummary(
              mien: 'Bắc', ngayCoTheVao: '', totalCandidates: bac['total'])
          : null,
    };

    final selected = <String, RebettingCandidate?>{
      'tatCa': tatCa['selected'],
      'nam': nam['selected'],
      'trung': trung['selected'],
      'bac': bac['selected'],
    };

    return RebettingResult(summaries: summaries, selected: selected);
  }
}
