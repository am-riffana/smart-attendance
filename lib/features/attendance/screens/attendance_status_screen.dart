import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../routes/app_routes.dart';
import '../../../shared/app_button.dart';
import '../../../shared/app_card.dart';

/// Screen presenting check-in result with location details
class AttendanceStatusScreen extends StatelessWidget {
  final bool isSuccess;
  final String message;
  final String? timestamp;
  final String? employeeId;

  // Phase 6 — GPS location details (all nullable)
  final bool? isWithinGeofence;
  final double? distanceToOfficeMeters;
  final double? locationAccuracy;
  final String? locationFailureMessage;

  const AttendanceStatusScreen({
    super.key,
    this.isSuccess = true,
    this.message = 'Attendance marked successfully.',
    this.timestamp,
    this.employeeId,
    this.isWithinGeofence,
    this.distanceToOfficeMeters,
    this.locationAccuracy,
    this.locationFailureMessage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Status'),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CircleAvatar(
                      radius: 38,
                      backgroundColor:
                          (isSuccess ? AppColors.success : AppColors.error).withValues(alpha: 0.12),
                      child: Icon(
                        isSuccess ? Icons.check_circle_rounded : Icons.cancel_rounded,
                        color: isSuccess ? AppColors.success : AppColors.error,
                        size: 48,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      isSuccess ? 'Verification Success' : 'Verification Failed',
                      textAlign: TextAlign.center,
                      style:
                          theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Attendance Details Card ──────────────────────────
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Captured Details',
                            style: theme.textTheme.labelMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const Divider(height: 16),
                          _DetailRow(
                            label: 'Timestamp',
                            value: timestamp ?? 'Today, Local Time',
                          ),
                          if (employeeId != null) ...[
                            const SizedBox(height: 6),
                            _DetailRow(label: 'Employee ID', value: employeeId!),
                          ],
                          const SizedBox(height: 6),
                          _DetailRow(
                            label: 'Status',
                            value: isSuccess ? 'Checked In' : 'Failed',
                          ),
                        ],
                      ),
                    ),

                    // ── Location Details Card ────────────────────────────
                    const SizedBox(height: 16),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.location_on_outlined, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                'Location Details',
                                style: theme.textTheme.labelMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const Divider(height: 16),
                          if (locationFailureMessage != null) ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.warning_amber_rounded,
                                  size: 16,
                                  color: AppColors.warning,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    locationFailureMessage!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.warning,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            if (isWithinGeofence != null) ...[
                              _LocationDetailRow(
                                label: 'Office Geofence',
                                value: isWithinGeofence! ? 'Within Office' : 'Outside Office',
                                valueColor: isWithinGeofence!
                                    ? AppColors.success
                                    : AppColors.warning,
                                icon: isWithinGeofence!
                                    ? Icons.check_circle_outline_rounded
                                    : Icons.location_off_outlined,
                              ),
                              const SizedBox(height: 6),
                            ],
                            if (distanceToOfficeMeters != null) ...[
                              _DetailRow(
                                label: 'Distance to Office',
                                value:
                                    '${distanceToOfficeMeters!.toStringAsFixed(0)} m',
                              ),
                              const SizedBox(height: 6),
                            ],
                            if (locationAccuracy != null) ...[
                              _DetailRow(
                                label: 'GPS Accuracy',
                                value: '±${locationAccuracy!.toStringAsFixed(0)} m',
                              ),
                            ],
                            if (isWithinGeofence == null &&
                                distanceToOfficeMeters == null &&
                                locationAccuracy == null)
                              const Text(
                                'Location not captured.',
                                style: TextStyle(fontSize: 13, color: Colors.grey),
                              ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),
                    AppButton(
                      label: 'Return to Dashboard',
                      onPressed: () => context.go(AppRoutes.employeeDashboard),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _LocationDetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final IconData? icon;

  const _LocationDetailRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: valueColor),
              const SizedBox(width: 4),
            ],
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: valueColor,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
