import 'package:dio/dio.dart';
import 'package:flutter_application_1/core/constants/api_constants.dart';
import 'package:flutter_application_1/core/constants/app_constants.dart';
import 'package:flutter_application_1/core/network/api_client.dart';
import 'package:flutter_application_1/core/network/network_exceptions.dart';
import 'package:flutter_application_1/data/datasources/attendance_local_data_source.dart';
import 'package:flutter_application_1/data/datasources/attendance_remote_data_source.dart';
import 'package:flutter_application_1/data/datasources/employee_remote_data_source.dart';
import 'package:flutter_application_1/data/models/attendance_record_model.dart';
import 'package:flutter_application_1/data/repositories/attendance_repository.dart';
import 'package:flutter_application_1/data/repositories/employee_repository.dart';
import 'package:flutter_test/flutter_test.dart';

// Test Fake for local SQLite data source in repository integration tests
class FakeLocalAttendanceDataSource extends AttendanceLocalDataSource {
  AttendanceRecordModel? savedRecord;
  int checkInCallCount = 0;

  @override
  Future<int> checkIn(AttendanceRecordModel record) async {
    checkInCallCount++;
    savedRecord = record.copyWith(id: 99);
    return 99;
  }
}

void main() {
  late ApiClient apiClient;

  setUp(() {
    apiClient = ApiClient(enableMock: true);
  });

  // ============================================================================
  // TASK 1 & 2: DIO CONFIGURATION & MOCK REST ENDPOINTS TESTS
  // ============================================================================
  group('Phase 8 - Dio Mock REST API Endpoints', () {
    test('1. Dio is configured with correct base options, timeouts, and headers', () {
      final options = apiClient.dio.options;
      expect(options.baseUrl, equals(ApiConstants.baseUrl));
      expect(options.connectTimeout, equals(ApiConstants.connectTimeout));
      expect(options.receiveTimeout, equals(ApiConstants.receiveTimeout));
      expect(options.headers['Content-Type'], equals('application/json'));
      expect(options.headers['Accept'], equals('application/json'));
    });

    test('2. GET employee info (/employees/EMP001) returns 200 and employee data', () async {
      final response = await apiClient.get<Map<String, dynamic>>('/employees/EMP001');

      expect(response.statusCode, equals(200));
      final body = response.data!;
      expect(body['success'], isTrue);
      expect(body['data']['employee_id'], equals('EMP001'));
      expect(body['data']['name'], equals('John Doe'));
      expect(body['data']['role'], equals('employee'));
    });

    test('3. GET all employees (/admin/employees) returns 200 with list of employees', () async {
      final response = await apiClient.get<Map<String, dynamic>>(ApiConstants.employeeListEndpoint);

      expect(response.statusCode, equals(200));
      final body = response.data!;
      expect(body['success'], isTrue);
      expect(body['count'], greaterThanOrEqualTo(4));
      final employees = body['data'] as List;
      expect(employees.any((e) => e['employee_id'] == 'EMP001'), isTrue);
      expect(employees.any((e) => e['employee_id'] == 'ADM001'), isTrue);
    });

    test('4. GET non-existent employee returns 404 NetworkException', () async {
      expect(
        () => apiClient.get<Map<String, dynamic>>('/employees/NON_EXISTENT_999'),
        throwsA(isA<NetworkException>().having((e) => e.statusCode, 'statusCode', 404)),
      );
    });

    test('5. GET attendance history returns 200 with matching records for employee', () async {
      final response = await apiClient.get<Map<String, dynamic>>(
        ApiConstants.attendanceHistoryEndpoint,
        queryParameters: {'employee_id': 'EMP001'},
      );

      expect(response.statusCode, equals(200));
      final body = response.data!;
      expect(body['success'], isTrue);
      final records = body['data'] as List;
      expect(records, isNotEmpty);
      expect(records.first['employee_id'], equals('EMP001'));
      expect(records.first['status'], equals('checked_in'));
    });

    test('6. POST attendance check-in returns 201 Created with saved record data', () async {
      final payload = {
        'employee_id': 'EMP003',
        'date': '2026-11-12',
        'check_in_time': '09:20 AM',
        'check_in_latitude': 12.9716,
        'check_in_longitude': 77.5946,
        'check_in_accuracy': 4.5,
        'is_within_geofence': 1,
        'distance_to_office_meters': 12.0,
        'status': AppConstants.statusCheckedIn,
      };

      final response = await apiClient.post<Map<String, dynamic>>(
        ApiConstants.attendanceCheckInEndpoint,
        data: payload,
      );

      expect(response.statusCode, equals(201));
      final body = response.data!;
      expect(body['success'], isTrue);
      expect(body['data']['employee_id'], equals('EMP003'));
      expect(body['data']['check_in_latitude'], equals(12.9716));
    });

    test('7. POST attendance check-in missing mandatory fields returns 400 Bad Request', () async {
      final invalidPayload = {
        'status': AppConstants.statusCheckedIn,
      };

      expect(
        () => apiClient.post<Map<String, dynamic>>(
          ApiConstants.attendanceCheckInEndpoint,
          data: invalidPayload,
        ),
        throwsA(isA<NetworkException>().having((e) => e.statusCode, 'statusCode', 400)),
      );
    });

    test('8. GET admin records returns all records with filtering support', () async {
      // 8a. All records
      final allResponse = await apiClient.get<Map<String, dynamic>>(ApiConstants.adminRecordsEndpoint);
      expect(allResponse.statusCode, equals(200));
      final allList = allResponse.data!['data'] as List;
      expect(allList.length, greaterThanOrEqualTo(2));

      // 8b. Filter by date
      final dateResponse = await apiClient.get<Map<String, dynamic>>(
        ApiConstants.adminRecordsEndpoint,
        queryParameters: {'date': '2026-11-12'},
      );
      expect(dateResponse.statusCode, equals(200));
      final dateList = dateResponse.data!['data'] as List;
      expect(dateList.every((r) => r['date'] == '2026-11-12'), isTrue);

      // 8c. Filter by search query
      final searchResponse = await apiClient.get<Map<String, dynamic>>(
        ApiConstants.adminRecordsEndpoint,
        queryParameters: {'search': 'Jane'},
      );
      expect(searchResponse.statusCode, equals(200));
      final searchList = searchResponse.data!['data'] as List;
      expect(searchList.length, equals(1));
      expect(searchList.first['employee_id'], equals('EMP002'));
    });
  });

  // ============================================================================
  // SIMULATION SCENARIOS: UNAUTHORIZED, SERVER ERROR & TIMEOUT
  // ============================================================================
  group('Phase 8 - Simulation Scenarios (Error & Timeout Handling)', () {
    test('1. Unauthorized scenario (401) throws NetworkException with 401 code', () async {
      expect(
        () => apiClient.get<Map<String, dynamic>>(
          '/employees/EMP001',
          options: Options(headers: {'X-Simulate-Unauthorized': 'true'}),
        ),
        throwsA(
          isA<NetworkException>()
              .having((e) => e.statusCode, 'statusCode', 401)
              .having((e) => e.message, 'message', contains('Unauthorized')),
        ),
      );
    });

    test('2. Server error scenario (500) throws NetworkException with 500 code', () async {
      expect(
        () => apiClient.get<Map<String, dynamic>>(
          '/attendance/history',
          options: Options(headers: {'X-Simulate-Server-Error': 'true'}),
        ),
        throwsA(
          isA<NetworkException>()
              .having((e) => e.statusCode, 'statusCode', 500)
              .having((e) => e.message, 'message', contains('Server Error')),
        ),
      );
    });

    test('3. Timeout scenario throws NetworkException with timeout message', () async {
      expect(
        () => apiClient.get<Map<String, dynamic>>(
          '/attendance/history',
          options: Options(headers: {'X-Simulate-Timeout': 'true'}),
        ),
        throwsA(
          isA<NetworkException>().having(
            (e) => e.message.toLowerCase(),
            'message',
            contains('timeout'),
          ),
        ),
      );
    });
  });

  // ============================================================================
  // TASK 3: DATA SOURCE & REPOSITORY INTEGRATION TESTS
  // ============================================================================
  group('Phase 8 - Data Source & Repository Integration', () {
    late AttendanceRemoteDataSource attendanceRemoteDataSource;
    late EmployeeRemoteDataSource employeeRemoteDataSource;

    setUp(() {
      attendanceRemoteDataSource = AttendanceRemoteDataSource(apiClient: apiClient);
      employeeRemoteDataSource = EmployeeRemoteDataSource(apiClient: apiClient);
    });

    test('1. EmployeeRemoteDataSource fetches employee profile model', () async {
      final employee = await employeeRemoteDataSource.fetchEmployee('EMP001');
      expect(employee.employeeId, equals('EMP001'));
      expect(employee.name, equals('John Doe'));
      expect(employee.email, equals('john.doe@company.com'));
      expect(employee.role, equals('employee'));
    });

    test('2. EmployeeRemoteDataSource fetches all registered employees', () async {
      final employees = await employeeRemoteDataSource.fetchEmployees();
      expect(employees.length, greaterThanOrEqualTo(4));
    });

    test('3. AttendanceRemoteDataSource submits check-in record and receives parsed model', () async {
      const record = AttendanceRecordModel(
        employeeId: 'EMP004',
        date: '2026-11-12',
        checkInTime: '09:00 AM',
        status: AppConstants.statusCheckedIn,
        checkInLatitude: 12.9716,
        checkInLongitude: 77.5946,
        checkInAccuracy: 5.0,
        isWithinGeofence: true,
        distanceToOfficeMeters: 14.0,
      );

      final result = await attendanceRemoteDataSource.submitCheckIn(record);
      expect(result.employeeId, equals('EMP004'));
      expect(result.checkInLatitude, equals(12.9716));
      expect(result.isWithinGeofence, isTrue);
    });

    test('4. AttendanceRemoteDataSource fetches employee history models', () async {
      final history = await attendanceRemoteDataSource.fetchEmployeeHistory('EMP001');
      expect(history, isNotEmpty);
      expect(history.first.employeeId, equals('EMP001'));
    });

    test('5. AttendanceRemoteDataSource fetches filtered admin records models', () async {
      final records = await attendanceRemoteDataSource.fetchAdminRecords(searchQuery: 'Jane');
      expect(records.length, equals(1));
      expect(records.first.employeeId, equals('EMP002'));
    });

    test('6. AttendanceRepositoryImpl syncCheckInToRemote submits to mock API', () async {
      final repo = AttendanceRepositoryImpl(
        remoteDataSource: attendanceRemoteDataSource,
      );

      const record = AttendanceRecordModel(
        employeeId: 'EMP002',
        date: '2026-11-12',
        checkInTime: '09:12 AM',
        status: AppConstants.statusCheckedIn,
      );

      final synced = await repo.syncCheckInToRemote(record);
      expect(synced, isNotNull);
      expect(synced!.employeeId, equals('EMP002'));
    });

    test('7. AttendanceRepositoryImpl checkIn preserves local SQLite if remote sync fails', () async {
      // Create an ApiClient that always simulates 500 server error
      final failingDio = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl));
      failingDio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            return handler.reject(
              DioException.badResponse(
                statusCode: 500,
                requestOptions: options,
                response: Response(
                  requestOptions: options,
                  statusCode: 500,
                  data: {'error': 'Mock server failure'},
                ),
              ),
            );
          },
        ),
      );

      final failingApiClient = ApiClient(dio: failingDio, enableMock: false);
      final failingRemoteDataSource = AttendanceRemoteDataSource(apiClient: failingApiClient);
      final fakeLocalDataSource = FakeLocalAttendanceDataSource();

      final repo = AttendanceRepositoryImpl(
        localDataSource: fakeLocalDataSource,
        remoteDataSource: failingRemoteDataSource,
      );

      const record = AttendanceRecordModel(
        employeeId: 'EMP001',
        date: '2026-11-12',
        checkInTime: '09:05 AM',
        status: AppConstants.statusCheckedIn,
      );

      // Local checkIn MUST succeed even though remote sync threw 500
      final result = await repo.checkIn(record);

      expect(fakeLocalDataSource.checkInCallCount, equals(1));
      expect(result.id, equals(99));
      expect(result.employeeId, equals('EMP001'));
    });

    test('8. EmployeeRepositoryImpl fetchRemoteEmployee and fetchRemoteEmployees work with mock API', () async {
      final repo = EmployeeRepositoryImpl(
        remoteDataSource: employeeRemoteDataSource,
      );

      final employee = await repo.fetchRemoteEmployee('EMP001');
      expect(employee, isNotNull);
      expect(employee!.employeeId, equals('EMP001'));

      final allEmployees = await repo.fetchRemoteEmployees();
      expect(allEmployees, isNotEmpty);
    });
  });
}
