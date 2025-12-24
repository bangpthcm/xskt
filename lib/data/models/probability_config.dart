// lib/data/models/probability_config.dart

// ✅ CẬP NHẬT: Chuyển đổi toàn bộ sang Logarithm tự nhiên (ln)
class ProbabilityConfig {
  final double thresholdLnTatCa; // Ngưỡng Log cho Tất cả
  final double thresholdLnTrung; // Ngưỡng Log cho Trung
  final double thresholdLnBac; // Ngưỡng Log cho Bắc
  final double thresholdLnXien; // Ngưỡng Log cho Xiên

  ProbabilityConfig({
    // Giá trị cũ: 1.18604e-75 -> ln(...) ≈ -172.63
    this.thresholdLnTatCa = -172.63,
    // Giá trị cũ: 5.56464e-49 -> ln(...) ≈ -111.11
    this.thresholdLnTrung = -111.11,
    // Giá trị cũ: 7.74656e-53 -> ln(...) ≈ -120.08
    this.thresholdLnBac = -120.08,
    // Giá trị cũ: 1.97e-6     -> ln(...) ≈ -13.14
    this.thresholdLnXien = -13.14,
  });

  // ✅ Validation: Kiểm tra ngưỡng Log hợp lý (thường là số âm lớn)
  bool get isValid {
    return _isValidLnThreshold(thresholdLnTatCa) &&
        _isValidLnThreshold(thresholdLnTrung) &&
        _isValidLnThreshold(thresholdLnBac) &&
        _isValidLnThreshold(thresholdLnXien);
  }

  // Ngưỡng Log thường nằm trong khoảng -500 đến -2
  static bool _isValidLnThreshold(double thresholdLn) {
    return thresholdLn >= -500.0 && thresholdLn <= -2.0;
  }

  // ✅ Helper: Lấy ngưỡng theo miền
  double getThresholdLn(String mien) {
    switch (mien.toLowerCase()) {
      case 'tatca':
      case 'tất cả':
      case 'all':
        return thresholdLnTatCa;
      case 'trung':
      case 'miền trung':
        return thresholdLnTrung;
      case 'bac':
      case 'bắc':
      case 'miền bắc':
        return thresholdLnBac;
      case 'xien':
      case 'xiên':
      case 'xiên bắc':
        return thresholdLnXien;
      default:
        return thresholdLnTatCa;
    }
  }

  // ✅ Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'thresholdLnTatCa': thresholdLnTatCa,
      'thresholdLnTrung': thresholdLnTrung,
      'thresholdLnBac': thresholdLnBac,
      'thresholdLnXien': thresholdLnXien,
    };
  }

  // ✅ Parse from JSON
  factory ProbabilityConfig.fromJson(Map<String, dynamic> json) {
    return ProbabilityConfig(
      thresholdLnTatCa:
          (json['thresholdLnTatCa'] as num?)?.toDouble() ?? -172.63,
      thresholdLnTrung:
          (json['thresholdLnTrung'] as num?)?.toDouble() ?? -111.11,
      thresholdLnBac: (json['thresholdLnBac'] as num?)?.toDouble() ?? -120.08,
      thresholdLnXien: (json['thresholdLnXien'] as num?)?.toDouble() ?? -13.14,
    );
  }

  // ✅ Default factory
  factory ProbabilityConfig.defaults() {
    return ProbabilityConfig();
  }

  // ✅ CopyWith
  ProbabilityConfig copyWith({
    double? thresholdLnTatCa,
    double? thresholdLnTrung,
    double? thresholdLnBac,
    double? thresholdLnXien,
  }) {
    return ProbabilityConfig(
      thresholdLnTatCa: thresholdLnTatCa ?? this.thresholdLnTatCa,
      thresholdLnTrung: thresholdLnTrung ?? this.thresholdLnTrung,
      thresholdLnBac: thresholdLnBac ?? this.thresholdLnBac,
      thresholdLnXien: thresholdLnXien ?? this.thresholdLnXien,
    );
  }

  @override
  String toString() {
    // Hiển thị số thực đơn giản, không cần scientific notation nữa
    return 'ProbabilityConfig(Ln values: '
        'All: ${thresholdLnTatCa.toStringAsFixed(2)}, '
        'Trung: ${thresholdLnTrung.toStringAsFixed(2)}, '
        'Bac: ${thresholdLnBac.toStringAsFixed(2)}, '
        'Xien: ${thresholdLnXien.toStringAsFixed(2)})';
  }
}

// Model giữ nguyên, chỉ đổi tên field cho rõ nghĩa nếu cần
class ProbabilityAnalysisResult {
  final String targetNumber;
  final double currentLogProbability; // Đổi tên từ currentProbability
  final int currentGanDays;
  final DateTime projectedEndDate;
  final DateTime entryDate;
  final int additionalDaysNeeded;
  final Map<String, double>
      logProbabilities; // Lưu các giá trị ln(P1), ln(P2)...
  final String mien;

  ProbabilityAnalysisResult({
    required this.targetNumber,
    required this.currentLogProbability,
    required this.currentGanDays,
    required this.projectedEndDate,
    required this.entryDate,
    required this.additionalDaysNeeded,
    required this.logProbabilities,
    required this.mien,
  });
}
