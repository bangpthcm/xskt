// lib/core/utils/number_utils.dart
import 'dart:math';
import 'package:intl/intl.dart';  // ✅ ADD: Import intl

class NumberUtils {
  static List<String> processResultString(String ketQuaStr) {
    // Tách số và chữ cái
    String fixed = ketQuaStr.replaceAllMapped(
      RegExp(r'(\d)(G\.)'),
      (match) => '${match.group(1)} ${match.group(2)}',
    );
    
    // Loại bỏ các ký tự không cần thiết
    String cleaned = fixed.replaceAll(RegExp(r'G\.\s*(ĐB|\d+):\s*'), '');
    
    // Tìm tất cả các số
    final numbers = RegExp(r'\d+').allMatches(cleaned)
        .map((m) => m.group(0)!)
        .toList();
    
    if (numbers.isEmpty) return [];
    
    // Lấy 2 chữ số cuối
    return numbers.map((num) {
      if (num.length >= 2) {
        return num.substring(num.length - 2);
      } else {
        return num.padLeft(2, '0');
      }
    }).toList();
  }

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
    final formatter = NumberFormat('#,##0.00', 'vi_VN');  // ✅ Giờ có thể dùng NumberFormat
    return formatter.format(amount);
  }
}