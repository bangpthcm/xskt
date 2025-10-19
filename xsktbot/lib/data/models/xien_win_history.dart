// lib/data/models/xien_win_history.dart

class XienWinHistory {
  final int stt;
  final String ngayKiemTra;
  final String capSoMucTieu;        // Cặp số mục tiêu (vd: "36-24")
  final String ngayBatDau;
  final String ngayTrung;
  final String? mienTrung;          // Luôn là "Bắc" nếu trúng
  final int soLanTrungCap;          // Số lần cặp xuất hiện cùng nhau
  final String chiTietTrung;        // Chi tiết (vd: "36: 3x, 24: 2x, cùng nhau: 2x")
  final double tienCuocMien;
  final double tongTienCuoc;
  final double tienVe;
  final double loiLo;
  final double roi;
  final int soNgayCuoc;
  final String trangThai;           // WIN/TRACKING/LOSE
  final String? ghiChu;

  XienWinHistory({
    required this.stt,
    required this.ngayKiemTra,
    required this.capSoMucTieu,
    required this.ngayBatDau,
    required this.ngayTrung,
    this.mienTrung,
    required this.soLanTrungCap,
    required this.chiTietTrung,
    required this.tienCuocMien,
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
      capSoMucTieu,
      ngayBatDau,
      ngayTrung,
      mienTrung ?? '',
      soLanTrungCap.toString(),
      chiTietTrung,
      _formatNumber(tienCuocMien),
      _formatNumber(tongTienCuoc),
      _formatNumber(tienVe),
      _formatNumber(loiLo),
      '${roi.toStringAsFixed(2)}%',
      soNgayCuoc.toString(),
      trangThai,
      ghiChu ?? '',
    ];
  }

  factory XienWinHistory.fromSheetRow(List<dynamic> row) {
    return XienWinHistory(
      stt: int.parse(row[0].toString()),
      ngayKiemTra: row[1].toString(),
      capSoMucTieu: row[2].toString(),
      ngayBatDau: row[3].toString(),
      ngayTrung: row[4].toString(),
      mienTrung: row[5].toString().isEmpty ? null : row[5].toString(),
      soLanTrungCap: int.parse(row[6].toString()),
      chiTietTrung: row[7].toString(),
      tienCuocMien: _parseNumber(row[8]),
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
    String str = value.toString().trim();
    
    // Chỉ cần xóa dấu chấm (phân cách nghìn VN)
    str = str.replaceAll('.', '');
    str = str.replaceAll(',', '');
    str = str.replaceAll(' ', '');
    
    return double.parse(str);
  }

  static double _parseROI(dynamic value) {
    String str = value.toString().trim().replaceAll('%', '');
    return double.parse(str);
  }
}