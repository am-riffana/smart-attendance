import 'package:sqflite/sqflite.dart';
import '../../core/constants/app_constants.dart';
import '../../core/database/database_constants.dart';
import '../../core/database/database_helper.dart';
import '../../core/errors/exceptions.dart';
import '../models/attendance_record_model.dart';

/// Data source executing local SQLite operations for Attendance Records
class AttendanceLocalDataSource {
  final DatabaseHelper _databaseHelper;

  AttendanceLocalDataSource({DatabaseHelper? databaseHelper})
      : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  Future<Database> get _db => _databaseHelper.database;

  /// Fetches attendance record for an employee on a specific date (yyyy-MM-dd)
  Future<AttendanceRecordModel?> getRecordForEmployeeAndDate(
    String employeeId,
    String date,
  ) async {
    try {
      final db = await _db;
      final results = await db.query(
        DatabaseConstants.tableAttendanceRecords,
        where: '${DatabaseConstants.colRecordEmployeeId} = ? AND ${DatabaseConstants.colRecordDate} = ?',
        whereArgs: [employeeId, date],
        limit: 1,
      );

      if (results.isEmpty) return null;
      return AttendanceRecordModel.fromMap(results.first);
    } catch (e) {
      throw LocalDatabaseException('Failed to fetch attendance record: $e');
    }
  }

  /// Records employee Check-In within a transaction to enforce duplicate prevention
  Future<int> checkIn(AttendanceRecordModel record) async {
    try {
      final db = await _db;

      return await db.transaction<int>((txn) async {
        // 1. Verify that a check-in doesn't already exist for this date
        final existing = await txn.query(
          DatabaseConstants.tableAttendanceRecords,
          where: '${DatabaseConstants.colRecordEmployeeId} = ? AND ${DatabaseConstants.colRecordDate} = ?',
          whereArgs: [record.employeeId, record.date],
          limit: 1,
        );

        if (existing.isNotEmpty) {
          throw const DuplicateAttendanceException(
            'Attendance has already been recorded for today. Duplicate check-ins are not permitted.',
          );
        }

        // 2. Insert new record
        return await txn.insert(
          DatabaseConstants.tableAttendanceRecords,
          record.toMap(),
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      });
    } on DuplicateAttendanceException {
      rethrow;
    } catch (e) {
      throw LocalDatabaseException('Failed to record check-in: $e');
    }
  }

  /// Records employee Check-Out (only allowed after an active check-in exists)
  Future<int> checkOut({
    required String employeeId,
    required String date,
    required String checkOutTime,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final db = await _db;

      return await db.transaction<int>((txn) async {
        // 1. Verify existing record for today
        final existing = await txn.query(
          DatabaseConstants.tableAttendanceRecords,
          where: '${DatabaseConstants.colRecordEmployeeId} = ? AND ${DatabaseConstants.colRecordDate} = ?',
          whereArgs: [employeeId, date],
          limit: 1,
        );

        if (existing.isEmpty) {
          throw const AppException(
            'Cannot check out without checking in first. Please scan and check in.',
          );
        }

        final currentRecord = AttendanceRecordModel.fromMap(existing.first);
        if (currentRecord.checkInTime == null) {
          throw const AppException(
            'Cannot check out without an active check-in.',
          );
        }

        if (currentRecord.checkOutTime != null) {
          throw const DuplicateAttendanceException(
            'Check-out has already been completed for today.',
          );
        }

        // 2. Update record with check-out details
        return await txn.update(
          DatabaseConstants.tableAttendanceRecords,
          {
            DatabaseConstants.colRecordCheckOutTime: checkOutTime,
            DatabaseConstants.colRecordCheckOutLat: latitude,
            DatabaseConstants.colRecordCheckOutLng: longitude,
            DatabaseConstants.colRecordStatus: AppConstants.statusCheckedOut,
          },
          where: '${DatabaseConstants.colRecordEmployeeId} = ? AND ${DatabaseConstants.colRecordDate} = ?',
          whereArgs: [employeeId, date],
        );
      });
    } catch (e) {
      if (e is AppException) rethrow;
      throw LocalDatabaseException('Failed to record check-out: $e');
    }
  }

  /// Retrieves attendance history for a single employee, sorted latest first
  Future<List<AttendanceRecordModel>> getHistoryForEmployee(String employeeId) async {
    try {
      final db = await _db;
      final results = await db.query(
        DatabaseConstants.tableAttendanceRecords,
        where: '${DatabaseConstants.colRecordEmployeeId} = ?',
        whereArgs: [employeeId],
        orderBy: '${DatabaseConstants.colRecordDate} DESC, ${DatabaseConstants.colRecordId} DESC',
      );
      return results.map((map) => AttendanceRecordModel.fromMap(map)).toList();
    } catch (e) {
      throw LocalDatabaseException('Failed to fetch attendance history: $e');
    }
  }

  /// Retrieves all attendance records with employee details, optional date, and text search
  Future<List<AttendanceRecordModel>> getAllRecords({
    String? date,
    String? searchQuery,
  }) async {
    try {
      final db = await _db;

      String query = '''
        SELECT 
          r.*,
          e.${DatabaseConstants.colEmpName} AS employee_name,
          e.${DatabaseConstants.colEmpEmail} AS employee_email
        FROM ${DatabaseConstants.tableAttendanceRecords} r
        INNER JOIN ${DatabaseConstants.tableEmployees} e 
          ON r.${DatabaseConstants.colRecordEmployeeId} = e.${DatabaseConstants.colEmpEmployeeId}
      ''';

      final whereClauses = <String>[];
      final whereArgs = <dynamic>[];

      if (date != null && date.isNotEmpty) {
        whereClauses.add('r.${DatabaseConstants.colRecordDate} = ?');
        whereArgs.add(date);
      }

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        whereClauses.add('(LOWER(e.${DatabaseConstants.colEmpName}) LIKE ? OR LOWER(r.${DatabaseConstants.colRecordEmployeeId}) LIKE ?)');
        final term = '%${searchQuery.trim().toLowerCase()}%';
        whereArgs.add(term);
        whereArgs.add(term);
      }

      if (whereClauses.isNotEmpty) {
        query += ' WHERE ${whereClauses.join(' AND ')}';
      }

      query += ' ORDER BY r.${DatabaseConstants.colRecordDate} DESC, r.${DatabaseConstants.colRecordId} DESC';

      final results = await db.rawQuery(query, whereArgs);
      return results.map((map) => AttendanceRecordModel.fromMap(map)).toList();
    } catch (e) {
      throw LocalDatabaseException('Failed to query all attendance records: $e');
    }
  }

  /// Aggregates attendance statistics for a given date (total, present, checked-in, not checked-in)
  Future<Map<String, int>> getAttendanceSummary(String date) async {
    try {
      final db = await _db;

      // 1. Total active employees (excluding admins)
      final empCountResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM ${DatabaseConstants.tableEmployees} WHERE ${DatabaseConstants.colEmpRole} = ?',
        [AppConstants.roleEmployee],
      );
      final totalEmployees = Sqflite.firstIntValue(empCountResult) ?? 0;

      // 2. Records for the requested date
      final recordsResult = await db.query(
        DatabaseConstants.tableAttendanceRecords,
        where: '${DatabaseConstants.colRecordDate} = ?',
        whereArgs: [date],
      );

      int checkedIn = 0;
      int checkedOut = 0;

      for (final row in recordsResult) {
        final record = AttendanceRecordModel.fromMap(row);
        if (record.isCheckedOut) {
          checkedOut++;
        } else if (record.isCheckedIn) {
          checkedIn++;
        }
      }

      final present = checkedIn + checkedOut;
      final notCheckedIn = totalEmployees > present ? (totalEmployees - present) : 0;

      return {
        'total': totalEmployees,
        'present': present,
        'checked_in': checkedIn,
        'checked_out': checkedOut,
        'not_checked_in': notCheckedIn,
      };
    } catch (e) {
      throw LocalDatabaseException('Failed to aggregate attendance metrics: $e');
    }
  }
}
