// lib/data/models/cycle_win_history.dart

class CycleWinHistory {
  final int stt;
  final String ngayKiemTra;        // Ngày kiểm tra
  final String soMucTieu;           // Số mục tiêu
  final String ngayBatDau;          // Ngày bắt đầu cược
  final String ngayTrung;           // Ngày trúng (có thể rỗng nếu chưa trúng)
  final String? mienTrung;          // Miền trúng (có thể null)
  final int soLanTrung;             // Số lần trúng
  final String cacTinhTrung;        // Các tỉnh trúng
  final double tienCuocSo;          // Tiền cược/số
  final double tongTienCuoc;        // Tổng tiền đã cược
  final double tienVe;              // Tiền về
  final double loiLo;               // Lời/Lỗ
  final double roi;                 // ROI %
  final int soNgayCuoc;             // Số ngày cược
  final String trangThai;           // WIN/TRACKING/LOSE
  final String? ghiChu;             // Ghi chú

  CycleWinHistory({
    required this.stt,
    required this.ngayKiemTra,
    required this.soMucTieu,
    required this.ngayBatDau,
    required this.ngayTrung,
    this.mienTrung,
    required this.soLanTrung,
    required this.cacTinhTrung,
    required this.tienCuocSo,
    required this.tongTienCuoc,
    required this.tienVe,
    required this.loiLo,
    required this.roi,
    required this.soNgayCuoc,
    required this.trangThai,
    this.ghiChu,
  });

  bool get isWin => trangThai == 'WIN';
  bool get isTracking => trangThai == 'TRACKING';

  List<String> toSheetRow() {
    return [
      stt.toString(),
      ngayKiemTra,
      soMucTieu,
      ngayBatDau,
      ngayTrung,
      mienTrung ?? '',
      soLanTrung.toString(),
      cacTinhTrung,
      _formatNumber(tienCuocSo),
      _formatNumber(tongTienCuoc),
      _formatNumber(tienVe),
      _formatNumber(loiLo),
      '${roi.toStringAsFixed(2)}%',
      soNgayCuoc.toString(),
      trangThai,
      ghiChu ?? '',
    ];
  }

  factory CycleWinHistory.fromSheetRow(List<dynamic> row) {
    return CycleWinHistory(
      stt: int.parse(row[0].toString()),
      ngayKiemTra: row[1].toString(),
      soMucTieu: row[2].toString(),
      ngayBatDau: row[3].toString(),
      ngayTrung: row[4].toString(),
      mienTrung: row[5].toString().isEmpty ? null : row[5].toString(),
      soLanTrung: int.parse(row[6].toString()),
      cacTinhTrung: row[7].toString(),
      tienCuocSo: _parseNumber(row[8]),
      tongTienCuoc: _parseNumber(row[9]),
      tienVe: _parseNumber(row[10]),
      loiLo: _parseNumber(row[11]),
      roi: _parseROI(row[12]),
      soNgayCuoc: int.parse(row[13].toString()),
      trangThai: row[14].toString(),
      ghiChu: row.length > 15 ? row[15].toString() : null,
    );
  }

  static String _formatNumber(double value) {
    final str = value.toStringAsFixed(2);
    final parts = str.split('.');
    final intPart = parts[0];
    final decimalPart = parts.length > 1 ? parts[1] : '00';
    
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

  static double _parseNumber(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    
    String str = value.toString().trim();
    if (str.isEmpty) return 0.0;
    
    // ✅ Xử lý format VN
    int dotCount = '.'.allMatches(str).length;
    int commaCount = ','.allMatches(str).length;
    
    if (dotCount > 0 && commaCount > 0) {
      str = str.replaceAll('.', '').replaceAll(',', '.');
    } else if (dotCount > 0) {
      if (dotCount > 1) {
        str = str.replaceAll('.', '');
      } else {
        final afterDot = str.length - str.indexOf('.') - 1;
        if (afterDot == 3) str = str.replaceAll('.', '');
      }
    } else if (commaCount > 0) {
      if (commaCount > 1) {
        str = str.replaceAll(',', '');
      } else {
        final afterComma = str.length - str.indexOf(',') - 1;
        if (afterComma <= 2) {
          str = str.replaceAll(',', '.');
        } else if (afterComma == 3) {
          str = str.replaceAll(',', '');
        }
      }
    }
    
    str = str.replaceAll(' ', '');
    
    try {
      return double.parse(str);
    } catch (e) {
      return 0.0;
    }
  }

  static double _parseROI(dynamic value) {
    String str = value.toString().trim().replaceAll('%', '');
    return double.parse(str);
  }
}