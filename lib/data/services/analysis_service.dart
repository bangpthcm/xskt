// lib/data/services/analysis_service.dart
import 'dart:math';
import '../models/gan_pair_info.dart';
import '../models/cycle_analysis_result.dart';
import '../models/lottery_result.dart';
import '../../core/utils/date_utils.dart' as date_utils;
import '../models/number_detail.dart';

class AnalysisService {
  Future<GanPairInfo?> findGanPairsMienBac(
    List<LotteryResult> allResults,
  ) async {
    print("Bắt đầu phân tích cặp số gan Miền Bắc");
    
    final bacResults = allResults.where((r) => r.mien == 'Bắc').toList();
    
    if (bacResults.isEmpty) {
      print("Không có dữ liệu Miền Bắc");
      return null;
    }

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

    if (pairLastSeen.isEmpty) {
      print("Chưa đủ dữ liệu để tạo cặp số");
      return null;
    }

    final sortedPairs = pairLastSeen.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    final top2Pairs = sortedPairs.take(2).toList();
    
    final now = DateTime.now();
    
    print("=== TOP 2 CẶP GAN NHẤT ===");
    for (var i = 0; i < top2Pairs.length; i++) {
      final entry = top2Pairs[i];
      final daysGan = now.difference(entry.value).inDays;
      print("${i + 1}. Cặp ${entry.key} - Gan: $daysGan ngày - Cuối: ${date_utils.DateUtils.formatDate(entry.value)}");
    }

    final longestGanPair = top2Pairs[0];
    final maxDaysGan = now.difference(longestGanPair.value).inDays;
    
    // ✅ FIX: Tạo đúng List<PairWithDays>
    final pairsWithDays = top2Pairs.map((entry) {
      final parts = entry.key.split('-');
      final daysGan = now.difference(entry.value).inDays;
      return PairWithDays(  // ✅ Giờ có thể dùng vì đã import từ gan_pair_info.dart
        pair: NumberPair(parts[0], parts[1]),
        daysGan: daysGan,
        lastSeen: entry.value,
      );
    }).toList();

    return GanPairInfo(
      daysGan: maxDaysGan,
      lastSeen: longestGanPair.value,
      pairs: pairsWithDays,  // ✅ Đúng type: List<PairWithDays>
    );
  }

  Future<CycleAnalysisResult?> analyzeCycle(
    List<LotteryResult> allResults,
  ) async {
    if (allResults.isEmpty) return null;

    // ✅ BƯỚC 1: Tìm lần xuất hiện cuối cùng của mỗi số (theo miền)
    final lastSeenMap = <String, Map<String, dynamic>>{};

    for (final result in allResults) {
      final date = date_utils.DateUtils.parseDate(result.ngay);
      if (date == null) continue;

      for (final number in result.numbers) {
        final key = number.padLeft(2, '0');
        
        if (!lastSeenMap.containsKey(key) ||
            date.isAfter(lastSeenMap[key]!['date'] as DateTime) ||
            (date.isAtSameMomentAs(lastSeenMap[key]!['date'] as DateTime) && 
            _isMienCloser(result.mien, lastSeenMap[key]!['mien'] as String))) {
          lastSeenMap[key] = {
            'date': date,
            'mien': result.mien,
            'ngay': result.ngay,
          };
        }
      }
    }

    if (lastSeenMap.length < 100) {
      print('Chưa đủ chu kỳ: ${lastSeenMap.length}/100');
      return null;
    }

    // ✅ BƯỚC 2: Tìm ngày hoàn thành chu kỳ
    final completionDate = lastSeenMap.values
        .map((v) => v['date'] as DateTime)
        .reduce((a, b) => a.isAfter(b) ? a : b);

    // ✅ BƯỚC 3: Tính số ngày gan theo MIỀN (không phải ngày lịch)
    final ganStats = <Map<String, dynamic>>[];
    
    for (final entry in lastSeenMap.entries) {
      final lastDate = entry.value['date'] as DateTime;
      final lastMien = entry.value['mien'] as String;
      
      if (lastDate.isBefore(completionDate)) {
        // ✅ ĐẾM SỐ LƯỢT QUAY CỦA MIỀN ĐÓ TỪ lastDate ĐẾN completionDate
        final daysGan = _countMienOccurrences(
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

    ganStats.sort((a, b) => 
        (b['days_gan'] as int).compareTo(a['days_gan'] as int));
    
    final maxGan = ganStats.first['days_gan'] as int;
    
    final longestGanGroup = ganStats
        .where((s) => s['days_gan'] == maxGan)
        .toList();

    final ganNumbers = longestGanGroup
        .map((s) => s['so'] as String)
        .toSet();

    final mienGroups = <String, List<String>>{};
    for (final stat in longestGanGroup) {
      final mien = stat['mien'] as String;
      mienGroups.putIfAbsent(mien, () => []);
      mienGroups[mien]!.add(stat['so'] as String);
    }

    String targetNumber = '';
    final mienPriority = ['Nam', 'Trung', 'Bắc'];
    
    for (final mien in mienPriority) {
      if (mienGroups.containsKey(mien) && mienGroups[mien]!.isNotEmpty) {
        targetNumber = mienGroups[mien]![Random().nextInt(mienGroups[mien]!.length)];
        break;
      }
    }
    
    if (targetNumber.isEmpty) {
      targetNumber = ganNumbers.first;
    }

    return CycleAnalysisResult(
      ganNumbers: ganNumbers,
      maxGanDays: maxGan,
      lastSeenDate: longestGanGroup.first['last_seen'] as DateTime,
      mienGroups: mienGroups,
      targetNumber: targetNumber,
    );
  }

  // ✅ HÀM MỚI: Đếm số NGÀY (không phải số dòng) của một miền
  int _countMienOccurrences(
    List<LotteryResult> allResults,
    DateTime startDate,
    DateTime endDate,
    String targetMien,
  ) {
    // ✅ SỬ DỤNG SET ĐỂ TRÁNH TRÙNG LẶP NGÀY
    final uniqueDates = <String>{};
    
    for (final result in allResults) {
      final date = date_utils.DateUtils.parseDate(result.ngay);
      if (date == null) continue;
      
      // Chỉ đếm từ SAU startDate đến endDate
      if (date.isAfter(startDate) && 
          (date.isBefore(endDate) || date.isAtSameMomentAs(endDate)) &&
          result.mien == targetMien) {
        // ✅ THÊM VÀO SET (tự động loại trùng)
        uniqueDates.add(result.ngay);
      }
    }
    
    // ✅ TRẢ VỀ SỐ NGÀY DUY NHẤT
    return uniqueDates.length;
  }

  bool _isMienCloser(String newMien, String oldMien) {
    const mienPriority = {'Bắc': 3, 'Trung': 2, 'Nam': 1};
    return (mienPriority[newMien] ?? 0) > (mienPriority[oldMien] ?? 0);
  }

  Future<NumberDetail?> analyzeNumberDetail(
    List<LotteryResult> allResults,
    String targetNumber,
  ) async {
    if (allResults.isEmpty) return null;

    final mienDetails = <String, MienDetail>{};
    final now = DateTime.now();

    // Phân tích theo từng miền
    for (final mien in ['Nam', 'Trung', 'Bắc']) {
      DateTime? lastSeenDate;
      String? lastSeenDateStr;

      // Lọc kết quả theo miền
      final mienResults = allResults.where((r) => r.mien == mien).toList();

      // Tìm lần xuất hiện cuối cùng của số này trong miền
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
        // ✅ TÍNH SỐ NGÀY GAN THEO MIỀN (không phải theo ngày lịch)
        final daysGan = _countMienOccurrences(
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
}