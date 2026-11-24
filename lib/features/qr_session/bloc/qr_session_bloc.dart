import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/errors/failures.dart';
import '../../../core/utils/qr_token_service.dart';
import '../../../data/models/attendance_session_model.dart';
import '../../../data/repositories/qr_session_repository.dart';
import 'qr_session_event.dart';
import 'qr_session_state.dart';

/// BLoC managing Dynamic QR session generation, SQLite persistence,
/// and live 5-minute countdown lifecycle.
class QRSessionBloc extends Bloc<QRSessionEvent, QRSessionState> {
  final QrSessionRepository qrSessionRepository;
  StreamSubscription<int>? _timerSubscription;

  QRSessionBloc({required this.qrSessionRepository})
      : super(const QRSessionInitial()) {
    on<LoadActiveQRSessionRequested>(_onLoadActiveSession);
    on<GenerateQRSessionRequested>(_onGenerateSession);
    on<QRSessionTimerTicked>(_onTimerTicked);
    on<QRSessionExpiredEvent>(_onSessionExpired);
  }

  /// Checks for an existing active session on screen open; generates one if none exists
  Future<void> _onLoadActiveSession(
    LoadActiveQRSessionRequested event,
    Emitter<QRSessionState> emit,
  ) async {
    emit(const QRSessionLoading());
    try {
      final active = await qrSessionRepository.getLatestActiveSession();
      if (active != null && !active.isExpired) {
        _startCountdown(active, emit);
      } else {
        // Automatically generate a new session if no active session exists
        await _generateAndStartSession(emit);
      }
    } on Failure catch (e) {
      emit(QRSessionError(message: e.message));
    } catch (e) {
      emit(QRSessionError(message: 'Failed to load QR session: $e'));
    }
  }

  /// Manually triggers generation of a new QR session
  Future<void> _onGenerateSession(
    GenerateQRSessionRequested event,
    Emitter<QRSessionState> emit,
  ) async {
    emit(const QRSessionLoading());
    try {
      await _generateAndStartSession(emit);
    } on Failure catch (e) {
      emit(QRSessionError(message: e.message));
    } catch (e) {
      emit(QRSessionError(message: 'Failed to generate QR session: $e'));
    }
  }

  Future<void> _generateAndStartSession(Emitter<QRSessionState> emit) async {
    _timerSubscription?.cancel();
    final newSession = await qrSessionRepository.generateNewSession();
    _startCountdown(newSession, emit);
  }

  void _startCountdown(AttendanceSessionModel session, Emitter<QRSessionState> emit) {
    _timerSubscription?.cancel();

    final remaining = session.remainingSeconds;
    if (remaining <= 0) {
      emit(QRSessionExpiredState(session: session));
      return;
    }

    final payload = QrTokenService.encodeQrPayload(
  sessionId: session.remoteSessionId ?? '',
  token: session.sessionToken,
  createdAt: session.createdAt,
  expiresAt: session.expiresAt,
);

    emit(QRSessionActive(
      session: session,
      qrPayload: payload,
      remainingSeconds: remaining,
    ));

    // Lifecycle-safe countdown stream emitting every second
    _timerSubscription = Stream.periodic(
      const Duration(seconds: 1),
      (sec) => remaining - sec - 1,
    ).take(remaining).listen(
      (secondsLeft) {
        if (secondsLeft > 0) {
          add(QRSessionTimerTicked(secondsLeft));
        } else {
          add(const QRSessionExpiredEvent());
        }
      },
    );
  }

  void _onTimerTicked(
    QRSessionTimerTicked event,
    Emitter<QRSessionState> emit,
  ) {
    if (state is QRSessionActive) {
      final current = state as QRSessionActive;
      emit(QRSessionActive(
        session: current.session,
        qrPayload: current.qrPayload,
        remainingSeconds: event.remainingSeconds,
      ));
    }
  }

  Future<void> _onSessionExpired(
    QRSessionExpiredEvent event,
    Emitter<QRSessionState> emit,
  ) async {
    _timerSubscription?.cancel();
    if (state is QRSessionActive) {
      final current = state as QRSessionActive;
      try {
        if (current.session.id != null) {
          await qrSessionRepository.expireSession(current.session.id!);
        }
      } catch (_) {}
      emit(QRSessionExpiredState(
        session: current.session.copyWith(status: AppConstants.sessionExpired),
      ));
    }
  }

  @override
  Future<void> close() {
    _timerSubscription?.cancel();
    return super.close();
  }
}
