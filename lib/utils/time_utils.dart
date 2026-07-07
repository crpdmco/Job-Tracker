import 'package:intl/intl.dart';

class TimeUtils {
  static String formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '${h}h ${m.toString().padLeft(2, '0')}m ${s.toString().padLeft(2, '0')}s';
    }
    if (m > 0) {
      return '${m}m ${s.toString().padLeft(2, '0')}s';
    }
    return '${s}s';
  }

  static String formatHoursCompact(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  static String formatHoursDecimal(Duration d) {
    return (d.inSeconds / 3600).toStringAsFixed(2);
  }

  static String formatDate(DateTime d) => DateFormat('MMM d, y').format(d);
  static String formatDateShort(DateTime d) => DateFormat('MMM d').format(d);
  static String formatTime(DateTime d) => DateFormat('h:mm a').format(d);
  static String formatDateTime(DateTime d) =>
      DateFormat('MMM d, y · h:mm a').format(d);
  static String formatDayKey(DateTime d) =>
      DateFormat('yyyy-MM-dd').format(d);
  static String formatWeekday(DateTime d) => DateFormat('EEE').format(d);
  static String formatMonthYear(DateTime d) => DateFormat('MMMM y').format(d);
}
