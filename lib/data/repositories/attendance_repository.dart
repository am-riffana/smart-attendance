import 'package:flutter/foundation.dart';
import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../datasources/attendance_local_data_source.dart';
import '../datasources/attendance_remote_data_source.dart';
import '../models/attendance_record_model.dart';

/// Contract for daily attendance check-in, check-out, and reporting (Offline-first with Remote Sync)
abstract class AttendanceRepository {
  Future<AttendanceRecordModel?> getTodayRecord(String employeeId, String date);
  Future<AttendanceRecordModel> checkIn(AttendanceRecordModel record);
  Future<void> checkOut({
    required String employeeId,
    required String date,
    required String checkOutTime,
    required double latitude,
    required double longitude,
  });
  Future<List<AttendanceRecordModel>> getEmployeeHistory(String employeeId);
  Future<List<AttendanceRecordModel>> getAllAttendanceRecords({
    String? date,
    String? searchQuery,
  });
  Future<Map<String, int>> getAttendanceSummary(String date);
}

/// Implementation of [AttendanceRepository] backed by SQLite and Mock REST API
class AttendanceRepositoryImpl implements AttendanceRepository {
  final AttendanceLocalDataSource _localDataSource;
  final AttendanceRemoteDataSource? _remoteDataSource;

  AttendanceRepositoryImpl({
    AttendanceLocalDataSource? localDataSource,
    AttendanceRemoteDataSource? remoteDataSource,
  })  : _localDataSource = localDataSource ?? AttendanceLocalDataSource(),
        _remoteDataSource = remoteDataSource ?? AttendanceRemoteDataSource();

  @override
  Future<AttendanceRecordModel?> getTodayRecord(String employeeId, String date) async {
    try {
      return await _localDataSource.getRecordForEmployeeAndDate(employeeId, date);
    } on LocalDatabaseException catch (e) {
      throw DatabaseFailure(e.message);
    } catch (e) {
      throw DatabaseFailure('Unexpected error retrieving daily attendance: $e');
    }
  }

  @override
  Future<AttendanceRecordModel> checkIn(AttendanceRecordModel record) async {
    try {
      // 1. Commit to local SQLite first (Single Source of Truth)
      final id = await _localDataSource.checkIn(record);
      final savedRecord = record.copyWith(id: id);

      // 2. Safely sync to Remote Mock REST API without blocking local success
      if (_remoteDataSource != null) {
        try {
          await _remoteDataSource.submitCheckIn(savedRecord);
        } catch (e) {
          debugPrint('[AttendanceRepository] Notice: Mock API check-in sync failed ($e). Local record preserved.');
        }
      }

      return savedRecord;
    } on DuplicateAttendanceException catch (e) {
      throw ValidationFailure(e.message);
    } on LocalDatabaseException catch (e) {
      throw DatabaseFailure(e.message);
    } catch (e) {
      throw DatabaseFailure('Unexpected error recording check-in: $e');
    }
  }

  @override
  Future<void> checkOut({
    required String employeeId,
    required String date,
    required String checkOutTime,
    required double latitude,
    required double longitude,
  }) async {
    try {
      await _localDataSource.checkOut(
        employeeId: employeeId,
        date: date,
        checkOutTime: checkOutTime,
        latitude: latitude,
        longitude: longitude,
      );
    } on DuplicateAttendanceException catch (e) {
      throw ValidationFailure(e.message);
    } on LocalDatabaseException catch (e) {
      throw DatabaseFailure(e.message);
    } on AppException catch (e) {
      throw ValidationFailure(e.message);
    } catch (e) {
      throw DatabaseFailure('Unexpected error recording check-out: $e');
    }
  }

  @override
  Future<List<AttendanceRecordModel>> getEmployeeHistory(String employeeId) async {
    try {
      return await _localDataSource.getHistoryForEmployee(employeeId);
    } on LocalDatabaseException catch (e) {
      throw DatabaseFailure(e.message);
    } catch (e) {
      throw DatabaseFailure('Unexpected error fetching attendance history: $e');
    }
  }

  @override
  Future<List<AttendanceRecordModel>> getAllAttendanceRecords({
    String? date,
    String? searchQuery,
  }) async {
    try {
      return await _localDataSource.getAllRecords(
        date: date,
        searchQuery: searchQuery,
      );
    } on LocalDatabaseException catch (e) {
      throw DatabaseFailure(e.message);
    } catch (e) {
      throw DatabaseFailure('Unexpected error fetching all attendance records: $e');
    }
  }

  @override
  Future<Map<String, int>> getAttendanceSummary(String date) async {
    try {
      return await _localDataSource.getAttendanceSummary(date);
    } on LocalDatabaseException catch (e) {
      throw DatabaseFailure(e.message);
    } catch (e) {
      throw DatabaseFailure('Unexpected error computing attendance summary: $e');
    }
  }

  // ── Phase 8: Mock REST API Integration Methods ─────────────────────────────

  Future<AttendanceRecordModel?> syncCheckInToRemote(AttendanceRecordModel record) async {
    if (_remoteDataSource == null) return null;
    return await _remoteDataSource.submitCheckIn(record);
  }

  Future<List<AttendanceRecordModel>> fetchRemoteHistory(String employeeId) async {
    if (_remoteDataSource == null) return [];
    return await _remoteDataSource.fetchEmployeeHistory(employeeId);
  }

  Future<List<AttendanceRecordModel>> fetchRemoteAdminRecords({
    String? date,
    String? searchQuery,
  }) async {
    if (_remoteDataSource == null) return [];
    return await _remoteDataSource.fetchAdminRecords(date: date, searchQuery: searchQuery);
  }
}
