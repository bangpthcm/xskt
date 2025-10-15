import 'dart:math';
import '../models/betting_row.dart';
import '../models/gan_pair_info.dart';
import '../models/cycle_analysis_result.dart';
import '../../core/utils/date_utils.dart' as date_utils;
import '../../core/utils/number_utils.dart';

class BettingTableService {
  // ✅ BỎ hard-coded constant
  // static const double _targetBudgetXien = 19000.0;
  
  static const double _winMultiplierXien = 17.0;
  static const int _durationBase = 185;
  static const double _startingProfit = 50.0;
  static const double _finalProfit = 800.0;

  // ✅ THÊM parameter xienBudget
  Future<List<BettingRow>> generateXienTable({
    required GanPairInfo ganInfo,
    required DateTime startDate,
    required double xienBudget,  // ✅ ADD
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

      tienCuocMien = (tienCuocMien * 100).ceil() / 100;
      tongTien += tienCuocMien;
      
      final loi = (tienCuocMien * _winMultiplierXien) - tongTien;

      rawTable.add({
        'ngay': date_utils.DateUtils.formatDate(startDate.add(Duration(days: i))),
        'cuoc_mien': tienCuocMien,
        'tong_tien': tongTien,
        'loi': loi,
      });
    }

    // ✅ Chuẩn hóa theo ngân sách từ config
    final rawTotalCost = rawTable.last['tong_tien'] as double;
    if (rawTotalCost <= 0) {
      throw Exception('Tổng tiền bằng 0');
    }

    final scalingFactor = xienBudget / rawTotalCost;  // ✅ DÙNG parameter

    final finalTable = <BettingRow>[];
    for (int i = 0; i < rawTable.length; i++) {
      final row = rawTable[i];
      finalTable.add(BettingRow.forXien(
        stt: i + 1,
        ngay: row['ngay'],
        mien: 'Bắc',
        so: capSoMucTieu.display,
        cuocMien: (row['cuoc_mien'] as double) * scalingFactor,
        tongTien: (row['tong_tien'] as double) * scalingFactor,
        loi: (row['loi'] as double) * scalingFactor,
      ));
    }

    return finalTable;
  }

  // Tạo bảng cược Chu kỳ
  Future<List<BettingRow>> generateCycleTable({
    required CycleAnalysisResult cycleResult,
    required DateTime startDate,
    required DateTime endDate,
    required int startMienIndex,
    required double budgetMin,
    required double budgetMax,
  }) async {
    final targetNumber = cycleResult.targetNumber;

    // Tối ưu lợi nhuận
    double lowProfit = 100.0;
    double highProfit = 100000.0;
    List<BettingRow>? bestTable;

    for (int i = 0; i < 30; i++) {
      if (highProfit < lowProfit) break;

      final midProfit = ((lowProfit + highProfit) / 2);
      
      final foundTable = await _optimizeStartBet(
        targetNumber: targetNumber,
        startDate: startDate,
        endDate: endDate,
        startMienIndex: startMienIndex,
        profitTarget: midProfit,
        budgetMin: budgetMin,
        budgetMax: budgetMax,
      );

      if (foundTable != null) {
        final adjustedProfit = midProfit * 3 / 4.2;
        bestTable = await _optimizeStartBet(
          targetNumber: targetNumber,
          startDate: startDate,
          endDate: endDate,
          startMienIndex: startMienIndex,
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
      throw Exception('Không thể tạo bảng cược phù hợp');
    }

    return bestTable;
  }

  Future<List<BettingRow>?> _optimizeStartBet({
    required String targetNumber,
    required DateTime startDate,
    required DateTime endDate,
    required int startMienIndex,
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

      final result = await _calculateTable(
        targetNumber: targetNumber,
        startDate: startDate,
        endDate: endDate,
        startMienIndex: startMienIndex,
        startBetValue: midBet,
        profitTarget: profitTarget,
      );

      final tableData = result['table'] as List<BettingRow>;
      final tongTien = result['tong_tien'] as double;

      if (tongTien >= budgetMin && tongTien <= budgetMax) {
        bestTable = tableData;
        highBet = midBet - 0.01;
      } else if (tongTien > budgetMax) {
        highBet = midBet - 0.01;
      } else {
        lowBet = midBet + 0.01;
      }
    }

    return bestTable;
  }

  Future<Map<String, dynamic>> _calculateTable({
    required String targetNumber,
    required DateTime startDate,
    required DateTime endDate,
    required int startMienIndex,
    required double startBetValue,
    required double profitTarget,
  }) async {
    final tableData = <BettingRow>[];
    double tongTien = 0.0;
    bool isFirstDay = true;

    final durationDays = endDate.difference(startDate).inDays + 1;
    int stt = 1;

    for (int dayOffset = 0; dayOffset < durationDays; dayOffset++) {
      final currentDate = startDate.add(Duration(days: dayOffset));
      final ngayStr = date_utils.DateUtils.formatDate(currentDate);
      final weekday = date_utils.DateUtils.getWeekday(currentDate);

      final initialMienIdx = isFirstDay ? startMienIndex : 0;
      final mienOrder = ['Nam', 'Trung', 'Bắc'];

      for (int i = initialMienIdx; i < mienOrder.length; i++) {
        final mien = mienOrder[i];
        final soLo = NumberUtils.calculateSoLo(mien, weekday);

        if (98 - soLo <= 0) continue;

        final requiredBet = (tongTien + profitTarget) / (98 - soLo);

        double tienCuoc1So = startBetValue;
        if (tableData.isNotEmpty) {
          final lastBet = tableData.last.cuocSo;
          tienCuoc1So = max(lastBet, requiredBet);
        }

        tienCuoc1So = (tienCuoc1So * 100).ceil() / 100;

        final tienCuocMien = tienCuoc1So * soLo;
        tongTien += tienCuocMien;

        final tienLoi1So = (tienCuoc1So * 98) - tongTien;
        final tienLoi2So = (tienCuoc1So * 98 * 2) - tongTien;

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
      }

      isFirstDay = false;
    }

    return {
      'table': tableData,
      'tong_tien': tongTien,
    };
  }
}