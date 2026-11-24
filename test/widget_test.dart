import 'package:flutter_application_1/data/models/attendance_record_model.dart';
import 'package:flutter_application_1/data/models/attendance_session_model.dart';
import 'package:flutter_application_1/data/models/employee_model.dart';
import 'package:flutter_application_1/data/repositories/attendance_repository.dart';
import 'package:flutter_application_1/data/repositories/employee_repository.dart';
import 'package:flutter_application_1/data/repositories/qr_session_repository.dart';
import 'package:flutter_application_1/features/admin/bloc/admin_bloc.dart';
import 'package:flutter_application_1/features/attendance/bloc/attendance_bloc.dart';
import 'package:flutter_application_1/features/auth/bloc/auth_bloc.dart';
import 'package:flutter_application_1/features/qr_scanner/bloc/qr_scanner_bloc.dart';
import 'package:flutter_application_1/features/qr_session/bloc/qr_session_bloc.dart';
import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/routes/app_router.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeEmployeeRepository implements EmployeeRepository {
  @override
  Future<List<EmployeeModel>> getEmployees() async => [];

  @override
  Future<EmployeeModel?> getEmployeeById(String employeeId) async => null;

  @override
  Future<EmployeeModel> authenticate(String identifier, String password) async {
    return const EmployeeModel(
      employeeId: 'ADM001',
      name: 'Admin',
      email: 'admin@company.com',
      password: 'admin',
      role: 'admin',
    );
  }

  @override
  Future<EmployeeModel?> getActiveSession() async => null;

  @override
  Future<void> saveActiveSession(String employeeId) async {}

  @override
  Future<void> clearActiveSession() async {}
}

class FakeAttendanceRepository implements AttendanceRepository {
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
  Future<List<AttendanceRecordModel>> getAllAttendanceRecords({String? date, String? searchQuery}) async => [];

  @override
  Future<Map<String, int>> getAttendanceSummary(String date) async => {
        'total': 0,
        'present': 0,
        'checked_in': 0,
        'checked_out': 0,
        'not_checked_in': 0,
      };
}

class FakeQrSessionRepository implements QrSessionRepository {
  @override
  Future<AttendanceSessionModel> createSession(AttendanceSessionModel session) async => session;

  @override
  Future<AttendanceSessionModel?> getSessionByToken(String token) async => null;

  @override
  Future<AttendanceSessionModel?> getSessionById(int sessionId) async => null;

  @override
  Future<AttendanceSessionModel> validateSession({
    required int sessionId,
    required String token,
  }) async {
    return AttendanceSessionModel(
      id: sessionId,
      sessionToken: token,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      status: 'active',
    );
  }
    @override
  Future<AttendanceSessionModel> validateRemoteSession({
    required String sessionId,
    required String token,
  }) async {
    return AttendanceSessionModel(
      id: 1,
      remoteSessionId: sessionId,
      sessionToken: token,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      status: 'active',
    );
  }

  @override
  Future<AttendanceSessionModel?> getLatestActiveSession() async => null;

  @override
  Future<void> expireSession(int sessionId) async {}

  @override
  Future<void> expirePastSessions() async {}

  @override
  Future<AttendanceSessionModel> generateNewSession() async {
    return AttendanceSessionModel(
      id: 1,
      sessionToken: 'ATT-SAMPLE1234',
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      status: 'active',
    );
  }
}

void main() {
  testWidgets('SmartAttendanceApp startup smoke test', (WidgetTester tester) async {
    final fakeEmpRepo = FakeEmployeeRepository();
    final fakeAttRepo = FakeAttendanceRepository();
    final fakeQrRepo = FakeQrSessionRepository();

    final authBloc = AuthBloc(employeeRepository: fakeEmpRepo);
    final adminBloc = AdminBloc(
      employeeRepository: fakeEmpRepo,
      attendanceRepository: fakeAttRepo,
    );
    final qrSessionBloc = QRSessionBloc(qrSessionRepository: fakeQrRepo);
    final qrScannerBloc = QRScannerBloc(qrSessionRepository: fakeQrRepo);
    final attendanceBloc = AttendanceBloc(attendanceRepository: fakeAttRepo);

    final router = AppRouter.createRouter(authBloc);

    await tester.pumpWidget(
      SmartAttendanceApp(
        authBloc: authBloc,
        adminBloc: adminBloc,
        qrSessionBloc: qrSessionBloc,
        qrScannerBloc: qrScannerBloc,
        attendanceBloc: attendanceBloc,
        router: router,
      ),
    );
    await tester.pump();

    expect(find.byType(SmartAttendanceApp), findsOneWidget);
  });
}
