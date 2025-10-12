class BettingRow {
  final int stt;
  final String ngay;
  final String mien;
  final String so;
  final int? soLo; // null cho bảng xiên
  final double cuocSo; // null cho bảng xiên
  final double cuocMien;
  final double tongTien;
  final double loi1So;
  final double? loi2So; // null cho bảng xiên

  BettingRow({
    required this.stt,
    required this.ngay,
    required this.mien,
    required this.so,
    this.soLo,
    required this.cuocSo,
    required this.cuocMien,
    required this.tongTien,
    required this.loi1So,
    this.loi2So,
  });

  // Cho bảng Chu kỳ (xsktBot1)
  factory BettingRow.forCycle({
    required int stt,
    required String ngay,
    required String mien,
    required String so,
    required int soLo,
    required double cuocSo,
    required double cuocMien,
    required double tongTien,
    required double loi1So,
    required double loi2So,
  }) {
    return BettingRow(
      stt: stt,
      ngay: ngay,
      mien: mien,
      so: so,
      soLo: soLo,
      cuocSo: cuocSo,
      cuocMien: cuocMien,
      tongTien: tongTien,
      loi1So: loi1So,
      loi2So: loi2So,
    );
  }

  // Cho bảng Xiên (xienBot)
  factory BettingRow.forXien({
    required int stt,
    required String ngay,
    required String mien,
    required String so,
    required double cuocMien,
    required double tongTien,
    required double loi,
  }) {
    return BettingRow(
      stt: stt,
      ngay: ngay,
      mien: mien,
      so: so,
      soLo: null,
      cuocSo: 0,
      cuocMien: cuocMien,
      tongTien: tongTien,
      loi1So: loi,
      loi2So: null,
    );
  }

  List<String> toSheetRow() {
    if (soLo != null && loi2So != null) {
      // Chu kỳ
      return [
        stt.toString(),
        ngay,
        mien,
        so,
        soLo.toString(),
        cuocSo.toStringAsFixed(2),
        cuocMien.toStringAsFixed(2),
        tongTien.toStringAsFixed(2),
        loi1So.toStringAsFixed(2),
        loi2So!.toStringAsFixed(2),
      ];
    } else {
      // Xiên
      return [
        stt.toString(),
        ngay,
        mien,
        so,
        cuocMien.toStringAsFixed(2),
        tongTien.toStringAsFixed(2),
        loi1So.toStringAsFixed(2),
      ];
    }
  }
}