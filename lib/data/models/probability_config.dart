// lib/data/models/probability_config.dart

class ProbabilityConfig {
  final double threshold; // Giá trị raw (ví dụ: 2e-14)

  ProbabilityConfig({
    this.threshold = 2e-14, // Default: 0.00000000000002%
  });

  // Validation
  bool get isValid => threshold >= 1e-16 && threshold <= 3e-14;

  // Convert raw value to percentage string for display
  String get thresholdPercentageString {
    final percentage = threshold * 100;
    return percentage.toStringAsExponential(2); // Ví dụ: "2.00e-14"
  }

  // Parse percentage string back to raw value
  static double parsePercentageString(String str) {
    try {
      final percentage = double.parse(str);
      return percentage / 100;
    } catch (e) {
      return 2e-14; // Default
    }
  }

  Map<String, dynamic> toJson() => {'threshold': threshold};

  factory ProbabilityConfig.fromJson(Map<String, dynamic> json) {
    return ProbabilityConfig(
      threshold: json['threshold'] ?? 2e-14,
    );
  }

  factory ProbabilityConfig.defaults() {
    return ProbabilityConfig(threshold: 2e-14);
  }

  ProbabilityConfig copyWith({double? threshold}) {
    return ProbabilityConfig(
      threshold: threshold ?? this.threshold,
    );
  }
}

// Model kết quả phân tích Probability
class ProbabilityAnalysisResult {
  final String targetNumber;
  final double currentProbability; // P_total hiện tại
  final int currentGanDays; // Số ngày gan hiện tại
  final DateTime projectedEndDate; // Ngày dự kiến đạt ngưỡng
  final DateTime entryDate; // Ngày vào cược
  final int additionalDaysNeeded; // Số ngày cần nuôi thêm
  final Map<String, double> probabilities; // P1, P2, P3, P_total
  final String mien; // Miền (Tất cả, Trung, Bắc)

  ProbabilityAnalysisResult({
    required this.targetNumber,
    required this.currentProbability,
    required this.currentGanDays,
    required this.projectedEndDate,
    required this.entryDate,
    required this.additionalDaysNeeded,
    required this.probabilities,
    required this.mien,
  });

  @override
  String toString() {
    return 'ProbabilityAnalysisResult('
        'number: $targetNumber, '
        'P_total: ${currentProbability.toStringAsExponential(4)}, '
        'gan: $currentGanDays days, '
        'need: $additionalDaysNeeded days)';
  }
}
