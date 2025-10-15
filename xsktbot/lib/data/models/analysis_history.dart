// lib/data/models/analysis_history.dart

class AnalysisHistory {
  final int stt;
  final String ngayCuoiKQXS;
  final String mienCuoiKQXS;
  final int soNgayGan;
  final String ngayLanCuoiVe;
  final String nhomGan;
  final String mienNam;
  final String mienTrung;
  final String mienBac;
  final String filter;  // ✅ ADD

  AnalysisHistory({
    required this.stt,
    required this.ngayCuoiKQXS,
    required this.mienCuoiKQXS,
    required this.soNgayGan,
    required this.ngayLanCuoiVe,
    required this.nhomGan,
    required this.mienNam,
    required this.mienTrung,
    required this.mienBac,
    required this.filter,  // ✅ ADD
  });

  List<String> toSheetRow() {
    return [
      stt.toString(),
      ngayCuoiKQXS,
      mienCuoiKQXS,
      soNgayGan.toString(),
      ngayLanCuoiVe,
      nhomGan,
      mienNam,
      mienTrung,
      mienBac,
      filter,  // ✅ ADD
    ];
  }

  factory AnalysisHistory.fromCycleResult({
    required int stt,
    required String ngayCuoiKQXS,
    required String mienCuoiKQXS,
    required int soNgayGan,
    required String ngayLanCuoiVe,
    required String nhomGan,
    required Map<String, List<String>> mienGroups,
    required String filter,  // ✅ ADD
  }) {
    return AnalysisHistory(
      stt: stt,
      ngayCuoiKQXS: ngayCuoiKQXS,
      mienCuoiKQXS: mienCuoiKQXS,
      soNgayGan: soNgayGan,
      ngayLanCuoiVe: ngayLanCuoiVe,
      nhomGan: nhomGan,
      mienNam: mienGroups['Nam']?.join(', ') ?? '',
      mienTrung: mienGroups['Trung']?.join(', ') ?? '',
      mienBac: mienGroups['Bắc']?.join(', ') ?? '',
      filter: filter,  // ✅ ADD
    );
  }

  factory AnalysisHistory.fromSheetRow(List<dynamic> row) {
    return AnalysisHistory(
      stt: int.parse(row[0].toString()),
      ngayCuoiKQXS: row[1].toString(),
      mienCuoiKQXS: row[2].toString(),
      soNgayGan: int.parse(row[3].toString()),
      ngayLanCuoiVe: row[4].toString(),
      nhomGan: row[5].toString(),
      mienNam: row.length > 6 ? row[6].toString() : '',
      mienTrung: row.length > 7 ? row[7].toString() : '',
      mienBac: row.length > 8 ? row[8].toString() : '',
      filter: row.length > 9 ? row[9].toString() : 'Tất cả',  // ✅ ADD
    );
  }

  bool isDuplicate(AnalysisHistory other) {
    return ngayCuoiKQXS == other.ngayCuoiKQXS &&
           soNgayGan == other.soNgayGan &&
           nhomGan == other.nhomGan &&
           filter == other.filter;  // ✅ ADD filter check
  }
}