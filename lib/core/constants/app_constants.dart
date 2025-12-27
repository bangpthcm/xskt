class AppConstants {
  static const List<String> mienOrder = ["Nam", "Trung", "Bắc"];

  // Budget defaults
  static const double defaultBudgetMin = 330000.0;
  static const double defaultBudgetMax = 350000.0;

  // Xiên betting constants
  static const double targetBudgetXien = 19000.0;
  static const double winMultiplierXien = 17.0;
  static const int durationBaseXien = 234;
  static const double startingProfit = 50.0;
  static const double finalProfit = 800.0;

  // ✅ CẤU HÌNH CÁC MIỀN (ĐÃ BỔ SUNG NAM)
  static const int durationBaseBac = 43;
  static const int durationBaseTrung = 26;
  static const int durationBaseNam = 22; // ✅ Thêm: Duration cơ sở cho miền Nam

  static const int bacGanWinMultiplier = 99;
  static const int trungGanWinMultiplier = 98;
  static const int namGanWinMultiplier = 98; // ✅ Thêm: Multiplier miền Nam

  static const int durationBaseCycle = 10;
  static const int cycleGanWinMultiplier = 98;

  // Win multipliers
  static const int winMultiplier = 98;

  // WebView URLs
  static const String homeUrlNam = 'https://xsmn.mobi/';
  static const String homeUrlTrung =
      'https://xsmn.mobi/xsmt-xo-so-mien-trung.html';
  static const String homeUrlBac = 'https://xsmn.mobi/xsmb-xo-so-mien-bac.html';

  // Time thresholds
  static const int timeThreshold1 = 1030; // 17:10
  static const int timeThreshold2 = 1090; // 18:10
}
