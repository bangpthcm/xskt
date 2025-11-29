class AppConstants {
  // RSS URLs
  static const Map<String, String> rssSources = {
    "Nam": "http://xskt.me/rssfeed/xsmn.rss",
    "Trung": "http://xskt.me/rssfeed/xsmt.rss",
    "Bắc": "http://xskt.me/rssfeed/xsmb.rss",
  };

  static const List<String> mienOrder = ["Nam", "Trung", "Bắc"];

  // Budget defaults
  static const double defaultBudgetMin = 330000.0;
  static const double defaultBudgetMax = 350000.0;

  // Xiên betting constants
  static const double targetBudgetXien = 19000.0;
  static const double winMultiplierXien = 17.0;
  static const int durationBase = 185;
  static const double startingProfit = 50.0;
  static const double finalProfit = 800.0;

  // Win multipliers
  static const int winMultiplier = 98;

  // WebView URLs
  static const String homeUrlNam = 'https://xsmn.mobi/';
  static const String homeUrlTrung = 'https://xsmn.mobi/xsmt-xo-so-mien-trung.html';
  static const String homeUrlBac = 'https://xsmn.mobi/xsmb-xo-so-mien-bac.html';

  // Time thresholds (in minutes from midnight)
  static const int timeThreshold1 = 1030; // 17:10
  static const int timeThreshold2 = 1090; // 18:10
}