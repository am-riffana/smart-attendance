import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/core/constants/app_constants.dart';
import 'package:flutter_application_1/core/database/database_helper.dart';
import 'package:flutter_application_1/data/datasources/employee_local_data_source.dart';
import 'package:flutter_application_1/data/datasources/qr_session_local_data_source.dart';
import 'package:flutter_application_1/data/datasources/attendance_local_data_source.dart';
import 'package:flutter_application_1/data/models/attendance_record_model.dart';
import 'package:flutter_application_1/data/models/attendance_session_model.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:flutter/foundation.dart';

void main() {
  setUpAll(() {
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
    }
  });

  group('Chrome & Web SQLite End-to-End Verification', () {
    test('1. DatabaseHelper initializes SQLite on Web without databaseFactory error', () async {
      final db = await DatabaseHelper.instance.database;
      expect(db.isOpen, isTrue);
    });

    test('2. Seeded initial employees exist in SQLite database', () async {
      final employeeDataSource = EmployeeLocalDataSource();
      final employees = await employeeDataSource.getAllEmployees();

      expect(employees.length, greaterThanOrEqualTo(5));
      expect(employees.any((e) => e.employeeId == 'ADM001' && e.isAdmin), isTrue);
      expect(employees.any((e) => e.employeeId == 'EMP001' && e.isEmployee), isTrue);
    });

    test('3. Employee and Admin authentication work against SQLite', () async {
      final employeeDataSource = EmployeeLocalDataSource();

      // Authenticate Admin
      final admin = await employeeDataSource.authenticate(
        identifier: 'admin@company.com',
        password: 'admin123',
      );
      expect(admin, isNotNull);
      expect(admin!.role, equals(AppConstants.roleAdmin));

      // Authenticate Employee
      final emp = await employeeDataSource.authenticate(
        identifier: 'EMP001',
        password: 'employee123',
      );
      expect(emp, isNotNull);
      expect(emp!.role, equals(AppConstants.roleEmployee));

      // Invalid password rejected
      final invalid = await employeeDataSource.authenticate(
        identifier: 'EMP001',
        password: 'wrongpassword',
      );
      expect(invalid, isNull);
    });

    test('4. Active app session persistence works in SQLite', () async {
      final employeeDataSource = EmployeeLocalDataSource();

      await employeeDataSource.saveActiveSession('EMP001');
      final activeId = await employeeDataSource.getActiveSessionEmployeeId();
      expect(activeId, equals('EMP001'));

      await employeeDataSource.clearActiveSession();
      final clearedId = await employeeDataSource.getActiveSessionEmployeeId();
      expect(clearedId, isNull);
    });

    test('5. Dynamic QR session creation and expiration works in SQLite', () async {
      final qrDataSource = QrSessionLocalDataSource();

      final now = DateTime.now().toUtc();
      final session = AttendanceSessionModel(
        sessionToken: 'test-chrome-token-${DateTime.now().millisecondsSinceEpoch}',
        createdAt: now,
        expiresAt: now.add(const Duration(minutes: 5)),
        status: AppConstants.sessionActive,
      );

      final sessionId = await qrDataSource.createSession(session);
      expect(sessionId, greaterThan(0));

      final fetched = await qrDataSource.getSessionByToken(session.sessionToken);
      expect(fetched, isNotNull);
      expect(fetched!.sessionToken, equals(session.sessionToken));
    });

    test('6. Attendance check-in and duplicate prevention work in SQLite', () async {
      final attendanceDataSource = AttendanceLocalDataSource();
      final testDate = '2099-01-01';

      final record = AttendanceRecordModel(
        employeeId: 'EMP001',
        date: testDate,
        checkInTime: '09:00:00',
        status: AppConstants.statusCheckedIn,
        checkInLatitude: 12.9716,
        checkInLongitude: 77.5946,
        checkInAccuracy: 10.0,
        isWithinGeofence: true,
      );

      final id = await attendanceDataSource.checkIn(record);
      expect(id, greaterThan(0));

      // Duplicate check-in on same day should throw
      expect(
        () => attendanceDataSource.checkIn(record),
        throwsA(isA<Exception>()),
      );

      // Verify record retrieved
      final fetched = await attendanceDataSource.getRecordForEmployeeAndDate('EMP001', testDate);
      expect(fetched, isNotNull);
      expect(fetched?.checkInLatitude, equals(12.9716));
      expect(fetched?.isWithinGeofence, isTrue);

      // Verify attendance summary
      final summary = await attendanceDataSource.getAttendanceSummary(testDate);
      expect(summary['present'], greaterThanOrEqualTo(1));
    });
  });
}
