import 'dart:convert';
import 'package:flutter_application_1/core/constants/app_constants.dart';
import 'package:flutter_application_1/core/errors/failures.dart';
import 'package:flutter_application_1/core/services/location_service.dart';
import 'package:flutter_application_1/core/utils/date_time_utils.dart';
import 'package:flutter_application_1/core/utils/qr_token_service.dart';
import 'package:flutter_application_1/data/models/attendance_record_model.dart';
import 'package:flutter_application_1/data/models/attendance_session_model.dart';
import 'package:flutter_application_1/data/models/employee_model.dart';
import 'package:flutter_application_1/data/repositories/attendance_repository.dart';
import 'package:flutter_application_1/data/repositories/employee_repository.dart';
import 'package:flutter_application_1/data/repositories/qr_session_repository.dart';
import 'package:flutter_application_1/features/attendance/bloc/attendance_bloc.dart';
import 'package:flutter_application_1/features/attendance/bloc/attendance_event.dart';
import 'package:flutter_application_1/features/attendance/bloc/attendance_state.dart';
import 'package:flutter_application_1/features/qr_scanner/bloc/qr_scanner_bloc.dart';
import 'package:flutter_application_1/features/qr_scanner/bloc/qr_scanner_event.dart';
import 'package:flutter_application_1/features/qr_scanner/bloc/qr_scanner_state.dart';
import 'package:flutter_test/flutter_test.dart';

// ============================================================================
// TEST FAKES & MOCKS
// ============================================================================

class FakeQrSessionRepository implements QrSessionRepository {
  AttendanceSessionModel? sessionToReturn;
  Failure? failureToThrow;
  int validateSessionCallCount = 0;

  @override
  Future<AttendanceSessionModel> validateSession({
    required int sessionId,
    required String token,
  }) async {
    validateSessionCallCount++;
    if (failureToThrow != null) {
      throw failureToThrow!;
    }
    if (sessionToReturn != null) {
      return sessionToReturn!;
    }
    throw const QrFailure('QR session not found or unrecognized.');
  }
    @override
  Future<AttendanceSessionModel> validateRemoteSession({
    required String sessionId,
    required String token,
  }) async {
    validateSessionCallCount++;

    if (failureToThrow != null) {
      throw failureToThrow!;
    }

    if (sessionToReturn != null &&
        sessionToReturn!.sessionToken == token) {
      return sessionToReturn!;
    }

    throw const QrFailure('QR session not found or unrecognized.');
  }

  @override
  Future<AttendanceSessionModel> createSession(AttendanceSessionModel session) async => session;

  @override
  Future<void> expirePastSessions() async {}

  @override
  Future<void> expireSession(int sessionId) async {}

  @override
  Future<AttendanceSessionModel> generateNewSession() async {
    return AttendanceSessionModel(
      id: 1,
      sessionToken: 'ATT-SAMPLE1234',
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      status: AppConstants.sessionActive,
    );
  }

  @override
  Future<AttendanceSessionModel?> getLatestActiveSession() async => sessionToReturn;

  @override
  Future<AttendanceSessionModel?> getSessionById(int sessionId) async => sessionToReturn;

  @override
  Future<AttendanceSessionModel?> getSessionByToken(String token) async => sessionToReturn;
}

class FakeAttendanceRepository implements AttendanceRepository {
  AttendanceRecordModel? todayRecord;
  Failure? checkInFailure;
  int checkInCallCount = 0;

  @override
  Future<AttendanceRecordModel?> getTodayRecord(String employeeId, String date) async {
    return todayRecord;
  }

  @override
  Future<AttendanceRecordModel> checkIn(AttendanceRecordModel record) async {
    checkInCallCount++;
    if (checkInFailure != null) {
      throw checkInFailure!;
    }
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
  Future<List<AttendanceRecordModel>> getAllAttendanceRecords({String? date, String? searchQuery}) async => [];

  @override
  Future<Map<String, int>> getAttendanceSummary(String date) async => {
        'total': 4,
        'present': todayRecord != null ? 1 : 0,
        'checked_in': todayRecord != null ? 1 : 0,
        'checked_out': 0,
        'not_checked_in': todayRecord != null ? 3 : 4,
      };

  @override
  Future<List<AttendanceRecordModel>> getEmployeeHistory(String employeeId) async {
    return todayRecord != null ? [todayRecord!] : [];
  }
}

class FakeLocationService implements LocationService {
  LocationResult locationResultToReturn = const LocationResult(
    latitude: AppConstants.defaultOfficeLatitude,
    longitude: AppConstants.defaultOfficeLongitude,
    accuracy: 10.0,
    capturedAt: '2026-11-12T09:00:00.000Z',
    isWithinGeofence: true,
    distanceToOfficeMeters: 15.0,
  );
  int captureCallCount = 0;

  @override
  Future<LocationResult> captureCheckInLocation() async {
    captureCallCount++;
    return locationResultToReturn;
  }
}

class FakeEmployeeRepository implements EmployeeRepository {
  EmployeeModel? activeSession;

  @override
  Future<EmployeeModel> authenticate(String identifier, String password) async {
    return const EmployeeModel(
      employeeId: 'EMP001',
      name: 'Jane Smith',
      email: 'jane@company.com',
      password: 'password',
      role: 'employee',
    );
  }

  @override
  Future<void> clearActiveSession() async {
    activeSession = null;
  }

  @override
  Future<EmployeeModel?> getActiveSession() async => activeSession;

  @override
  Future<EmployeeModel?> getEmployeeById(String employeeId) async => null;

  @override
  Future<List<EmployeeModel>> getEmployees() async => [];

  @override
  Future<void> saveActiveSession(String employeeId) async {}
}

// ============================================================================
// MAIN TEST SUITE
// ============================================================================

// ============================================================================
// MAIN TEST SUITE
// ============================================================================

void main() {
  group('Phase 5 - QRScannerBloc Tests', () {
    late FakeQrSessionRepository fakeQrRepo;
    late QRScannerBloc qrScannerBloc;

    setUp(() {
      fakeQrRepo = FakeQrSessionRepository();
      qrScannerBloc = QRScannerBloc(qrSessionRepository: fakeQrRepo);
    });

    tearDown(() {
      qrScannerBloc.close();
    });

    test('1. Initial state is QRScannerInitial', () {
      expect(qrScannerBloc.state, equals(const QRScannerInitial()));
    });

    test('2. StartScannerRequested emits QRScannerScanning', () async {
      qrScannerBloc.add(const StartScannerRequested());
      await expectLater(qrScannerBloc.stream, emits(const QRScannerScanning()));
    });

    test('2b. ResetScannerRequested transitions back to QRScannerScanning', () async {
      qrScannerBloc.add(const CameraErrorOccurred('error'));
      await expectLater(
        qrScannerBloc.stream,
        emits(const QRScannerFailure(message: 'error')),
      );

      qrScannerBloc.add(const ResetScannerRequested());
      await expectLater(qrScannerBloc.stream, emits(const QRScannerScanning()));
    });

    test('3. CameraPermissionDeniedEvent emits QRScannerPermissionDenied', () async {
      qrScannerBloc.add(const CameraPermissionDeniedEvent());
      await expectLater(qrScannerBloc.stream, emits(const QRScannerPermissionDenied()));
    });

    test('4. CameraErrorOccurred emits QRScannerFailure', () async {
      qrScannerBloc.add(const CameraErrorOccurred('Camera sensor unavailable'));
      await expectLater(
        qrScannerBloc.stream,
        emits(const QRScannerFailure(message: 'Camera sensor unavailable')),
      );
    });

    test('5. Empty barcode string emits QRScannerFailure', () async {
      qrScannerBloc.add(const QRCodeDetected('   '));
      await expectLater(
        qrScannerBloc.stream,
        emitsInOrder([
          const QRScannerProcessing(),
          const QRScannerFailure(message: 'Empty barcode detected.'),
        ]),
      );
    });

    test('6. Non-JSON string emits QRScannerFailure', () async {
      qrScannerBloc.add(const QRCodeDetected('hello-world-not-json'));
      await expectLater(
        qrScannerBloc.stream,
        emitsInOrder([
          const QRScannerProcessing(),
          predicate<QRScannerState>((state) {
            return state is QRScannerFailure && state.message.contains('Invalid QR code format');
          }),
        ]),
      );
    });

    test('7. Malformed JSON missing required fields emits QRScannerFailure', () async {
      final incompletePayload = jsonEncode({'session_id': 10});
      qrScannerBloc.add(QRCodeDetected(incompletePayload));
      await expectLater(
        qrScannerBloc.stream,
        emitsInOrder([
          const QRScannerProcessing(),
          predicate<QRScannerState>((state) {
            return state is QRScannerFailure && state.message.contains('Invalid QR code format');
          }),
        ]),
      );
    });

    test('8. Malformed expiration date format emits QRScannerFailure', () async {
      final invalidDatePayload = jsonEncode({
        'session_id': 10,
        'token': 'ATT-1234567890AB',
        'created_at': DateTime.now().toIso8601String(),
        'expires_at': 'not-a-valid-date',
      });
      qrScannerBloc.add(QRCodeDetected(invalidDatePayload));
      await expectLater(
        qrScannerBloc.stream,
        emitsInOrder([
          const QRScannerProcessing(),
          predicate<QRScannerState>((state) {
            return state is QRScannerFailure && state.message.contains('Invalid expiration date format');
          }),
        ]),
      );
    });

    test('9. Expired session in payload emits QRScannerFailure', () async {
      final pastDate = DateTime.now().subtract(const Duration(minutes: 10));
      final expiredPayload = QrTokenService.encodeQrPayload(
        sessionId: 5,
        token: 'ATT-PASTTOKEN1',
        createdAt: pastDate.subtract(const Duration(minutes: 5)),
        expiresAt: pastDate,
      );

      qrScannerBloc.add(QRCodeDetected(expiredPayload));
      await expectLater(
        qrScannerBloc.stream,
        emitsInOrder([
          const QRScannerProcessing(),
          predicate<QRScannerState>((state) {
            return state is QRScannerFailure && state.message.contains('expired');
          }),
        ]),
      );
    });

    test('10. Expired session in SQLite database emits QRScannerFailure', () async {
      // Future payload date, but SQLite repository throws expired session failure
      final futureDate = DateTime.now().add(const Duration(minutes: 4));
      final payload = QrTokenService.encodeQrPayload(
        sessionId: 20,
        token: 'ATT-EXPIREDDB1',
        createdAt: DateTime.now(),
        expiresAt: futureDate,
      );

      fakeQrRepo.failureToThrow = const QrFailure(
        'Attendance QR code has expired. Please ask the administrator to generate a new QR session.',
      );

      qrScannerBloc.add(QRCodeDetected(payload));
      await expectLater(
        qrScannerBloc.stream,
        emitsInOrder([
          const QRScannerProcessing(),
          predicate<QRScannerState>((state) {
            return state is QRScannerFailure && state.message.contains('expired');
          }),
        ]),
      );
    });

    test('11. Unknown or unrecognized session in SQLite emits QRScannerFailure', () async {
      final payload = QrTokenService.encodeQrPayload(
        sessionId: 999,
        token: 'ATT-UNKNOWN123',
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(minutes: 4)),
      );

      fakeQrRepo.failureToThrow = const QrFailure('QR session not found or unrecognized.');

      qrScannerBloc.add(QRCodeDetected(payload));
      await expectLater(
        qrScannerBloc.stream,
        emitsInOrder([
          const QRScannerProcessing(),
          predicate<QRScannerState>((state) {
            return state is QRScannerFailure && state.message.contains('not found');
          }),
        ]),
      );
    });

    test('12. Valid active QR payload matching SQLite emits QRScannerSuccess', () async {
      final validSession = AttendanceSessionModel(
        id: 42,
        sessionToken: 'ATT-VALIDTOKEN',
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
        status: AppConstants.sessionActive,
      );

      fakeQrRepo.sessionToReturn = validSession;

      final payload = QrTokenService.encodeQrPayload(
        sessionId: validSession.id!,
        token: validSession.sessionToken,
        createdAt: validSession.createdAt,
        expiresAt: validSession.expiresAt,
      );

      qrScannerBloc.add(QRCodeDetected(payload));
      await expectLater(
        qrScannerBloc.stream,
        emitsInOrder([
          const QRScannerProcessing(),
          QRScannerSuccess(session: validSession),
        ]),
      );
    });

    test('13. Debouncing: Frame detected while QRScannerProcessing is ignored', () async {
      final validSession = AttendanceSessionModel(
        id: 1,
        sessionToken: 'ATT-TOKEN12345',
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
        status: AppConstants.sessionActive,
      );
      fakeQrRepo.sessionToReturn = validSession;

      final payload = QrTokenService.encodeQrPayload(
        sessionId: 1,
        token: 'ATT-TOKEN12345',
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      );

      // Trigger first scan
      qrScannerBloc.add(QRCodeDetected(payload));
      // Immediate duplicate frame from camera
      qrScannerBloc.add(QRCodeDetected(payload));

      await expectLater(
        qrScannerBloc.stream,
        emitsInOrder([
          const QRScannerProcessing(),
          QRScannerSuccess(session: validSession),
        ]),
      );

      // Verify repository was called exactly once
      expect(fakeQrRepo.validateSessionCallCount, equals(1));
    });
  });

  group('Phase 5 - AttendanceBloc & Duplicate Check-in Prevention Tests', () {
    late FakeAttendanceRepository fakeAttRepo;
    late FakeLocationService fakeLocationService;
    late AttendanceBloc attendanceBloc;

    setUp(() {
      fakeAttRepo = FakeAttendanceRepository();
      fakeLocationService = FakeLocationService();
      attendanceBloc = AttendanceBloc(
        attendanceRepository: fakeAttRepo,
        locationService: fakeLocationService,
      );
    });

    tearDown(() {
      attendanceBloc.close();
    });

    test('1. Initial state is AttendanceInitial', () {
      expect(attendanceBloc.state, equals(const AttendanceInitial()));
    });

    test('2. LoadTodayAttendanceRequested returns null record when not checked in', () async {
      fakeAttRepo.todayRecord = null;
      attendanceBloc.add(const LoadTodayAttendanceRequested(employeeId: 'EMP001'));

      await expectLater(
        attendanceBloc.stream,
        emitsInOrder([
          const AttendanceLoading(),
          const AttendanceTodayStatusLoaded(record: null),
        ]),
      );
    });

    test('3. LoadTodayAttendanceRequested returns record when checked in', () async {
      final todayRecord = AttendanceRecordModel(
        id: 1,
        employeeId: 'EMP001',
        date: DateTimeUtils.todayDateString(),
        checkInTime: '09:00 AM',
        status: AppConstants.statusCheckedIn,
      );
      fakeAttRepo.todayRecord = todayRecord;

      attendanceBloc.add(const LoadTodayAttendanceRequested(employeeId: 'EMP001'));

      await expectLater(
        attendanceBloc.stream,
        emitsInOrder([
          const AttendanceLoading(),
          AttendanceTodayStatusLoaded(record: todayRecord),
        ]),
      );
    });

    test('4. AttendanceCheckInRequested records check-in and emits AttendanceCheckInSuccess', () async {
      fakeAttRepo.todayRecord = null;
      final session = AttendanceSessionModel(
        id: 1,
        sessionToken: 'ATT-VALID123456',
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
        status: AppConstants.sessionActive,
      );

      attendanceBloc.add(
        AttendanceCheckInRequested(
          employeeId: 'EMP001',
          session: session,
          role: AppConstants.roleEmployee,
        ),
      );

      await expectLater(
        attendanceBloc.stream,
        emitsInOrder([
          const AttendanceCapturingLocation(),
          const AttendanceLoading(),
          predicate<AttendanceState>((state) {
            return state is AttendanceCheckInSuccess &&
                state.record.employeeId == 'EMP001' &&
                state.record.status == AppConstants.statusCheckedIn;
          }),
        ]),
      );

      expect(fakeAttRepo.checkInCallCount, equals(1));
    });

    test('5. Duplicate check-in is rejected at BLoC level when already checked in today', () async {
      // Simulate that employee already checked in today
      final existingRecord = AttendanceRecordModel(
        id: 10,
        employeeId: 'EMP001',
        date: DateTimeUtils.todayDateString(),
        checkInTime: '08:45 AM',
        status: AppConstants.statusCheckedIn,
      );
      fakeAttRepo.todayRecord = existingRecord;

      final session = AttendanceSessionModel(
        id: 2,
        sessionToken: 'ATT-SESSION2222',
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
        status: AppConstants.sessionActive,
      );

      attendanceBloc.add(
        AttendanceCheckInRequested(
          employeeId: 'EMP001',
          session: session,
          role: AppConstants.roleEmployee,
        ),
      );

      await expectLater(
        attendanceBloc.stream,
        emitsInOrder([
          const AttendanceCapturingLocation(),
          const AttendanceLoading(),
          predicate<AttendanceState>((state) {
            return state is AttendanceDuplicateError &&
                state.message.contains('already checked in today');
          }),
        ]),
      );

      // Verify that checkIn was NOT called on repository because BLoC blocked it
      expect(fakeAttRepo.checkInCallCount, equals(0));
    });

    test('6. Duplicate check-in is rejected when repository/database constraint throws ValidationFailure', () async {
      fakeAttRepo.todayRecord = null; // BLoC check passes initially
      fakeAttRepo.checkInFailure = const ValidationFailure(
        'Attendance has already been recorded for today. Duplicate check-ins are not permitted.',
      );

      final session = AttendanceSessionModel(
        id: 3,
        sessionToken: 'ATT-SESSION3333',
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
        status: AppConstants.sessionActive,
      );

      attendanceBloc.add(
        AttendanceCheckInRequested(
          employeeId: 'EMP001',
          session: session,
          role: AppConstants.roleEmployee,
        ),
      );

      await expectLater(
        attendanceBloc.stream,
        emitsInOrder([
          const AttendanceCapturingLocation(),
          const AttendanceLoading(),
          predicate<AttendanceState>((state) {
            return state is AttendanceDuplicateError &&
                state.message.contains('Duplicate check-ins are not permitted');
          }),
        ]),
      );
    });

    test('7. Admin role check-in attempt is rejected with clear error message', () async {
      final session = AttendanceSessionModel(
        id: 4,
        sessionToken: 'ATT-SESSION4444',
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
        status: AppConstants.sessionActive,
      );

      attendanceBloc.add(
        AttendanceCheckInRequested(
          employeeId: 'ADM001',
          session: session,
          role: AppConstants.roleAdmin,
        ),
      );

      await expectLater(
        attendanceBloc.stream,
        emits(predicate<AttendanceState>((state) {
          return state is AttendanceError &&
              state.message.contains('Administrators cannot mark attendance');
        })),
      );

      expect(fakeAttRepo.checkInCallCount, equals(0));
    });

    test('8. AttendanceResetRequested resets state back to AttendanceInitial', () async {
      attendanceBloc.add(const AttendanceResetRequested());
      await expectLater(attendanceBloc.stream, emits(const AttendanceInitial()));
    });
  });

  // ============================================================================
  // PHASE 6: GPS LOCATION CAPTURE & ATTENDANCE LOCATION VALIDATION TESTS
  // ============================================================================
  group('Phase 6 - GPS Location Capture & Geofence Validation Tests', () {
    late FakeAttendanceRepository fakeAttRepo;
    late FakeLocationService fakeLocationService;
    late AttendanceBloc attendanceBloc;

    setUp(() {
      fakeAttRepo = FakeAttendanceRepository();
      fakeLocationService = FakeLocationService();
      attendanceBloc = AttendanceBloc(
        attendanceRepository: fakeAttRepo,
        locationService: fakeLocationService,
      );
    });

    tearDown(() {
      attendanceBloc.close();
    });

    test('1. Check-in inside office geofence saves coordinates, accuracy, and withinGeofence=true', () async {
      fakeAttRepo.todayRecord = null;
      fakeLocationService.locationResultToReturn = const LocationResult(
        latitude: AppConstants.defaultOfficeLatitude,
        longitude: AppConstants.defaultOfficeLongitude,
        accuracy: 6.5,
        capturedAt: '2026-11-12T09:30:00.000Z',
        isWithinGeofence: true,
        distanceToOfficeMeters: 22.0,
      );

      final session = AttendanceSessionModel(
        id: 10,
        sessionToken: 'ATT-GEOFENCE-IN',
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
        status: AppConstants.sessionActive,
      );

      attendanceBloc.add(
        AttendanceCheckInRequested(
          employeeId: 'EMP001',
          session: session,
          role: AppConstants.roleEmployee,
        ),
      );

      await expectLater(
        attendanceBloc.stream,
        emitsInOrder([
          const AttendanceCapturingLocation(),
          const AttendanceLoading(),
          predicate<AttendanceState>((state) {
            if (state is! AttendanceCheckInSuccess) return false;
            final record = state.record;
            final loc = state.locationResult;
            return record.checkInLatitude == AppConstants.defaultOfficeLatitude &&
                record.checkInLongitude == AppConstants.defaultOfficeLongitude &&
                record.checkInAccuracy == 6.5 &&
                record.locationCapturedAt == '2026-11-12T09:30:00.000Z' &&
                record.isWithinGeofence == true &&
                record.distanceToOfficeMeters == 22.0 &&
                loc?.isWithinGeofence == true &&
                loc?.isSuccess == true;
          }),
        ]),
      );

      // Verify the record committed to repository contains location attributes
      expect(fakeAttRepo.todayRecord?.checkInLatitude, equals(AppConstants.defaultOfficeLatitude));
      expect(fakeAttRepo.todayRecord?.checkInLongitude, equals(AppConstants.defaultOfficeLongitude));
      expect(fakeAttRepo.todayRecord?.checkInAccuracy, equals(6.5));
      expect(fakeAttRepo.todayRecord?.isWithinGeofence, isTrue);
      expect(fakeAttRepo.todayRecord?.distanceToOfficeMeters, equals(22.0));
    });

    test('2. Check-in outside office geofence records distance and withinGeofence=false', () async {
      fakeAttRepo.todayRecord = null;
      fakeLocationService.locationResultToReturn = const LocationResult(
        latitude: 13.0827,
        longitude: 80.2707,
        accuracy: 12.0,
        capturedAt: '2026-11-12T09:35:00.000Z',
        isWithinGeofence: false,
        distanceToOfficeMeters: 290000.0,
      );

      final session = AttendanceSessionModel(
        id: 11,
        sessionToken: 'ATT-GEOFENCE-OUT',
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
        status: AppConstants.sessionActive,
      );

      attendanceBloc.add(
        AttendanceCheckInRequested(
          employeeId: 'EMP002',
          session: session,
          role: AppConstants.roleEmployee,
        ),
      );

      await expectLater(
        attendanceBloc.stream,
        emitsInOrder([
          const AttendanceCapturingLocation(),
          const AttendanceLoading(),
          predicate<AttendanceState>((state) {
            if (state is! AttendanceCheckInSuccess) return false;
            final record = state.record;
            return record.isWithinGeofence == false &&
                record.distanceToOfficeMeters == 290000.0 &&
                state.locationResult?.isWithinGeofence == false;
          }),
        ]),
      );

      expect(fakeAttRepo.todayRecord?.isWithinGeofence, isFalse);
    });

    test('3. Permission denied gracefully allows check-in without location data', () async {
      fakeAttRepo.todayRecord = null;
      fakeLocationService.locationResultToReturn = const LocationResult(
        failure: LocationFailureReason.permissionDenied,
      );

      final session = AttendanceSessionModel(
        id: 12,
        sessionToken: 'ATT-PERM-DENIED',
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
        status: AppConstants.sessionActive,
      );

      attendanceBloc.add(
        AttendanceCheckInRequested(
          employeeId: 'EMP003',
          session: session,
          role: AppConstants.roleEmployee,
        ),
      );

      await expectLater(
        attendanceBloc.stream,
        emitsInOrder([
          const AttendanceCapturingLocation(),
          const AttendanceLoading(),
          predicate<AttendanceState>((state) {
            if (state is! AttendanceCheckInSuccess) return false;
            final record = state.record;
            final loc = state.locationResult;
            return record.checkInLatitude == null &&
                record.isWithinGeofence == null &&
                loc?.failure == LocationFailureReason.permissionDenied &&
                loc?.failureMessage.contains('Location permission was denied') == true;
          }),
        ]),
      );

      expect(fakeAttRepo.todayRecord?.status, equals(AppConstants.statusCheckedIn));
      expect(fakeAttRepo.todayRecord?.checkInLatitude, isNull);
    });

    test('4. GPS service disabled gracefully allows check-in with serviceDisabled reason', () async {
      fakeAttRepo.todayRecord = null;
      fakeLocationService.locationResultToReturn = const LocationResult(
        failure: LocationFailureReason.serviceDisabled,
      );

      final session = AttendanceSessionModel(
        id: 13,
        sessionToken: 'ATT-GPS-DISABLED',
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
        status: AppConstants.sessionActive,
      );

      attendanceBloc.add(
        AttendanceCheckInRequested(
          employeeId: 'EMP004',
          session: session,
          role: AppConstants.roleEmployee,
        ),
      );

      await expectLater(
        attendanceBloc.stream,
        emitsInOrder([
          const AttendanceCapturingLocation(),
          const AttendanceLoading(),
          predicate<AttendanceState>((state) {
            if (state is! AttendanceCheckInSuccess) return false;
            return state.locationResult?.failure == LocationFailureReason.serviceDisabled &&
                state.locationResult?.failureMessage.contains('Location services are disabled') == true;
          }),
        ]),
      );

      expect(fakeAttRepo.todayRecord?.status, equals(AppConstants.statusCheckedIn));
    });

    test('5. Location timeout gracefully allows check-in with timeout reason', () async {
      fakeAttRepo.todayRecord = null;
      fakeLocationService.locationResultToReturn = const LocationResult(
        failure: LocationFailureReason.timeout,
      );

      final session = AttendanceSessionModel(
        id: 14,
        sessionToken: 'ATT-TIMEOUT',
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
        status: AppConstants.sessionActive,
      );

      attendanceBloc.add(
        AttendanceCheckInRequested(
          employeeId: 'EMP001',
          session: session,
          role: AppConstants.roleEmployee,
        ),
      );

      await expectLater(
        attendanceBloc.stream,
        emitsInOrder([
          const AttendanceCapturingLocation(),
          const AttendanceLoading(),
          predicate<AttendanceState>((state) {
            if (state is! AttendanceCheckInSuccess) return false;
            return state.locationResult?.failure == LocationFailureReason.timeout;
          }),
        ]),
      );
    });

    test('6. AttendanceRecordModel serializes and deserializes all location attributes correctly', () {
      final model = AttendanceRecordModel(
        id: 42,
        employeeId: 'EMP001',
        date: '2026-11-12',
        checkInTime: '09:00 AM',
        checkInLatitude: 12.9716,
        checkInLongitude: 77.5946,
        checkInAccuracy: 5.2,
        locationCapturedAt: '2026-11-12T09:00:00.000Z',
        isWithinGeofence: true,
        distanceToOfficeMeters: 18.4,
        status: AppConstants.statusCheckedIn,
        sessionId: 10,
      );

      final map = model.toMap(includeId: true);
      expect(map['id'], equals(42));
      expect(map['check_in_latitude'], equals(12.9716));
      expect(map['check_in_longitude'], equals(77.5946));
      expect(map['check_in_accuracy'], equals(5.2));
      expect(map['location_captured_at'], equals('2026-11-12T09:00:00.000Z'));
      expect(map['is_within_geofence'], equals(1));
      expect(map['distance_to_office_meters'], equals(18.4));

      final fromDb = AttendanceRecordModel.fromMap(map);
      expect(fromDb.id, equals(42));
      expect(fromDb.checkInLatitude, equals(12.9716));
      expect(fromDb.checkInLongitude, equals(77.5946));
      expect(fromDb.checkInAccuracy, equals(5.2));
      expect(fromDb.locationCapturedAt, equals('2026-11-12T09:00:00.000Z'));
      expect(fromDb.isWithinGeofence, isTrue);
      expect(fromDb.distanceToOfficeMeters, equals(18.4));
    });
  });
}
