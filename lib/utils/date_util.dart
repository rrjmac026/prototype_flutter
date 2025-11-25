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

  static String getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()}w ago';
    } else {
      return '${(difference.inDays / 30).floor()}mo ago';
    }
  }
}
