// lib/data/models/cycle_analysis_result.dart

class CycleAnalysisResult {
  final Set<String> ganNumbers;
  final int maxGanDays; // Đây là ngày gan hiện tại
  final DateTime lastSeenDate;
  final Map<String, List<String>> mienGroups;
  final String targetNumber;

  // Các trường mới thêm theo yêu cầu (Anh phải tự tính toán và map dữ liệu vào đây ở tầng Service)
  final int historicalGan; // Ngày gan quá khứ (cực đại lịch sử)
  final int occurrenceCount; // Số lần xuất hiện thực tế
  final double expectedCount; // Số lần xuất hiện kỳ vọng (kExpected)
  final int analysisDays; // Số ngày trong khoảng phân tích

  CycleAnalysisResult({
    required this.ganNumbers,
    required this.maxGanDays,
    required this.lastSeenDate,
    required this.mienGroups,
    required this.targetNumber,
    this.historicalGan = 0, // Default tạm thời để code không gãy
    this.occurrenceCount = 0,
    this.expectedCount = 0.0,
    this.analysisDays = 0,
  });

  String get ganNumbersDisplay => ganNumbers.join(', ');
}
