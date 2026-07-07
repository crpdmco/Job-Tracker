import 'package:intl/intl.dart';

class TimeUtils {
  static String formatDate(DateTime d) => DateFormat('MMM d, y').format(d);
  static String formatDateShort(DateTime d) => DateFormat('MMM d').format(d);
  static String formatDateTime(DateTime d) =>
      DateFormat('MMM d, y · h:mm a').format(d);
  static String formatDayKey(DateTime d) =>
      DateFormat('yyyy-MM-dd').format(d);
  static String formatWeekday(DateTime d) => DateFormat('EEE').format(d);
  static String formatMonthYear(DateTime d) => DateFormat('MMMM y').format(d);
}