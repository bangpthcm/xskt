// lib/data/services/betting_table_service.dart

import 'dart:math';
import '../models/betting_row.dart';
import '../models/gan_pair_info.dart';
import '../models/cycle_analysis_result.dart';
import '../../core/utils/date_utils.dart' as date_utils;
import '../../core/utils/number_utils.dart';

class BettingTableService {
  static const double _winMultiplierXien = 17.0;
  static const int _durationBase = 185;
  static const double _startingProfit = 50.0;
  static const double _finalProfit = 1000.0;
  
  // ✅ Constants cho Bắc gan
  static const int _bacGanDurationBase = 35;
  static const int _bacGanWinMultiplier = 99;

  // ✅ Constants cho Trung gan
  static const int _trungGanDurationBase = 30;
  static const int _trungGanWinMultiplier = 98;

  /// Generate Xien Table
  Future<List<BettingRow>> generateXienTable({
    required GanPairInfo ganInfo,
    required DateTime startDate,
    required double xienBudget,
  }) async {
    final soNgayGan = ganInfo.daysGan;
    final durationDays = _durationBase - soNgayGan;

    if (durationDays <= 1) {
      throw Exception('Số ngày gan quá lớn: $soNgayGan');
    }

    final capSoMucTieu = ganInfo.randomPair;
    final rawTable = <Map<String, dynamic>>[];
    
    double tongTien = 0.0;
    final profitStep = (_finalProfit - _startingProfit) / (durationDays - 1);
    double tienCuocMien = _startingProfit / (_winMultiplierXien - 1);

    for (int i = 0; i < durationDays; i++) {
      final currentProfitTarget = _startingProfit + (profitStep * i);
      
      if (i > 0) {
        tienCuocMien = (tongTien + currentProfitTarget) / (_winMultiplierXien - 1);
      }

      if (rawTable.isNotEmpty) {
        tienCuocMien = max(rawTable.last['cuoc_mien'] as double, tienCuocMien);
      }

      // Làm tròn lên số nguyên
      tienCuocMien = tienCuocMien.ceilToDouble();

      tongTien += tienCuocMien;
      
      final loi = (tienCuocMien * _winMultiplierXien) - tongTien;

      rawTable.add({
        'ngay': date_utils.DateUtils.formatDate(startDate.add(Duration(days: i))),
        'cuoc_mien': tienCuocMien,
        'tong_tien': tongTien,
        'loi': loi,
      });
    }

    // Chuẩn hóa theo ngân sách
    final rawTotalCost = rawTable.last['tong_tien'] as double;
    if (rawTotalCost <= 0) {
      throw Exception('Tổng tiền bằng 0');
    }

    final scalingFactor = xienBudget / rawTotalCost;

    final finalTable = <BettingRow>[];
    for (int i = 0; i < rawTable.length; i++) {
      final row = rawTable[i];
      
      double cuocMien = (row['cuoc_mien'] as double) * scalingFactor;
      cuocMien = cuocMien.ceilToDouble();
      
      double tongTien = i == 0 
          ? cuocMien 
          : finalTable[i-1].tongTien + cuocMien;
      
      double loi = (cuocMien * _winMultiplierXien) - tongTien;
      
      finalTable.add(BettingRow.forXien(
        stt: i + 1,
        ngay: row['ngay'],
        mien: 'Bắc',
        so: capSoMucTieu.display,
        cuocMien: cuocMien,
        tongTien: tongTien,
        loi: loi,
      ));
    }

    return finalTable;
  }

  /// Generate Cycle Table
  Future<List<BettingRow>> generateCycleTable({
    required CycleAnalysisResult cycleResult,
    required DateTime startDate,
    required DateTime endDate,
    required int startMienIndex,
    required double budgetMin,
    required double budgetMax,
  }) async {
    final targetNumber = cycleResult.targetNumber;
    
    String targetMien = 'Nam';
    for (final entry in cycleResult.mienGroups.entries) {
      if (entry.value.contains(targetNumber)) {
        targetMien = entry.key;
        break;
      }
    }
    
    print('🎯 Target number: $targetNumber');
    print('🌍 Target mien: $targetMien');
    print('📊 Current gan days (by mien): ${cycleResult.maxGanDays}');

    double lowProfit = 100.0;
    double highProfit = 100000.0;
    List<BettingRow>? bestTable;

    for (int i = 0; i < 30; i++) {
      if (highProfit < lowProfit) break;

      final midProfit = ((lowProfit + highProfit) / 2);
      
      final foundTable = await _optimizeStartBet(
        targetNumber: targetNumber,
        targetMien: targetMien,
        startDate: startDate,
        endDate: endDate,
        startMienIndex: startMienIndex,
        profitTarget: midProfit,
        budgetMin: budgetMin,
        budgetMax: budgetMax,
        lastSeenDate: cycleResult.lastSeenDate,
      );

      if (foundTable != null) {
        final adjustedProfit = midProfit * 3 / 4.2;
        bestTable = await _optimizeStartBet(
          targetNumber: targetNumber,
          targetMien: targetMien,
          startDate: startDate,
          endDate: endDate,
          startMienIndex: startMienIndex,
          profitTarget: adjustedProfit,
          budgetMin: budgetMin,
          budgetMax: budgetMax,
          lastSeenDate: cycleResult.lastSeenDate,
        );
        lowProfit = midProfit + 1;
      } else {
        highProfit = midProfit - 1;
      }
    }

    if (bestTable == null) {
      // ✅ THÊM: Thử tạo 1 lần cuối để lấy số tiền thực tế
      final testResult = await _optimizeStartBet(
        targetNumber: targetNumber,
        targetMien: targetMien,
        startDate: startDate,
        endDate: endDate,
        startMienIndex: startMienIndex,
        profitTarget: 100.0,  // Profit thấp nhất
        budgetMin: 0,  // Bỏ qua budget check
        budgetMax: double.infinity,
        lastSeenDate: cycleResult.lastSeenDate,
      );
      
      if (testResult != null && testResult.isNotEmpty) {
        final actualTotal = testResult.last.tongTien;
        throw Exception(
          'Không thể tạo bảng cược phù hợp!\n'
          'Ngân sách tối đa: ${NumberUtils.formatCurrency(budgetMax)} VNĐ\n'
          'Tổng tiền tối thiểu cần: ${NumberUtils.formatCurrency(actualTotal)} VNĐ\n'
          'Thiếu: ${NumberUtils.formatCurrency(actualTotal - budgetMax)} VNĐ'
        );
      }
      
      throw Exception('Không thể tạo bảng cược phù hợp');
    }

    return bestTable;
  }

  Future<List<BettingRow>?> _optimizeStartBet({
    required String targetNumber,
    required String targetMien,
    required DateTime startDate,
    required DateTime endDate,
    required int startMienIndex,
    required double profitTarget,
    required double budgetMin,
    required double budgetMax,
    required DateTime lastSeenDate,
  }) async {
    double lowBet = 1.0;
    double highBet = 1000.0;
    List<BettingRow>? bestTable;

    for (int i = 0; i < 30; i++) {
      if (highBet < lowBet) break;

      double midBet = ((lowBet + highBet) / 2);
      if (midBet < 1.0) midBet = 1.0;

      final result = await _calculateTable(
        targetNumber: targetNumber,
        targetMien: targetMien,
        startDate: startDate,
        endDate: endDate,
        startMienIndex: startMienIndex,
        startBetValue: midBet,
        profitTarget: profitTarget,
        lastSeenDate: lastSeenDate,
      );

      final tableData = result['table'] as List<BettingRow>;
      final tongTien = result['tong_tien'] as double;

      if (tongTien >= budgetMin && tongTien <= budgetMax) {
        bestTable = tableData;
        highBet = midBet - 1;
      } else if (tongTien > budgetMax) {
        highBet = midBet - 1;
      } else {
        lowBet = midBet + 1;
      }
    }

    return bestTable;
  }

  Future<Map<String, dynamic>> _calculateTable({
    required String targetNumber,
    required String targetMien,
    required DateTime startDate,
    required DateTime endDate,
    required int startMienIndex,
    required double startBetValue,
    required double profitTarget,
    required DateTime lastSeenDate,
  }) async {
    final tableData = <BettingRow>[];
    double tongTien = 0.0;
    
    // ✅ Đếm số lần quay của targetMien từ lastSeenDate đến startDate
    int mienCount = _countTargetMienOccurrences(
      startDate: lastSeenDate,
      endDate: startDate,
      targetMien: targetMien,
    );
    
    print('📊 Initial mienCount (from lastSeenDate to startDate): $mienCount');
    
    final maxMienCount = 9;
    
    int stt = 1;
    DateTime currentDate = startDate;
    
    bool isFirstDay = true;

    outerLoop:
    while (mienCount < maxMienCount && currentDate.isBefore(endDate.add(Duration(days: 1)))) {
      final ngayStr = date_utils.DateUtils.formatDate(currentDate);
      final weekday = date_utils.DateUtils.getWeekday(currentDate);

      final initialMienIdx = isFirstDay ? startMienIndex : 0;
      final mienOrder = ['Nam', 'Trung', 'Bắc'];

      print('📅 Date: $ngayStr, weekday: $weekday, startMienIdx: $initialMienIdx, isFirstDay: $isFirstDay');

      for (int i = initialMienIdx; i < mienOrder.length; i++) {
        final mien = mienOrder[i];
        
        final soLo = NumberUtils.calculateSoLo(mien, weekday);

        if (98 - soLo <= 0) {
          print('   ⚠️ Skip $mien (invalid soLo)');
          continue;
        }

        final requiredBet = (tongTien + profitTarget) / (98 - soLo);

        double tienCuoc1So = startBetValue;
        if (tableData.isNotEmpty) {
          final lastBet = tableData.last.cuocSo;
          tienCuoc1So = max(lastBet, requiredBet);
        }

        tienCuoc1So = tienCuoc1So.ceilToDouble();

        final tienCuocMien = tienCuoc1So * soLo;
        tongTien += tienCuocMien;

        final tienLoi1So = (tienCuoc1So * 98) - tongTien;
        final tienLoi2So = (tienCuoc1So * 98 * 2) - tongTien;

        //print('   ✅ Add row: STT=$stt, Mien=$mien, So=$targetNumber, SoLo=$soLo, Cuoc=$tienCuoc1So, Tong=$tongTien');

        tableData.add(BettingRow.forCycle(
          stt: stt++,
          ngay: ngayStr,
          mien: mien,
          so: targetNumber,
          soLo: soLo,
          cuocSo: tienCuoc1So,
          cuocMien: tienCuocMien,
          tongTien: tongTien,
          loi1So: tienLoi1So,
          loi2So: tienLoi2So,
        ));
        
        if (mien == targetMien) {
          mienCount++;
          //print('   🎯 Target mien count: $mienCount/$maxMienCount');
          
          if (mienCount >= maxMienCount) {
            print('   ✅ Reached max mien count (9), stopping...');
            break outerLoop;
          }
        }
      }

      isFirstDay = false;
      currentDate = currentDate.add(Duration(days: 1));
    }

    print('✅ Table generation completed: ${tableData.length} rows, total: $tongTien');

    return {
      'table': tableData,
      'tong_tien': tongTien,  // ✅ Trả về tổng tiền cuối cùng (tại lần 9)
    };
  }

  // ✅ NEW HELPER: Đếm số lần quay của targetMien từ startDate đến endDate
  int _countTargetMienOccurrences({
    required DateTime startDate,
    required DateTime endDate,
    required String targetMien,
  }) {
    int count = 0;
    DateTime current = startDate.add(Duration(days: 1)); // Bắt đầu từ ngày sau lastSeenDate
    
    while (current.isBefore(endDate) || current.isAtSameMomentAs(endDate)) {
      // ✅ Mọi miền đều quay mỗi ngày
      count++;
      current = current.add(Duration(days: 1));
    }
    
    return count;
  }

  /// ✅ Generate Bắc Gan Table (chỉ cược Miền Bắc, multiplier 99)
  Future<List<BettingRow>> generateBacGanTable({
    required CycleAnalysisResult cycleResult,
    required DateTime startDate,
    required DateTime endDate,
    required double budgetMin,
    required double budgetMax,
  }) async {
    final targetNumber = cycleResult.targetNumber;
    
    print('🎯 Generating Bắc Gan Table');
    print('   Target number: $targetNumber');
    print('   Start: ${date_utils.DateUtils.formatDate(startDate)}');
    print('   End: ${date_utils.DateUtils.formatDate(endDate)}');
    print('   Duration base: $_bacGanDurationBase days');
    print('   Win multiplier: $_bacGanWinMultiplier');

    // Tối ưu lợi nhuận
    double lowProfit = 100.0;
    double highProfit = 100000.0;
    List<BettingRow>? bestTable;

    for (int i = 0; i < 30; i++) {
      if (highProfit < lowProfit) break;

      final midProfit = ((lowProfit + highProfit) / 2);
      
      final foundTable = await _optimizeStartBetForBacGan(
        targetNumber: targetNumber,
        startDate: startDate,
        endDate: endDate,
        profitTarget: midProfit,
        budgetMin: budgetMin,
        budgetMax: budgetMax,
      );

      if (foundTable != null) {
        final adjustedProfit = midProfit * 3 / 4.2;
        bestTable = await _optimizeStartBetForBacGan(
          targetNumber: targetNumber,
          startDate: startDate,
          endDate: endDate,
          profitTarget: adjustedProfit,
          budgetMin: budgetMin,
          budgetMax: budgetMax,
        );
        lowProfit = midProfit + 1;
      } else {
        highProfit = midProfit - 1;
      }
    }

    if (bestTable == null) {
      // ✅ THÊM: Thử tạo 1 lần để lấy số tiền thực tế
      final testTable = await _calculateBacGanTable(
        targetNumber: targetNumber,
        startDate: startDate,
        endDate: endDate,
        startBetValue: 1.0,
        profitTarget: 100.0,
      );
      
      if (testTable['table'] != null) {
        final actualTotal = testTable['tong_tien'] as double;
        throw Exception(
          'Không thể tạo bảng cược Bắc gan phù hợp!\n'
          'Ngân sách tối đa: ${NumberUtils.formatCurrency(budgetMax)} VNĐ\n'
          'Tổng tiền tối thiểu cần: ${NumberUtils.formatCurrency(actualTotal)} VNĐ\n'
          'Thiếu: ${NumberUtils.formatCurrency(actualTotal - budgetMax)} VNĐ'
        );
      }
      
      throw Exception('Không thể tạo bảng cược Bắc gan phù hợp');
    }

    return bestTable;
  }

  /// Helper: Optimize start bet for Bắc Gan
  Future<List<BettingRow>?> _optimizeStartBetForBacGan({
    required String targetNumber,
    required DateTime startDate,
    required DateTime endDate,
    required double profitTarget,
    required double budgetMin,
    required double budgetMax,
  }) async {
    double lowBet = 1.0;
    double highBet = 1000.0;
    List<BettingRow>? bestTable;

    for (int i = 0; i < 30; i++) {
      if (highBet < lowBet) break;

      double midBet = ((lowBet + highBet) / 2);
      if (midBet < 1.0) midBet = 1.0;

      final result = await _calculateBacGanTable(
        targetNumber: targetNumber,
        startDate: startDate,
        endDate: endDate,
        startBetValue: midBet,
        profitTarget: profitTarget,
      );

      final tableData = result['table'] as List<BettingRow>;
      final tongTien = result['tong_tien'] as double;

      if (tongTien >= budgetMin && tongTien <= budgetMax) {
        bestTable = tableData;
        highBet = midBet - 1;
      } else if (tongTien > budgetMax) {
        highBet = midBet - 1;
      } else {
        lowBet = midBet + 1;
      }
    }

    return bestTable;
  }

  /// Helper: Calculate Bắc Gan Table
  Future<Map<String, dynamic>> _calculateBacGanTable({
    required String targetNumber,
    required DateTime startDate,
    required DateTime endDate,
    required double startBetValue,
    required double profitTarget,
  }) async {
    final tableData = <BettingRow>[];
    double tongTien = 0.0;
    
    int stt = 1;
    DateTime currentDate = startDate;
    int dayCount = 0;

    // ✅ FIXED: CHỈ CƯỢC MIỀN BẮC, LOOP ĐẾN KHI ĐẠT 35 NGÀY
    // KHÔNG CẦN đếm mienCount từ trước vì đây là bảng riêng
    while (dayCount < _bacGanDurationBase && 
           currentDate.isBefore(endDate.add(Duration(days: 1)))) {
      
      final ngayStr = date_utils.DateUtils.formatDate(currentDate);
      final weekday = date_utils.DateUtils.getWeekday(currentDate);

      final mien = 'Bắc';
      final soLo = NumberUtils.calculateSoLo(mien, weekday);

      if (_bacGanWinMultiplier - soLo <= 0) {
        currentDate = currentDate.add(Duration(days: 1));
        continue;
      }

      final requiredBet = (tongTien + profitTarget) / (_bacGanWinMultiplier - soLo);

      double tienCuoc1So = startBetValue;
      if (tableData.isNotEmpty) {
        final lastBet = tableData.last.cuocSo;
        tienCuoc1So = max(lastBet, requiredBet);
      }

      tienCuoc1So = tienCuoc1So.ceilToDouble();

      final tienCuocMien = tienCuoc1So * soLo;
      tongTien += tienCuocMien;

      final tienLoi1So = (tienCuoc1So * _bacGanWinMultiplier) - tongTien;
      final tienLoi2So = (tienCuoc1So * _bacGanWinMultiplier * 2) - tongTien;

      tableData.add(BettingRow.forCycle(
        stt: stt++,
        ngay: ngayStr,
        mien: mien,
        so: targetNumber,
        soLo: soLo,
        cuocSo: tienCuoc1So,
        cuocMien: tienCuocMien,
        tongTien: tongTien,
        loi1So: tienLoi1So,
        loi2So: tienLoi2So,
      ));
      
      dayCount++;
      currentDate = currentDate.add(Duration(days: 1));
    }

    print('✅ Bac Gan table completed: ${tableData.length} rows, total: $tongTien');

    return {
      'table': tableData,
      'tong_tien': tongTien,
    };
  }

  /// ✅ Generate Trung Gan Table (chỉ cược Miền Trung, multiplier 98)
  Future<List<BettingRow>> generateTrungGanTable({
    required CycleAnalysisResult cycleResult,
    required DateTime startDate,
    required DateTime endDate,
    required double budgetMin,
    required double budgetMax,
  }) async {
    final targetNumber = cycleResult.targetNumber;
    
    print('🎯 Generating Trung Gan Table');
    print('   Target number: $targetNumber');
    print('   Start: ${date_utils.DateUtils.formatDate(startDate)}');
    print('   End: ${date_utils.DateUtils.formatDate(endDate)}');
    print('   Duration base: $_trungGanDurationBase days');
    print('   Win multiplier: $_trungGanWinMultiplier');

    // Tối ưu lợi nhuận
    double lowProfit = 100.0;
    double highProfit = 100000.0;
    List<BettingRow>? bestTable;

    for (int i = 0; i < 30; i++) {
      if (highProfit < lowProfit) break;

      final midProfit = ((lowProfit + highProfit) / 2);
      
      final foundTable = await _optimizeStartBetForTrungGan(
        targetNumber: targetNumber,
        startDate: startDate,
        endDate: endDate,
        profitTarget: midProfit,
        budgetMin: budgetMin,
        budgetMax: budgetMax,
      );

      if (foundTable != null) {
        final adjustedProfit = midProfit * 3 / 4.2;
        bestTable = await _optimizeStartBetForTrungGan(
          targetNumber: targetNumber,
          startDate: startDate,
          endDate: endDate,
          profitTarget: adjustedProfit,
          budgetMin: budgetMin,
          budgetMax: budgetMax,
        );
        lowProfit = midProfit + 1;
      } else {
        highProfit = midProfit - 1;
      }
    }

    if (bestTable == null) {
      // ✅ THÊM: Thử tạo 1 lần để lấy số tiền thực tế
      final testTable = await _calculateTrungGanTable(
        targetNumber: targetNumber,
        startDate: startDate,
        endDate: endDate,
        startBetValue: 1.0,
        profitTarget: 100.0,
      );
      
      if (testTable['table'] != null) {
        final actualTotal = testTable['tong_tien'] as double;
        throw Exception(
          'Không thể tạo bảng cược Trung gan phù hợp!\n'
          'Ngân sách tối đa: ${NumberUtils.formatCurrency(budgetMax)} VNĐ\n'
          'Tổng tiền tối thiểu cần: ${NumberUtils.formatCurrency(actualTotal)} VNĐ\n'
          'Thiếu: ${NumberUtils.formatCurrency(actualTotal - budgetMax)} VNĐ'
        );
      }
      
      throw Exception('Không thể tạo bảng cược Trung gan phù hợp');
    }

    return bestTable;
  }

  /// Helper: Optimize start bet for Trung Gan
  Future<List<BettingRow>?> _optimizeStartBetForTrungGan({
    required String targetNumber,
    required DateTime startDate,
    required DateTime endDate,
    required double profitTarget,
    required double budgetMin,
    required double budgetMax,
  }) async {
    double lowBet = 1.0;
    double highBet = 1000.0;
    List<BettingRow>? bestTable;

    for (int i = 0; i < 30; i++) {
      if (highBet < lowBet) break;

      double midBet = ((lowBet + highBet) / 2);
      if (midBet < 1.0) midBet = 1.0;

      final result = await _calculateTrungGanTable(
        targetNumber: targetNumber,
        startDate: startDate,
        endDate: endDate,
        startBetValue: midBet,
        profitTarget: profitTarget,
      );

      final tableData = result['table'] as List<BettingRow>;
      final tongTien = result['tong_tien'] as double;

      if (tongTien >= budgetMin && tongTien <= budgetMax) {
        bestTable = tableData;
        highBet = midBet - 1;
      } else if (tongTien > budgetMax) {
        highBet = midBet - 1;
      } else {
        lowBet = midBet + 1;
      }
    }

    return bestTable;
  }

  /// Helper: Calculate Trung Gan Table
  Future<Map<String, dynamic>> _calculateTrungGanTable({
    required String targetNumber,
    required DateTime startDate,
    required DateTime endDate,
    required double startBetValue,
    required double profitTarget,
  }) async {
    final tableData = <BettingRow>[];
    double tongTien = 0.0;
    
    int stt = 1;
    DateTime currentDate = startDate;
    int dayCount = 0;

    // ✅ FIXED: CHỈ CƯỢC MIỀN TRUNG, LOOP ĐẾN KHI ĐẠT 30 NGÀY
    // KHÔNG CẦN đếm mienCount từ trước vì đây là bảng riêng
    while (dayCount < _trungGanDurationBase && 
           currentDate.isBefore(endDate.add(Duration(days: 1)))) {
      
      final ngayStr = date_utils.DateUtils.formatDate(currentDate);
      final weekday = date_utils.DateUtils.getWeekday(currentDate);

      final mien = 'Trung';
      final soLo = NumberUtils.calculateSoLo(mien, weekday);

      if (_trungGanWinMultiplier - soLo <= 0) {
        currentDate = currentDate.add(Duration(days: 1));
        continue;
      }

      final requiredBet = (tongTien + profitTarget) / (_trungGanWinMultiplier - soLo);

      double tienCuoc1So = startBetValue;
      if (tableData.isNotEmpty) {
        final lastBet = tableData.last.cuocSo;
        tienCuoc1So = max(lastBet, requiredBet);
      }

      tienCuoc1So = tienCuoc1So.ceilToDouble();

      final tienCuocMien = tienCuoc1So * soLo;
      tongTien += tienCuocMien;

      final tienLoi1So = (tienCuoc1So * _trungGanWinMultiplier) - tongTien;
      final tienLoi2So = (tienCuoc1So * _trungGanWinMultiplier * 2) - tongTien;

      tableData.add(BettingRow.forCycle(
        stt: stt++,
        ngay: ngayStr,
        mien: mien,
        so: targetNumber,
        soLo: soLo,
        cuocSo: tienCuoc1So,
        cuocMien: tienCuocMien,
        tongTien: tongTien,
        loi1So: tienLoi1So,
        loi2So: tienLoi2So,
      ));
      
      dayCount++;
      currentDate = currentDate.add(Duration(days: 1));
    }

    print('✅ Trung Gan table completed: ${tableData.length} rows, total: $tongTien');

    return {
      'table': tableData,
      'tong_tien': tongTien,
    };
  }
}