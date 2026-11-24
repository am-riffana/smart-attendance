import 'package:sqflite/sqflite.dart';
import '../../core/database/database_constants.dart';
import '../../core/database/database_helper.dart';
import '../../core/errors/exceptions.dart';
import '../models/employee_model.dart';

/// Data source executing local SQLite operations for Employees
class EmployeeLocalDataSource {
  final DatabaseHelper _databaseHelper;

  EmployeeLocalDataSource({DatabaseHelper? databaseHelper})
      : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  Future<Database> get _db => _databaseHelper.database;

  /// Retrieves all registered employees
  Future<List<EmployeeModel>> getAllEmployees() async {
    try {
      final db = await _db;
      final results = await db.query(
        DatabaseConstants.tableEmployees,
        orderBy: '${DatabaseConstants.colEmpEmployeeId} ASC',
      );
      return results.map((map) => EmployeeModel.fromMap(map)).toList();
    } catch (e) {
      throw LocalDatabaseException('Failed to fetch employees: $e');
    }
  }

  /// Finds employee by unique Employee ID (e.g. 'EMP001')
  Future<EmployeeModel?> getEmployeeById(String employeeId) async {
    try {
      final db = await _db;
      final results = await db.query(
        DatabaseConstants.tableEmployees,
        where: '${DatabaseConstants.colEmpEmployeeId} = ?',
        whereArgs: [employeeId.trim()],
        limit: 1,
      );
      if (results.isEmpty) return null;
      return EmployeeModel.fromMap(results.first);
    } catch (e) {
      throw LocalDatabaseException('Failed to fetch employee by ID: $e');
    }
  }

  /// Finds employee by Email
  Future<EmployeeModel?> getEmployeeByEmail(String email) async {
    try {
      final db = await _db;
      final results = await db.query(
        DatabaseConstants.tableEmployees,
        where: '${DatabaseConstants.colEmpEmail} = ?',
        whereArgs: [email.trim().toLowerCase()],
        limit: 1,
      );
      if (results.isEmpty) return null;
      return EmployeeModel.fromMap(results.first);
    } catch (e) {
      throw LocalDatabaseException('Failed to fetch employee by email: $e');
    }
  }

  /// Authenticates user against SQLite database using parameterized query
  /// Checks both employee_id and email fields
  Future<EmployeeModel?> authenticate({
    required String identifier,
    required String password,
  }) async {
    try {
      final db = await _db;
      final cleanIdentifier = identifier.trim();

      // Parameterized query preventing SQL injection
      final results = await db.query(
        DatabaseConstants.tableEmployees,
        where: '(${DatabaseConstants.colEmpEmployeeId} = ? OR LOWER(${DatabaseConstants.colEmpEmail}) = LOWER(?)) AND ${DatabaseConstants.colEmpPassword} = ?',
        whereArgs: [cleanIdentifier, cleanIdentifier, password],
        limit: 1,
      );

      if (results.isEmpty) return null;
      return EmployeeModel.fromMap(results.first);
    } catch (e) {
      throw LocalDatabaseException('Authentication query failed: $e');
    }
  }

  /// Inserts a new employee
  Future<int> insertEmployee(EmployeeModel employee) async {
    try {
      final db = await _db;
      return await db.insert(
        DatabaseConstants.tableEmployees,
        employee.toMap(),
        conflictAlgorithm: ConflictAlgorithm.fail,
      );
    } catch (e) {
      throw LocalDatabaseException('Failed to insert employee: $e');
    }
  }

  /// Retrieves the currently persisted active session employee ID
  Future<String?> getActiveSessionEmployeeId() async {
    try {
      final db = await _db;
      final results = await db.query(
        DatabaseConstants.tableAppSession,
        columns: [DatabaseConstants.colSessionUserEmployeeId],
        where: '${DatabaseConstants.colSessionUserId} = ?',
        whereArgs: [1],
        limit: 1,
      );
      if (results.isEmpty) return null;
      return results.first[DatabaseConstants.colSessionUserEmployeeId] as String?;
    } catch (e) {
      throw LocalDatabaseException('Failed to read active session: $e');
    }
  }

  /// Persists the active session for an authenticated employee
  Future<void> saveActiveSession(String employeeId) async {
    try {
      final db = await _db;
      await db.insert(
        DatabaseConstants.tableAppSession,
        {
          DatabaseConstants.colSessionUserId: 1,
          DatabaseConstants.colSessionUserEmployeeId: employeeId,
          DatabaseConstants.colSessionUserLoggedInAt: DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      throw LocalDatabaseException('Failed to save active session: $e');
    }
  }

  /// Clears the active session row on logout
  /// Does NOT touch employees or attendance records
  Future<void> clearActiveSession() async {
    try {
      final db = await _db;
      await db.delete(
        DatabaseConstants.tableAppSession,
        where: '${DatabaseConstants.colSessionUserId} = ?',
        whereArgs: [1],
      );
    } catch (e) {
      throw LocalDatabaseException('Failed to clear active session: $e');
    }
  }
}
