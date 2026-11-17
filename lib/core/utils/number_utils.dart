// lib/core/utils/number_utils.dart
import 'package:intl/intl.dart';  // ✅ ADD: Import intl

class NumberUtils {

  static int calculateSoLo(String mien, int weekday) {
    if (mien == "Nam") {
      if (weekday == 1) return 36; // Thứ 3
      if (weekday == 5) return 72; // Thứ 7
      return 54;
    } else if (mien == "Trung") {
      if (weekday == 3 || weekday == 5 || weekday == 6) {
        return 54; // Thứ 5, 7, CN
      }
      return 36;
    } else { // Bắc
      return 27;
    }
  }

  static String formatCurrency(double amount) {
    // Làm tròn về số nguyên và format không có phần thập phân
    final formatter = NumberFormat('#,##0', 'vi_VN');
    return formatter.format(amount.round());
  }
}