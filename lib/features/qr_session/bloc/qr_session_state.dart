import 'package:equatable/equatable.dart';
import '../../../data/models/attendance_session_model.dart';

/// States emitted by [QRSessionBloc]
abstract class QRSessionState extends Equatable {
  const QRSessionState();

  @override
  List<Object?> get props => [];
}

class QRSessionInitial extends QRSessionState {
  const QRSessionInitial();
}

class QRSessionLoading extends QRSessionState {
  const QRSessionLoading();
}

class QRSessionActive extends QRSessionState {
  final AttendanceSessionModel session;
  final String qrPayload;
  final int remainingSeconds;

  const QRSessionActive({
    required this.session,
    required this.qrPayload,
    required this.remainingSeconds,
  });

  @override
  List<Object?> get props => [session, qrPayload, remainingSeconds];
}

class QRSessionExpiredState extends QRSessionState {
  final AttendanceSessionModel session;

  const QRSessionExpiredState({required this.session});

  @override
  List<Object?> get props => [session];
}

class QRSessionError extends QRSessionState {
  final String message;

  const QRSessionError({required this.message});

  @override
  List<Object?> get props => [message];
}
