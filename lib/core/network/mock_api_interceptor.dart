import 'dart:convert';
import 'package:dio/dio.dart';
import '../constants/api_constants.dart';

/// Local Mock REST API Interceptor for Smart Attendance
///
/// NOTE: This is a simulated Mock API for development, testing, and assessment
/// verification. It intercepts HTTP requests made to [ApiConstants.baseUrl] and
/// returns realistic JSON responses using domain models without requiring a live
/// remote backend.
class MockApiInterceptor extends Interceptor {
  // In-memory mock database of sample employees
  final List<Map<String, dynamic>> _mockEmployees = [
    {
      'id': 1,
      'employee_id': 'EMP001',
      'name': 'John Doe',
      'email': 'john.doe@company.com',
      'role': 'employee',
    },
    {
      'id': 2,
      'employee_id': 'EMP002',
      'name': 'Jane Smith',
      'email': 'jane.smith@company.com',
      'role': 'employee',
    },
    {
      'id': 3,
      'employee_id': 'EMP003',
      'name': 'Robert Brown',
      'email': 'robert.b@company.com',
      'role': 'employee',
    },
    {
      'id': 4,
      'employee_id': 'EMP004',
      'name': 'Emily Davis',
      'email': 'emily.d@company.com',
      'role': 'employee',
    },
    {
      'id': 5,
      'employee_id': 'ADM001',
      'name': 'System Administrator',
      'email': 'admin@company.com',
      'role': 'admin',
    },
  ];

  // In-memory mock storage of attendance records
  final List<Map<String, dynamic>> _mockRecords = [
    {
      'id': 1,
      'employee_id': 'EMP001',
      'employee_name': 'John Doe',
      'employee_email': 'john.doe@company.com',
      'date': '2026-11-12',
      'check_in_time': '09:05 AM',
      'check_out_time': null,
      'status': 'checked_in',
      'check_in_latitude': 12.9716,
      'check_in_longitude': 77.5946,
      'check_in_accuracy': 5.0,
      'location_captured_at': '2026-11-12T09:05:00.000Z',
      'is_within_geofence': 1,
      'distance_to_office_meters': 18.0,
      'session_id': 1,
    },
    {
      'id': 2,
      'employee_id': 'EMP002',
      'employee_name': 'Jane Smith',
      'employee_email': 'jane.smith@company.com',
      'date': '2026-11-12',
      'check_in_time': '09:15 AM',
      'check_out_time': null,
      'status': 'checked_in',
      'check_in_latitude': 12.9800,
      'check_in_longitude': 77.6000,
      'check_in_accuracy': 12.0,
      'location_captured_at': '2026-11-12T09:15:00.000Z',
      'is_within_geofence': 0,
      'distance_to_office_meters': 1500.0,
      'session_id': 1,
    },
  ];

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final path = options.path;
    final method = options.method.toUpperCase();

    // ── Simulation Scenarios ─────────────────────────────────────────────────
    // 1. Timeout simulation
    if (options.headers.containsKey('X-Simulate-Timeout') || path.contains('/timeout')) {
      return handler.reject(
        DioException.connectionTimeout(
          requestOptions: options,
          timeout: options.connectTimeout ?? const Duration(seconds: 15),
        ),
      );
    }

    // 2. Unauthorized (401) simulation
    if (options.headers.containsKey('X-Simulate-Unauthorized') ||
        path.contains('/unauthorized') ||
        options.headers['Authorization'] == 'Bearer invalid_token') {
      return handler.reject(
        DioException.badResponse(
          statusCode: 401,
          requestOptions: options,
          response: Response(
            requestOptions: options,
            statusCode: 401,
            data: {
              'success': false,
              'error': 'Unauthorized',
              'message': 'Unauthorized: Invalid, missing, or expired authentication token.',
            },
          ),
        ),
      );
    }

    // 3. Server Error (500) simulation
    if (options.headers.containsKey('X-Simulate-Server-Error') || path.contains('/server-error')) {
      return handler.reject(
        DioException.badResponse(
          statusCode: 500,
          requestOptions: options,
          response: Response(
            requestOptions: options,
            statusCode: 500,
            data: {
              'success': false,
              'error': 'Internal Server Error',
              'message': 'Server Error: Simulated remote server failure.',
            },
          ),
        ),
      );
    }

    // ── Endpoint 1: Fetching Employee Information ────────────────────────────
    if (method == 'GET' && (path == ApiConstants.employeeListEndpoint || path == '/admin/employees')) {
      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            'success': true,
            'count': _mockEmployees.length,
            'data': _mockEmployees,
          },
        ),
      );
    }

    if (method == 'GET' && (path.startsWith(ApiConstants.employeesEndpoint) || path.startsWith('/employees'))) {
      final segments = Uri.parse(path).pathSegments;
      final requestedId = segments.length > 1
          ? segments.last
          : (options.queryParameters['employee_id'] as String?);

      final emp = _mockEmployees.firstWhere(
        (e) => e['employee_id'] == requestedId || e['id'].toString() == requestedId,
        orElse: () => {},
      );

      if (emp.isNotEmpty) {
        return handler.resolve(
          Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'success': true,
              'data': emp,
            },
          ),
        );
      } else {
        return handler.reject(
          DioException.badResponse(
            statusCode: 404,
            requestOptions: options,
            response: Response(
              requestOptions: options,
              statusCode: 404,
              data: {
                'success': false,
                'error': 'Not Found',
                'message': 'Employee not found.',
              },
            ),
          ),
        );
      }
    }

    // ── Endpoint 2: Fetching Attendance Records (Personal History) ────────────
    if (method == 'GET' &&
        (path == ApiConstants.attendanceHistoryEndpoint || path == '/attendance/history')) {
      final employeeId = options.queryParameters['employee_id'] as String?;
      var filtered = List<Map<String, dynamic>>.from(_mockRecords);
      if (employeeId != null && employeeId.isNotEmpty) {
        filtered = filtered.where((r) => r['employee_id'] == employeeId).toList();
      }

      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            'success': true,
            'count': filtered.length,
            'data': filtered,
          },
        ),
      );
    }

    // ── Endpoint 3: Submitting Attendance Check-In Data ───────────────────────
    if (method == 'POST' &&
        (path == ApiConstants.attendanceCheckInEndpoint || path == '/attendance/check-in')) {
      dynamic data = options.data;
      if (data is String) {
        data = jsonDecode(data);
      }

      final payload = Map<String, dynamic>.from(data as Map);
      final employeeId = payload['employee_id'] as String?;
      final date = payload['date'] as String?;

      if (employeeId == null || employeeId.isEmpty || date == null || date.isEmpty) {
        return handler.reject(
          DioException.badResponse(
            statusCode: 400,
            requestOptions: options,
            response: Response(
              requestOptions: options,
              statusCode: 400,
              data: {
                'success': false,
                'error': 'Bad Request',
                'message': 'employee_id and date are mandatory fields.',
              },
            ),
          ),
        );
      }

      final newRecord = Map<String, dynamic>.from(payload);
      newRecord['id'] = _mockRecords.length + 100;
      newRecord['status'] = payload['status'] ?? 'checked_in';
      _mockRecords.add(newRecord);

      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 201,
          data: {
            'success': true,
            'message': 'Check-in recorded successfully on mock server.',
            'data': newRecord,
          },
        ),
      );
    }

    // ── Endpoint 4: Fetching Admin Attendance Records (with Filters) ──────────
    if (method == 'GET' &&
        (path == ApiConstants.adminRecordsEndpoint || path == '/admin/records')) {
      final dateFilter = options.queryParameters['date'] as String?;
      final searchQuery = options.queryParameters['search'] as String? ??
          options.queryParameters['search_query'] as String?;

      var filtered = List<Map<String, dynamic>>.from(_mockRecords);

      if (dateFilter != null && dateFilter.isNotEmpty) {
        filtered = filtered.where((r) => r['date'] == dateFilter).toList();
      }

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final query = searchQuery.trim().toLowerCase();
        filtered = filtered.where((r) {
          final name = (r['employee_name'] as String?)?.toLowerCase() ?? '';
          final empId = (r['employee_id'] as String?)?.toLowerCase() ?? '';
          return name.contains(query) || empId.contains(query);
        }).toList();
      }

      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            'success': true,
            'count': filtered.length,
            'data': filtered,
          },
        ),
      );
    }

    // Fallback: pass request through if not handled by mock
    return handler.next(options);
  }
}
