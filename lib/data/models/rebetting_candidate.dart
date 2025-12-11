// lib/data/models/rebetting_candidate.dart

class RebettingCandidate {
  final String soMucTieu; // Số cược lại
  final String mienTrung; // Miền: Nam/Trung/Bắc
  final String ngayBatDauCu; // Ngày bắt đầu cũ (cột D sheet)
  final String ngayTrungCu; // Ngày trúng cũ (cột E sheet)
  final int soNgayGanCu; // Gan cũ (cột N sheet)
  final int soNgayGanMoi; // Gan mới (tính từ ngayTrung đến hôm nay)
  final int rebettingDuration; // Duration = 2×Threshold - soNgayGanCu
  final String ngayCoTheVao; // Ngày start date từ _findBestStartBet

  RebettingCandidate({
    required this.soMucTieu,
    required this.mienTrung,
    required this.ngayBatDauCu,
    required this.ngayTrungCu,
    required this.soNgayGanCu,
    required this.soNgayGanMoi,
    required this.rebettingDuration,
    required this.ngayCoTheVao,
  });

  @override
  String toString() {
    return 'RebettingCandidate('
        'so: $soMucTieu, mien: $mienTrung, '
        'duration: $rebettingDuration, '
        'ngayVao: $ngayCoTheVao)';
  }
}
