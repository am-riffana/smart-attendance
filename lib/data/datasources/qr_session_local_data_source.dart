import 'package:sqflite/sqflite.dart';
import '../../core/constants/app_constants.dart';
import '../../core/database/database_constants.dart';
import '../../core/database/database_helper.dart';
import '../../core/errors/exceptions.dart';
import '../models/attendance_session_model.dart';

/// Data source managing Attendance QR Sessions in SQLite
class QrSessionLocalDataSource {
  final DatabaseHelper _databaseHelper;

  QrSessionLocalDataSource({DatabaseHelper? databaseHelper})
      : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  Future<Database> get _db => _databaseHelper.database;

  /// Creates a new QR session in SQLite
  Future<int> createSession(AttendanceSessionModel session) async {
    try {
      final db = await _db;
      return await db.insert(
        DatabaseConstants.tableAttendanceSessions,
        session.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      throw LocalDatabaseException('Failed to create QR session: $e');
    }
  }

  /// Finds session by token with parameterized query
  Future<AttendanceSessionModel?> getSessionByToken(String token) async {
    try {
      final db = await _db;
      final results = await db.query(
        DatabaseConstants.tableAttendanceSessions,
        where: '${DatabaseConstants.colSessionToken} = ?',
        whereArgs: [token.trim()],
        limit: 1,
      );
      if (results.isEmpty) return null;
      return AttendanceSessionModel.fromMap(results.first);
    } catch (e) {
      throw LocalDatabaseException('Failed to find QR session by token: $e');
    }
  }

  /// Finds session by primary ID with parameterized query
  Future<AttendanceSessionModel?> getSessionById(int sessionId) async {
    try {
      final db = await _db;
      final results = await db.query(
        DatabaseConstants.tableAttendanceSessions,
        where: '${DatabaseConstants.colSessionId} = ?',
        whereArgs: [sessionId],
        limit: 1,
      );
      if (results.isEmpty) return null;
      return AttendanceSessionModel.fromMap(results.first);
    } catch (e) {
      throw LocalDatabaseException('Failed to find QR session by ID: $e');
    }
  }

  /// Gets the most recent active session
  Future<AttendanceSessionModel?> getLatestActiveSession() async {
    try {
      final db = await _db;
      final nowUtcIso = DateTime.now().toUtc().toIso8601String();

      // Parameterized query for active sessions whose expires_at is in the future
      final results = await db.query(
        DatabaseConstants.tableAttendanceSessions,
        where: '${DatabaseConstants.colSessionStatus} = ? AND ${DatabaseConstants.colSessionExpiresAt} > ?',
        whereArgs: [AppConstants.sessionActive, nowUtcIso],
        orderBy: '${DatabaseConstants.colSessionId} DESC',
        limit: 1,
      );

      if (results.isEmpty) return null;
      final session = AttendanceSessionModel.fromMap(results.first);
      // Defensive check: ensure session is not expired
      if (session.isExpired) {
        if (session.id != null) {
          await updateSessionStatus(session.id!, AppConstants.sessionExpired);
        }
        return null;
      }
      return session;
    } catch (e) {
      throw LocalDatabaseException('Failed to fetch latest active QR session: $e');
    }
  }

  /// Updates status of a QR session (e.g. marked as 'expired')
  Future<int> updateSessionStatus(int sessionId, String status) async {
    try {
      final db = await _db;
      return await db.update(
        DatabaseConstants.tableAttendanceSessions,
        {DatabaseConstants.colSessionStatus: status},
        where: '${DatabaseConstants.colSessionId} = ?',
        whereArgs: [sessionId],
      );
    } catch (e) {
      throw LocalDatabaseException('Failed to update QR session status: $e');
    }
  }

  /// Automatically marks any session past its expiration timestamp as 'expired'
  Future<int> expirePastSessions() async {
    try {
      final db = await _db;
      final nowUtcIso = DateTime.now().toUtc().toIso8601String();

      return await db.update(
        DatabaseConstants.tableAttendanceSessions,
        {DatabaseConstants.colSessionStatus: AppConstants.sessionExpired},
        where: '${DatabaseConstants.colSessionStatus} = ? AND ${DatabaseConstants.colSessionExpiresAt} <= ?',
        whereArgs: [AppConstants.sessionActive, nowUtcIso],
      );
    } catch (e) {
      throw LocalDatabaseException('Failed to expire past sessions: $e');
    }
  }
}
