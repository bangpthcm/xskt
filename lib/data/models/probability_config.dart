// lib/data/models/probability_config.dart

class ProbabilityConfig {
  final double thresholdLnTatCa;
  final double thresholdLnNam; // ✅ THÊM
  final double thresholdLnTrung;
  final double thresholdLnBac;
  final double thresholdLnXien;

  ProbabilityConfig({
    this.thresholdLnTatCa = -22.08040323, // P= -15
    this.thresholdLnNam = -22.35514584, // ✅ THÊM (Giá trị mặc định cho Nam)
    this.thresholdLnTrung = -24.85461559,
    this.thresholdLnBac = -21.83610792,
    this.thresholdLnXien = -502.3605773,
  });

  bool get isValid {
    return _isValidLnThreshold(thresholdLnTatCa) &&
        _isValidLnThreshold(thresholdLnNam) && // ✅ THÊM Validate
        _isValidLnThreshold(thresholdLnTrung) &&
        _isValidLnThreshold(thresholdLnBac) &&
        _isValidLnThreshold(thresholdLnXien);
  }

  static bool _isValidLnThreshold(double thresholdLn) {
    return thresholdLn >= -700.0 && thresholdLn <= -2.0;
  }

  Map<String, dynamic> toJson() {
    return {
      'thresholdLnTatCa': thresholdLnTatCa,
      'thresholdLnNam': thresholdLnNam, // ✅ THÊM
      'thresholdLnTrung': thresholdLnTrung,
      'thresholdLnBac': thresholdLnBac,
      'thresholdLnXien': thresholdLnXien,
    };
  }

  factory ProbabilityConfig.fromJson(Map<String, dynamic> json) {
    return ProbabilityConfig(
      thresholdLnTatCa:
          (json['thresholdLnTatCa'] as num?)?.toDouble() ?? -22.08040323,
      thresholdLnNam: (json['thresholdLnNam'] as num?)?.toDouble() ??
          -22.35514584, // ✅ THÊM
      thresholdLnTrung:
          (json['thresholdLnTrung'] as num?)?.toDouble() ?? -24.85461559,
      thresholdLnBac:
          (json['thresholdLnBac'] as num?)?.toDouble() ?? -21.83610792,
      thresholdLnXien:
          (json['thresholdLnXien'] as num?)?.toDouble() ?? -502.3605773,
    );
  }

  factory ProbabilityConfig.defaults() {
    return ProbabilityConfig();
  }

  ProbabilityConfig copyWith({
    double? thresholdLnTatCa,
    double? thresholdLnNam, // ✅ THÊM
    double? thresholdLnTrung,
    double? thresholdLnBac,
    double? thresholdLnXien,
  }) {
    return ProbabilityConfig(
      thresholdLnTatCa: thresholdLnTatCa ?? this.thresholdLnTatCa,
      thresholdLnNam: thresholdLnNam ?? this.thresholdLnNam, // ✅ THÊM
      thresholdLnTrung: thresholdLnTrung ?? this.thresholdLnTrung,
      thresholdLnBac: thresholdLnBac ?? this.thresholdLnBac,
      thresholdLnXien: thresholdLnXien ?? this.thresholdLnXien,
    );
  }

  @override
  String toString() {
    return 'ProbabilityConfig(Ln values: '
        'All: ${thresholdLnTatCa.toStringAsFixed(2)}, '
        'Nam: ${thresholdLnNam.toStringAsFixed(2)}, ' // ✅ THÊM
        'Trung: ${thresholdLnTrung.toStringAsFixed(2)}, '
        'Bac: ${thresholdLnBac.toStringAsFixed(2)}, '
        'Xien: ${thresholdLnXien.toStringAsFixed(2)})';
  }
}

// ... (Giữ nguyên class ProbabilityAnalysisResult)
class ProbabilityAnalysisResult {
  final String targetNumber;
  final double currentLogProbability;
  final int currentGanDays;
  final DateTime projectedEndDate;
  final DateTime entryDate;
  final int additionalDaysNeeded;
  final Map<String, double> logProbabilities;
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
