/// Application-wide constants for Smart QR Attendance
class AppConstants {
  AppConstants._();

  static const String appName = 'Smart QR Attendance';
  static const String appVersion = '1.0.0';

  // Session & QR
  /// QR code validity duration (5 minutes as specified in requirements)
  static const Duration qrSessionExpiry = Duration(minutes: 5);
  static const int qrSessionExpirySeconds = 300;

  // Roles
  static const String roleAdmin = 'admin';
  static const String roleEmployee = 'employee';

  // Attendance Statuses
  static const String statusPresent = 'present';
  static const String statusCheckedIn = 'checked_in';
  static const String statusCheckedOut = 'checked_out';
  static const String statusLate = 'late';
  static const String statusAbsent = 'absent';

  // QR Session Statuses
  static const String sessionActive = 'active';
  static const String sessionExpired = 'expired';
  static const String sessionCancelled = 'cancelled';

  // Location Geofence Defaults (in meters)
  static const double defaultGeofenceRadiusMeters = 150.0;
  static const int locationTimeoutSeconds = 12;

  // Office Coordinates (sample office for geofence validation)
  static const double defaultOfficeLatitude = 12.9716;
  static const double defaultOfficeLongitude = 77.5946;
}
