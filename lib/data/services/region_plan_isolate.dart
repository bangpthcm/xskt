// lib/data/services/region_plan_isolate.dart
//
// ✅ MỤC ĐÍCH: Gộp toàn bộ phần tính toán NẶNG NHẤT của app
// (AnalysisService.findOptimalStartDateForCycle + preview generateTable)
// thành 1 lệnh compute() DUY NHẤT, chạy trên isolate nền.
//
// Trước đây: findOptimalStartDateForCycle chạy trực tiếp trên main/UI isolate,
// bên trong nó lặp tới 45 lần, mỗi lần lại gọi generateCycleTable (lặp tới
// 22 x 22 x 100 bước) => hàng triệu phép tính chặn UI thread => app bị treo.
//
// Bây giờ: toàn bộ chuỗi này được gói trong 1 hàm static, gửi sang isolate
// khác qua compute(), UI thread hoàn toàn rảnh trong lúc tính.

import 'package:flutter/foundation.dart';

import '../models/betting_row.dart';
import '../models/cycle_analysis_result.dart';
import '../models/lottery_result.dart';
import 'analysis_service.dart';
import 'betting_table_service.dart';

enum _MienTarget { tatca, nam, trung, bac }

/// Toàn bộ dữ liệu đầu vào cần thiết để tính plan cho 1 miền.
/// Đây phải là các object "sendable" (không chứa closure/Service/instance
/// có network) để Dart có thể copy sang isolate khác.
class RegionPlanIsolateParams {
  final String mienName; // 'Tất cả' | 'Nam' | 'Trung' | 'Bắc'
  final CycleAnalysisResult cycleResult;
  final List<LotteryResult> allResults;
  final DateTime baseStartDate;
  final DateTime endDate;
  final String endMien;
  final double availableBudget;
  final double budgetMin;
  final int maxMienCount;

  RegionPlanIsolateParams({
    required this.mienName,
    required this.cycleResult,
    required this.allResults,
    required this.baseStartDate,
    required this.endDate,
    required this.endMien,
    required this.availableBudget,
    required this.budgetMin,
    required this.maxMienCount,
  });
}

class RegionPlanIsolateResult {
  final DateTime? startDate;
  final int startMienIndex;
  final double? loi1So;
  final bool hasBudgetError;

  RegionPlanIsolateResult({
    this.startDate,
    this.startMienIndex = 0,
    this.loi1So,
  }) : hasBudgetError = startDate == null;
}

class RegionPlanIsolate {
  /// Entry point công khai — gọi hàm này từ ViewModel (main isolate).
  /// compute() sẽ tự spawn 1 isolate riêng để chạy _computeHeavy.
  static Future<RegionPlanIsolateResult> run(
      RegionPlanIsolateParams params) async {
    return compute(_computeHeavy, params);
  }

  /// Chạy song song nhiều miền cùng lúc, mỗi miền 1 isolate riêng.
  /// Nhanh hơn nhiều so với chạy tuần tự (await từng cái).
  static Future<Map<String, RegionPlanIsolateResult>> runMultiple(
      Map<String, RegionPlanIsolateParams> paramsByMien) async {
    final entries = paramsByMien.entries.toList();
    final results = await Future.wait(
      entries.map((e) => run(e.value)),
    );
    return {
      for (int i = 0; i < entries.length; i++) entries[i].key: results[i],
    };
  }

  // ⚠️ Hàm này chạy TRÊN ISOLATE KHÁC — không được truy cập bất kỳ state
  // nào của UI/ViewModel, chỉ được dùng dữ liệu có trong `params`.
  static Future<RegionPlanIsolateResult> _computeHeavy(
      RegionPlanIsolateParams params) async {
    // Tạo instance mới trong isolate này — BettingTableService không có
    // field nào nên khởi tạo lại hoàn toàn an toàn & rẻ.
    final bettingService = BettingTableService();

    final target = _mapMien(params.mienName);

    final optimalResult = await AnalysisService.findOptimalStartDateForCycle(
      baseStartDate: params.baseStartDate,
      endDate: params.endDate,
      endMien: params.endMien,
      availableBudget: params.availableBudget,
      budgetMin: params.budgetMin,
      mien: params.mienName,
      targetNumber: params.cycleResult.targetNumber,
      cycleResult: params.cycleResult,
      allResults: params.allResults,
      bettingService: bettingService,
      maxMienCount: params.maxMienCount,
    );

    if (optimalResult == null) {
      // Không tìm được ngày bắt đầu phù hợp trong ngân sách => thiếu vốn
      return RegionPlanIsolateResult();
    }

    final durationLimit = params.endDate.difference(optimalResult.date).inDays;

    double? loi1So;
    try {
      List<BettingRow> preview;
      switch (target) {
        case _MienTarget.tatca:
          preview = await bettingService.generateCycleTable(
            cycleResult: params.cycleResult,
            startDate: optimalResult.date,
            endDate: params.endDate,
            endMien: params.endMien,
            startMienIndex: optimalResult.mienIndex,
            budgetMin: params.budgetMin,
            budgetMax: params.availableBudget,
            allResults: params.allResults,
            maxMienCount: durationLimit,
            durationLimit: durationLimit,
          );
          break;
        case _MienTarget.nam:
          preview = await bettingService.generateNamGanTable(
            cycleResult: params.cycleResult,
            startDate: optimalResult.date,
            endDate: params.endDate,
            budgetMin: params.budgetMin,
            budgetMax: params.availableBudget,
            durationLimit: durationLimit,
          );
          break;
        case _MienTarget.trung:
          preview = await bettingService.generateTrungGanTable(
            cycleResult: params.cycleResult,
            startDate: optimalResult.date,
            endDate: params.endDate,
            budgetMin: params.budgetMin,
            budgetMax: params.availableBudget,
            durationLimit: durationLimit,
          );
          break;
        case _MienTarget.bac:
          preview = await bettingService.generateBacGanTable(
            cycleResult: params.cycleResult,
            startDate: optimalResult.date,
            endDate: params.endDate,
            budgetMin: params.budgetMin,
            budgetMax: params.availableBudget,
            durationLimit: durationLimit,
          );
          break;
      }
      if (preview.isNotEmpty) loi1So = preview.last.loi1So;
    } catch (_) {
      // Không tính được preview lời 1 số -> vẫn giữ ngày tối ưu tìm được
    }

    return RegionPlanIsolateResult(
      startDate: optimalResult.date,
      startMienIndex: optimalResult.mienIndex,
      loi1So: loi1So,
    );
  }

  static _MienTarget _mapMien(String mien) {
    final n = mien.toLowerCase();
    if (n.contains('nam')) return _MienTarget.nam;
    if (n.contains('trung')) return _MienTarget.trung;
    if (n.contains('bắc') || n.contains('bac')) return _MienTarget.bac;
    return _MienTarget.tatca;
  }
}
