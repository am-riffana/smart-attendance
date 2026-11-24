import 'package:equatable/equatable.dart';
import '../../../data/models/attendance_session_model.dart';

/// States emitted by [QRScannerBloc]
abstract class QRScannerState extends Equatable {
  const QRScannerState();

  @override
  List<Object?> get props => [];
}

class QRScannerInitial extends QRScannerState {
  const QRScannerInitial();
}

class QRScannerScanning extends QRScannerState {
  const QRScannerScanning();
}

/// State emitted while validating decoded QR data; prevents repeated scan events
class QRScannerProcessing extends QRScannerState {
  const QRScannerProcessing();
}

/// State emitted when QR session is validated against SQLite
class QRScannerSuccess extends QRScannerState {
  final AttendanceSessionModel session;

  const QRScannerSuccess({required this.session});

  @override
  List<Object?> get props => [session];
}

/// State emitted when QR is invalid, expired, malformed, or unknown
class QRScannerFailure extends QRScannerState {
  final String message;

  const QRScannerFailure({required this.message});

  @override
  List<Object?> get props => [message];
}

/// State emitted when camera permission is denied
class QRScannerPermissionDenied extends QRScannerState {
  const QRScannerPermissionDenied();
}
