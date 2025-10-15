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

  // ✅ Helper để format số với dấu phẩy phân cách hàng nghìn
  static String _formatNumberWithCommas(double value) {
    // Format với 2 chữ số thập phân
    final str = value.toStringAsFixed(2);
    final parts = str.split('.');
    final intPart = parts[0];
    final decimalPart = parts.length > 1 ? parts[1] : '00';
    
    // Thêm dấu chấm phân cách hàng nghìn (format EU/VN)
    String formatted = '';
    int count = 0;
    for (int i = intPart.length - 1; i >= 0; i--) {
      if (count == 3) {
        formatted = '.$formatted';
        count = 0;
      }
      formatted = intPart[i] + formatted;
      count++;
    }
    
    return '$formatted,$decimalPart';
  }

  List<String> toSheetRow() {
    if (soLo != null && loi2So != null) {
      // Chu kỳ
      return [
        stt.toString(),
        ngay,
        mien,
        so,
        _formatNumberWithCommas(soLo!.toDouble()),  // ✅ Format
        _formatNumberWithCommas(cuocSo),            // ✅ Format
        _formatNumberWithCommas(cuocMien),          // ✅ Format
        _formatNumberWithCommas(tongTien),          // ✅ Format
        _formatNumberWithCommas(loi1So),            // ✅ Format
        _formatNumberWithCommas(loi2So!),           // ✅ Format
      ];
    } else {
      // Xiên
      return [
        stt.toString(),
        ngay,
        mien,
        so,
        _formatNumberWithCommas(cuocMien),          // ✅ Format
        _formatNumberWithCommas(tongTien),          // ✅ Format
        _formatNumberWithCommas(loi1So),            // ✅ Format
      ];
    }
  }
} 