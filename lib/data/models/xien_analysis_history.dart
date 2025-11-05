// lib/data/models/xien_analysis_history.dart

class XienAnalysisHistory {
  final int stt;
  final String ngayCuoiKQXS;        // Ngày cuối cùng trong KQXS
  final String mienCuoiKQXS;        // Miền cuối cùng trong KQXS
  final int soNgayGan;              // Số ngày gan của cặp này
  final String ngayLanCuoiVe;       // Ngày lần cuối về của cặp số
  final String capSo;               // Cặp số (vd: "36-24")

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