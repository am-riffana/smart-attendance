import 'package:equatable/equatable.dart';

/// Events processed by [QRSessionBloc]
abstract class QRSessionEvent extends Equatable {
  const QRSessionEvent();

  @override
  List<Object?> get props => [];
}

/// Dispatched to check if an active session is currently running in SQLite
class LoadActiveQRSessionRequested extends QRSessionEvent {
  const LoadActiveQRSessionRequested();
}

/// Dispatched to generate a new 5-minute dynamic QR session
class GenerateQRSessionRequested extends QRSessionEvent {
  const GenerateQRSessionRequested();
}

/// Internal event fired on every 1-second countdown tick
class QRSessionTimerTicked extends QRSessionEvent {
  final int remainingSeconds;

  const QRSessionTimerTicked(this.remainingSeconds);

  @override
  List<Object?> get props => [remainingSeconds];
}

/// Internal event fired when countdown reaches 0
class QRSessionExpiredEvent extends QRSessionEvent {
  const QRSessionExpiredEvent();
}
