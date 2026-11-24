/// API & Network constants for Dio REST Client
class ApiConstants {
  ApiConstants._();

  // Base URL (configured for mock or remote backend)
  static const String baseUrl = 'https://api.smartattendance.local/v1';

  // Network Timeouts
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);
  static const Duration sendTimeout = Duration(seconds: 15);

  // Endpoints
  static const String loginEndpoint = '/auth/login';
  static const String logoutEndpoint = '/auth/logout';
  static const String createSessionEndpoint = '/qr/sessions';
  static const String verifyQrEndpoint = '/qr/verify';
  static const String attendanceCheckInEndpoint = '/attendance/check-in';
  static const String attendanceCheckOutEndpoint = '/attendance/check-out';
  static const String attendanceHistoryEndpoint = '/attendance/history';
  static const String adminAnalyticsEndpoint = '/admin/analytics';
  static const String employeeListEndpoint = '/admin/employees';
  static const String adminRecordsEndpoint = '/admin/records';
  static const String employeesEndpoint = '/employees';
}
