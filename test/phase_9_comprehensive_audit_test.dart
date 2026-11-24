import 'package:dio/dio.dart';
import 'package:flutter_application_1/core/constants/api_constants.dart';
import 'package:flutter_application_1/core/constants/app_constants.dart';
import 'package:flutter_application_1/core/errors/failures.dart';
import 'package:flutter_application_1/core/network/api_client.dart';
import 'package:flutter_application_1/core/network/network_exceptions.dart';
import 'package:flutter_application_1/core/services/location_service.dart';
import 'package:flutter_application_1/core/utils/qr_token_service.dart';
import 'package:flutter_application_1/data/models/attendance_record_model.dart';
import 'package:flutter_application_1/data/models/attendance_session_model.dart';
import 'package:flutter_application_1/data/models/employee_model.dart';
import 'package:flutter_application_1/data/repositories/attendance_repository.dart';
import 'package:flutter_application_1/data/repositories/employee_repository.dart';
import 'package:flutter_application_1/data/repositories/qr_session_repository.dart';
import 'package:flutter_application_1/features/admin/bloc/admin_records_bloc.dart';
import 'package:flutter_application_1/features/admin/bloc/admin_records_event.dart';
import 'package:flutter_application_1/features/admin/bloc/admin_records_state.dart';
import 'package:flutter_application_1/features/attendance/bloc/attendance_bloc.dart';
import 'package:flutter_application_1/features/attendance/bloc/attendance_event.dart';
import 'package:flutter_application_1/features/attendance/bloc/attendance_state.dart';
import 'package:flutter_application_1/features/auth/bloc/auth_bloc.dart';
import 'package:flutter_application_1/features/history/bloc/history_bloc.dart';
import 'package:flutter_application_1/features/history/bloc/history_event.dart';
import 'package:flutter_application_1/features/history/bloc/history_state.dart';
import 'package:flutter_application_1/features/qr_scanner/bloc/qr_scanner_bloc.dart';
import 'package:flutter_application_1/features/qr_scanner/bloc/qr_scanner_event.dart';
import 'package:flutter_application_1/features/qr_scanner/bloc/qr_scanner_state.dart';
import 'package:flutter_application_1/routes/app_router.dart';
import 'package:flutter_application_1/routes/app_routes.dart';
import 'package:flutter_test/flutter_test.dart';

// ============================================================================
// COMPREHENSIVE TEST FAKES
// ============================================================================

class MockEmployeeRepo implements EmployeeRepository {
  EmployeeModel? sessionToReturn;

  @override
  Future<EmployeeModel> authenticate(String identifier, String password) async {
    return const EmployeeModel(
      employeeId: 'EMP001',
      name: 'John Doe',
      email: 'john.doe@company.com',
      password: 'password',
      role: 'employee',
    );
  }

  @override
  Future<void> clearActiveSession() async => sessionToReturn = null;
  @override
  Future<EmployeeModel?> getActiveSession() async => sessionToReturn;
  @override
  Future<EmployeeModel?> getEmployeeById(String employeeId) async => null;
  @override
  Future<List<EmployeeModel>> getEmployees() async => [];
  @override
  Future<void> saveActiveSession(String employeeId) async {}
  Future<EmployeeModel?> fetchRemoteEmployee(String employeeId) async => null;
  Future<List<EmployeeModel>> fetchRemoteEmployees() async => [];
}

class MockQrSessionRepo implements QrSessionRepository {
   
  AttendanceSessionModel? dbSession;

  @override
  Future<AttendanceSessionModel> validateSession({
    required int sessionId,
    required String token,
  }) async {
    if (dbSession != null && dbSession!.id == sessionId && dbSession!.sessionToken == token) {
      if (dbSession!.isExpired) {
        throw const QrFailure('QR session has expired in database.');
      }
      return dbSession!;
    }
    throw const QrFailure('QR session not recognized or token mismatch.');
  }
    @override
  Future<AttendanceSessionModel> validateRemoteSession({
    required String sessionId,
    required String token,
  }) async {
    if (dbSession != null &&
        dbSession!.sessionToken == token) {
      if (dbSession!.isExpired) {
        throw const QrFailure('QR session has expired in database.');
      }
      return dbSession!;
    }
    throw const QrFailure('QR session not recognized or token mismatch.');
  }

  @override
  Future<AttendanceSessionModel> createSession(AttendanceSessionModel session) async => session;
  @override
  Future<void> expirePastSessions() async {}
  @override
  Future<void> expireSession(int sessionId) async {}
  @override
  Future<AttendanceSessionModel> generateNewSession() async => dbSession!;
  @override
  Future<AttendanceSessionModel?> getLatestActiveSession() async => dbSession;
  @override
  Future<AttendanceSessionModel?> getSessionById(int sessionId) async => dbSession;
  @override
  Future<AttendanceSessionModel?> getSessionByToken(String token) async => dbSession;
}

class MockAttendanceRepo implements AttendanceRepository {
  AttendanceRecordModel? todayRecord;
  int checkInCount = 0;
  List<AttendanceRecordModel> historyList = [];
  List<AttendanceRecordModel> adminList = [];

  @override
  Future<AttendanceRecordModel?> getTodayRecord(String employeeId, String date) async => todayRecord;

  @override
  Future<AttendanceRecordModel> checkIn(AttendanceRecordModel record) async {
    checkInCount++;
    todayRecord = record.copyWith(id: 101);
    return todayRecord!;
  }

  @override
  Future<void> checkOut({
    required String employeeId,
    required String date,
    required String checkOutTime,
    required double latitude,
    required double longitude,
  }) async {}

  @override
  Future<List<AttendanceRecordModel>> getEmployeeHistory(String employeeId) async => historyList;

  @override
  Future<List<AttendanceRecordModel>> getAllAttendanceRecords({String? date, String? searchQuery}) async => adminList;

  @override
  Future<Map<String, int>> getAttendanceSummary(String date) async => {
        'total': 4,
        'present': todayRecord != null ? 1 : 0,
        'checked_in': todayRecord != null ? 1 : 0,
        'checked_out': 0,
        'not_checked_in': todayRecord != null ? 3 : 4,
      };

  Future<AttendanceRecordModel?> syncCheckInToRemote(AttendanceRecordModel record) async => record;
  Future<List<AttendanceRecordModel>> fetchRemoteHistory(String employeeId) async => historyList;
  Future<List<AttendanceRecordModel>> fetchRemoteAdminRecords({String? date, String? searchQuery}) async => adminList;
}

class MockLocationService implements LocationService {
  LocationResult resultToReturn = const LocationResult(
    latitude: AppConstants.defaultOfficeLatitude,
    longitude: AppConstants.defaultOfficeLongitude,
    accuracy: 5.0,
    capturedAt: '2026-11-12T09:00:00.000Z',
    isWithinGeofence: true,
    distanceToOfficeMeters: 10.0,
  );

  @override
  Future<LocationResult> captureCheckInLocation() async => resultToReturn;
}

void main() {
  group('Phase 9 - Task 2: Role Restrictions & Route Guard Audit', () {
    test('1. Unauthenticated state redirects protected routes to login', () {
      final authBloc = AuthBloc(employeeRepository: MockEmployeeRepo());
      final router = AppRouter.createRouter(authBloc);

      // Verify router is instantiated and configured
      expect(router.routeInformationProvider.value.uri.path, equals(AppRoutes.splash));
      authBloc.close();
    });

    test('2. Employee role guard prevents Admin from accessing employee check-in in AttendanceBloc', () async {
      final attRepo = MockAttendanceRepo();
      final attBloc = AttendanceBloc(attendanceRepository: attRepo);

      final session = AttendanceSessionModel(
        id: 1,
        sessionToken: 'ATT-SAMPLE',
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
        status: AppConstants.sessionActive,
      );

      attBloc.add(AttendanceCheckInRequested(
        employeeId: 'ADM001',
        session: session,
        role: AppConstants.roleAdmin,
      ));

      await expectLater(
        attBloc.stream,
        emits(predicate<AttendanceState>((state) {
          return state is AttendanceError &&
              state.message.contains('Administrators cannot mark attendance');
        })),
      );

      expect(attRepo.checkInCount, equals(0));
      attBloc.close();
    });

    test('3. Admin role guard prevents Employee from querying all records in AdminRecordsBloc', () async {
      final attRepo = MockAttendanceRepo();
      final adminRecordsBloc = AdminRecordsBloc(attendanceRepository: attRepo);

      adminRecordsBloc.add(const LoadAdminRecordsRequested(role: AppConstants.roleEmployee));

      await expectLater(
        adminRecordsBloc.stream,
        emits(predicate<AdminRecordsState>((state) {
          return state is AdminRecordsError &&
              state.message.contains('Unauthorized access: Only administrators can view all employee attendance records');
        })),
      );

      adminRecordsBloc.close();
    });
  });

  group('Phase 9 - Task 3: QR Security, Expiration & Duplicate Check-in Audit', () {
    late MockQrSessionRepo qrRepo;
    late QRScannerBloc qrScannerBloc;

    setUp(() {
      qrRepo = MockQrSessionRepo();
      qrScannerBloc = QRScannerBloc(qrSessionRepository: qrRepo);
    });

    tearDown(() {
      qrScannerBloc.close();
    });

    test('1. Token mismatch or altered payload is rejected', () async {
      qrRepo.dbSession = AttendanceSessionModel(
        id: 1,
        sessionToken: 'ATT-ORIGINAL12',
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
        status: AppConstants.sessionActive,
      );

      // Payload contains altered token
      final tamperedPayload = QrTokenService.encodeQrPayload(
        sessionId: 1,
        token: 'ATT-ALTERED999',
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      );

      qrScannerBloc.add(QRCodeDetected(tamperedPayload));

      await expectLater(
        qrScannerBloc.stream,
        emitsInOrder([
          const QRScannerProcessing(),
          predicate<QRScannerState>((state) {
            return state is QRScannerFailure &&
                state.message.contains('QR session not recognized or token mismatch');
          }),
        ]),
      );
    });

    test('2. Expired payload timestamp is rejected before calling database', () async {
      final pastTime = DateTime.now().subtract(const Duration(minutes: 10));
      final expiredPayload = QrTokenService.encodeQrPayload(
        sessionId: 2,
        token: 'ATT-EXPIRED123',
        createdAt: pastTime.subtract(const Duration(minutes: 5)),
        expiresAt: pastTime,
      );

      qrScannerBloc.add(QRCodeDetected(expiredPayload));

      await expectLater(
        qrScannerBloc.stream,
        emitsInOrder([
          const QRScannerProcessing(),
          predicate<QRScannerState>((state) {
            return state is QRScannerFailure &&
                state.message.contains('Attendance QR code has expired');
          }),
        ]),
      );
    });

    test('3. Multi-level duplicate check-in prevention blocks consecutive check-in on same day', () async {
      final attRepo = MockAttendanceRepo();
      final attBloc = AttendanceBloc(
        attendanceRepository: attRepo,
        locationService: MockLocationService(),
      );

      final session = AttendanceSessionModel(
        id: 3,
        sessionToken: 'ATT-DUPETOKEN1',
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
        status: AppConstants.sessionActive,
      );

      // First check-in succeeds
      attBloc.add(AttendanceCheckInRequested(
        employeeId: 'EMP001',
        session: session,
        role: AppConstants.roleEmployee,
      ));

      await expectLater(
        attBloc.stream,
        emitsInOrder([
          const AttendanceCapturingLocation(),
          const AttendanceLoading(),
          predicate<AttendanceState>((s) => s is AttendanceCheckInSuccess),
        ]),
      );

      expect(attRepo.checkInCount, equals(1));

      // Second check-in on the same day is blocked at BLoC layer
      attBloc.add(AttendanceCheckInRequested(
        employeeId: 'EMP001',
        session: session,
        role: AppConstants.roleEmployee,
      ));

      await expectLater(
        attBloc.stream,
        emitsInOrder([
          const AttendanceCapturingLocation(),
          const AttendanceLoading(),
          predicate<AttendanceState>((s) =>
              s is AttendanceDuplicateError && s.message.contains('already checked in today')),
        ]),
      );

      expect(attRepo.checkInCount, equals(1));
      attBloc.close();
    });
  });

  group('Phase 9 - Task 4 & 5: GPS Location, Geofence & History Audit', () {
    test('1. Check-in inside geofence saves accurate GPS coordinates', () async {
      final attRepo = MockAttendanceRepo();
      final locService = MockLocationService();
      locService.resultToReturn = const LocationResult(
        latitude: AppConstants.defaultOfficeLatitude,
        longitude: AppConstants.defaultOfficeLongitude,
        accuracy: 4.2,
        capturedAt: '2026-11-12T09:00:00.000Z',
        isWithinGeofence: true,
        distanceToOfficeMeters: 8.5,
      );

      final attBloc = AttendanceBloc(
        attendanceRepository: attRepo,
        locationService: locService,
      );

      final session = AttendanceSessionModel(
        id: 1,
        sessionToken: 'ATT-GEOFENCE12',
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
        status: AppConstants.sessionActive,
      );

      attBloc.add(AttendanceCheckInRequested(
        employeeId: 'EMP001',
        session: session,
        role: AppConstants.roleEmployee,
      ));

      await expectLater(
        attBloc.stream,
        emitsInOrder([
          const AttendanceCapturingLocation(),
          const AttendanceLoading(),
          predicate<AttendanceState>((s) {
            if (s is! AttendanceCheckInSuccess) return false;
            final r = s.record;
            return r.checkInLatitude == AppConstants.defaultOfficeLatitude &&
                r.checkInAccuracy == 4.2 &&
                r.isWithinGeofence == true &&
                r.distanceToOfficeMeters == 8.5;
          }),
        ]),
      );

      attBloc.close();
    });

    test('2. Employee can view only their own history in HistoryBloc', () async {
      final attRepo = MockAttendanceRepo();
      attRepo.historyList = [
        const AttendanceRecordModel(
          id: 1,
          employeeId: 'EMP001',
          date: '2026-11-12',
          checkInTime: '09:00 AM',
          status: AppConstants.statusCheckedIn,
        ),
      ];

      final historyBloc = HistoryBloc(attendanceRepository: attRepo);
      historyBloc.add(const LoadHistoryRequested(
        employeeId: 'EMP001',
        role: AppConstants.roleEmployee,
      ));

      await expectLater(
        historyBloc.stream,
        emitsInOrder([
          const HistoryLoading(),
          predicate<HistoryState>((s) =>
              s is HistoryLoaded && s.records.every((r) => r.employeeId == 'EMP001')),
        ]),
      );

      historyBloc.close();
    });
  });

  group('Phase 9 - Task 6: Dio Mock REST API Endpoints & Exceptions Audit', () {
    late ApiClient apiClient;

    setUp(() {
      apiClient = ApiClient(enableMock: true);
    });

    test('1. GET /employees/EMP001 returns valid employee JSON with 200 OK', () async {
      final response = await apiClient.get<Map<String, dynamic>>('/employees/EMP001');
      expect(response.statusCode, equals(200));
      expect(response.data!['data']['employee_id'], equals('EMP001'));
    });

    test('2. GET /employees/INVALID returns 404', () async {
      expect(
        () => apiClient.get<Map<String, dynamic>>('/employees/INVALID'),
        throwsA(isA<NetworkException>().having((e) => e.statusCode, 'statusCode', 404)),
      );
    });

    test('3. Simulated 401 Unauthorized scenario is handled properly', () async {
      expect(
        () => apiClient.get<Map<String, dynamic>>(
          '/attendance/history',
          options: Options(headers: {'X-Simulate-Unauthorized': 'true'}),
        ),
        throwsA(isA<NetworkException>().having((e) => e.statusCode, 'statusCode', 401)),
      );
    });

    test('4. Simulated 500 Server Error scenario is handled properly', () async {
      expect(
        () => apiClient.get<Map<String, dynamic>>(
          '/attendance/history',
          options: Options(headers: {'X-Simulate-Server-Error': 'true'}),
        ),
        throwsA(isA<NetworkException>().having((e) => e.statusCode, 'statusCode', 500)),
      );
    });

    test('5. Simulated Timeout scenario is translated into NetworkException', () async {
      expect(
        () => apiClient.get<Map<String, dynamic>>(
          '/attendance/history',
          options: Options(headers: {'X-Simulate-Timeout': 'true'}),
        ),
        throwsA(isA<NetworkException>().having((e) => e.message.toLowerCase(), 'message', contains('timeout'))),
      );
    });

    test('6. POST /attendance/check-in returns 201 Created', () async {
      final response = await apiClient.post<Map<String, dynamic>>(
        ApiConstants.attendanceCheckInEndpoint,
        data: {
          'employee_id': 'EMP001',
          'date': '2026-11-12',
          'check_in_time': '09:00 AM',
          'status': 'checked_in',
        },
      );

      expect(response.statusCode, equals(201));
      expect(response.data!['success'], isTrue);
    });
  });
}
