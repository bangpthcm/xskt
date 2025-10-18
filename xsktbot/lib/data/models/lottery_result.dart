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
  factory LotteryResult.fromSheetRow(List<dynamic> row) {
    if (row.length < 3) throw Exception('Invalid row data');
    
    return LotteryResult(
      ngay: row[0].toString(),
      mien: row[1].toString(),
      tinh: row[2].toString(),
      // ✅ FIX: Chỉ loại bỏ empty, KHÔNG loại bỏ số 0
      numbers: row.sublist(3)
          .map((e) => e.toString().trim())
          .where((n) => n.isNotEmpty)  // ✅ CHỈ CHECK EMPTY
          .map((n) => n.padLeft(2, '0'))  // ✅ Format: 0 → "00", 5 → "05"
          .toList(),
    );
  }

  // ✅ THÊM: Chuyển đổi sang sheet row
  List<String> toSheetRow() {
    // Format: [ngay, mien, tinh, ...numbers]
    return [ngay, mien, tinh, ...numbers];
  }
}