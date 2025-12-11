// lib/data/models/rebetting_summary.dart

// ✨ THÊM import này
import 'rebetting_candidate.dart';

class RebettingSummary {
  final String mien; // 'Tất cả', 'Nam', 'Trung', 'Bắc'
  final String ngayCoTheVao; // Từ RebettingCandidate (min duration)
  final int totalCandidates; // Tổng ứng viên trước lọc

  RebettingSummary({
    required this.mien,
    required this.ngayCoTheVao,
    required this.totalCandidates,
  });

  @override
  String toString() =>
      'RebettingSummary($mien: $ngayCoTheVao, total: $totalCandidates)';
}

class RebettingResult {
  final Map<String, RebettingSummary?>
      summaries; // Key: 'tatCa', 'nam', 'trung', 'bac'
  final Map<String, RebettingCandidate?>
      selected; // Số được chọn (min duration)

  RebettingResult({
    required this.summaries,
    required this.selected,
  });

  @override
  String toString() => 'RebettingResult('
      'tatCa: ${summaries['tatCa']}, '
      'nam: ${summaries['nam']}, '
      'trung: ${summaries['trung']}, '
      'bac: ${summaries['bac']})';
}
