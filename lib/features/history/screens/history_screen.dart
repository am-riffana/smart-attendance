import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../../data/models/attendance_record_model.dart';
import '../../../routes/app_routes.dart';
import '../../../shared/app_button.dart';
import '../../../shared/app_card.dart';
import '../../../shared/status_badge.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';
import '../bloc/history_bloc.dart';
import '../bloc/history_event.dart';
import '../bloc/history_state.dart';

/// Employee Attendance History Screen displaying personal records and GPS geofence details
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  void _loadHistory() {
    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated) {
      context.read<HistoryBloc>().add(
            LoadHistoryRequested(
              employeeId: authState.user.employeeId,
              role: authState.user.role,
            ),
          );
    }
  }

  void _refreshHistory() {
    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated) {
      context.read<HistoryBloc>().add(
            RefreshHistoryRequested(
              employeeId: authState.user.employeeId,
              role: authState.user.role,
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = context.watch<AuthBloc>().state;
    final currentUser = authState is Authenticated ? authState.user : null;

    // Guard: Prevent Admin accounts from attempting to view personal employee history
    if (currentUser != null && currentUser.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Attendance History')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: AppCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.admin_panel_settings_rounded,
                    size: 56,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Administrator Notice',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Administrators do not have personal attendance records. '
                    'Please view the Admin Attendance Records screen to view employee history.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  AppButton(
                    label: 'View All Employee Records',
                    onPressed: () => context.go(AppRoutes.adminRecords),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Attendance History'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refreshHistory,
          ),
        ],
      ),
      body: SafeArea(
        child: BlocBuilder<HistoryBloc, HistoryState>(
          builder: (context, state) {
            if (state is HistoryLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is HistoryError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: AppCard(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            size: 48,
                            color: AppColors.error,
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Failed to Load History',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            state.message,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                          const SizedBox(height: 18),
                          AppButton(
                            label: 'Retry',
                            onPressed: _loadHistory,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }

            if (state is HistoryEmpty) {
              return RefreshIndicator(
                onRefresh: () async => _refreshHistory(),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 360),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.history_toggle_off_rounded,
                                size: 64,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'No Attendance Records Yet',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Once you scan the Smart QR code at the office, '
                                'your daily check-in records will appear here.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            if (state is HistoryLoaded) {
              return RefreshIndicator(
                onRefresh: () async => _refreshHistory(),
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: state.records.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final record = state.records[index];
                    return _buildRecordCard(context, record);
                  },
                ),
              );
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildRecordCard(BuildContext context, AttendanceRecordModel record) {
    final theme = Theme.of(context);
    final parsedDate = DateTime.tryParse(record.date);
    final displayDate = parsedDate != null
        ? DateTimeUtils.formatHumanDate(parsedDate)
        : record.date;

    final hasLocation = record.checkInLatitude != null ||
        record.isWithinGeofence != null ||
        record.distanceToOfficeMeters != null;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Date & Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    displayDate,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
              StatusBadge(status: record.status),
            ],
          ),
          const Divider(height: 20),

          // Time Grid
          Row(
            children: [
              Expanded(
                child: _buildTimeBlock(
                  label: 'Check-In',
                  time: record.checkInTime ?? '--:--',
                  icon: Icons.login_rounded,
                  color: AppColors.success,
                ),
              ),
              Container(
                width: 1,
                height: 36,
                color: theme.colorScheme.outline.withValues(alpha: 0.3),
              ),
              Expanded(
                child: _buildTimeBlock(
                  label: 'Check-Out',
                  time: record.checkOutTime ?? '--:--',
                  icon: Icons.logout_rounded,
                  color: Colors.grey,
                ),
              ),
            ],
          ),

          // Location Section (when available)
          if (hasLocation) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            record.isWithinGeofence == true
                                ? Icons.verified_rounded
                                : Icons.location_off_rounded,
                            size: 15,
                            color: record.isWithinGeofence == true
                                ? AppColors.success
                                : AppColors.warning,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            record.isWithinGeofence == true
                                ? 'Within Office Geofence'
                                : 'Outside Office Geofence',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: record.isWithinGeofence == true
                                  ? AppColors.success
                                  : AppColors.warning,
                            ),
                          ),
                        ],
                      ),
                      if (record.distanceToOfficeMeters != null)
                        Text(
                          '${record.distanceToOfficeMeters!.toStringAsFixed(0)}m from office',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                    ],
                  ),
                  if (record.checkInAccuracy != null || record.checkInLatitude != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (record.checkInLatitude != null && record.checkInLongitude != null)
                          Text(
                            'GPS: ${record.checkInLatitude!.toStringAsFixed(4)}, ${record.checkInLongitude!.toStringAsFixed(4)}',
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        if (record.checkInAccuracy != null)
                          Text(
                            '±${record.checkInAccuracy!.toStringAsFixed(0)}m accuracy',
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimeBlock({
    required String label,
    required String time,
    required IconData icon,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            time,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ],
      ),
    );
  }
}
