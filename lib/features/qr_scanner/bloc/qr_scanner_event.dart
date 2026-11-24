import 'package:equatable/equatable.dart';

/// Events processed by [QRScannerBloc]
abstract class QRScannerEvent extends Equatable {
  const QRScannerEvent();

  @override
  List<Object?> get props => [];
}

/// Dispatched when the scanner screen initializes
class StartScannerRequested extends QRScannerEvent {
  const StartScannerRequested();
}

/// Dispatched when MobileScanner captures a barcode
class QRCodeDetected extends QRScannerEvent {
  final String rawCode;

  const QRCodeDetected(this.rawCode);

  @override
  List<Object?> get props => [rawCode];
}

/// Dispatched to reset scanner and allow a new scan attempt
class ResetScannerRequested extends QRScannerEvent {
  const ResetScannerRequested();
}

/// Dispatched when camera permission is explicitly denied
class CameraPermissionDeniedEvent extends QRScannerEvent {
  const CameraPermissionDeniedEvent();
}

/// Dispatched when a camera hardware or platform error occurs
class CameraErrorOccurred extends QRScannerEvent {
  final String message;

  const CameraErrorOccurred(this.message);

  @override
  List<Object?> get props => [message];
}
