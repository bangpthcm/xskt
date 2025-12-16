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

  Map<String, dynamic> toMap() => {
        'ngay': ngay,
        'mien': mien,
        'tinh': tinh,
        'numbers': numbers,
      };

  factory LotteryResult.fromMap(Map<String, dynamic> map) => LotteryResult(
        ngay: map['ngay'] ?? '',
        mien: map['mien'] ?? '',
        tinh: map['tinh'] ?? '',
        numbers: List<String>.from(map['numbers'] ?? []),
      );

  factory LotteryResult.fromSheetRow(List<dynamic> row) {
    if (row.length < 3) throw Exception('Invalid row data');

    return LotteryResult(
      ngay: row[0].toString(),
      mien: row[1].toString(),
      tinh: row[2].toString(),
      // Tối ưu: Chỉ duyệt 1 lần để lọc và format
      numbers: row.sublist(3).fold<List<String>>([], (prev, e) {
        final s = e.toString().trim();
        if (s.isNotEmpty) prev.add(s.padLeft(2, '0'));
        return prev;
      }),
    );
  }

  List<String> toSheetRow() => [ngay, mien, tinh, ...numbers];
}
