// lib/data/models/win_result.dart

class WinResult {
  final double profit;
  final int occurrences;
  final String winningMien;
  final List<ProvinceWin> provinces;
  final DateTime winDate;
  final String targetNumber;
  final double totalBet;
  final double totalReturn;

  WinResult({
    required this.profit,
    required this.occurrences,
    required this.winningMien,
    required this.provinces,
    required this.winDate,
    required this.targetNumber,
    required this.totalBet,
    required this.totalReturn,
  });

  bool get isWin => occurrences > 0;
  
  double get roi => totalBet > 0 ? (profit / totalBet) * 100 : 0;

  String get provincesDisplay {
    return provinces.map((p) => '${p.name} (${p.count}x)').join(', ');
  }
}

class ProvinceWin {
  final String name;
  final int count;

  ProvinceWin({
    required this.name,
    required this.count,
  });
}

// Helper class: Kết quả kiểm tra một miền
class MienCheckResult {
  final int occurrences;
  final List<ProvinceWin> provinces;

  MienCheckResult({
    required this.occurrences,
    required this.provinces,
  });

  bool get hasWin => occurrences > 0;
}