// lib/data/models/cycle_analysis_result.dart

class CycleAnalysisResult {
  final Set<String> ganNumbers;
  final int maxGanDays; // Gan hiện tại (ngày) - Cột E
  final DateTime lastSeenDate; // Ngày cuối - Cột F
  final Map<String, List<String>> mienGroups;
  final String targetNumber; // Số mục tiêu - Cột B

  // Dữ liệu mới từ Sheet analysis_cycle
  final int ganCurrentSlots; // Gan hiện tại (slots) - Cột D
  final int ganCKTruocSlots; // Gan CK trước (slots) - Cột G
  final int ganCKTruocDays; // Gan CK trước (ngày) - Cột H
  final int ganCKKiaSlots; // Gan CK kìa (slots) - Cột I
  final int ganCKKiaDays; // Gan CK kìa (ngày) - Cột J

  // Logic cũ (giữ lại để tương thích, nhưng sẽ tính toán nhẹ hoặc gán default)
  final int historicalGan;
  final int occurrenceCount;
  final double expectedCount;
  final int analysisDays;

  CycleAnalysisResult({
    required this.ganNumbers,
    required this.maxGanDays,
    required this.lastSeenDate,
    required this.mienGroups,
    required this.targetNumber,
    this.ganCurrentSlots = 0,
    this.ganCKTruocSlots = 0,
    this.ganCKTruocDays = 0,
    this.ganCKKiaSlots = 0,
    this.ganCKKiaDays = 0,
    this.historicalGan = 0,
    this.occurrenceCount = 0,
    this.expectedCount = 0.0,
    this.analysisDays = 0,
  });

  String get ganNumbersDisplay => ganNumbers.join(', ');
}
