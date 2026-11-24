import 'package:equatable/equatable.dart';
import '../../../core/services/location_service.dart';
import '../../../data/models/attendance_session_model.dart';

/// Events processed by [AttendanceBloc]
abstract class AttendanceEvent extends Equatable {
  const AttendanceEvent();

  @override
  List<Object?> get props => [];
}

/// Dispatched to fetch today's attendance record for an employee
class LoadTodayAttendanceRequested extends AttendanceEvent {
  final String employeeId;

  const LoadTodayAttendanceRequested({required this.employeeId});

  @override
  List<Object?> get props => [employeeId];
}

/// Dispatched to record check-in after successful QR validation.
/// [locationResult] is nullable — location capture may fail gracefully
/// without blocking the check-in.
class AttendanceCheckInRequested extends AttendanceEvent {
  final String employeeId;
  final AttendanceSessionModel session;
  final String? role;
  final LocationResult? locationResult;

  const AttendanceCheckInRequested({
    required this.employeeId,
    required this.session,
    this.role,
    this.locationResult,
  });

  @override
  List<Object?> get props => [employeeId, session, role, locationResult];
}

/// Dispatched to reset check-in status
class AttendanceResetRequested extends AttendanceEvent {
  const AttendanceResetRequested();
}
