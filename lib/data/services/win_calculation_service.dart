// lib/data/services/win_calculation_service.dart

import '../models/win_result.dart';
import '../models/lottery_result.dart';
import '../models/gan_pair_info.dart';
import '../../core/utils/date_utils.dart' as date_utils;

class WinCalculationService {
  static const int _cycleMultiplier = 98;
  static const int _xienMultiplier = 17;

  /// Tính lời cho Chu kỳ (Số đơn)
  Future<WinResult?> calculateCycleWin({
    required String targetNumber,
    required String checkDate,
    required List<LotteryResult> allResults,
    required double totalBet,
    required double betPerNumber,
  }) async {
    print('🔍 Checking cycle win for number $targetNumber on $checkDate');
    
    // 1. Filter by date
    final dateResults = allResults
        .where((r) => r.ngay == checkDate)
        .toList();
    
    if (dateResults.isEmpty) {
      print('   ⚠️ No results for date $checkDate');
      return null;
    }

    // 2. Check Nam (exclude Bến Tre)
    print('   🌍 Checking Miền Nam...');
    final namWin = _checkMien(
      results: dateResults,
      mien: 'Nam',
      targetNumber: targetNumber,
      excludeProvinces: ['Bến Tre'],
    );
    
    if (namWin.hasWin) {
      print('   ✅ WIN in Nam: ${namWin.occurrences}x');
      return _calculateProfit(
        occurrences: namWin.occurrences,
        betPerOccurrence: betPerNumber,
        totalBet: totalBet,
        multiplier: _cycleMultiplier,
        winningMien: 'Nam',
        provinces: namWin.provinces,
        targetNumber: targetNumber,
        checkDate: checkDate,
      );
    }
    
    // 3. Check Trung
    print('   🌍 Checking Miền Trung...');
    final trungWin = _checkMien(
      results: dateResults,
      mien: 'Trung',
      targetNumber: targetNumber,
    );
    
    if (trungWin.hasWin) {
      print('   ✅ WIN in Trung: ${trungWin.occurrences}x');
      return _calculateProfit(
        occurrences: trungWin.occurrences,
        betPerOccurrence: betPerNumber,
        totalBet: totalBet,
        multiplier: _cycleMultiplier,
        winningMien: 'Trung',
        provinces: trungWin.provinces,
        targetNumber: targetNumber,
        checkDate: checkDate,
      );
    }
    
    // 4. Check Bắc
    print('   🌍 Checking Miền Bắc...');
    final bacWin = _checkMien(
      results: dateResults,
      mien: 'Bắc',
      targetNumber: targetNumber,
    );
    
    if (bacWin.hasWin) {
      print('   ✅ WIN in Bắc: ${bacWin.occurrences}x');
      return _calculateProfit(
        occurrences: bacWin.occurrences,
        betPerOccurrence: betPerNumber,
        totalBet: totalBet,
        multiplier: _cycleMultiplier,
        winningMien: 'Bắc',
        provinces: bacWin.provinces,
        targetNumber: targetNumber,
        checkDate: checkDate,
      );
    }
    
    // No win
    print('   ❌ No win for $targetNumber on $checkDate');
    return null;
  }

  /// Tính lời cho Xiên (Cặp số)
  Future<WinResult?> calculateXienWin({
    required NumberPair targetPair,
    required String checkDate,
    required List<LotteryResult> allResults,
    required double totalBet,
    required double betPerMien,
  }) async {
    print('🔍 Checking xien win for pair ${targetPair.display} on $checkDate');
    
    // Xiên chỉ check Miền Bắc
    final dateResults = allResults
        .where((r) => r.ngay == checkDate && r.mien == 'Bắc')
        .toList();
    
    if (dateResults.isEmpty) {
      print('   ⚠️ No Bắc results for date $checkDate');
      return null;
    }

    // Đếm số lần mỗi số xuất hiện
    int count1 = 0;
    int count2 = 0;
    
    for (final result in dateResults) {
      count1 += result.numbers.where((n) => n == targetPair.first).length;
      count2 += result.numbers.where((n) => n == targetPair.second).length;
    }

    // Số lần cặp xuất hiện = min(count1, count2)
    final pairOccurrences = count1 < count2 ? count1 : count2;
    
    if (pairOccurrences == 0) {
      print('   ❌ Pair not found together');
      return null;
    }

    print('   ✅ Pair found ${pairOccurrences}x (${targetPair.first}: ${count1}x, ${targetPair.second}: ${count2}x)');

    final profit = (pairOccurrences * _xienMultiplier * betPerMien) - totalBet;
    final totalReturn = pairOccurrences * _xienMultiplier * betPerMien;

    return WinResult(
      profit: profit,
      occurrences: pairOccurrences,
      winningMien: 'Bắc',
      provinces: [ProvinceWin(name: 'Miền Bắc', count: pairOccurrences)],
      winDate: date_utils.DateUtils.parseDate(checkDate) ?? DateTime.now(),
      targetNumber: targetPair.display,
      totalBet: totalBet,
      totalReturn: totalReturn,
    );
  }

  /// Helper: Kiểm tra một miền
  MienCheckResult _checkMien({
    required List<LotteryResult> results,
    required String mien,
    required String targetNumber,
    List<String> excludeProvinces = const [],
  }) {
    print('   🔎 _checkMien: mien=$mien, target=$targetNumber, excludeProvinces=$excludeProvinces');
    
    final filtered = results
        .where((r) => 
          r.mien == mien && 
          !excludeProvinces.contains(r.tinh))
        .toList();
    
    print('      Found ${filtered.length} results for $mien');
    for (final r in filtered) {
      print('      - ${r.tinh}: ${r.numbers.join(", ")}');
    }
    
    int totalCount = 0;
    final provinces = <ProvinceWin>[];
    
    for (final result in filtered) {
      final occurrencesInProvince = result.numbers
          .where((n) {
            // ✅ ADD: Debug comparison
            print('         Comparing: "$n" == "$targetNumber" ? ${n == targetNumber}');
            return n == targetNumber;
          })
          .length;
      
      if (occurrencesInProvince > 0) {
        totalCount += occurrencesInProvince;
        provinces.add(ProvinceWin(
          name: result.tinh,
          count: occurrencesInProvince,
        ));
        print('      ✅ ${result.tinh}: ${occurrencesInProvince}x');
      }
    }
    
    print('      Total occurrences: $totalCount');
    
    return MienCheckResult(
      occurrences: totalCount,
      provinces: provinces,
    );
  }

  /// Helper: Tính lời
  WinResult _calculateProfit({
    required int occurrences,
    required double betPerOccurrence,
    required double totalBet,
    required int multiplier,
    required String winningMien,
    required List<ProvinceWin> provinces,
    required String targetNumber,
    required String checkDate,
  }) {
    final totalReturn = occurrences * multiplier * betPerOccurrence;
    final profit = totalReturn - totalBet;
    
    print('   💰 Calculation:');
    print('      Occurrences: $occurrences');
    print('      Multiplier: $multiplier');
    print('      Bet per occurrence: $betPerOccurrence');
    print('      Total return: $totalReturn');
    print('      Total bet: $totalBet');
    print('      Profit: $profit');
    
    return WinResult(
      profit: profit,
      occurrences: occurrences,
      winningMien: winningMien,
      provinces: provinces,
      winDate: date_utils.DateUtils.parseDate(checkDate) ?? DateTime.now(),
      targetNumber: targetNumber,
      totalBet: totalBet,
      totalReturn: totalReturn,
    );
  }

  /// Tính số ngày giữa 2 ngày
  int calculateDaysBetween(String startDate, String endDate) {
    final start = date_utils.DateUtils.parseDate(startDate);
    final end = date_utils.DateUtils.parseDate(endDate);
    
    if (start == null || end == null) return 0;
    
    return end.difference(start).inDays;
  }
}