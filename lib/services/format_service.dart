import 'package:intl/intl.dart';
import 'package:hijri/hijri_calendar.dart';
import '../models/models.dart';

const List<String> weekdaysAr = [
  'الأحد',
  'الإثنين',
  'الثلاثاء',
  'الأربعاء',
  'الخميس',
  'الجمعة',
  'السبت',
];

const Map<String, String> _hindiDigits = {
  '0': '٠',
  '1': '١',
  '2': '٢',
  '3': '٣',
  '4': '٤',
  '5': '٥',
  '6': '٦',
  '7': '٧',
  '8': '٨',
  '9': '٩',
};

/// Formats a number with thousands separators, and converts digits
/// to Hindi (Eastern Arabic) numerals if the user has selected that option.
///
/// Guards against NaN/Infinity (which NumberFormat cannot handle and would
/// throw on) — these should never occur with normal use, but a defensive
/// fallback here prevents a crash if they ever do (e.g. a corrupted entry).
String formatNumber(num value, NumeralSystem system) {
  final safeValue = value.isFinite ? value : 0;
  final formatted = NumberFormat('#,##0').format(safeValue);
  if (system == NumeralSystem.hindi) {
    return formatted.split('').map((ch) => _hindiDigits[ch] ?? ch).join();
  }
  return formatted;
}

String formatSigned(num value, NumeralSystem system) {
  final safeValue = value.isFinite ? value : 0;
  if (safeValue < 0) {
    return '- ${formatNumber(safeValue.abs(), system)}';
  }
  return formatNumber(safeValue, system);
}

/// weekday index: Dart's DateTime.weekday is 1=Monday..7=Sunday.
/// We need 0=Sunday..6=Saturday to match weekdaysAr.
int _sundayBasedWeekday(DateTime d) => d.weekday % 7;

/// Formats a date as "الاثنين 6/4" (Gregorian) by default,
/// or Hijri equivalent if selected in settings.
///
/// If Hijri conversion ever fails for an edge-case date, falls back to
/// the Gregorian format rather than crashing — a slightly wrong date
/// system is far less disruptive than an app crash.
String formatDayLabel(DateTime date, NumeralSystem system,
    {DateSystem dateSystem = DateSystem.gregorian}) {
  final weekday = weekdaysAr[_sundayBasedWeekday(date)];
  if (dateSystem == DateSystem.hijri) {
    try {
      final hijri = HijriCalendar.fromDate(date);
      return '$weekday ${formatNumber(hijri.hMonth, system)}/${formatNumber(hijri.hDay, system)}';
    } catch (_) {
      // fall through to Gregorian below
    }
  }
  return '$weekday ${formatNumber(date.month, system)}/${formatNumber(date.day, system)}';
}

bool isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
