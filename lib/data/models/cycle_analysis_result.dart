class CycleAnalysisResult {
  final Set<String> ganNumbers;
  final int maxGanDays;
  final DateTime lastSeenDate;
  final Map<String, List<String>> mienGroups;
  final String targetNumber;

  CycleAnalysisResult({
    required this.ganNumbers,
    required this.maxGanDays,
    required this.lastSeenDate,
    required this.mienGroups,
    required this.targetNumber,
  });

  String get ganNumbersDisplay => ganNumbers.join(', ');
}