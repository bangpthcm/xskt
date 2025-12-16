// lib/data/services/analysis_service.dart
import 'dart:math';

import 'package:flutter/foundation.dart'; // ✅ Import compute

import '../../core/utils/date_utils.dart' as date_utils;
import '../models/app_config.dart';
import '../models/cycle_analysis_result.dart';
import '../models/cycle_win_history.dart';
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
  // ⚡ PROBABILITY MODE METHODS (Chạy trong Isolate)
  // =====================================================================

  /// Phân tích Probability Mode (Public method)
  Future<ProbabilityAnalysisResult?> analyzeProbabilityMode(
    List<LotteryResult> allResults,
    String mien, // 'Tất cả', 'Trung', 'Bắc'
    double threshold,
  ) async {
    print('🔄 [Probability] Starting analysis for $mien...');

    // Filter results theo miền nếu cần
    final filteredResults = (mien == 'Tất cả')
        ? allResults
        : allResults.where((r) => r.mien == mien).toList();

    if (filteredResults.isEmpty) {
      print('❌ [Probability] No data for $mien');
      return null;
    }

    // ✅ Chạy trong Isolate để không đơ UI
    return await compute(_analyzeProbabilityCompute, {
      'results': filteredResults,
      'mien': mien,
      'threshold': threshold,
    });
  }

  /// Static method để chạy trong isolate
  static ProbabilityAnalysisResult? _analyzeProbabilityCompute(
    Map<String, dynamic> params,
  ) {
    var results = params['results'] as List<LotteryResult>;
    final mien = params['mien'] as String;
    final threshold = params['threshold'] as double;

    // ✂️ TỐI ƯU: Cắt 368 ngày mới nhất
    const int limit = 368;
    if (results.length > limit) {
      results = results.sublist(results.length - limit);
      print('✂️ [Optimization] Trimmed data to last $limit records.');
    }

    print(
        '\n🔢 [Probability] ========== START DEBUG (SHOW GAN + SLOTS) ==========');

    try {
      // 1. TÍNH P (Unique Date Logic)
      final p = _calculateAverageProbability(
          results); // Đã có log chi tiết bên trong hàm này

      // 2. TÍNH GLOBAL SLOTS & K_EXPECTED
      int totalSlotsAllData = 0;
      for (final r in results) {
        totalSlotsAllData += r.numbers.length;
      }

      final kExpected = totalSlotsAllData / 100.0;

      print('📊 [Global Stats]:');
      print('   Total Data Rows: ${results.length}');
      print('   Total Slots: $totalSlotsAllData');
      print('   K_expected: ${kExpected.toStringAsFixed(2)}');

      final allProbabilities = <String, Map<String, double>>{};
      double checkSumSlots = 0;

      for (int i = 0; i <= 99; i++) {
        final number = i.toString().padLeft(2, '0');
        final stats = _getNumberStats(results, number);

        if (stats == null) continue;

        final currentGan = stats['currentGan']!; // 👈 Đây là "Gan cũ" cậu cần
        final lastCycleGan = stats['lastCycleGan']!;
        final slots = stats['slots']!;

        checkSumSlots += slots;

        final p1 = _calculateP1(p, currentGan);
        final p2 = _calculateP2(p, lastCycleGan, currentGan);

        double p3;
        if (slots == 0) {
          p3 = 0.000001;
        } else {
          p3 = slots / kExpected;
        }

        final pTotal = p1 * p2 * p3;

        allProbabilities[number] = {
          'p1': p1,
          'p2': p2,
          'p3': p3,
          'pTotal': pTotal,
          'currentGan': currentGan,
          'lastCycleGan': lastCycleGan,
          'slots': slots,
        };

        // 🖨️ UPDATE: In thêm "Gan" vào log để kiểm tra
        if (i < 10 || slots > kExpected * 1.5) {
          print(
              '   🔹 Num $number: Gan=${currentGan.toInt()}d | Slots=${slots.toInt()} (Exp ~${kExpected.toStringAsFixed(1)}) -> P3=${p3.toStringAsFixed(4)}');
        }
      }

      // CHECK SUM
      print(
          '\n⚖️ [CROSS-CHECK]: Global=$totalSlotsAllData vs Sum=${checkSumSlots.toInt()}');

      if (allProbabilities.isEmpty) return null;

      // 3. TÌM MIN P_TOTAL
      String? bestNumber;
      double minProb = double.infinity;

      allProbabilities.forEach((number, data) {
        if (data['pTotal']! < minProb) {
          minProb = data['pTotal']!;
          bestNumber = number;
        }
      });

      if (bestNumber == null) return null;

      final bestData = allProbabilities[bestNumber!]!;

      print('\n🎯 [Result] Best Number: $bestNumber');
      print(
          '   Gan hien tai: ${bestData['currentGan']!.toInt()} ngay'); // In rõ ở kết quả cuối cùng
      print('   P_total: ${minProb.toStringAsExponential(6)}');

      // 4. SIMULATION
      int simulatedGanDays = bestData['currentGan']!.toInt();
      double simulatedPTotal = minProb;
      int daysNeeded = 0;
      const maxIterations = 10000;

      while (simulatedPTotal >= threshold && daysNeeded < maxIterations) {
        simulatedGanDays++;
        daysNeeded++;

        final newP1 = _calculateP1(p, simulatedGanDays.toDouble());
        final newP2 = _calculateP2(
            p, bestData['lastCycleGan']!, simulatedGanDays.toDouble());
        final currentP3 = bestData['p3']!;

        simulatedPTotal = newP1 * newP2 * currentP3;
      }

      final now = DateTime.now();
      final projectedEndDate = now.add(Duration(days: daysNeeded));

      return ProbabilityAnalysisResult(
        targetNumber: bestNumber!,
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
    } catch (e, stackTrace) {
      print('❌ [Probability] Error: $e');
      print(stackTrace);
      return null;
    }
  }

  // =====================================================================
  // 🔧 HELPER METHODS
  // =====================================================================

  /// Tính xác suất trung bình p = Tổng số giải / Tổng số ngày
  // ✅ UPDATE: In thêm Log chi tiết về mẫu số (Days) và tử số (Slots)
  static double _calculateAverageProbability(List<LotteryResult> results) {
    if (results.isEmpty) return 0.0;

    final uniqueDates = <String>{};
    int totalNumbers = 0;

    for (final result in results) {
      uniqueDates.add(result.ngay);
      totalNumbers += result.numbers.length;
    }

    final totalDays = uniqueDates.length; // Mẫu số chuẩn

    // 🖨️ PRINT DEBUG: Xem chính xác bao nhiêu ngày được dùng
    print('      📐 [P Calculation Info]');
    print('         - Input Rows: ${results.length}');
    print(
        '         - Unique Days (Denominator): $totalDays'); // 👈 Cái cậu cần đây
    print('         - Total Slots (Numerator): $totalNumbers');

    if (totalDays == 0) return 0.0;

    final avgNumbersPerDay = totalNumbers / totalDays;
    print('         - Avg Slots/Day: ${avgNumbersPerDay.toStringAsFixed(4)}');

    // Công thức tính xác suất nền
    return (1 - pow(0.99, avgNumbersPerDay)).toDouble();
  }

  /// Lấy thống kê của một số cụ thể
  static Map<String, double>? _getNumberStats(
    List<LotteryResult> results,
    String targetNumber,
  ) {
    final completionDate = _getCompletionDate(results);
    if (completionDate == null) return null;

    DateTime? lastSeenDate;
    String? lastSeenMien;
    int lastSeenIndex = -1;

    // Tìm lần xuất hiện cuối
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

    // 1. TÍNH GAN HIỆN TẠI (Current Gan)
    // Logic: Tính từ sau lần cuối đến hôm nay -> Cần tính cả hôm nay (excludeEndDate = false)
    final currentGan = _countMienOccurrencesStatic(
      results,
      lastSeenDate,
      completionDate,
      lastSeenMien,
      excludeEndDate: false,
    );

    int lastCycleGan = 0;
    DateTime? secondLastSeenDate;

    // Tìm chu kỳ trước (Lần trúng áp chót)
    for (int i = lastSeenIndex - 1; i >= 0; i--) {
      if (results[i].numbers.contains(targetNumber)) {
        final date = date_utils.DateUtils.parseDate(results[i].ngay);
        if (date != null) {
          secondLastSeenDate = date;
          break;
        }
      }
    }

    if (secondLastSeenDate != null) {
      // 2. TÍNH GAN CŨ (Last Cycle Gan)
      // Logic: Tính từ sau lần áp chót đến TRƯỚC lần cuối -> KHÔNG tính ngày lần cuối (excludeEndDate = true)
      lastCycleGan = _countMienOccurrencesStatic(
        results,
        secondLastSeenDate,
        lastSeenDate, // Đây là ngày trúng (End Date)
        lastSeenMien,
        excludeEndDate:
            true, // 👈 QUAN TRỌNG: Loại bỏ ngày trúng ra khỏi số đếm Gan
      );
    }

    int occurrences = 0;
    int slots = 0;

    for (final result in results) {
      int count = result.numbers.where((n) => n == targetNumber).length;
      if (count > 0) {
        occurrences++;
        slots += count;
      }
    }

    final uniqueDates = results.map((r) => r.ngay).toSet();
    final totalDays = uniqueDates.length;

    return {
      'currentGan': currentGan.toDouble(),
      'lastCycleGan': lastCycleGan.toDouble(),
      'occurrences': occurrences.toDouble(),
      'totalDays': totalDays.toDouble(),
      'slots': slots.toDouble(),
    };
  }

  /// P1 (Hiện tại): (1 - p)^y
  static double _calculateP1(double p, double currentGanDays) {
    if (p >= 1.0 || p <= 0.0) return 0.0;
    return pow(1 - p, currentGanDays).toDouble();
  }

  /// P2 (Chu kỳ): (1 - p)^x × p × (1 - p)^y
  static double _calculateP2(double p, double lastCycleGan, double currentGan) {
    if (p >= 1.0 || p <= 0.0) return 0.0;
    return pow(1 - p, lastCycleGan).toDouble() *
        p *
        pow(1 - p, currentGan).toDouble();
  }

  /// P3 (Tần suất): Binomial CDF
  static double _calculateP3(double p, double occurrences, double totalDays) {
    if (p >= 1.0 || p <= 0.0) return 0.0;

    final n = totalDays.toInt();
    final k = occurrences.toInt();

    double cdf = 0.0;

    for (int i = 0; i <= k; i++) {
      final binomialCoeff = _binomialCoefficient(n, i);
      final prob = binomialCoeff * pow(p, i) * pow(1 - p, n - i);
      cdf += prob;
    }

    return cdf;
  }

  /// Tính hệ số nhị thức
  static double _binomialCoefficient(int n, int k) {
    if (k > n) return 0.0;
    if (k == 0 || k == n) return 1.0;

    k = min(k, n - k);

    double result = 1.0;
    for (int i = 0; i < k; i++) {
      result *= (n - i).toDouble();
      result /= (i + 1).toDouble();
    }

    return result;
  }

  Future<GanPairInfo?> findGanPairsMienBac(
      List<LotteryResult> allResults) async {
    final cacheKey = 'ganpair_${allResults.length}';
    if (_ganPairCache.containsKey(cacheKey)) return _ganPairCache[cacheKey];

    // ✅ Chạy tính toán nặng trong Isolate
    final result = await compute(_findGanPairsMienBacCompute, allResults);

    if (result != null) _ganPairCache[cacheKey] = result;
    return result;
  }

  Future<CycleAnalysisResult?> analyzeCycle(
      List<LotteryResult> allResults) async {
    final cacheKey = 'cycle_${allResults.length}';
    if (_cycleCache.containsKey(cacheKey)) return _cycleCache[cacheKey];

    // ✅ Chạy tính toán nặng trong Isolate
    final result = await compute(_analyzeCycleCompute, allResults);

    if (result != null) _cycleCache[cacheKey] = result;
    return result;
  }

  // =======================================================================
  // ⚡ STATIC METHODS (Logic tính toán chạy ở luồng riêng)
  // =======================================================================
  static DateTime? _getCompletionDate(List<LotteryResult> results) {
    if (results.isEmpty) return null;

    DateTime? latestDate;

    for (final result in results) {
      final date = date_utils.DateUtils.parseDate(result.ngay);
      if (date == null) continue;

      if (latestDate == null || date.isAfter(latestDate)) {
        latestDate = date;
      }
    }

    return latestDate;
  }

  GanPairInfo? _findGanPairsMienBacCompute(List<LotteryResult> allResults) {
    final bacResults = allResults.where((r) => r.mien == 'Bắc').toList();
    if (bacResults.isEmpty) return null;

    final resultsByDate = <DateTime, Set<String>>{};
    for (final result in bacResults) {
      final date = date_utils.DateUtils.parseDate(result.ngay);
      if (date == null) continue;
      resultsByDate.putIfAbsent(date, () => {});
      resultsByDate[date]!.addAll(result.numbers);
    }

    final pairLastSeen = <String, DateTime>{};
    final sortedDates = resultsByDate.keys.toList()..sort();

    for (final date in sortedDates) {
      final numbersOnDate = resultsByDate[date]!;
      if (numbersOnDate.length >= 2) {
        final numbersList = numbersOnDate.toList()..sort();
        for (int i = 0; i < numbersList.length - 1; i++) {
          for (int j = i + 1; j < numbersList.length; j++) {
            final pairKey = '${numbersList[i]}-${numbersList[j]}';
            pairLastSeen[pairKey] = date;
          }
        }
      }
    }

    if (pairLastSeen.isEmpty) return null;

    final sortedPairs = pairLastSeen.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final top2Pairs = sortedPairs.take(2).toList();
    final now = DateTime.now();

    final longestGanPair = top2Pairs[0];
    final maxDaysGan = now.difference(longestGanPair.value).inDays;

    final pairsWithDays = top2Pairs.map((entry) {
      final parts = entry.key.split('-');
      return PairWithDays(
        pair: NumberPair(parts[0], parts[1]),
        daysGan: now.difference(entry.value).inDays,
        lastSeen: entry.value,
      );
    }).toList();

    return GanPairInfo(
      daysGan: maxDaysGan,
      lastSeen: longestGanPair.value,
      pairs: pairsWithDays,
    );
  }

  CycleAnalysisResult? _analyzeCycleCompute(List<LotteryResult> allResults) {
    if (allResults.isEmpty) return null;

    // 1. Map lần cuối xuất hiện
    final lastSeenMap = <String, Map<String, dynamic>>{};
    for (final result in allResults) {
      final date = date_utils.DateUtils.parseDate(result.ngay);
      if (date == null) continue;

      for (final number in result.numbers) {
        final key = number.padLeft(2, '0');
        if (!lastSeenMap.containsKey(key) ||
            date.isAfter(lastSeenMap[key]!['date'] as DateTime) ||
            (date.isAtSameMomentAs(lastSeenMap[key]!['date'] as DateTime) &&
                _isMienCloserStatic(
                    result.mien, lastSeenMap[key]!['mien'] as String))) {
          lastSeenMap[key] = {
            'date': date,
            'mien': result.mien,
            'ngay': result.ngay,
          };
        }
      }
    }

    if (lastSeenMap.length < 100) return null;

    // 2. Tìm ngày hoàn thành chu kỳ
    final completionDate = lastSeenMap.values
        .map((v) => v['date'] as DateTime)
        .reduce((a, b) => a.isAfter(b) ? a : b);

    // 3. Tính số ngày gan
    final ganStats = <Map<String, dynamic>>[];
    for (final entry in lastSeenMap.entries) {
      final lastDate = entry.value['date'] as DateTime;
      final lastMien = entry.value['mien'] as String;

      if (lastDate.isBefore(completionDate)) {
        final daysGan = _countMienOccurrencesStatic(
          allResults,
          lastDate,
          completionDate,
          lastMien,
        );
        ganStats.add({
          'so': entry.key,
          'days_gan': daysGan,
          'mien': lastMien,
          'last_seen': lastDate,
        });
      }
    }

    if (ganStats.isEmpty) return null;

    // 4. Tìm kết quả max gan
    ganStats
        .sort((a, b) => (b['days_gan'] as int).compareTo(a['days_gan'] as int));
    final maxGan = ganStats.first['days_gan'] as int;
    final longestGanGroup =
        ganStats.where((s) => s['days_gan'] == maxGan).toList();

    // ... Xây dựng result ...
    final ganNumbers = longestGanGroup.map((s) => s['so'] as String).toSet();
    final mienGroups = <String, List<String>>{};
    for (final stat in longestGanGroup) {
      final mien = stat['mien'] as String;
      mienGroups.putIfAbsent(mien, () => []);
      mienGroups[mien]!.add(stat['so'] as String);
    }

    String targetNumber = ganNumbers.first; // Simplified selection

    return CycleAnalysisResult(
      ganNumbers: ganNumbers,
      maxGanDays: maxGan,
      lastSeenDate: longestGanGroup.first['last_seen'] as DateTime,
      mienGroups: mienGroups,
      targetNumber: targetNumber,
    );
  }

  // ✅ Hàm này phải là static để gọi được trong isolate
  static int _countMienOccurrencesStatic(
    List<LotteryResult> allResults,
    DateTime startDate,
    DateTime endDate,
    String targetMien, {
    bool excludeEndDate = false, // Mặc định là FALSE (Tính cả ngày cuối)
  }) {
    final uniqueDates = <String>{};
    for (final result in allResults) {
      final date = date_utils.DateUtils.parseDate(result.ngay);
      if (date == null) continue;

      // Điều kiện ngày bắt đầu: Luôn phải sau ngày trúng trước đó
      bool isAfterStart = date.isAfter(startDate);

      // Điều kiện ngày kết thúc: Tùy thuộc vào cờ excludeEndDate
      bool isValidEnd;
      if (excludeEndDate) {
        // Nếu là Gan cũ: Phải NHỎ HƠN ngày trúng sau (Strictly Before)
        isValidEnd = date.isBefore(endDate);
      } else {
        // Nếu là Gan hiện tại: Nhỏ hơn hoặc BẰNG ngày cuối (Inclusive)
        isValidEnd = date.isBefore(endDate) || date.isAtSameMomentAs(endDate);
      }

      if (isAfterStart && isValidEnd && result.mien == targetMien) {
        uniqueDates.add(result.ngay);
      }
    }
    return uniqueDates.length;
  }

  bool _isMienCloserStatic(String newMien, String oldMien) {
    const mienPriority = {'Bắc': 3, 'Trung': 2, 'Nam': 1};
    return (mienPriority[newMien] ?? 0) > (mienPriority[oldMien] ?? 0);
  }

  // =======================================================================
  // 🔍 INSTANCE METHODS (Vẫn giữ lại để UI gọi)
  // =======================================================================

  Future<NumberDetail?> analyzeNumberDetail(
    List<LotteryResult> allResults,
    String targetNumber,
  ) async {
    if (allResults.isEmpty) return null;

    final mienDetails = <String, MienDetail>{};
    final now = DateTime.now();

    for (final mien in ['Nam', 'Trung', 'Bắc']) {
      DateTime? lastSeenDate;
      String? lastSeenDateStr;

      final mienResults = allResults.where((r) => r.mien == mien).toList();

      for (final result in mienResults) {
        if (result.numbers.contains(targetNumber)) {
          final date = date_utils.DateUtils.parseDate(result.ngay);
          if (date != null) {
            if (lastSeenDate == null || date.isAfter(lastSeenDate)) {
              lastSeenDate = date;
              lastSeenDateStr = result.ngay;
            }
          }
        }
      }

      if (lastSeenDate != null && lastSeenDateStr != null) {
        // ✅ FIX: Gọi hàm static _countMienOccurrencesStatic
        final daysGan = _countMienOccurrencesStatic(
          allResults,
          lastSeenDate,
          now,
          mien,
        );

        mienDetails[mien] = MienDetail(
          mien: mien,
          daysGan: daysGan,
          lastSeenDate: lastSeenDate,
          lastSeenDateStr: lastSeenDateStr,
        );
      }
    }

    if (mienDetails.isEmpty) return null;

    return NumberDetail(
      number: targetNumber,
      mienDetails: mienDetails,
    );
  }

  void clearCache() {
    _cycleCache.clear();
    _ganPairCache.clear();
  }

// ✅ COPY VÀ THAY THẾ TOÀN BỘ METHOD hasNumberReappeared

  Future<bool> hasNumberReappeared(
    String targetNumber,
    DateTime sinceDate,
    List<LotteryResult> allResults, {
    String mien = '',
  }) async {
    // ✨ Chạy trong isolate để không đơ UI
    return await compute(_hasNumberReappearedCompute, {
      'targetNumber': targetNumber,
      'sinceDate': sinceDate.millisecondsSinceEpoch,
      'allResults': allResults,
      'mien': mien,
    });
  }

  /// Static method để chạy trong isolate
  /// Lý do: compute() yêu cầu static function
  bool _hasNumberReappearedCompute(Map<String, dynamic> params) {
    final targetNumber = params['targetNumber'] as String;
    final sinceDate = DateTime.fromMillisecondsSinceEpoch(
      params['sinceDate'] as int,
    );
    final allResults = params['allResults'] as List<LotteryResult>;
    final mien = params['mien'] as String? ?? '';

    return _hasNumberReappearedStatic(
      targetNumber,
      sinceDate,
      allResults,
      mien: mien,
    );
  }

  int calculateNewGanDays(
    DateTime ngayTrungCu,
    List<LotteryResult> allResults,
  ) {
    // Tìm ngày mới nhất trong KQXS
    DateTime? newestDate;

    for (final result in allResults) {
      final resultDate = date_utils.DateUtils.parseDate(result.ngay);

      if (resultDate != null) {
        if (newestDate == null || resultDate.isAfter(newestDate)) {
          newestDate = resultDate;
        }
      }
    }

    // Nếu không tìm được ngày, dùng hôm nay
    newestDate ??= DateTime.now();

    // Tính số ngày
    final newGanDays = newestDate.difference(ngayTrungCu).inDays;

    print('📊 Gan mới: từ ${date_utils.DateUtils.formatDate(ngayTrungCu)} '
        'đến ${date_utils.DateUtils.formatDate(newestDate)} '
        '= $newGanDays ngày');

    return newGanDays;
  }

  Future<RebettingResult> calculateRebetting({
    required List<LotteryResult> allResults,
    required AppConfig config,
    required List<CycleWinHistory> cycleWins,
    required List<CycleWinHistory> namWins,
    required List<CycleWinHistory> trungWins,
    required List<CycleWinHistory> bacWins,
    required BettingTableService bettingService,
  }) async {
    print('🔄 Bắt đầu tính Rebetting...');

    final result = await compute(_calculateRebettingCompute, {
      'allResults': allResults,
      'config': config,
      'cycleWins': cycleWins,
      'namWins': namWins,
      'trungWins': trungWins,
      'bacWins': bacWins,
    });

    // ✨ THÊM: Tính ngayCoTheVao bằng _findBestStartBet
    // (sẽ làm ở giai đoạn 4 - BettingTableService)

    return result;
  }

  /// Static method để compute - FIXED VERSION
  RebettingResult _calculateRebettingCompute(
    Map<String, dynamic> params,
  ) {
    final allResults = params['allResults'] as List<LotteryResult>;
    final config = params['config'] as AppConfig;
    final cycleWins = params['cycleWins'] as List<CycleWinHistory>;
    final namWins = params['namWins'] as List<CycleWinHistory>;
    final trungWins = params['trungWins'] as List<CycleWinHistory>;
    final bacWins = params['bacWins'] as List<CycleWinHistory>;

    // Hàm helper: Xử lý 1 loại
    Map<String, dynamic> processType(
      String typeName,
      List<CycleWinHistory> wins,
      String mien,
      int threshold,
    ) {
      final candidates = <RebettingCandidate>[];

      print('📋 Xử lý loại: $typeName ($mien)');

      for (final win in wins) {
        // Chỉ lấy bản ghi WIN
        if (!win.isWin) continue;

        final soMucTieu = win.soMucTieu;
        final ngayBatDauCu = win.ngayBatDau;
        final ngayTrungCu = win.ngayTrung;
        final soNgayGanCu = win.soNgayCuoc;

        // ✅ CRITICAL FIX: Kiểm tra số có xuất hiện lại sau ngày trúng không
        final ngayTrungDate = date_utils.DateUtils.parseDate(ngayTrungCu);
        if (ngayTrungDate == null) continue;

        // ✨ FIX LỖI Ở ĐÂY:
        // Nếu mien là 'Mixed' (Tất cả), ta truyền chuỗi rỗng '' để hàm check không lọc theo miền
        // Nếu là 'Nam', 'Trung', 'Bắc' thì giữ nguyên để lọc
        String mienToCheck = (mien == 'Mixed') ? '' : mien;

        // 🔴 KEY CHECK: Nếu số đã về sau ngày trúng (cho MIỀN này) → LOẠI
        if (_hasNumberReappearedStatic(
          soMucTieu,
          ngayTrungDate,
          allResults,
          mien:
              mienToCheck, // 👈 Sửa dòng này: Dùng biến mienToCheck thay vì mien
        )) {
          print('   ⏭️  Số $soMucTieu đã về sau $ngayTrungCu ($mien) → loại');
          continue; // ← Skip ứng viên này
        }

        // Nếu vượt qua check, mới tính toán tiếp
        print('   ✅ Số $soMucTieu chưa về sau $ngayTrungCu → có thể dùng');

        // Tính gan mới
        final soNgayGanMoi = _calculateNewGanDaysStatic(
          ngayTrungDate,
          allResults,
          mienToCheck, // ✅ Truyền thêm miền
        );

        // Tính duration
        final rebettingDuration = ((2.4 * threshold) - soNgayGanCu).round();

        if (rebettingDuration <= 0) {
          print('       ⏭️  Duration âm ($rebettingDuration) → loại');
          continue;
        }

        // Tạo candidate
        final candidate = RebettingCandidate(
          soMucTieu: soMucTieu,
          mienTrung: mien,
          ngayBatDauCu: ngayBatDauCu,
          ngayTrungCu: ngayTrungCu,
          soNgayGanCu: soNgayGanCu,
          soNgayGanMoi: soNgayGanMoi,
          rebettingDuration: rebettingDuration,
          ngayCoTheVao: '', // Tạm để trống
        );

        candidates.add(candidate);
        print('       ✅ Thêm: số=$soMucTieu, duration=$rebettingDuration');
      }

      // Tìm 1 số có duration MIN
      RebettingCandidate? selected;
      if (candidates.isNotEmpty) {
        selected = candidates.reduce(
            (a, b) => a.rebettingDuration < b.rebettingDuration ? a : b);
        print(
            '   🎯 Chọn: số=${selected.soMucTieu} (duration=${selected.rebettingDuration})');
      } else {
        print('   ❌ Không có ứng viên nào');
      }

      return {
        'candidates': candidates,
        'selected': selected,
        'total': candidates.length,
      };
    }

    // Xử lý 4 loại
    final tatCa = processType(
      'Tất cả',
      cycleWins,
      'Mixed',
      config.duration.thresholdCycleDuration,
    );

    final nam = processType(
      'Nam',
      namWins,
      'Nam',
      config.duration.thresholdCycleDuration,
    );

    final trung = processType(
      'Trung',
      trungWins,
      'Trung',
      config.duration.thresholdTrungDuration,
    );

    final bac = processType(
      'Bắc',
      bacWins,
      'Bắc',
      config.duration.thresholdBacDuration,
    );

    // Tạo RebettingSummary
    final summaries = <String, RebettingSummary?>{
      'tatCa': tatCa['selected'] != null
          ? RebettingSummary(
              mien: 'Tất cả',
              ngayCoTheVao: '',
              totalCandidates: tatCa['total'] as int,
            )
          : null,
      'nam': nam['selected'] != null
          ? RebettingSummary(
              mien: 'Nam',
              ngayCoTheVao: '',
              totalCandidates: nam['total'] as int,
            )
          : null,
      'trung': trung['selected'] != null
          ? RebettingSummary(
              mien: 'Trung',
              ngayCoTheVao: '',
              totalCandidates: trung['total'] as int,
            )
          : null,
      'bac': bac['selected'] != null
          ? RebettingSummary(
              mien: 'Bắc',
              ngayCoTheVao: '',
              totalCandidates: bac['total'] as int,
            )
          : null,
    };

    final selected = <String, RebettingCandidate?>{
      'tatCa': tatCa['selected'] as RebettingCandidate?,
      'nam': nam['selected'] as RebettingCandidate?,
      'trung': trung['selected'] as RebettingCandidate?,
      'bac': bac['selected'] as RebettingCandidate?,
    };

    return RebettingResult(
      summaries: summaries,
      selected: selected,
    );
  }

  /// Static helper: Kiểm tra số có vô lại sau ngày trúng
  /// ✅ CRITICAL FIX: Lọc theo MIỀN + chỉ check từ ngàyTrúng đến hôm nay
  bool _hasNumberReappearedStatic(
    String targetNumber,
    DateTime sinceDate,
    List<LotteryResult> allResults, {
    String mien = '', // ✨ THÊM: Optional mien filter
  }) {
    // 🐛 FIX: Normalize target number to 2 digits
    final normalizedTarget = targetNumber.padLeft(2, '0');

    print(
        '      🔍 Check xem $normalizedTarget có xuất hiện sau ${date_utils.DateUtils.formatDate(sinceDate)}${mien.isNotEmpty ? ' ($mien)' : ''}...');

    // ✅ FIX: Tìm completion date thay vì dùng DateTime.now()
    final completionDate = _getCompletionDate(allResults);
    if (completionDate == null) {
      print('         ⚠️ Không tìm thấy completion date');
      return false;
    }

    // 🐛 DEBUG: Count total results and mien matches
    int totalResults = 0;
    int mienMatches = 0;
    int dateMatches = 0;

    for (final result in allResults) {
      totalResults++;

      final resultDate = date_utils.DateUtils.parseDate(result.ngay);

      if (resultDate == null) {
        print('         ⚠️  Failed to parse date: ${result.ngay}');
        continue;
      }

      // ✅ CRITICAL: Chỉ check từ NGÀY TRÚNG đến COMPLETION DATE (không bao gồm ngày trúng)
      if (resultDate.isAfter(sinceDate) &&
          (resultDate.isBefore(completionDate) ||
              resultDate.isAtSameMomentAs(completionDate))) {
        dateMatches++;

        // ✨ THÊM: Nếu có miền filter, chỉ check miền đó
        if (mien.isNotEmpty && result.mien != mien) {
          continue; // ← Bỏ qua nếu không phải miền cần check
        }

        mienMatches++;

        // 🐛 DEBUG: Print matching dates
        if (mienMatches <= 3) {
          // Only print first 3 matches
          print(
              '         📅 Checking date ${result.ngay} (${result.mien}) - Numbers: ${result.numbers.take(5).join(", ")}...');
        }

        // 🐛 FIX: Check với cả 2 format (1 digit và 2 digits)
        if (result.numbers.contains(normalizedTarget) ||
            result.numbers.contains(targetNumber)) {
          print(
              '         ⚠️  FOUND: $normalizedTarget vào ngày ${result.ngay} (${result.mien})');
          return true; // ← Số đã vô lại
        }
      }
    }

    print(
        '         📊 Stats: Total=$totalResults, InRange=$dateMatches, MienMatch=$mienMatches');
    print('         ✅ Không tìm thấy');
    return false; // ← Chưa vô lại
  }

  /// Static helper: Tính gan mới
  int _calculateNewGanDaysStatic(
    DateTime ngayTrungCu,
    List<LotteryResult> allResults,
    String mien, // ✅ THÊM: Cần biết miền để đếm đúng
  ) {
    // ✅ FIX: Tìm ngày mới nhất trong KQXS
    final newestDate = _getCompletionDate(allResults);

    if (newestDate == null) {
      print('⚠️ Không tìm thấy completion date');
      return 0;
    }

    // ✅ FIX: Đếm số ngày miền đó từ ngayTrungCu đến newestDate
    final newGanDays = _countMienOccurrencesStatic(
      allResults,
      ngayTrungCu,
      newestDate,
      mien,
    );

    print('📊 Gan mới: từ ${date_utils.DateUtils.formatDate(ngayTrungCu)} '
        'đến ${date_utils.DateUtils.formatDate(newestDate)} '
        '($mien) = $newGanDays ngày');

    return newGanDays;
  }
}
