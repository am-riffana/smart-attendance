import 'package:equatable/equatable.dart';
import '../../../core/services/location_service.dart';
import '../../../data/models/attendance_record_model.dart';

/// States emitted by [AttendanceBloc]
abstract class AttendanceState extends Equatable {
  const AttendanceState();

  @override
  List<Object?> get props => [];
}

class AttendanceInitial extends AttendanceState {
  const AttendanceInitial();
}

class AttendanceLoading extends AttendanceState {
  const AttendanceLoading();
}

/// Emitted while GPS location is being fetched (before writing to SQLite)
class AttendanceCapturingLocation extends AttendanceState {
  const AttendanceCapturingLocation();
}

/// Emitted when today's attendance record is loaded for display on Employee Dashboard
class AttendanceTodayStatusLoaded extends AttendanceState {
  final AttendanceRecordModel? record;

  const AttendanceTodayStatusLoaded({required this.record});

  bool get isCheckedIn => record != null && record!.isCheckedIn;
  bool get isCheckedOut => record != null && record!.isCheckedOut;

  @override
  List<Object?> get props => [record];
}

/// Emitted when check-in is successfully committed to SQLite.
/// [locationResult] carries location capture details (may be null if location failed).
class AttendanceCheckInSuccess extends AttendanceState {
  final AttendanceRecordModel record;
  final LocationResult? locationResult;

  const AttendanceCheckInSuccess({
    required this.record,
    this.locationResult,
  });

  @override
  List<Object?> get props => [record, locationResult];
}

/// Emitted when an employee attempts a duplicate check-in on the same date
class AttendanceDuplicateError extends AttendanceState {
  final String message;

  const AttendanceDuplicateError({required this.message});

  @override
  List<Object?> get props => [message];
}

/// General attendance failure state
class AttendanceError extends AttendanceState {
  final String message;

  const AttendanceError({required this.message});

  @override
  List<Object?> get props => [message];
}
