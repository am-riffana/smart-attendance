/// Route path and name constants
class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String splashName = 'splash';

  static const String login = '/login';
  static const String loginName = 'login';

  static const String adminDashboard = '/admin';
  static const String adminDashboardName = 'admin_dashboard';

  static const String employeeDashboard = '/employee';
  static const String employeeDashboardName = 'employee_dashboard';

  static const String qrSession = '/admin/qr-session';
  static const String qrSessionName = 'qr_session';

  static const String qrScanner = '/employee/qr-scanner';
  static const String qrScannerName = 'qr_scanner';

  static const String attendanceStatus = '/attendance/status';
  static const String attendanceStatusName = 'attendance_status';

  static const String attendanceHistory = '/history';
  static const String attendanceHistoryName = 'attendance_history';

  static const String adminRecords = '/admin/records';
  static const String adminRecordsName = 'admin_records';
}
