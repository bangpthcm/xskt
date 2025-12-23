// lib/data/models/probability_config.dart

// ✅ THAY THẾ: Từ threshold duy nhất → ngưỡng riêng từng loại
class ProbabilityConfig {
  final double thresholdTatCa; // Tất cả (3 miền)
  final double thresholdTrung; // Miền Trung
  final double thresholdBac; // Miền Bắc
  final double thresholdXien; // Xiên Bắc

  ProbabilityConfig({
    this.thresholdTatCa = 1.18604e-75,
    this.thresholdTrung = 5.56464e-49,
    this.thresholdBac = 7.74656e-53,
    this.thresholdXien = 1.97e-6, // Xiên có ngưỡng khác (cao hơn)
  });

  // ✅ Validation: tất cả ngưỡng phải trong range
  bool get isValid {
    return _isValidThreshold(thresholdTatCa) &&
        _isValidThreshold(thresholdTrung) &&
        _isValidThreshold(thresholdBac) &&
        _isValidThreshold(thresholdXien);
  }

  // ✅ Helper: Validate individual threshold
  static bool _isValidThreshold(double threshold) {
    return threshold >= 3e-8 && threshold <= 2e-6;
  }

  // ✅ Helper: Lấy ngưỡng theo loại cược
  double getThreshold(String mien) {
    switch (mien.toLowerCase()) {
      case 'tatca':
      case 'tất cả':
      case 'all':
        return thresholdTatCa;
      case 'trung':
      case 'miền trung':
        return thresholdTrung;
      case 'bac':
      case 'bắc':
      case 'miền bắc':
        return thresholdBac;
      case 'xien':
      case 'xiên':
      case 'xiên bắc':
        return thresholdXien;
      default:
        return thresholdTatCa; // Default
    }
  }

  // ✅ Helper: Convert sang Scientific notation string
  String get thresholdTatCaString => thresholdTatCa.toStringAsExponential(2);
  String get thresholdTrungString => thresholdTrung.toStringAsExponential(2);
  String get thresholdBacString => thresholdBac.toStringAsExponential(2);
  String get thresholdXienString => thresholdXien.toStringAsExponential(2);

  // ✅ Helper: Parse string (scientific notation) thành double
  static double parseString(String str) {
    try {
      final trimmed = str.trim();
      if (trimmed.isEmpty) return 7.74656e-53; // Default
      return double.parse(trimmed);
    } catch (e) {
      print('⚠️ Error parsing threshold string "$str": $e');
      return 7.74656e-53; // Default fallback
    }
  }

  // ✅ Convert to JSON (lưu vào SharedPreferences)
  Map<String, dynamic> toJson() {
    return {
      'thresholdTatCa': thresholdTatCa,
      'thresholdTrung': thresholdTrung,
      'thresholdBac': thresholdBac,
      'thresholdXien': thresholdXien,
    };
  }

  // ✅ Parse từ JSON (load từ SharedPreferences)
  factory ProbabilityConfig.fromJson(Map<String, dynamic> json) {
    return ProbabilityConfig(
      thresholdTatCa:
          (json['thresholdTatCa'] as num?)?.toDouble() ?? 1.18604E-75,
      thresholdTrung:
          (json['thresholdTrung'] as num?)?.toDouble() ?? 5.56464e-49,
      thresholdBac: (json['thresholdBac'] as num?)?.toDouble() ?? 7.74656e-53,
      thresholdXien: (json['thresholdXien'] as num?)?.toDouble() ?? 1.97e-6,
    );
  }

  // ✅ Default config
  factory ProbabilityConfig.defaults() {
    return ProbabilityConfig(
      thresholdTatCa: 1.18604E-75,
      thresholdTrung: 5.56464e-49,
      thresholdBac: 7.74656e-53,
      thresholdXien: 1.97e-6,
    );
  }

  // ✅ Copy with: Tạo bản sao với một số fields thay đổi
  ProbabilityConfig copyWith({
    double? thresholdTatCa,
    double? thresholdTrung,
    double? thresholdBac,
    double? thresholdXien,
  }) {
    return ProbabilityConfig(
      thresholdTatCa: thresholdTatCa ?? this.thresholdTatCa,
      thresholdTrung: thresholdTrung ?? this.thresholdTrung,
      thresholdBac: thresholdBac ?? this.thresholdBac,
      thresholdXien: thresholdXien ?? this.thresholdXien,
    );
  }

  @override
  String toString() {
    return 'ProbabilityConfig('
        'tatCa: $thresholdTatCaString, '
        'trung: $thresholdTrungString, '
        'bac: $thresholdBacString, '
        'xien: $thresholdXienString)';
  }
}

// ============================================================================
// Model kết quả phân tích Probability (GIỮ NGUYÊN)
// ============================================================================

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
