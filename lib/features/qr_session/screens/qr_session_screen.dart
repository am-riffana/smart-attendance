import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../../shared/app_button.dart';
import '../../../shared/app_card.dart';
import '../../../shared/error_view.dart';
import '../../../shared/loading_indicator.dart';
import '../../../shared/status_badge.dart';
import '../bloc/qr_session_bloc.dart';
import '../bloc/qr_session_event.dart';
import '../bloc/qr_session_state.dart';

/// Professional QR Session Generation screen displaying live 5-minute countdown
/// and generated QR image strictly driven by [QRSessionBloc]
class QrSessionScreen extends StatefulWidget {
  const QrSessionScreen({super.key});

  @override
  State<QrSessionScreen> createState() => _QrSessionScreenState();
}

class _QrSessionScreenState extends State<QrSessionScreen> {
  @override
  void initState() {
    super.initState();
    // Synchronize active session and countdown timer state safely on mount
    context.read<QRSessionBloc>().add(const LoadActiveQRSessionRequested());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final qrBloc = context.read<QRSessionBloc>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance QR Session'),
        actions: [
          IconButton(
            tooltip: 'Regenerate QR',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => qrBloc.add(const GenerateQRSessionRequested()),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: BlocConsumer<QRSessionBloc, QRSessionState>(
                listener: (context, state) {
                  if (state is QRSessionExpiredState) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('QR session has expired. Please generate a new one.'),
                        backgroundColor: AppColors.warning,
                        duration: Duration(seconds: 3),
                      ),
                    );
                  }
                },
                builder: (context, state) {
                  if (state is QRSessionLoading) {
                    return const LoadingIndicator(message: 'Generating attendance session...');
                  }

                  if (state is QRSessionError) {
                    return ErrorView(
                      title: 'Session Generation Failed',
                      message: state.message,
                      onRetry: () => qrBloc.add(const GenerateQRSessionRequested()),
                    );
                  }

                  final isActive = state is QRSessionActive;
                  final isExpired = state is QRSessionExpiredState;

                  final remainingSeconds = isActive ? state.remainingSeconds : 0;
                  final session = isActive
                      ? state.session
                      : (isExpired ? state.session : null);
                  final qrPayload = isActive ? state.qrPayload : '';

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Countdown Header Card
                      AppCard(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isActive ? 'Time Remaining' : 'Session Status',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isActive
                                      ? DateTimeUtils.formatSecondsToMinutes(remainingSeconds)
                                      : '00:00',
                                  style: theme.textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: isActive
                                        ? (remainingSeconds < 60 ? AppColors.warning : AppColors.primary)
                                        : AppColors.absent,
                                  ),
                                ),
                              ],
                            ),
                            StatusBadge(
                              status: isActive ? AppConstants.sessionActive : AppConstants.sessionExpired,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // QR Code Presentation Box
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isExpired ? AppColors.error : AppColors.lightBorder,
                              width: isExpired ? 2 : 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              QrImageView(
                                data: qrPayload.isNotEmpty ? qrPayload : 'EXPIRED-SESSION',
                                version: QrVersions.auto,
                                size: 240,
                                backgroundColor: Colors.white,
                              ),
                              if (isExpired)
                                Container(
                                  width: 240,
                                  height: 240,
                                  color: Colors.white.withValues(alpha: 0.92),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.timer_off_outlined,
                                        size: 48,
                                        color: AppColors.error,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'SESSION EXPIRED',
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.error,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Generate a new code to continue',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Session Metadata Card
                      if (session != null) ...[
                        AppCard(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Column(
                            children: [
                              _MetaRow(
                                label: 'Session Token',
                                value: session.sessionToken,
                                isMonospace: true,
                              ),
                              const Divider(height: 16),
                              _MetaRow(
                                label: 'Generated At',
                                value: DateTimeUtils.formatTime(session.createdAt),
                              ),
                              const SizedBox(height: 6),
                              _MetaRow(
                                label: 'Expires At (5 min)',
                                value: DateTimeUtils.formatTime(session.expiresAt),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Action Button
                      AppButton(
                        label: isExpired ? 'Generate New QR Session' : 'Regenerate Session',
                        icon: Icons.refresh_rounded,
                        type: isExpired ? AppButtonType.primary : AppButtonType.outlined,
                        onPressed: () => qrBloc.add(const GenerateQRSessionRequested()),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isMonospace;

  const _MetaRow({
    required this.label,
    required this.value,
    this.isMonospace = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            fontFamily: isMonospace ? 'monospace' : null,
          ),
        ),
      ],
    );
  }
}
