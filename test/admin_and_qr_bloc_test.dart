import 'package:flutter_application_1/core/constants/app_constants.dart';
import 'package:flutter_application_1/core/errors/failures.dart';
import 'package:flutter_application_1/core/utils/qr_token_service.dart';
import 'package:flutter_application_1/data/models/attendance_record_model.dart';
import 'package:flutter_application_1/data/models/attendance_session_model.dart';
import 'package:flutter_application_1/data/models/employee_model.dart';
import 'package:flutter_application_1/data/repositories/attendance_repository.dart';
import 'package:flutter_application_1/data/repositories/employee_repository.dart';
import 'package:flutter_application_1/data/repositories/qr_session_repository.dart';
import 'package:flutter_application_1/features/admin/bloc/admin_bloc.dart';
import 'package:flutter_application_1/features/admin/bloc/admin_event.dart';
import 'package:flutter_application_1/features/admin/bloc/admin_state.dart';
import 'package:flutter_application_1/features/qr_session/bloc/qr_session_bloc.dart';
import 'package:flutter_application_1/features/qr_session/bloc/qr_session_event.dart';
import 'package:flutter_application_1/features/qr_session/bloc/qr_session_state.dart';
import 'package:flutter_test/flutter_test.dart';

class TestEmployeeRepository implements EmployeeRepository {
  final List<EmployeeModel> _employees = [
    const EmployeeModel(
      employeeId: 'EMP001',
      name: 'John Doe',
      email: 'john@company.com',
      password: 'password',
      role: 'employee',
    ),
    const EmployeeModel(
      employeeId: 'EMP002',
      name: 'Jane Smith',
      email: 'jane@company.com',
      password: 'password',
      role: 'employee',
    ),
    const EmployeeModel(
      employeeId: 'ADM001',
      name: 'Admin',
      email: 'admin@company.com',
      password: 'admin',
      role: 'admin',
    ),
  ];

  @override
  Future<List<EmployeeModel>> getEmployees() async => _employees;

  @override
  Future<EmployeeModel?> getEmployeeById(String employeeId) async => null;

  @override
  Future<EmployeeModel> authenticate(String identifier, String password) async => _employees.first;

  @override
  Future<EmployeeModel?> getActiveSession() async => null;

  @override
  Future<void> saveActiveSession(String employeeId) async {}

  @override
  Future<void> clearActiveSession() async {}
}

class TestAttendanceRepository implements AttendanceRepository {
  @override
  Future<AttendanceRecordModel?> getTodayRecord(String employeeId, String date) async => null;

  @override
  Future<AttendanceRecordModel> checkIn(AttendanceRecordModel record) async => record;

  @override
  Future<void> checkOut({
    required String employeeId,
    required String date,
    required String checkOutTime,
    required double latitude,
    required double longitude,
  }) async {}

  @override
  Future<List<AttendanceRecordModel>> getEmployeeHistory(String employeeId) async => [];

  @override
  Future<List<AttendanceRecordModel>> getAllAttendanceRecords({String? date, String? searchQuery}) async => [
        const AttendanceRecordModel(
          employeeId: 'EMP001',
          date: '2026-11-12',
          checkInTime: '09:00 AM',
          status: 'checked_in',
        ),
      ];

  @override
  Future<Map<String, int>> getAttendanceSummary(String date) async => {
        'total': 2,
        'present': 1,
        'checked_in': 1,
        'checked_out': 0,
        'not_checked_in': 1,
      };
}

class TestQrSessionRepository implements QrSessionRepository {
  AttendanceSessionModel? currentSession;

  @override
  Future<AttendanceSessionModel> createSession(AttendanceSessionModel session) async {
    currentSession = session.copyWith(id: 101);
    return currentSession!;
  }

  @override
  Future<AttendanceSessionModel?> getSessionByToken(String token) async {
    if (currentSession != null && currentSession!.sessionToken == token) {
      return currentSession;
    }
    return null;
  }

  @override
  Future<AttendanceSessionModel?> getSessionById(int sessionId) async {
    if (currentSession != null && currentSession!.id == sessionId) {
      return currentSession;
    }
    return null;
  }

  @override
  Future<AttendanceSessionModel> validateSession({
    required int sessionId,
    required String token,
  }) async {
    final session = (currentSession != null &&
            (currentSession!.id == sessionId || currentSession!.sessionToken == token))
        ? currentSession
        : null;

    if (session == null) {
      throw const QrFailure('QR session not found or unrecognized.');
    }
    if (session.sessionToken.toUpperCase() != token.toUpperCase()) {
      throw const QrFailure('Security token verification failed. Invalid QR code.');
    }
    if (session.status != AppConstants.sessionActive) {
      throw QrFailure('This attendance session is no longer active (status: ${session.status}).');
    }
    if (DateTime.now().isAfter(session.expiresAt)) {
      throw const QrFailure('Attendance QR code has expired.');
    }
    return session;
  }
    @override
  Future<AttendanceSessionModel> validateRemoteSession({
    required String sessionId,
    required String token,
  }) async {
    if (currentSession != null &&
        currentSession!.sessionToken == token) {
      return currentSession!;
    }
    throw const QrFailure('QR session not found or unrecognized.');
  }

  @override
  Future<AttendanceSessionModel?> getLatestActiveSession() async => currentSession;

  @override
  Future<void> expireSession(int sessionId) async {
    if (currentSession != null && currentSession!.id == sessionId) {
      currentSession = currentSession!.copyWith(status: AppConstants.sessionExpired);
    }
  }

  @override
  Future<void> expirePastSessions() async {
    if (currentSession != null) {
      currentSession = currentSession!.copyWith(status: AppConstants.sessionExpired);
    }
  }

  @override
  Future<AttendanceSessionModel> generateNewSession() async {
    await expirePastSessions();
    final token = QrTokenService.generateSecureToken();
    final now = DateTime.now();
    final session = AttendanceSessionModel(
      id: 102,
      sessionToken: token,
      createdAt: now,
      expiresAt: now.add(AppConstants.qrSessionExpiry),
      status: AppConstants.sessionActive,
    );
    currentSession = session;
    return session;
  }
}

void main() {
  group('AdminBloc Tests', () {
    late TestEmployeeRepository empRepo;
    late TestAttendanceRepository attRepo;
    late AdminBloc adminBloc;

    setUp(() {
      empRepo = TestEmployeeRepository();
      attRepo = TestAttendanceRepository();
      adminBloc = AdminBloc(
        employeeRepository: empRepo,
        attendanceRepository: attRepo,
      );
    });

    tearDown(() {
      adminBloc.close();
    });

    test('Loads dashboard metrics and excludes admin from employee count', () async {
      expectLater(
        adminBloc.stream,
        emitsInOrder([
          const AdminLoading(),
          predicate<AdminState>((state) {
            if (state is! AdminLoaded) return false;
            // 2 employees (excluding the 1 admin)
            return state.totalEmployees == 2 &&
                state.presentCount == 1 &&
                state.checkedInCount == 1 &&
                state.notCheckedInCount == 1 &&
                state.employees.length == 2;
          }),
        ]),
      );

      adminBloc.add(const AdminDashboardLoadRequested());
    });
  });

  group('QRSessionBloc Tests', () {
    late TestQrSessionRepository qrRepo;
    late QRSessionBloc qrBloc;

    setUp(() {
      qrRepo = TestQrSessionRepository();
      qrBloc = QRSessionBloc(qrSessionRepository: qrRepo);
    });

    tearDown(() {
      qrBloc.close();
    });

    test('Generates unique QR session with 5-minute expiry', () async {
      expectLater(
        qrBloc.stream,
        emitsInOrder([
          const QRSessionLoading(),
          predicate<QRSessionState>((state) {
            if (state is! QRSessionActive) return false;
            final payload = QrTokenService.decodeQrPayload(state.qrPayload);
            return payload != null &&
                state.session.status == 'active' &&
                state.remainingSeconds > 290 &&
                state.remainingSeconds <= 300;
          }),
        ]),
      );

      qrBloc.add(const GenerateQRSessionRequested());
    });

    test('Cryptographically secure tokens are unique across generations', () {
      final token1 = QrTokenService.generateSecureToken();
      final token2 = QrTokenService.generateSecureToken();
      expect(token1, isNot(equals(token2)));
      expect(token1.startsWith('ATT-'), true);
      expect(token2.startsWith('ATT-'), true);
    });
  });
}
