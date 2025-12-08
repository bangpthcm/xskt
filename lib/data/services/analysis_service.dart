// lib/data/services/analysis_service.dart
import 'package:flutter/foundation.dart'; // ✅ Import compute
import '../models/gan_pair_info.dart';
import '../models/cycle_analysis_result.dart';
import '../models/lottery_result.dart';
import '../../core/utils/date_utils.dart' as date_utils;
import '../models/number_detail.dart';

class AnalysisService {
  final Map<String, GanPairInfo> _ganPairCache = {};
  final Map<String, CycleAnalysisResult> _cycleCache = {};
  
  Future<GanPairInfo?> findGanPairsMienBac(List<LotteryResult> allResults) async {
    final cacheKey = 'ganpair_${allResults.length}';
    if (_ganPairCache.containsKey(cacheKey)) return _ganPairCache[cacheKey];
    
    // ✅ Chạy tính toán nặng trong Isolate
    final result = await compute(_findGanPairsMienBacCompute, allResults);
    
    if (result != null) _ganPairCache[cacheKey] = result;
    return result;
  }

  Future<CycleAnalysisResult?> analyzeCycle(List<LotteryResult> allResults) async {
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

  static GanPairInfo? _findGanPairsMienBacCompute(List<LotteryResult> allResults) {
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

  static CycleAnalysisResult? _analyzeCycleCompute(List<LotteryResult> allResults) {
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
            _isMienCloserStatic(result.mien, lastSeenMap[key]!['mien'] as String))) {
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
    ganStats.sort((a, b) => (b['days_gan'] as int).compareTo(a['days_gan'] as int));
    final maxGan = ganStats.first['days_gan'] as int;
    final longestGanGroup = ganStats.where((s) => s['days_gan'] == maxGan).toList();
    
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
    String targetMien,
  ) {
    final uniqueDates = <String>{};
    for (final result in allResults) {
      final date = date_utils.DateUtils.parseDate(result.ngay);
      if (date == null) continue;
      // Logic đếm ngày
      if (date.isAfter(startDate) && 
          (date.isBefore(endDate) || date.isAtSameMomentAs(endDate)) &&
          result.mien == targetMien) {
        uniqueDates.add(result.ngay);
      }
    }
    return uniqueDates.length;
  }

  static bool _isMienCloserStatic(String newMien, String oldMien) {
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
}