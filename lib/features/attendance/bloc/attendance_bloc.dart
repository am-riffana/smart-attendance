import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/errors/failures.dart';
import '../../../core/services/location_service.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../../data/models/attendance_record_model.dart';
import '../../../data/repositories/attendance_repository.dart';
import 'attendance_event.dart';
import 'attendance_state.dart';

/// BLoC managing daily check-in, check-out, and duplicate attendance prevention.
/// Phase 6: GPS location capture is performed before every check-in.
class AttendanceBloc extends Bloc<AttendanceEvent, AttendanceState> {
  final AttendanceRepository attendanceRepository;
  final LocationService locationService;

  AttendanceBloc({
    required this.attendanceRepository,
    LocationService? locationService,
  })  : locationService = locationService ?? LocationService(),
        super(const AttendanceInitial()) {
    on<LoadTodayAttendanceRequested>(_onLoadTodayAttendance);
    on<AttendanceCheckInRequested>(_onCheckInRequested);
    on<AttendanceResetRequested>((event, emit) => emit(const AttendanceInitial()));
  }

  /// Fetches today's attendance record from SQLite
  Future<void> _onLoadTodayAttendance(
    LoadTodayAttendanceRequested event,
    Emitter<AttendanceState> emit,
  ) async {
    emit(const AttendanceLoading());
    try {
      final todayDate = DateTimeUtils.todayDateString();
      final record = await attendanceRepository.getTodayRecord(
        event.employeeId,
        todayDate,
      );
      emit(AttendanceTodayStatusLoaded(record: record));
    } on Failure catch (e) {
      emit(AttendanceError(message: e.message));
    } catch (e) {
      emit(AttendanceError(message: 'Failed to load attendance record: $e'));
    }
  }

  /// Records Check-in with:
  ///   1. Admin role guard
  ///   2. GPS location capture (graceful — does NOT block check-in on failure)
  ///   3. Business-logic duplicate check
  ///   4. SQLite transaction with UNIQUE constraint enforcement
  Future<void> _onCheckInRequested(
    AttendanceCheckInRequested event,
    Emitter<AttendanceState> emit,
  ) async {
    // 0. Role Guard: prevent Admins from marking employee attendance
    if (event.role != null && event.role == AppConstants.roleAdmin) {
      emit(const AttendanceError(
        message: 'Administrators cannot mark attendance. Only employee accounts can check in.',
      ));
      return;
    }

    final todayDate = DateTimeUtils.todayDateString();
    final nowTime = DateTimeUtils.formatTime(DateTime.now());

    // 1. Capture GPS location (non-blocking — emit dedicated state so UI can show feedback)
    emit(const AttendanceCapturingLocation());
    final locationResult = await locationService.captureCheckInLocation();

    emit(const AttendanceLoading());

    try {
      // 2. Business Logic Check: verify employee has not already checked in today
      final existingRecord = await attendanceRepository.getTodayRecord(
        event.employeeId,
        todayDate,
      );

      if (existingRecord != null && existingRecord.isCheckedIn) {
        emit(const AttendanceDuplicateError(
          message: 'You have already checked in today. Duplicate attendance check-ins are not permitted.',
        ));
        return;
      }

      // 3. Build attendance record — include location data when available
      final newRecord = AttendanceRecordModel(
        employeeId: event.employeeId,
        date: todayDate,
        checkInTime: nowTime,
        status: AppConstants.statusCheckedIn,
        sessionId: event.session.id,
        checkInLatitude: locationResult.latitude,
        checkInLongitude: locationResult.longitude,
        checkInAccuracy: locationResult.accuracy,
        locationCapturedAt: locationResult.capturedAt,
        isWithinGeofence: locationResult.isSuccess ? locationResult.isWithinGeofence : null,
        distanceToOfficeMeters: locationResult.distanceToOfficeMeters,
      );

      // 4. Commit to SQLite within a transaction
      final savedRecord = await attendanceRepository.checkIn(newRecord);

      emit(AttendanceCheckInSuccess(
        record: savedRecord,
        locationResult: locationResult,
      ));
    } on ValidationFailure catch (e) {
      emit(AttendanceDuplicateError(message: e.message));
    } on Failure catch (e) {
      emit(AttendanceError(message: e.message));
    } catch (e) {
      emit(AttendanceError(message: 'Failed to record attendance: $e'));
    }
  }
}
