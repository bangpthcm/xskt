class AppConstants {
  static const List<String> mienOrder = ["Nam", "Trung", "Bắc"];

  // Budget defaults
  static const double defaultBudgetMin = 330000.0;
  static const double defaultBudgetMax = 1750000.0;

  // Xiên betting constants
  static const double targetBudgetXien = 400000.0;
  static const double winMultiplierXien = 17.0;
  static const double startingProfit = 2000.0;
  static const double finalProfit = 3000.0;
  // ✅ THÊM MỚI: 3 mốc bước nhảy cho đường cong "quả đồi"
  static const double xienProfitStepMin = 100.0; // Bước nhảy ở ngày đầu tiên
  static const double xienProfitStepPeak =
      750.0; // Bước nhảy đỉnh (tại mốc 2/3)
  static const double xienProfitStepEnd = 100.0; // Bước nhảy ở ngày cuối cùng

  static const int bacGanWinMultiplier = 99;
  static const int trungGanWinMultiplier = 98;
  static const int namGanWinMultiplier = 98; // ✅ Thêm: Multiplier miền Nam

  // Win multipliers
  static const int winMultiplier = 98;

  // WebView URLs
  static const String homeUrlNam =
      'https://xoso.com.vn/xo-so-mien-nam/xsmn-p1.html';
  static const String homeUrlTrung =
      'https://xoso.com.vn/xo-so-mien-trung/xsmt-p1.html';
  static const String homeUrlBac =
      'https://xoso.com.vn/xo-so-mien-bac/xsmb-p1.html';

  // Time thresholds
  static const int timeThreshold1 = 1030; // 17:10
  static const int timeThreshold2 = 1090; // 18:10

  // ✅ Ngưỡng "Ngày nuôi" cố định theo miền — dùng để xem đã đủ điều kiện
  // tạo bảng cược hay chưa (Ngày nuôi <= ngưỡng => đã thỏa điều kiện)
  static const int ganDaysThresholdTatCa = 4;
  static const int ganDaysThresholdNam = 8;
  static const int ganDaysThresholdTrung = 12;
  static const int ganDaysThresholdBac = 20;
  static const int ganDaysThresholdXien = 55;

  static int getGanDaysThreshold(String mien) {
    final m = mien.toLowerCase();
    if (m.contains('nam')) return ganDaysThresholdNam;
    if (m.contains('trung')) return ganDaysThresholdTrung;
    if (m.contains('bắc') || m.contains('bac')) return ganDaysThresholdBac;
    if (m.contains('xien') || m.contains('xiên')) return ganDaysThresholdXien;
    return ganDaysThresholdTatCa;
  }
}
