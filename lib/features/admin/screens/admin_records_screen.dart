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
import '../bloc/admin_records_bloc.dart';
import '../bloc/admin_records_event.dart';
import '../bloc/admin_records_state.dart';

/// Admin Screen displaying comprehensive employee attendance records with search and date filtering
class AdminRecordsScreen extends StatefulWidget {
  const AdminRecordsScreen({super.key});

  @override
  State<AdminRecordsScreen> createState() => _AdminRecordsScreenState();
}

class _AdminRecordsScreenState extends State<AdminRecordsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedDate;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadRecords() {
    final authState = context.read<AuthBloc>().state;
    final role = authState is Authenticated ? authState.user.role : null;
    context.read<AdminRecordsBloc>().add(
          LoadAdminRecordsRequested(
            role: role,
            date: _selectedDate,
            searchQuery: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
          ),
        );
  }

  void _onSearchChanged(String query) {
    final authState = context.read<AuthBloc>().state;
    final role = authState is Authenticated ? authState.user.role : null;
    context.read<AdminRecordsBloc>().add(
          SearchAdminRecords(
            searchQuery: query.trim().isEmpty ? null : query.trim(),
            date: _selectedDate,
            role: role,
          ),
        );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initialDate = _selectedDate != null
        ? (DateTime.tryParse(_selectedDate!) ?? now)
        : now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
    );

    if (picked != null) {
      final formatted = DateTimeUtils.formatDate(picked);
      setState(() {
        _selectedDate = formatted;
      });
      if (mounted) {
        final authState = context.read<AuthBloc>().state;
        final role = authState is Authenticated ? authState.user.role : null;
        context.read<AdminRecordsBloc>().add(
              FilterAdminRecordsByDate(
                date: formatted,
                searchQuery: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
                role: role,
              ),
            );
      }
    }
  }

  void _clearDateFilter() {
    setState(() {
      _selectedDate = null;
    });
    final authState = context.read<AuthBloc>().state;
    final role = authState is Authenticated ? authState.user.role : null;
    context.read<AdminRecordsBloc>().add(
          FilterAdminRecordsByDate(
            date: null,
            searchQuery: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
            role: role,
          ),
        );
  }

  void _clearAllFilters() {
    setState(() {
      _selectedDate = null;
      _searchController.clear();
    });
    final authState = context.read<AuthBloc>().state;
    final role = authState is Authenticated ? authState.user.role : null;
    context.read<AdminRecordsBloc>().add(ClearAdminRecordsFilter(role: role));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = context.watch<AuthBloc>().state;
    final currentUser = authState is Authenticated ? authState.user : null;
    final isAdmin = currentUser?.isAdmin ?? false;

    // Guard: Prevent Non-Admins from accessing all employee records
    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Attendance Records')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: AppCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.lock_person_rounded,
                    size: 56,
                    color: AppColors.error,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Administrator Access Required',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'You do not have permission to view all employee attendance records. '
                    'This screen is strictly restricted to system administrators.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  AppButton(
                    label: 'Return to Dashboard',
                    onPressed: () => context.go(AppRoutes.employeeDashboard),
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
        title: const Text('All Attendance Records'),
        actions: [
          IconButton(
            tooltip: 'Refresh Records',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadRecords,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search and Date Filter Controls
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search by employee name or ID...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  _onSearchChanged('');
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onChanged: _onSearchChanged,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    tooltip: _selectedDate != null ? 'Date: $_selectedDate' : 'Filter by Date',
                    icon: Icon(
                      Icons.calendar_month_rounded,
                      color: _selectedDate != null ? AppColors.primary : null,
                    ),
                    onPressed: _pickDate,
                  ),
                ],
              ),
            ),

            // Active Filter Chips Bar
            if (_selectedDate != null || _searchController.text.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    if (_selectedDate != null) ...[
                      Chip(
                        avatar: const Icon(Icons.event, size: 16),
                        label: Text('Date: $_selectedDate'),
                        deleteIcon: const Icon(Icons.close, size: 14),
                        onDeleted: _clearDateFilter,
                        visualDensity: VisualDensity.compact,
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (_searchController.text.trim().isNotEmpty) ...[
                      Chip(
                        avatar: const Icon(Icons.search, size: 16),
                        label: Text('"${_searchController.text.trim()}"'),
                        deleteIcon: const Icon(Icons.close, size: 14),
                        onDeleted: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                        visualDensity: VisualDensity.compact,
                      ),
                      const SizedBox(width: 6),
                    ],
                    const Spacer(),
                    TextButton(
                      onPressed: _clearAllFilters,
                      child: const Text('Clear All', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),

            // Content Area driven by AdminRecordsBloc
            Expanded(
              child: BlocBuilder<AdminRecordsBloc, AdminRecordsState>(
                builder: (context, state) {
                  if (state is AdminRecordsLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (state is AdminRecordsError) {
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
                                  'Error Loading Records',
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
                                  onPressed: _loadRecords,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  if (state is AdminRecordsEmpty) {
                    final hasFilter = state.hasActiveFilter;
                    return RefreshIndicator(
                      onRefresh: () async => _loadRecords(),
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(height: MediaQuery.of(context).size.height * 0.18),
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 360),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      hasFilter
                                          ? Icons.filter_alt_off_rounded
                                          : Icons.folder_open_rounded,
                                      size: 56,
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      hasFilter
                                          ? 'No Records Matching Filter'
                                          : 'No Attendance Records Found',
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      hasFilter
                                          ? 'No attendance records match your active search or date filter.'
                                          : 'No attendance check-ins have been recorded by employees yet.',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
                                    ),
                                    if (hasFilter) ...[
                                      const SizedBox(height: 18),
                                      AppButton(
                                        label: 'Clear Filters',
                                        type: AppButtonType.outlined,
                                        onPressed: _clearAllFilters,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  if (state is AdminRecordsLoaded) {
                    return RefreshIndicator(
                      onRefresh: () async => _loadRecords(),
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                        itemCount: state.records.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final record = state.records[index];
                          return _buildAdminRecordCard(context, record);
                        },
                      ),
                    );
                  }

                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminRecordCard(BuildContext context, AttendanceRecordModel record) {
    final theme = Theme.of(context);
    final hasLocation = record.checkInLatitude != null ||
        record.isWithinGeofence != null ||
        record.distanceToOfficeMeters != null;

    final parsedDate = DateTime.tryParse(record.date);
    final displayDate = parsedDate != null
        ? DateTimeUtils.formatHumanDate(parsedDate)
        : record.date;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Employee Avatar, Name, ID & Status
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: Text(
                  record.employeeName?.isNotEmpty == true
                      ? record.employeeName![0].toUpperCase()
                      : record.employeeId.replaceAll('EMP', ''),
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
                      record.employeeName ?? 'Employee ${record.employeeId}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'ID: ${record.employeeId}${record.employeeEmail != null ? ' • ${record.employeeEmail}' : ''}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              StatusBadge(status: record.status),
            ],
          ),
          const Divider(height: 20),

          // Date and Check-In / Out Times
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.event_outlined, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    displayDate,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    'In: ${record.checkInTime ?? '--:--'}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const Text(' | ', style: TextStyle(color: Colors.grey)),
                  Text(
                    'Out: ${record.checkOutTime ?? '--:--'}',
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),

          // Location details if present
          if (hasLocation) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(
                    record.isWithinGeofence == true
                        ? Icons.verified_rounded
                        : Icons.location_off_rounded,
                    size: 14,
                    color: record.isWithinGeofence == true
                        ? AppColors.success
                        : AppColors.warning,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    record.isWithinGeofence == true
                        ? 'Office Geofence'
                        : 'Outside Geofence',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: record.isWithinGeofence == true
                          ? AppColors.success
                          : AppColors.warning,
                    ),
                  ),
                  if (record.distanceToOfficeMeters != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      '(${record.distanceToOfficeMeters!.toStringAsFixed(0)}m away)',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                  const Spacer(),
                  if (record.checkInAccuracy != null)
                    Text(
                      '±${record.checkInAccuracy!.toStringAsFixed(0)}m',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
