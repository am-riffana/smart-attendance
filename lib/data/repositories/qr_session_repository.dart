
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/qr_token_service.dart';
import '../datasources/qr_session_local_data_source.dart';
import '../models/attendance_session_model.dart';

abstract class QrSessionRepository {
  Future<AttendanceSessionModel> createSession(
    AttendanceSessionModel session,
  );

  Future<AttendanceSessionModel?> getSessionByToken(String token);

  Future<AttendanceSessionModel?> getSessionById(int sessionId);

  Future<AttendanceSessionModel?> getLatestActiveSession();

  Future<void> expireSession(int sessionId);

  Future<void> expirePastSessions();

  Future<AttendanceSessionModel> generateNewSession();

  Future<AttendanceSessionModel> validateSession({
    required int sessionId,
    required String token,
  });

  // Validate QR session using shared Supabase database
  Future<AttendanceSessionModel> validateRemoteSession({
    required String sessionId,
    required String token,
  });
}

/// Implementation of QrSessionRepository
class QrSessionRepositoryImpl implements QrSessionRepository {
  final QrSessionLocalDataSource _localDataSource;

  SupabaseClient get _supabase => Supabase.instance.client;

  QrSessionRepositoryImpl({
    QrSessionLocalDataSource? localDataSource,
  }) : _localDataSource =
           localDataSource ?? QrSessionLocalDataSource();

  /// Generate a shared QR session through Supabase
  @override
  Future<AttendanceSessionModel> generateNewSession() async {
    try {
      await _localDataSource.expirePastSessions();

      final token = QrTokenService.generateSecureToken();

      final response = await _supabase.rpc(
        'create_qr_session',
        params: {
          'p_token': token,
        },
      );

      if (response is! List || response.isEmpty) {
        throw Exception('Supabase did not return a QR session.');
      }

      final row = Map<String, dynamic>.from(
        response.first as Map,
      );

      final remoteId = row['qr_id'].toString();

      final createdAt = DateTime.parse(
        row['qr_created_at'].toString(),
      ).toLocal();

      final expiresAt = DateTime.parse(
        row['qr_expires_at'].toString(),
      ).toLocal();

      final session = AttendanceSessionModel(
        remoteSessionId: remoteId,
        sessionToken: token,
        createdAt: createdAt,
        expiresAt: expiresAt,
        status: AppConstants.sessionActive,
      );

      // Keep a local SQLite copy on the Admin device.
      final localId = await _localDataSource.createSession(session);

      return session.copyWith(id: localId);
    } catch (e) {
      throw DatabaseFailure(
        'Failed to generate shared QR session: $e',
      );
    }
  }

  /// Validate a QR session using Supabase UUID and token
  @override
  Future<AttendanceSessionModel> validateRemoteSession({
    required String sessionId,
    required String token,
  }) async {
    try {
      final response = await _supabase.rpc(
        'validate_qr_session',
        params: {
          'p_session_id': sessionId,
          'p_token': token,
        },
      );

      if (response is! List || response.isEmpty) {
        throw const QrFailure('QR session not found.');
      }

      final row = Map<String, dynamic>.from(
        response.first as Map,
      );

      return AttendanceSessionModel(
        remoteSessionId: row['qr_id'].toString(),
        sessionToken: token,
        createdAt: DateTime.parse(
          row['qr_created_at'].toString(),
        ).toLocal(),
        expiresAt: DateTime.parse(
          row['qr_expires_at'].toString(),
        ).toLocal(),
        status: AppConstants.sessionActive,
      );
    } on QrFailure {
      rethrow;
    } catch (e) {
      throw QrFailure(
        'Shared QR validation failed: $e',
      );
    }
  }

  /// Create a local SQLite session
  @override
  Future<AttendanceSessionModel> createSession(
    AttendanceSessionModel session,
  ) async {
    try {
      final id = await _localDataSource.createSession(session);
      return session.copyWith(id: id);
    } on LocalDatabaseException catch (e) {
      throw DatabaseFailure(e.message);
    } catch (e) {
      throw DatabaseFailure(
        'Unexpected error creating QR session: $e',
      );
    }
  }

  @override
  Future<AttendanceSessionModel?> getSessionByToken(
    String token,
  ) async {
    try {
      return await _localDataSource.getSessionByToken(token);
    } on LocalDatabaseException catch (e) {
      throw DatabaseFailure(e.message);
    } catch (e) {
      throw DatabaseFailure(
        'Unexpected error finding QR session: $e',
      );
    }
  }

  @override
  Future<AttendanceSessionModel?> getSessionById(
    int sessionId,
  ) async {
    try {
      return await _localDataSource.getSessionById(sessionId);
    } on LocalDatabaseException catch (e) {
      throw DatabaseFailure(e.message);
    } catch (e) {
      throw DatabaseFailure(
        'Unexpected error finding QR session by ID: $e',
      );
    }
  }

  /// Existing local SQLite validation (kept for compatibility)
  @override
  Future<AttendanceSessionModel> validateSession({
    required int sessionId,
    required String token,
  }) async {
    try {
      var session =
          await _localDataSource.getSessionById(sessionId);

      session ??=
          await _localDataSource.getSessionByToken(token);

      if (session == null) {
        throw const QrFailure(
          'QR session not found or unrecognized.',
        );
      }

      if (session.sessionToken.trim().toUpperCase() !=
          token.trim().toUpperCase()) {
        throw const QrFailure(
          'Security token verification failed. Invalid QR code.',
        );
      }

      if (session.status != AppConstants.sessionActive) {
        throw QrFailure(
          'This attendance session is no longer active '
          '(status: ${session.status}).',
        );
      }

      if (DateTime.now().isAfter(session.expiresAt)) {
        if (session.id != null) {
          await _localDataSource.updateSessionStatus(
            session.id!,
            AppConstants.sessionExpired,
          );
        }

        throw const QrFailure(
          'Attendance QR code has expired. '
          'Please ask the administrator to generate a new QR session.',
        );
      }

      return session;
    } on QrFailure {
      rethrow;
    } on LocalDatabaseException catch (e) {
      throw DatabaseFailure(e.message);
    } catch (e) {
      throw QrFailure('QR validation error: $e');
    }
  }

  @override
  Future<AttendanceSessionModel?> getLatestActiveSession() async {
    try {
      return await _localDataSource.getLatestActiveSession();
    } on LocalDatabaseException catch (e) {
      throw DatabaseFailure(e.message);
    } catch (e) {
      throw DatabaseFailure(
        'Unexpected error finding latest active QR session: $e',
      );
    }
  }

  @override
  Future<void> expireSession(int sessionId) async {
    try {
      await _localDataSource.updateSessionStatus(
        sessionId,
        AppConstants.sessionExpired,
      );
    } on LocalDatabaseException catch (e) {
      throw DatabaseFailure(e.message);
    } catch (e) {
      throw DatabaseFailure(
        'Unexpected error expiring session: $e',
      );
    }
  }

  @override
  Future<void> expirePastSessions() async {
    try {
      await _localDataSource.expirePastSessions();
    } on LocalDatabaseException catch (e) {
      throw DatabaseFailure(e.message);
    } catch (e) {
      throw DatabaseFailure(
        'Unexpected error expiring past sessions: $e',
      );
    }
  }
}
