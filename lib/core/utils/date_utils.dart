import 'package:intl/intl.dart';

class DateUtils {
  static final DateFormat _ddMMyyyyFormat = DateFormat('dd/MM/yyyy');

  static DateTime? parseDate(String dateStr) {
    try {
      return _ddMMyyyyFormat.parse(dateStr);
    } catch (_) {
      // Ignore error
      return null;
    }
  }

  static String formatDate(DateTime date) => _ddMMyyyyFormat.format(date);

  static String? getDateFromRssLink(String linkText) {
    final match = RegExp(r'(\d{1,2})-(\d{1,2})-(\d{4})').firstMatch(linkText);
    if (match != null) {
      try {
        return formatDate(DateTime(
          int.parse(match.group(3)!),
          int.parse(match.group(2)!),
          int.parse(match.group(1)!),
        ));
      } catch (_) {}
    }
    return null;
  }

  static bool isHoliday(DateTime date) => date.month == 9 && date.day == 2;

  static int getWeekday(DateTime date) => date.weekday - 1;
}
