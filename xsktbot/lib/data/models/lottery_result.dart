class LotteryResult {
  final String ngay;
  final String mien;
  final String tinh;
  final List<String> numbers;

  LotteryResult({
    required this.ngay,
    required this.mien,
    required this.tinh,
    required this.numbers,
  });

  Map<String, dynamic> toMap() {
    return {
      'ngay': ngay,
      'mien': mien,
      'tinh': tinh,
      'numbers': numbers,
    };
  }

  factory LotteryResult.fromMap(Map<String, dynamic> map) {
    return LotteryResult(
      ngay: map['ngay'] ?? '',
      mien: map['mien'] ?? '',
      tinh: map['tinh'] ?? '',
      numbers: List<String>.from(map['numbers'] ?? []),
    );
  }

  // Chuyển đổi từ sheet row
  factory LotteryResult.fromSheetRow(List<String> row) {
    if (row.length < 3) throw Exception('Invalid row data');
    
    // DEBUG: In ra số lượng cột
    //print("DEBUG fromSheetRow: Tổng cột = ${row.length}, Số từ cột 3 = ${row.sublist(3).length}");
    //print("DEBUG 3 số cuối: ${row.sublist(row.length - 3)}");
    
    return LotteryResult(
      ngay: row[0],
      mien: row[1],
      tinh: row[2],
      numbers: row.sublist(3).where((n) => n.isNotEmpty).toList(),
    );
  }
}