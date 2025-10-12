import 'package:intl/intl.dart';

class DateUtils {
  static final DateFormat _ddMMyyyyFormat = DateFormat('dd/MM/yyyy');
  
  static DateTime? parseDate(String dateStr) {
    try {
      return _ddMMyyyyFormat.parse(dateStr);
    } catch (e) {
      return null;
    }
  }

  static String formatDate(DateTime date) {
    return _ddMMyyyyFormat.format(date);
  }

  static String? getDateFromRssLink(String linkText) {
    final regex = RegExp(r'(\d{1,2})-(\d{1,2})-(\d{4})');
    final match = regex.firstMatch(linkText);
    
    if (match != null) {
      try {
        final day = int.parse(match.group(1)!);
        final month = int.parse(match.group(2)!);
        final year = int.parse(match.group(3)!);
        
        final date = DateTime(year, month, day);
        return formatDate(date);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  static bool isHoliday(DateTime date) {
    // Quốc khánh 2/9
    if (date.month == 9 && date.day == 2) return true;
    
    // TODO: Implement lunar calendar check for Tết
    // Cần thư viện lunar_calendar hoặc API
    
    return false;
  }

  static int getWeekday(DateTime date) {
    // Python weekday: Monday=0, Sunday=6
    // Dart weekday: Monday=1, Sunday=7
    return date.weekday - 1;
  }
}