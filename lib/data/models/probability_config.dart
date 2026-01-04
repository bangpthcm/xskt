// lib/data/models/probability_config.dart

class ProbabilityConfig {
  final double thresholdLnTatCa;
  final double thresholdLnNam; // ✅ THÊM
  final double thresholdLnTrung;
  final double thresholdLnBac;
  final double thresholdLnXien;

  ProbabilityConfig({
    this.thresholdLnTatCa = -167.5848846,
    this.thresholdLnNam = -44.75945663, // ✅ THÊM (Giá trị mặc định cho Nam)
    this.thresholdLnTrung = -47.91175079,
    this.thresholdLnBac = -27.41528511,
    this.thresholdLnXien = -349.9847258,
  });

  bool get isValid {
    return _isValidLnThreshold(thresholdLnTatCa) &&
        _isValidLnThreshold(thresholdLnNam) && // ✅ THÊM Validate
        _isValidLnThreshold(thresholdLnTrung) &&
        _isValidLnThreshold(thresholdLnBac) &&
        _isValidLnThreshold(thresholdLnXien);
  }

  static bool _isValidLnThreshold(double thresholdLn) {
    return thresholdLn >= -500.0 && thresholdLn <= -2.0;
  }

  double getThresholdLn(String mien) {
    switch (mien.toLowerCase()) {
      case 'tatca':
      case 'tất cả':
      case 'all':
        return thresholdLnTatCa;
      case 'nam': // ✅ THÊM CASE NAM
      case 'miền nam':
        return thresholdLnNam;
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
          (json['thresholdLnTatCa'] as num?)?.toDouble() ?? -167.5848846,
      thresholdLnNam: (json['thresholdLnNam'] as num?)?.toDouble() ??
          -44.75945663, // ✅ THÊM
      thresholdLnTrung:
          (json['thresholdLnTrung'] as num?)?.toDouble() ?? -47.91175079,
      thresholdLnBac:
          (json['thresholdLnBac'] as num?)?.toDouble() ?? -27.41528511,
      thresholdLnXien:
          (json['thresholdLnXien'] as num?)?.toDouble() ?? -349.9847258,
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
