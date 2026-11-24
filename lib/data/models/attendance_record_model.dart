import 'package:equatable/equatable.dart';
import '../../core/constants/app_constants.dart';
import '../../core/database/database_constants.dart';

/// Model representing a daily employee attendance record
class AttendanceRecordModel extends Equatable {
  final int? id;
  final String employeeId;
  final String date; // 'yyyy-MM-dd'
  final String? checkInTime; // ISO or 'hh:mm a'
  final String? checkOutTime;
  final double? checkInLatitude;
  final double? checkInLongitude;
  final double? checkOutLatitude;
  final double? checkOutLongitude;
  final String status;
  final int? sessionId;

  // Phase 6: GPS location capture fields (nullable — location may fail gracefully)
  final double? checkInAccuracy;
  final String? locationCapturedAt; // device-local ISO 8601
  final bool? isWithinGeofence;
  final double? distanceToOfficeMeters;

  // Joined metadata for UI convenience
  final String? employeeName;
  final String? employeeEmail;

  const AttendanceRecordModel({
    this.id,
    required this.employeeId,
    required this.date,
    this.checkInTime,
    this.checkOutTime,
    this.checkInLatitude,
    this.checkInLongitude,
    this.checkOutLatitude,
    this.checkOutLongitude,
    required this.status,
    this.sessionId,
    this.checkInAccuracy,
    this.locationCapturedAt,
    this.isWithinGeofence,
    this.distanceToOfficeMeters,
    this.employeeName,
    this.employeeEmail,
  });

  bool get isCheckedIn => checkInTime != null && checkInTime!.isNotEmpty;
  bool get isCheckedOut => checkOutTime != null && checkOutTime!.isNotEmpty;
  bool get isCompleted => isCheckedIn && isCheckedOut;

  factory AttendanceRecordModel.fromMap(Map<String, dynamic> map) {
    return AttendanceRecordModel(
      id: map[DatabaseConstants.colRecordId] as int?,
      employeeId: map[DatabaseConstants.colRecordEmployeeId] as String? ?? '',
      date: map[DatabaseConstants.colRecordDate] as String? ?? '',
      checkInTime: map[DatabaseConstants.colRecordCheckInTime] as String?,
      checkOutTime: map[DatabaseConstants.colRecordCheckOutTime] as String?,
      checkInLatitude: (map[DatabaseConstants.colRecordCheckInLat] as num?)?.toDouble(),
      checkInLongitude: (map[DatabaseConstants.colRecordCheckInLng] as num?)?.toDouble(),
      checkOutLatitude: (map[DatabaseConstants.colRecordCheckOutLat] as num?)?.toDouble(),
      checkOutLongitude: (map[DatabaseConstants.colRecordCheckOutLng] as num?)?.toDouble(),
      status: map[DatabaseConstants.colRecordStatus] as String? ?? AppConstants.statusAbsent,
      sessionId: map[DatabaseConstants.colRecordSessionId] as int?,
      checkInAccuracy: (map[DatabaseConstants.colRecordCheckInAccuracy] as num?)?.toDouble(),
      locationCapturedAt: map[DatabaseConstants.colRecordLocationCapturedAt] as String?,
      isWithinGeofence: map[DatabaseConstants.colRecordIsWithinGeofence] != null
          ? (map[DatabaseConstants.colRecordIsWithinGeofence] as int) == 1
          : null,
      distanceToOfficeMeters:
          (map[DatabaseConstants.colRecordDistanceToOffice] as num?)?.toDouble(),
      employeeName: map['employee_name'] as String?,
      employeeEmail: map['employee_email'] as String?,
    );
  }

  Map<String, dynamic> toMap({bool includeId = false}) {
    final map = <String, dynamic>{
      DatabaseConstants.colRecordEmployeeId: employeeId,
      DatabaseConstants.colRecordDate: date,
      DatabaseConstants.colRecordCheckInTime: checkInTime,
      DatabaseConstants.colRecordCheckOutTime: checkOutTime,
      DatabaseConstants.colRecordCheckInLat: checkInLatitude,
      DatabaseConstants.colRecordCheckInLng: checkInLongitude,
      DatabaseConstants.colRecordCheckOutLat: checkOutLatitude,
      DatabaseConstants.colRecordCheckOutLng: checkOutLongitude,
      DatabaseConstants.colRecordStatus: status,
      DatabaseConstants.colRecordSessionId: sessionId,
      DatabaseConstants.colRecordCheckInAccuracy: checkInAccuracy,
      DatabaseConstants.colRecordLocationCapturedAt: locationCapturedAt,
      DatabaseConstants.colRecordIsWithinGeofence:
          isWithinGeofence != null ? (isWithinGeofence! ? 1 : 0) : null,
      DatabaseConstants.colRecordDistanceToOffice: distanceToOfficeMeters,
    };
    if (includeId && id != null) {
      map[DatabaseConstants.colRecordId] = id;
    }
    return map;
  }

  factory AttendanceRecordModel.fromJson(Map<String, dynamic> json) =>
      AttendanceRecordModel.fromMap(json);
  Map<String, dynamic> toJson() => toMap(includeId: true);

  AttendanceRecordModel copyWith({
    int? id,
    String? employeeId,
    String? date,
    String? checkInTime,
    String? checkOutTime,
    double? checkInLatitude,
    double? checkInLongitude,
    double? checkOutLatitude,
    double? checkOutLongitude,
    String? status,
    int? sessionId,
    double? checkInAccuracy,
    String? locationCapturedAt,
    bool? isWithinGeofence,
    double? distanceToOfficeMeters,
    String? employeeName,
    String? employeeEmail,
  }) {
    return AttendanceRecordModel(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      date: date ?? this.date,
      checkInTime: checkInTime ?? this.checkInTime,
      checkOutTime: checkOutTime ?? this.checkOutTime,
      checkInLatitude: checkInLatitude ?? this.checkInLatitude,
      checkInLongitude: checkInLongitude ?? this.checkInLongitude,
      checkOutLatitude: checkOutLatitude ?? this.checkOutLatitude,
      checkOutLongitude: checkOutLongitude ?? this.checkOutLongitude,
      status: status ?? this.status,
      sessionId: sessionId ?? this.sessionId,
      checkInAccuracy: checkInAccuracy ?? this.checkInAccuracy,
      locationCapturedAt: locationCapturedAt ?? this.locationCapturedAt,
      isWithinGeofence: isWithinGeofence ?? this.isWithinGeofence,
      distanceToOfficeMeters: distanceToOfficeMeters ?? this.distanceToOfficeMeters,
      employeeName: employeeName ?? this.employeeName,
      employeeEmail: employeeEmail ?? this.employeeEmail,
    );
  }

  @override
  List<Object?> get props => [
        id,
        employeeId,
        date,
        checkInTime,
        checkOutTime,
        checkInLatitude,
        checkInLongitude,
        checkOutLatitude,
        checkOutLongitude,
        status,
        sessionId,
        checkInAccuracy,
        locationCapturedAt,
        isWithinGeofence,
        distanceToOfficeMeters,
        employeeName,
        employeeEmail,
      ];
}
