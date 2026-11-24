import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../../data/models/attendance_record_model.dart';
import '../../../routes/app_routes.dart';
import '../../../shared/app_button.dart';
import '../../../shared/app_card.dart';
import '../../../shared/confirmation_dialog.dart';
import '../../../shared/status_badge.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_event.dart';
import '../../auth/bloc/auth_state.dart';
import '../bloc/attendance_bloc.dart';
import '../bloc/attendance_event.dart';
import '../bloc/attendance_state.dart';

/// Employee Dashboard Screen with live attendance status and BLoC integration
class EmployeeDashboardScreen extends StatefulWidget {
  const EmployeeDashboardScreen({super.key});

  @override
  State<EmployeeDashboardScreen> createState() => _EmployeeDashboardScreenState();
}

class _EmployeeDashboardScreenState extends State<EmployeeDashboardScreen> {
  @override
  void initState() {
    super.initState();
    _loadTodayAttendance();
  }

  void _loadTodayAttendance() {
    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated) {
      context.read<AttendanceBloc>().add(
        LoadTodayAttendanceRequested(employeeId: authState.user.employeeId),
      );
    }
  }

  Future<void> _refreshTodayAttendance() async {
    _loadTodayAttendance();
  }

  Future<void> _handleScanQr(BuildContext context) async {
    await context.push(AppRoutes.qrScanner);
    if (mounted) {
      _loadTodayAttendance();
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Sign Out',
      message: 'Are you sure you want to sign out?',
      confirmLabel: 'Sign Out',
      isDestructive: true,
    );
    if (confirmed == true && context.mounted) {
      context.read<AuthBloc>().add(const AuthLogoutRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee Portal'),
        actions: [
          IconButton(
            tooltip: 'Sign Out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => _handleLogout(context),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshTodayAttendance,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Employee Profile Card displaying authenticated employee info
                BlocBuilder<AuthBloc, AuthState>(
                  builder: (context, state) {
                    final employeeName = state is Authenticated ? state.user.name : 'Employee';
                    final employeeId = state is Authenticated ? state.user.employeeId : 'EMP001';

                    return AppCard(
                      color: AppColors.primary,
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 26,
                            backgroundColor: Colors.white24,
                            child: Icon(Icons.person_outline_rounded, color: Colors.white, size: 30),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  employeeName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'ID: $employeeId • ${DateTimeUtils.formatHumanDate(DateTime.now())}',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),

                // Today's Status Card driven by AttendanceBloc
                BlocBuilder<AttendanceBloc, AttendanceState>(
                  builder: (context, attendanceState) {
                    AttendanceRecordModel? todayRecord;
                    if (attendanceState is AttendanceTodayStatusLoaded) {
                      todayRecord = attendanceState.record;
                    } else if (attendanceState is AttendanceCheckInSuccess) {
                      todayRecord = attendanceState.record;
                    }

                    final isCheckedIn = todayRecord != null && todayRecord.isCheckedIn;
                    final status = todayRecord?.status ?? 'absent';
                    final checkInTime = todayRecord?.checkInTime ?? '--:--';
                    final checkOutTime = todayRecord?.checkOutTime ?? '--:--';

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "Today's Status",
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  StatusBadge(status: status),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _TimeColumn(label: 'Check-In', time: checkInTime),
                                  _TimeColumn(label: 'Check-Out', time: checkOutTime),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Scan QR to Check In Button
                        AppButton(
                          label: isCheckedIn ? 'Already Checked In' : 'Scan QR to Check In',
                          icon: isCheckedIn ? Icons.check_circle_rounded : Icons.qr_code_scanner_rounded,
                          height: 52,
                          type: isCheckedIn ? AppButtonType.outlined : AppButtonType.primary,
                          onPressed: isCheckedIn
                              ? () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'You have already checked in today at $checkInTime. Duplicate check-ins are not permitted.',
                                      ),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              : () => _handleScanQr(context),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),

                // Attendance History Navigation Button
                AppButton(
                  label: 'Attendance History',
                  icon: Icons.history_rounded,
                  type: AppButtonType.outlined,
                  onPressed: () => context.push(AppRoutes.attendanceHistory),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TimeColumn extends StatelessWidget {
  final String label;
  final String time;

  const _TimeColumn({required this.label, required this.time});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        Text(
          time,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
