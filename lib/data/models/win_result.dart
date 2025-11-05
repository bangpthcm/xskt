// lib/data/models/win_result.dart

class WinResult {
  final double profit;              // Tiền lời
  final int occurrences;            // Số lần trúng
  final String winningMien;         // Miền trúng
  final List<ProvinceWin> provinces; // Các tỉnh trúng với số lần
  final DateTime winDate;           // Ngày trúng
  final String targetNumber;        // Số/cặp mục tiêu
  final double totalBet;            // Tổng tiền đã cược
  final double totalReturn;         // Tổng tiền về

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