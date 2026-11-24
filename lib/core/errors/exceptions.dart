/// Base custom exceptions thrown by data sources and services
class AppException implements Exception {
  final String message;
  final int? statusCode;

  const AppException(this.message, {this.statusCode});

  @override
  String toString() => 'AppException: $message (code: $statusCode)';
}

/// Custom exception for local SQLite errors
class LocalDatabaseException extends AppException {
  const LocalDatabaseException(super.message);
}

class AuthException extends AppException {
  const AuthException(super.message, {super.statusCode});
}

class QrValidationException extends AppException {
  const QrValidationException(super.message);
}

class LocationException extends AppException {
  const LocationException(super.message);
}

class DuplicateAttendanceException extends AppException {
  const DuplicateAttendanceException(super.message);
}

class PermissionException extends AppException {
  const PermissionException(super.message);
}
