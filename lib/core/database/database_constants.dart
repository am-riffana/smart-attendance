/// SQLite Database configuration, table and column definitions
class DatabaseConstants {
  DatabaseConstants._();

  static const String databaseName = 'smart_attendance.db';
  static const int databaseVersion = 2;

  // Table: employees
  static const String tableEmployees = 'employees';
  static const String colEmpId = 'id';
  static const String colEmpEmployeeId = 'employee_id';
  static const String colEmpName = 'name';
  static const String colEmpEmail = 'email';
  static const String colEmpPassword = 'password';
  static const String colEmpRole = 'role';

  // Table: attendance_sessions
  static const String tableAttendanceSessions = 'attendance_sessions';
  static const String colSessionId = 'id';
  static const String colSessionToken = 'session_token';
  static const String colSessionCreatedAt = 'created_at';
  static const String colSessionExpiresAt = 'expires_at';
  static const String colSessionStatus = 'status';

  // Table: attendance_records
  static const String tableAttendanceRecords = 'attendance_records';
  static const String colRecordId = 'id';
  static const String colRecordEmployeeId = 'employee_id';
  static const String colRecordDate = 'date';
  static const String colRecordCheckInTime = 'check_in_time';
  static const String colRecordCheckOutTime = 'check_out_time';
  static const String colRecordCheckInLat = 'check_in_latitude';
  static const String colRecordCheckInLng = 'check_in_longitude';
  static const String colRecordCheckOutLat = 'check_out_latitude';
  static const String colRecordCheckOutLng = 'check_out_longitude';
  static const String colRecordStatus = 'status';
  static const String colRecordSessionId = 'session_id';

  // Location capture columns (added in DB version 2)
  static const String colRecordCheckInAccuracy = 'check_in_accuracy';
  static const String colRecordLocationCapturedAt = 'location_captured_at';
  static const String colRecordIsWithinGeofence = 'is_within_geofence';
  static const String colRecordDistanceToOffice = 'distance_to_office_meters';

  // Table: app_session (local active session persistence)
  static const String tableAppSession = 'app_session';
  static const String colSessionUserId = 'id';
  static const String colSessionUserEmployeeId = 'employee_id';
  static const String colSessionUserLoggedInAt = 'logged_in_at';

  // Create Table Statements
  static const String createTableAppSession = '''
    CREATE TABLE IF NOT EXISTS $tableAppSession (
      $colSessionUserId INTEGER PRIMARY KEY CHECK ($colSessionUserId = 1),
      $colSessionUserEmployeeId TEXT NOT NULL,
      $colSessionUserLoggedInAt TEXT NOT NULL,
      FOREIGN KEY ($colSessionUserEmployeeId) REFERENCES $tableEmployees ($colEmpEmployeeId)
    );
  ''';

  static const String createTableEmployees = '''
    CREATE TABLE $tableEmployees (
      $colEmpId INTEGER PRIMARY KEY AUTOINCREMENT,
      $colEmpEmployeeId TEXT NOT NULL UNIQUE,
      $colEmpName TEXT NOT NULL,
      $colEmpEmail TEXT NOT NULL UNIQUE,
      $colEmpPassword TEXT NOT NULL,
      $colEmpRole TEXT NOT NULL
    );
  ''';

  static const String createTableAttendanceSessions = '''
    CREATE TABLE $tableAttendanceSessions (
      $colSessionId INTEGER PRIMARY KEY AUTOINCREMENT,
      $colSessionToken TEXT NOT NULL UNIQUE,
      $colSessionCreatedAt TEXT NOT NULL,
      $colSessionExpiresAt TEXT NOT NULL,
      $colSessionStatus TEXT NOT NULL
    );
  ''';

  static const String createTableAttendanceRecords = '''
    CREATE TABLE $tableAttendanceRecords (
      $colRecordId INTEGER PRIMARY KEY AUTOINCREMENT,
      $colRecordEmployeeId TEXT NOT NULL,
      $colRecordDate TEXT NOT NULL,
      $colRecordCheckInTime TEXT,
      $colRecordCheckOutTime TEXT,
      $colRecordCheckInLat REAL,
      $colRecordCheckInLng REAL,
      $colRecordCheckOutLat REAL,
      $colRecordCheckOutLng REAL,
      $colRecordCheckInAccuracy REAL,
      $colRecordLocationCapturedAt TEXT,
      $colRecordIsWithinGeofence INTEGER,
      $colRecordDistanceToOffice REAL,
      $colRecordStatus TEXT NOT NULL,
      $colRecordSessionId INTEGER,
      FOREIGN KEY ($colRecordEmployeeId) REFERENCES $tableEmployees ($colEmpEmployeeId),
      FOREIGN KEY ($colRecordSessionId) REFERENCES $tableAttendanceSessions ($colSessionId),
      UNIQUE($colRecordEmployeeId, $colRecordDate)
    );
  ''';

  // Indexes for query performance
  static const String createIndexRecordsEmployeeDate = '''
    CREATE INDEX idx_records_emp_date ON $tableAttendanceRecords ($colRecordEmployeeId, $colRecordDate);
  ''';

  static const String createIndexSessionsToken = '''
    CREATE INDEX idx_sessions_token ON $tableAttendanceSessions ($colSessionToken);
  ''';

  // ── Version 1 → 2 migration: add GPS location columns to attendance_records ──
  static const String migrateV1V2AddCheckInAccuracy =
      'ALTER TABLE $tableAttendanceRecords ADD COLUMN $colRecordCheckInAccuracy REAL';
  static const String migrateV1V2AddLocationCapturedAt =
      'ALTER TABLE $tableAttendanceRecords ADD COLUMN $colRecordLocationCapturedAt TEXT';
  static const String migrateV1V2AddIsWithinGeofence =
      'ALTER TABLE $tableAttendanceRecords ADD COLUMN $colRecordIsWithinGeofence INTEGER';
  static const String migrateV1V2AddDistanceToOffice =
      'ALTER TABLE $tableAttendanceRecords ADD COLUMN $colRecordDistanceToOffice REAL';
}
