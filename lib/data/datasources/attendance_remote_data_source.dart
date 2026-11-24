import '../../core/constants/api_constants.dart';
import '../../core/errors/failures.dart';
import '../../core/network/api_client.dart';
import '../../core/network/network_exceptions.dart';
import '../models/attendance_record_model.dart';

/// Remote REST API data source for attendance check-in and records
class AttendanceRemoteDataSource {
  final ApiClient _apiClient;

  AttendanceRemoteDataSource({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  /// Submits an attendance check-in payload to the mock REST API
  Future<AttendanceRecordModel> submitCheckIn(AttendanceRecordModel record) async {
    try {
      final response = await _apiClient.post(
        ApiConstants.attendanceCheckInEndpoint,
        data: record.toMap(),
      );

      final data = response.data;
      if (data is Map && data['data'] != null) {
        return AttendanceRecordModel.fromMap(
          Map<String, dynamic>.from(data['data'] as Map),
        );
      }
      return record;
    } on NetworkException catch (e) {
      if (e.statusCode == 401) {
        throw AuthFailure(e.message, statusCode: e.statusCode);
      }
      throw ServerFailure(e.message, statusCode: e.statusCode);
    } catch (e) {
      throw ServerFailure('Unexpected error syncing check-in with remote API: $e');
    }
  }

  /// Fetches an employee's attendance history from the mock REST API
  Future<List<AttendanceRecordModel>> fetchEmployeeHistory(String employeeId) async {
    try {
      final response = await _apiClient.get(
        ApiConstants.attendanceHistoryEndpoint,
        queryParameters: {'employee_id': employeeId},
      );

      final data = response.data;
      if (data is Map && data['data'] is List) {
        final list = data['data'] as List;
        return list
            .map((item) => AttendanceRecordModel.fromMap(Map<String, dynamic>.from(item as Map)))
            .toList();
      }
      return [];
    } on NetworkException catch (e) {
      if (e.statusCode == 401) {
        throw AuthFailure(e.message, statusCode: e.statusCode);
      }
      throw ServerFailure(e.message, statusCode: e.statusCode);
    } catch (e) {
      throw ServerFailure('Unexpected error fetching attendance history from remote API: $e');
    }
  }

  /// Fetches all employee attendance records with optional date and search query for Admins
  Future<List<AttendanceRecordModel>> fetchAdminRecords({
    String? date,
    String? searchQuery,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (date != null && date.isNotEmpty) {
        queryParams['date'] = date;
      }
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        queryParams['search'] = searchQuery.trim();
      }

      final response = await _apiClient.get(
        ApiConstants.adminRecordsEndpoint,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final data = response.data;
      if (data is Map && data['data'] is List) {
        final list = data['data'] as List;
        return list
            .map((item) => AttendanceRecordModel.fromMap(Map<String, dynamic>.from(item as Map)))
            .toList();
      }
      return [];
    } on NetworkException catch (e) {
      if (e.statusCode == 401) {
        throw AuthFailure(e.message, statusCode: e.statusCode);
      }
      throw ServerFailure(e.message, statusCode: e.statusCode);
    } catch (e) {
      throw ServerFailure('Unexpected error fetching admin records from remote API: $e');
    }
  }
}
