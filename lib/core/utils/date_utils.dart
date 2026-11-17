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

  static int getWeekday(DateTime date) => date.weekday - 1;
}
