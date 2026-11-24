
import 'package:equatable/equatable.dart';

import '../../core/constants/app_constants.dart';
import '../../core/database/database_constants.dart';

class AttendanceSessionModel extends Equatable {
  // Local SQLite ID
  final int? id;

  // Shared Supabase UUID
  final String? remoteSessionId;

  final String sessionToken;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String status;

  const AttendanceSessionModel({
    this.id,
    this.remoteSessionId,
    required this.sessionToken,
    required this.createdAt,
    required this.expiresAt,
    required this.status,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  bool get isActive =>
      status == AppConstants.sessionActive && !isExpired;

  int get remainingSeconds {
    final diff = expiresAt.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }

  // Read existing SQLite session
  factory AttendanceSessionModel.fromMap(
    Map<String, dynamic> map,
  ) {
    return AttendanceSessionModel(
      id: map[DatabaseConstants.colSessionId] as int?,
      sessionToken:
          map[DatabaseConstants.colSessionToken] as String? ?? '',
      createdAt: DateTime.tryParse(
            map[DatabaseConstants.colSessionCreatedAt].toString(),
          )?.toLocal() ??
          DateTime.now(),
      expiresAt: DateTime.tryParse(
            map[DatabaseConstants.colSessionExpiresAt].toString(),
          )?.toLocal() ??
          DateTime.now(),
      status: map[DatabaseConstants.colSessionStatus] as String? ??
          AppConstants.sessionExpired,
    );
  }

  // Save existing SQLite session
  Map<String, dynamic> toMap({bool includeId = false}) {
    final map = <String, dynamic>{
      DatabaseConstants.colSessionToken: sessionToken,
      DatabaseConstants.colSessionCreatedAt:
          createdAt.toUtc().toIso8601String(),
      DatabaseConstants.colSessionExpiresAt:
          expiresAt.toUtc().toIso8601String(),
      DatabaseConstants.colSessionStatus: status,
    };

    if (includeId && id != null) {
      map[DatabaseConstants.colSessionId] = id;
    }

    return map;
  }

  // Read a Supabase function response or JSON session
  factory AttendanceSessionModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return AttendanceSessionModel(
      id: int.tryParse(json['id']?.toString() ?? ''),
      remoteSessionId:
          json['qr_id']?.toString() ??
          json['remote_session_id']?.toString() ??
          (json['id']?.toString().contains('-') == true
              ? json['id'].toString()
              : null),
      sessionToken:
          json['session_token']?.toString() ??
          json['token']?.toString() ??
          '',
      createdAt: DateTime.tryParse(
            (json['qr_created_at'] ??
                    json['created_at'])
                .toString(),
          )?.toLocal() ??
          DateTime.now(),
      expiresAt: DateTime.tryParse(
            (json['qr_expires_at'] ??
                    json['expires_at'])
                .toString(),
          )?.toLocal() ??
          DateTime.now(),
      status: json['status']?.toString() ??
          AppConstants.sessionActive,
    );
  }

  Map<String, dynamic> toJson() => {
        ...toMap(includeId: true),
        if (remoteSessionId != null)
          'remote_session_id': remoteSessionId,
      };

  AttendanceSessionModel copyWith({
    int? id,
    String? remoteSessionId,
    String? sessionToken,
    DateTime? createdAt,
    DateTime? expiresAt,
    String? status,
  }) {
    return AttendanceSessionModel(
      id: id ?? this.id,
      remoteSessionId: remoteSessionId ?? this.remoteSessionId,
      sessionToken: sessionToken ?? this.sessionToken,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      status: status ?? this.status,
    );
  }

  @override
  List<Object?> get props => [
        id,
        remoteSessionId,
        sessionToken,
        createdAt,
        expiresAt,
        status,
      ];
}
