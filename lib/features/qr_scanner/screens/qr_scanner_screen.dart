import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/theme/app_colors.dart';
import '../../../routes/app_routes.dart';
import '../../../shared/app_button.dart';
import '../../../shared/app_card.dart';
import '../../attendance/bloc/attendance_bloc.dart';
import '../../attendance/bloc/attendance_event.dart';
import '../../attendance/bloc/attendance_state.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';
import '../bloc/qr_scanner_bloc.dart';
import '../bloc/qr_scanner_event.dart';
import '../bloc/qr_scanner_state.dart';

/// Employee QR Scanner Screen backed by MobileScanner and BLoC
class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  late final MobileScannerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: kIsWeb ? CameraFacing.front : CameraFacing.back,
      torchEnabled: false,
    );

    // Initialize scanner and attendance states
    context.read<QRScannerBloc>().add(const StartScannerRequested());
    context.read<AttendanceBloc>().add(const AttendanceResetRequested());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _resetScanner() {
    context.read<QRScannerBloc>().add(const ResetScannerRequested());
    context.read<AttendanceBloc>().add(const AttendanceResetRequested());
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final currentUser = authState is Authenticated ? authState.user : null;
    final isAdmin = currentUser?.isAdmin ?? false;

    // Guard: Prevent Admin from scanning attendance
    if (isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Attendance Scanner')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: AppCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.admin_panel_settings_rounded, size: 56, color: AppColors.primary),
                  const SizedBox(height: 16),
                  const Text(
                    'Administrator Access',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Administrators cannot mark attendance. Use the Admin Dashboard to generate dynamic QR codes for employees.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  AppButton(
                    label: 'Return to Admin Dashboard',
                    onPressed: () => context.go(AppRoutes.adminDashboard),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final mediaQuery = MediaQuery.of(context);
    const scanBoxSize = 250.0;
    final scanWindow = Rect.fromCenter(
      center: Offset(mediaQuery.size.width / 2, (mediaQuery.size.height - mediaQuery.padding.top - kToolbarHeight) / 2),
      width: scanBoxSize,
      height: scanBoxSize,
    );

    return MultiBlocListener(
      listeners: [
        BlocListener<QRScannerBloc, QRScannerState>(
          listener: (context, qrState) {
            if (qrState is QRScannerSuccess) {
              if (currentUser != null) {
                context.read<AttendanceBloc>().add(
                  AttendanceCheckInRequested(
                    employeeId: currentUser.employeeId,
                    session: qrState.session,
                    role: currentUser.role,
                  ),
                );
              }
            }
          },
        ),
        BlocListener<AttendanceBloc, AttendanceState>(
          listener: (context, attendanceState) {
            if (attendanceState is AttendanceCheckInSuccess) {
              final loc = attendanceState.locationResult;
              context.go(
                AppRoutes.attendanceStatus,
                extra: {
                  'isSuccess': true,
                  'message': 'Attendance marked successfully for today!',
                  'timestamp': attendanceState.record.checkInTime,
                  'employeeId': attendanceState.record.employeeId,
                  'isWithinGeofence': (loc != null && loc.isSuccess) ? loc.isWithinGeofence : null,
                  'distanceToOfficeMeters': loc?.distanceToOfficeMeters,
                  'locationAccuracy': loc?.accuracy,
                  'locationFailureMessage':
                      (loc != null && loc.failure != null) ? loc.failureMessage : null,
                },
              );
            }
          },
        ),
      ],
      child: BlocBuilder<QRScannerBloc, QRScannerState>(
        builder: (context, qrState) {
          return BlocBuilder<AttendanceBloc, AttendanceState>(
            builder: (context, attendanceState) {
              final isProcessing =
                  qrState is QRScannerProcessing ||
                  attendanceState is AttendanceLoading ||
                  attendanceState is AttendanceCapturingLocation;

              return Scaffold(
                backgroundColor: Colors.black,
                appBar: AppBar(
                  title: const Text('Scan Attendance QR'),
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  actions: [
                    if (!kIsWeb)
                      ValueListenableBuilder<MobileScannerState>(
                        valueListenable: _controller,
                        builder: (context, scannerState, child) {
                          final isTorchOn = scannerState.torchState == TorchState.on;
                          return IconButton(
                            tooltip: isTorchOn ? 'Turn Torch Off' : 'Turn Torch On',
                            icon: Icon(
                              isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                              color: isTorchOn ? Colors.amber : Colors.white,
                            ),
                            onPressed: () async {
                              try {
                                await _controller.toggleTorch();
                              } catch (e) {
                                debugPrint('[QRScanner] Torch toggle unsupported: $e');
                              }
                            },
                          );
                        },
                      ),
                    IconButton(
                      tooltip: 'Switch Camera',
                      icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white),
                      onPressed: () async {
                        try {
                          await _controller.switchCamera();
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Camera switching is not supported or only one camera is available.'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
                body: Stack(
                  children: [
                    // Camera Preview
                    MobileScanner(
                      controller: _controller,
                      errorBuilder: (context, error, child) {
                        if (error.errorCode == MobileScannerErrorCode.permissionDenied) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                              context.read<QRScannerBloc>().add(const CameraPermissionDeniedEvent());
                            }
                          });
                        }
                        return _buildCameraErrorView(context, error.errorCode.message);
                      },
                      onDetect: (capture) {
                        // Prevent re-triggering while already processing, succeeded, or showing error
                        if (qrState is QRScannerProcessing ||
                            qrState is QRScannerSuccess ||
                            qrState is QRScannerFailure) {
                          return;
                        }

                        final barcodes = capture.barcodes;
                        if (barcodes.isNotEmpty) {
                          final code = barcodes.first.rawValue;
                          if (code != null && code.trim().isNotEmpty) {
                            context.read<QRScannerBloc>().add(QRCodeDetected(code));
                          }
                        }
                      },
                    ),

                    // Custom Cutout Overlay
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _ScannerOverlayPainter(
                          scanWindow: scanWindow,
                          borderRadius: 20,
                        ),
                      ),
                    ),

                    // Instructions Banner below the frame
                    Positioned(
                      top: scanWindow.bottom + 24,
                      left: 24,
                      right: 24,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline_rounded, color: Colors.white70, size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Align the Smart Attendance QR code within the frame to check in.',
                                style: TextStyle(color: Colors.white, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Loading / Validating Overlay HUD
                    if (isProcessing)
                      Container(
                        color: Colors.black54,
                        child: Center(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 40),
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const CircularProgressIndicator(),
                                const SizedBox(height: 18),
                                Text(
                                  attendanceState is AttendanceCapturingLocation
                                      ? 'Capturing GPS location...'
                                      : 'Verifying QR session & recording attendance...',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                ),
                                if (attendanceState is AttendanceCapturingLocation) ...[
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Please allow location access when prompted.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),

                    // QR Validation Failure Dialog Card
                    if (qrState is QRScannerFailure)
                      _buildFeedbackCard(
                        context,
                        icon: Icons.cancel_rounded,
                        iconColor: AppColors.error,
                        title: 'Invalid QR Code',
                        message: qrState.message,
                        primaryLabel: 'Scan Again',
                        onPrimaryPressed: _resetScanner,
                        secondaryLabel: 'Return to Dashboard',
                        onSecondaryPressed: () => context.pop(),
                      ),

                    // Duplicate Check-In Prevention Dialog Card
                    if (attendanceState is AttendanceDuplicateError)
                      _buildFeedbackCard(
                        context,
                        icon: Icons.warning_amber_rounded,
                        iconColor: AppColors.warning,
                        title: 'Already Checked In',
                        message: attendanceState.message,
                        primaryLabel: 'Return to Dashboard',
                        onPrimaryPressed: () => context.go(AppRoutes.employeeDashboard),
                        secondaryLabel: 'Scan Again',
                        onSecondaryPressed: _resetScanner,
                      ),

                    // Attendance Recording Error Dialog Card
                    if (attendanceState is AttendanceError)
                      _buildFeedbackCard(
                        context,
                        icon: Icons.error_outline_rounded,
                        iconColor: AppColors.error,
                        title: 'Check-In Error',
                        message: attendanceState.message,
                        primaryLabel: 'Try Again',
                        onPrimaryPressed: _resetScanner,
                        secondaryLabel: 'Return to Dashboard',
                        onSecondaryPressed: () => context.pop(),
                      ),

                    // Camera Permission Denied View
                    if (qrState is QRScannerPermissionDenied)
                      Positioned.fill(
                        child: _buildPermissionDeniedView(context),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildFeedbackCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
    required String primaryLabel,
    required VoidCallback onPrimaryPressed,
    String? secondaryLabel,
    VoidCallback? onSecondaryPressed,
  }) {
    return Container(
      color: Colors.black.withValues(alpha: 0.75),
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: AppCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: iconColor.withValues(alpha: 0.12),
                  child: Icon(icon, color: iconColor, size: 40),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
                ),
                const SizedBox(height: 22),
                AppButton(
                  label: primaryLabel,
                  onPressed: onPrimaryPressed,
                ),
                if (secondaryLabel != null && onSecondaryPressed != null) ...[
                  const SizedBox(height: 8),
                  AppButton(
                    label: secondaryLabel,
                    type: AppButtonType.outlined,
                    onPressed: onSecondaryPressed,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionDeniedView(BuildContext context) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: AppCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.no_photography_outlined, size: 56, color: AppColors.error),
                const SizedBox(height: 16),
                const Text(
                  'Camera Permission Required',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Camera access is required to scan the Smart Attendance QR code. Please enable camera permission to continue.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
                ),
                const SizedBox(height: 20),
                AppButton(
                  label: 'Allow Camera Access',
                  onPressed: () {
                    _controller.start();
                    context.read<QRScannerBloc>().add(const StartScannerRequested());
                  },
                ),
                const SizedBox(height: 8),
                AppButton(
                  label: 'Return to Dashboard',
                  type: AppButtonType.outlined,
                  onPressed: () => context.pop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCameraErrorView(BuildContext context, String message) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_off_rounded, size: 48, color: Colors.white70),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _controller.start(),
                child: const Text('Restart Camera'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom painter rendering a dark frosted overlay with a clear rounded rectangular cutout
class _ScannerOverlayPainter extends CustomPainter {
  final Rect scanWindow;
  final double borderRadius;

  const _ScannerOverlayPainter({
    required this.scanWindow,
    this.borderRadius = 20.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()..color = Colors.black.withValues(alpha: 0.65);

    final backgroundPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final cutoutPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(scanWindow, Radius.circular(borderRadius)),
      );

    final overlayPath = Path.combine(PathOperation.difference, backgroundPath, cutoutPath);
    canvas.drawPath(overlayPath, backgroundPaint);

    // Viewport Border
    final borderPaint = Paint()
      ..color = AppColors.primaryLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    canvas.drawRRect(
      RRect.fromRectAndRadius(scanWindow, Radius.circular(borderRadius)),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter oldDelegate) =>
      oldDelegate.scanWindow != scanWindow;
}
