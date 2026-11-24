import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../constants/app_constants.dart';
import '../errors/exceptions.dart';
import 'database_constants.dart';

/// Singleton helper managing SQLite database initialization, migrations,
/// and automated sample data seeding.
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  factory DatabaseHelper() => instance;

  /// Returns active database instance or opens a new connection
  Future<Database> get database async {
    if (_database != null && _database!.isOpen) {
      return _database!;
    }
    _database = await _initDatabase();
    return _database!;
  }

  /// Initializes database with configuration and migration handlers
  Future<Database> _initDatabase() async {
    try {
      final String path;
      if (kIsWeb) {
        // On Flutter Web, SQLite databases are stored in browser IndexedDB
        // using the database name directly as the storage identifier.
        path = DatabaseConstants.databaseName;
      } else {
        final dbPath = await getDatabasesPath();
        path = p.join(dbPath, DatabaseConstants.databaseName);
      }

      return await openDatabase(
        path,
        version: DatabaseConstants.databaseVersion,
        onConfigure: _onConfigure,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    } catch (e) {
      debugPrint('[DatabaseHelper] Error initializing database: $e');
      throw LocalDatabaseException('Failed to initialize local SQLite database: $e');
    }
  }

  /// Enables SQLite foreign key constraints and verifies session table
  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON;');
    // Ensure app_session table exists even if created prior to Phase 3
    await db.execute(DatabaseConstants.createTableAppSession);
  }

  /// Creates tables and indexes, then seeds initial employee data
  Future<void> _onCreate(Database db, int version) async {
    if (kDebugMode) {
      debugPrint('[DatabaseHelper] Creating tables for database version $version...');
    }

    final batch = db.batch();

    // 1. Create employees table
    batch.execute(DatabaseConstants.createTableEmployees);

    // 2. Create attendance sessions table
    batch.execute(DatabaseConstants.createTableAttendanceSessions);

    // 3. Create attendance records table
    batch.execute(DatabaseConstants.createTableAttendanceRecords);

    // 4. Create local session storage table
    batch.execute(DatabaseConstants.createTableAppSession);

    // 5. Create performance indexes
    batch.execute(DatabaseConstants.createIndexRecordsEmployeeDate);
    batch.execute(DatabaseConstants.createIndexSessionsToken);

    await batch.commit(noResult: true);

    // Seed sample Admin and Employee records
    await _seedInitialEmployees(db);

    if (kDebugMode) {
      debugPrint('✅ [DatabaseHelper] Tables and initial seed data created successfully.');
    }
  }

  /// Handles schema migrations for future version upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (kDebugMode) {
      debugPrint('[DatabaseHelper] Upgrading database from $oldVersion to $newVersion...');
    }

    // Version 1 → 2: Add GPS location capture columns to attendance_records
    if (oldVersion < 2) {
      await db.execute(DatabaseConstants.migrateV1V2AddCheckInAccuracy);
      await db.execute(DatabaseConstants.migrateV1V2AddLocationCapturedAt);
      await db.execute(DatabaseConstants.migrateV1V2AddIsWithinGeofence);
      await db.execute(DatabaseConstants.migrateV1V2AddDistanceToOffice);

      if (kDebugMode) {
        debugPrint('[DatabaseHelper] ✅ v1→v2 migration: GPS location columns added to attendance_records.');
      }
    }
  }

  /// Seeds initial Admin and Employee credentials into the database
  Future<void> _seedInitialEmployees(Database db) async {
    final sampleEmployees = [
      {
        DatabaseConstants.colEmpEmployeeId: 'ADM001',
        DatabaseConstants.colEmpName: 'System Administrator',
        DatabaseConstants.colEmpEmail: 'admin@company.com',
        DatabaseConstants.colEmpPassword: 'admin123',
        DatabaseConstants.colEmpRole: AppConstants.roleAdmin,
      },
      {
        DatabaseConstants.colEmpEmployeeId: 'EMP001',
        DatabaseConstants.colEmpName: 'John Doe',
        DatabaseConstants.colEmpEmail: 'john.doe@company.com',
        DatabaseConstants.colEmpPassword: 'employee123',
        DatabaseConstants.colEmpRole: AppConstants.roleEmployee,
      },
      {
        DatabaseConstants.colEmpEmployeeId: 'EMP002',
        DatabaseConstants.colEmpName: 'Jane Smith',
        DatabaseConstants.colEmpEmail: 'jane.smith@company.com',
        DatabaseConstants.colEmpPassword: 'employee123',
        DatabaseConstants.colEmpRole: AppConstants.roleEmployee,
      },
      {
        DatabaseConstants.colEmpEmployeeId: 'EMP003',
        DatabaseConstants.colEmpName: 'Robert Brown',
        DatabaseConstants.colEmpEmail: 'robert.b@company.com',
        DatabaseConstants.colEmpPassword: 'employee123',
        DatabaseConstants.colEmpRole: AppConstants.roleEmployee,
      },
      {
        DatabaseConstants.colEmpEmployeeId: 'EMP004',
        DatabaseConstants.colEmpName: 'Emily Davis',
        DatabaseConstants.colEmpEmail: 'emily.d@company.com',
        DatabaseConstants.colEmpPassword: 'employee123',
        DatabaseConstants.colEmpRole: AppConstants.roleEmployee,
      },
    ];

    final batch = db.batch();
    for (final emp in sampleEmployees) {
      batch.insert(
        DatabaseConstants.tableEmployees,
        emp,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Closes database connection
  Future<void> close() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }
  }
}
