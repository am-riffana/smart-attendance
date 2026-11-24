import 'package:intl/intl.dart';

/// Utilities for standardizing date, time, and countdown formatting
class DateTimeUtils {
  DateTimeUtils._();

  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
  static final DateFormat _timeFormat = DateFormat('hh:mm a');
  static final DateFormat _dateTimeFormat = DateFormat('yyyy-MM-dd hh:mm a');
  static final DateFormat _humanDateFormat = DateFormat('EEE, MMM d, yyyy');

  /// Returns today's date formatted as 'yyyy-MM-dd'
  static String todayDateString() {
    return _dateFormat.format(DateTime.now());
  }

  /// Formats [dateTime] to 'yyyy-MM-dd' in local timezone
  static String formatDate(DateTime dateTime) {
    return _dateFormat.format(dateTime.toLocal());
  }

  /// Formats [dateTime] to 'hh:mm a' (e.g. '09:30 AM') in local timezone
  static String formatTime(DateTime dateTime) {
    return _timeFormat.format(dateTime.toLocal());
  }

  /// Formats [dateTime] to 'yyyy-MM-dd hh:mm a' in local timezone
  static String formatDateTime(DateTime dateTime) {
    return _dateTimeFormat.format(dateTime.toLocal());
  }

  /// Formats [dateTime] to readable 'Mon, Jan 15, 2026'
  static String formatHumanDate(DateTime dateTime) {
    return _humanDateFormat.format(dateTime.toLocal());
  }

  /// Formats an ISO-8601 string safely into readable local time
  static String formatIsoToTime(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '--:--';
    final parsed = DateTime.tryParse(isoString);
    if (parsed == null) return '--:--';
    return formatTime(parsed);
  }

  /// Formats an ISO-8601 string safely into readable local date
  static String formatIsoToDate(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '--';
    final parsed = DateTime.tryParse(isoString);
    if (parsed == null) return '--';
    return formatDate(parsed);
  }

  /// Checks if a given timestamp has passed the current moment
  static bool isExpired(DateTime expiresAt) {
    return DateTime.now().isAfter(expiresAt);
  }

  /// Formats duration in seconds into 'mm:ss' countdown representation
  static String formatSecondsToMinutes(int totalSeconds) {
    if (totalSeconds <= 0) return '00:00';
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
