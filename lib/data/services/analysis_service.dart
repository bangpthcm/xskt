// lib/data/services/analysis_service.dart
import 'package:flutter/foundation.dart'; // ✅ Import compute

import '../../core/utils/date_utils.dart' as date_utils;
import '../models/app_config.dart';
import '../models/cycle_analysis_result.dart';
import '../models/cycle_win_history.dart';
import '../models/gan_pair_info.dart';
import '../models/lottery_result.dart';
import '../models/number_detail.dart';
import '../models/rebetting_candidate.dart';
import '../models/rebetting_summary.dart';
import 'betting_table_service.dart';

class AnalysisService {
  final Map<String, GanPairInfo> _ganPairCache = {};
  final Map<String, CycleAnalysisResult> _cycleCache = {};

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

  static GanPairInfo? _findGanPairsMienBacCompute(
      List<LotteryResult> allResults) {
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

  static CycleAnalysisResult? _analyzeCycleCompute(
      List<LotteryResult> allResults) {
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

  Future<bool> hasNumberReappeared(
    String targetNumber,
    DateTime sinceDate,
    List<LotteryResult> allResults,
  ) async {
    // ✨ Chạy trong isolate để không đơ UI
    return await compute(_hasNumberReappearedCompute, {
      'targetNumber': targetNumber,
      'sinceDate': sinceDate.millisecondsSinceEpoch,
      'allResults': allResults,
    });
  }

  /// Static method để chạy trong isolate
  /// Lý do: compute() yêu cầu static function
  static bool _hasNumberReappearedCompute(Map<String, dynamic> params) {
    final targetNumber = params['targetNumber'] as String;
    final sinceDate = DateTime.fromMillisecondsSinceEpoch(
      params['sinceDate'] as int,
    );
    final allResults = params['allResults'] as List<LotteryResult>;

    // Duyệt qua tất cả kết quả từ sinceDate đến hôm nay
    for (final result in allResults) {
      final resultDate = date_utils.DateUtils.parseDate(result.ngay);

      if (resultDate == null) continue;

      // Nếu ngày >= sinceDate và có chứa số
      if (resultDate.isAfter(sinceDate) ||
          resultDate.isAtSameMomentAs(sinceDate)) {
        if (result.numbers.contains(targetNumber)) {
          print('✅ Số $targetNumber đã xuất hiện lại ngày ${result.ngay}');
          return true;
        }
      }
    }

    print('⏳ Số $targetNumber chưa xuất hiện lại');
    return false;
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

  /// Static method để compute
  static RebettingResult _calculateRebettingCompute(
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

        // ✨ Kiểm tra: số có xuất hiện lại không?
        final ngayTrungDate = date_utils.DateUtils.parseDate(ngayTrungCu);
        if (ngayTrungDate == null) continue;

        // Tính gan mới
        final soNgayGanMoi = _calculateNewGanDaysStatic(
          ngayTrungDate,
          allResults,
        );

        // Nếu số đã xuất hiện lại → skip
        if (_hasNumberReappearedStatic(soMucTieu, ngayTrungDate, allResults)) {
          print('   ⏭️  Số $soMucTieu đã về → bỏ qua');
          continue;
        }

        // Tính duration
        final rebettingDuration = (2 * threshold) - soNgayGanCu;

        if (rebettingDuration <= 0) {
          print(
              '   ⏭️  Số $soMucTieu có duration âm ($rebettingDuration) → bỏ qua');
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
          ngayCoTheVao: '', // ✨ Tạm để trống, sẽ tính ở giai đoạn 4
        );

        candidates.add(candidate);
        print('   ✅ Thêm: $candidate');
      }

      // Tìm 1 số có duration MIN
      RebettingCandidate? selected;
      if (candidates.isNotEmpty) {
        selected = candidates.reduce(
            (a, b) => a.rebettingDuration < b.rebettingDuration ? a : b);
        print(
            '   🎯 Chọn: ${selected.soMucTieu} (duration: ${selected.rebettingDuration})');
      } else {
        print('   ❌ Không có ứng viên');
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
              ngayCoTheVao: '', // Tạm để trống
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

  /// Static helper: Tính gan mới
  static int _calculateNewGanDaysStatic(
    DateTime ngayTrungCu,
    List<LotteryResult> allResults,
  ) {
    DateTime? newestDate;

    for (final result in allResults) {
      final resultDate = date_utils.DateUtils.parseDate(result.ngay);
      if (resultDate != null) {
        if (newestDate == null || resultDate.isAfter(newestDate)) {
          newestDate = resultDate;
        }
      }
    }

    newestDate ??= DateTime.now();
    return newestDate.difference(ngayTrungCu).inDays;
  }

  /// Static helper: Kiểm tra số có vô lại
  static bool _hasNumberReappearedStatic(
    String targetNumber,
    DateTime sinceDate,
    List<LotteryResult> allResults,
  ) {
    for (final result in allResults) {
      final resultDate = date_utils.DateUtils.parseDate(result.ngay);

      if (resultDate == null) continue;

      if ((resultDate.isAfter(sinceDate) ||
              resultDate.isAtSameMomentAs(sinceDate)) &&
          result.numbers.contains(targetNumber)) {
        return true;
      }
    }

    return false;
  }
}
