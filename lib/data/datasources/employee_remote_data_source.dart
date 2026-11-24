import '../../core/constants/api_constants.dart';
import '../../core/errors/failures.dart';
import '../../core/network/api_client.dart';
import '../../core/network/network_exceptions.dart';
import '../models/employee_model.dart';

/// Remote REST API data source for employee profiles and directory
class EmployeeRemoteDataSource {
  final ApiClient _apiClient;

  EmployeeRemoteDataSource({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  /// Fetches an individual employee profile from the mock REST API
  Future<EmployeeModel> fetchEmployee(String employeeId) async {
    try {
      final response = await _apiClient.get(
        '${ApiConstants.employeesEndpoint}/$employeeId',
      );

      final data = response.data;
      if (data is Map && data['data'] != null) {
        return EmployeeModel.fromMap(
          Map<String, dynamic>.from(data['data'] as Map),
        );
      }
      throw const ServerFailure('Invalid server response format for employee profile.');
    } on NetworkException catch (e) {
      if (e.statusCode == 401) {
        throw AuthFailure(e.message, statusCode: e.statusCode);
      }
      throw ServerFailure(e.message, statusCode: e.statusCode);
    } catch (e) {
      if (e is Failure) rethrow;
      throw ServerFailure('Unexpected error fetching employee from remote API: $e');
    }
  }

  /// Fetches all registered employees from the mock REST API
  Future<List<EmployeeModel>> fetchEmployees() async {
    try {
      final response = await _apiClient.get(
        ApiConstants.employeeListEndpoint,
      );

      final data = response.data;
      if (data is Map && data['data'] is List) {
        final list = data['data'] as List;
        return list
            .map((item) => EmployeeModel.fromMap(Map<String, dynamic>.from(item as Map)))
            .toList();
      }
      return [];
    } on NetworkException catch (e) {
      if (e.statusCode == 401) {
        throw AuthFailure(e.message, statusCode: e.statusCode);
      }
      throw ServerFailure(e.message, statusCode: e.statusCode);
    } catch (e) {
      if (e is Failure) rethrow;
      throw ServerFailure('Unexpected error fetching employees from remote API: $e');
    }
  }
}
