import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../../routes/app_routes.dart';
import '../../../shared/app_button.dart';
import '../../../shared/app_card.dart';
import '../../../shared/confirmation_dialog.dart';
import '../../../shared/error_view.dart';
import '../../../shared/loading_indicator.dart';
import '../../../shared/status_badge.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_event.dart';
import '../../auth/bloc/auth_state.dart';
import '../bloc/admin_bloc.dart';
import '../bloc/admin_event.dart';
import '../bloc/admin_state.dart';

/// Professional Admin Dashboard Screen populated with real SQLite statistics and employee listings
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Dispatch initial load safely once on mount
    final adminBloc = context.read<AdminBloc>();
    if (adminBloc.state is AdminInitial) {
      adminBloc.add(const AdminDashboardLoadRequested());
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Sign Out',
      message: 'Are you sure you want to sign out of the Admin portal?',
      confirmLabel: 'Sign Out',
      isDestructive: true,
    );
    if (confirmed == true && mounted) {
      context.read<AuthBloc>().add(const AuthLogoutRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final adminBloc = context.read<AdminBloc>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Refresh Data',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => adminBloc.add(const AdminRefreshRequested()),
          ),
          IconButton(
            tooltip: 'Sign Out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: SafeArea(
        child: BlocBuilder<AdminBloc, AdminState>(
          builder: (context, adminState) {
            if (adminState is AdminLoading) {
              return const LoadingIndicator(message: 'Calculating attendance metrics...');
            }

            if (adminState is AdminError) {
              return ErrorView(
                title: 'Unable to load dashboard',
                message: adminState.message,
                onRetry: () => adminBloc.add(const AdminDashboardLoadRequested()),
              );
            }

            final totalEmployees = adminState is AdminLoaded ? adminState.totalEmployees : 0;
            final presentCount = adminState is AdminLoaded ? adminState.presentCount : 0;
            final checkedInCount = adminState is AdminLoaded ? adminState.checkedInCount : 0;
            final notCheckedInCount = adminState is AdminLoaded ? adminState.notCheckedInCount : 0;
            final employees = adminState is AdminLoaded ? adminState.employees : [];
            final todayRecords = adminState is AdminLoaded ? adminState.todayRecords : {};

            return RefreshIndicator(
              onRefresh: () async {
                adminBloc.add(const AdminRefreshRequested());
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Admin Identity Header Card
                    BlocBuilder<AuthBloc, AuthState>(
                      builder: (context, authState) {
                        final adminName = authState is Authenticated ? authState.user.name : 'System Administrator';
                        final adminId = authState is Authenticated ? authState.user.employeeId : 'ADM001';

                        return AppCard(
                          color: AppColors.primary,
                          child: Row(
                            children: [
                              const CircleAvatar(
                                radius: 26,
                                backgroundColor: Colors.white24,
                                child: Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 30),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      adminName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$adminId • ${DateTimeUtils.formatHumanDate(DateTime.now())}',
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

                    // Primary Admin Quick Actions
                    Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            label: 'Generate QR',
                            icon: Icons.qr_code_2_rounded,
                            onPressed: () async {
                              await context.push(AppRoutes.qrSession);
                              if (context.mounted) {
                                adminBloc.add(const AdminRefreshRequested());
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppButton(
                            label: 'All Records',
                            icon: Icons.table_chart_outlined,
                            type: AppButtonType.outlined,
                            onPressed: () async {
                              await context.push(AppRoutes.adminRecords);
                              if (context.mounted) {
                                adminBloc.add(const AdminRefreshRequested());
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // SQLite Calculated KPI Metrics Grid
                    Text(
                      "Today's Attendance Overview",
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 1.45,
                      children: [
                        _MetricCard(
                          title: 'Total Employees',
                          value: '$totalEmployees',
                          icon: Icons.people_outline_rounded,
                          color: AppColors.primary,
                        ),
                        _MetricCard(
                          title: 'Present Today',
                          value: '$presentCount',
                          icon: Icons.check_circle_outline_rounded,
                          color: AppColors.present,
                        ),
                        _MetricCard(
                          title: 'Checked-in',
                          value: '$checkedInCount',
                          icon: Icons.login_rounded,
                          color: AppColors.checkedIn,
                        ),
                        _MetricCard(
                          title: 'Not Checked-in',
                          value: '$notCheckedInCount',
                          icon: Icons.pending_actions_rounded,
                          color: AppColors.absent,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Registered Employee List Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Registered Employees (${employees.length})',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Today Status',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (employees.isEmpty)
                      const AppCard(
                        padding: EdgeInsets.all(20),
                        child: Center(
                          child: Text('No employees found in the database.'),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: employees.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final emp = employees[index];
                          final record = todayRecords[emp.employeeId];
                          final status = record != null ? record.status : AppConstants.statusAbsent;

                          return AppCard(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                                  child: Text(
                                    emp.name.isNotEmpty ? emp.name[0].toUpperCase() : 'E',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        emp.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${emp.employeeId} • ${emp.email}',
                                        style: TextStyle(
                                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                StatusBadge(status: status),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                ),
              ),
              Icon(icon, color: color, size: 20),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
