// lib/data/models/xien_analysis_history.dart

class XienAnalysisHistory {
  final int stt;
  final String ngayCuoiKQXS;
  final String mienCuoiKQXS;
  final int soNgayGan;
  final String ngayLanCuoiVe;
  final String capSo;

  XienAnalysisHistory({
    required this.stt,
    required this.ngayCuoiKQXS,
    required this.mienCuoiKQXS,
    required this.soNgayGan,
    required this.ngayLanCuoiVe,
    required this.capSo,
  });

  // Chuyển sang dạng row để ghi vào Google Sheets
  List<String> toSheetRow() {
    return [
      stt.toString(),
      ngayCuoiKQXS,
      mienCuoiKQXS,
      soNgayGan.toString(),
      ngayLanCuoiVe,
      capSo,
    ];
  }

  // Parse từ row trong Google Sheets
  factory XienAnalysisHistory.fromSheetRow(List<dynamic> row) {
    return XienAnalysisHistory(
      stt: int.parse(row[0].toString()),
      ngayCuoiKQXS: row[1].toString(),
      mienCuoiKQXS: row[2].toString(),
      soNgayGan: int.parse(row[3].toString()),
      ngayLanCuoiVe: row[4].toString(),
      capSo: row[5].toString(),
    );
  }

  // So sánh để tránh duplicate
  bool isDuplicate(XienAnalysisHistory other) {
    return ngayCuoiKQXS == other.ngayCuoiKQXS &&
           capSo == other.capSo;
  }
}