
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/errors/failures.dart';
import '../../../core/utils/qr_token_service.dart';
import '../../../data/repositories/qr_session_repository.dart';
import 'qr_scanner_event.dart';
import 'qr_scanner_state.dart';

/// BLoC managing QR code scanning, debouncing repeated camera frames,
/// and validating sessions against SQLite or Supabase.
class QRScannerBloc extends Bloc<QRScannerEvent, QRScannerState> {
  final QrSessionRepository qrSessionRepository;

  QRScannerBloc({required this.qrSessionRepository})
      : super(const QRScannerInitial()) {
    on<StartScannerRequested>(
      (event, emit) => emit(const QRScannerScanning()),
    );

    on<ResetScannerRequested>(
      (event, emit) => emit(const QRScannerScanning()),
    );

    on<CameraPermissionDeniedEvent>(
      (event, emit) => emit(const QRScannerPermissionDenied()),
    );

    on<CameraErrorOccurred>(
      (event, emit) => emit(QRScannerFailure(message: event.message)),
    );

    on<QRCodeDetected>(_onQRCodeDetected);
  }

  Future<void> _onQRCodeDetected(
    QRCodeDetected event,
    Emitter<QRScannerState> emit,
  ) async {
    // Prevent duplicate scan processing.
    if (state is QRScannerProcessing ||
        state is QRScannerSuccess ||
        state is QRScannerFailure) {
      return;
    }

    emit(const QRScannerProcessing());

    final raw = event.rawCode.trim();

    if (raw.isEmpty) {
      emit(const QRScannerFailure(
        message: 'Empty barcode detected.',
      ));
      return;
    }

    // 1. Decode QR JSON payload.
    final payload = QrTokenService.decodeQrPayload(raw);

    if (payload == null) {
      emit(const QRScannerFailure(
        message:
            'Invalid QR code format. The scanned code is not a valid Smart Attendance session.',
      ));
      return;
    }

    // 2. Read session ID, token and expiry.
    final rawSessionId = payload['session_id'];

    final String? sessionId = rawSessionId is String
        ? rawSessionId.trim()
        : rawSessionId is num
            ? rawSessionId.toInt().toString()
            : null;

    final token = payload['token'];
    final expiresAtStr = payload['expires_at'];

    if (sessionId == null ||
        sessionId.isEmpty ||
        token is! String ||
        token.isEmpty ||
        expiresAtStr is! String ||
        expiresAtStr.isEmpty) {
      emit(const QRScannerFailure(
        message:
            'Malformed QR payload. Missing required session identifier, token, or expiry.',
      ));
      return;
    }

    // 3. Check QR expiry timestamp.
    try {
      final payloadExpiry = DateTime.parse(expiresAtStr);

      if (DateTime.now().isAfter(payloadExpiry)) {
        emit(const QRScannerFailure(
          message:
              'Attendance QR code has expired. Please ask the administrator to generate a new QR session.',
        ));
        return;
      }
    } catch (_) {
      emit(const QRScannerFailure(
        message: 'Malformed QR payload. Invalid expiration date format.',
      ));
      return;
    }

    // 4. Validate using the correct session source.
    try {
      final localSessionId = int.tryParse(sessionId);

      final session = localSessionId != null
          ? await qrSessionRepository.validateSession(
              sessionId: localSessionId,
              token: token,
            )
          : await qrSessionRepository.validateRemoteSession(
              sessionId: sessionId,
              token: token,
            );

      emit(QRScannerSuccess(session: session));
    } on Failure catch (e) {
      emit(QRScannerFailure(message: e.message));
    } catch (e) {
      emit(QRScannerFailure(
        message: 'QR validation error: $e',
      ));
    }
  }
}
