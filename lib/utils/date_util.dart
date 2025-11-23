import 'package:intl/intl.dart';

class DateUtil {
  static DateTime toPhTime(DateTime date) {
    return date.toUtc().add(const Duration(hours: 8)); // UTC+8 for Philippines
  }

  static String formatDateTime(DateTime date) {
    final phTime = toPhTime(date);
    return DateFormat('MMM d, y • h:mm a').format(phTime) + ' PHT';
  }

  static String formatDateTimeDetailed(DateTime date) {
    final phTime = toPhTime(date);
    return DateFormat('MMMM d, y • h:mm:ss a').format(phTime) + ' PHT';
  }

  static String formatDateRange(DateTime start, DateTime end) {
    final phStart = toPhTime(start);
    final phEnd = toPhTime(end);
    return '${DateFormat('MMM d').format(phStart)} - ${DateFormat('MMM d').format(phEnd)}';
  }
}
