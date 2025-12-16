// lib/data/models/probability_config.dart

class ProbabilityConfig {
  final double threshold; // Giá trị raw (ví dụ: 5e-12)

  ProbabilityConfig({
    this.threshold = 5e-12,
  });

  // Validation: Range từ 1e-16 đến 3e-11
  bool get isValid => threshold >= 3e-14 && threshold <= 2e-11;

  // SỬA: Bỏ nhân 100, trả về giá trị raw dưới dạng string
  String get thresholdString {
    return threshold.toStringAsExponential(2); // Ví dụ: "2.00e-11"
  }

  // SỬA: Bỏ chia 100, parse trực tiếp giá trị raw
  static double parseString(String str) {
    try {
      return double.parse(str);
    } catch (e) {
      return 5e-12; // Default
    }
  }

  Map<String, dynamic> toJson() => {'threshold': threshold};

  factory ProbabilityConfig.fromJson(Map<String, dynamic> json) {
    return ProbabilityConfig(
      threshold: json['threshold']?.toDouble() ?? 5e-12,
    );
  }

  // ... (giữ nguyên phần còn lại)
  factory ProbabilityConfig.defaults() {
    return ProbabilityConfig(threshold: 5e-12);
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
