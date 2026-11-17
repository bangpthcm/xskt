class AppConstants {
  static const List<String> mienOrder = ["Nam", "Trung", "Bắc"];

  // Xiên betting constants
  static const double targetBudgetXien = 100000.0;
  static const double winMultiplierXien = 17.0;
  static const double startingProfit = 500.0;
  // ✅ THÊM MỚI: 3 mốc bước nhảy cho đường cong "quả đồi"
  static const double xienProfitStepMin = 100.0; // Bước nhảy ở ngày đầu tiên
  static const double xienProfitStepPeak =
      2000.0; // Bước nhảy đỉnh (tại mốc 2/3)
  static const double xienProfitStepEnd = 100.0; // Bước nhảy ở ngày cuối cùng

  static const int bacGanWinMultiplier = 99;
  static const int trungGanWinMultiplier = 98;
  static const int namGanWinMultiplier = 98; // ✅ Thêm: Multiplier miền Nam

  // Win multipliers
  static const int winMultiplier = 98;


  // ✅ Ngưỡng "Ngày nuôi" cố định theo miền — dùng để xem đã đủ điều kiện
  // tạo bảng cược hay chưa (Ngày nuôi <= ngưỡng => đã thỏa điều kiện)
  static const int ganDaysThresholdTatCa = 5;
  static const int ganDaysThresholdNam = 10;
  static const int ganDaysThresholdTrung = 12;
  static const int ganDaysThresholdBac = 18;
  static const int ganDaysThresholdXien = 80;

  static int getGanDaysThreshold(String mien) {
    final m = mien.toLowerCase();
    if (m.contains('nam')) return ganDaysThresholdNam;
    if (m.contains('trung')) return ganDaysThresholdTrung;
    if (m.contains('bắc') || m.contains('bac')) return ganDaysThresholdBac;
    if (m.contains('xien') || m.contains('xiên')) return ganDaysThresholdXien;
    return ganDaysThresholdTatCa;
  }
}
