import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/errors/failures.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../../data/models/attendance_record_model.dart';
import '../../../data/repositories/attendance_repository.dart';
import '../../../data/repositories/employee_repository.dart';
import 'admin_event.dart';
import 'admin_state.dart';

/// BLoC managing Admin dashboard metrics, employee listings, and attendance aggregations
class AdminBloc extends Bloc<AdminEvent, AdminState> {
  final EmployeeRepository employeeRepository;
  final AttendanceRepository attendanceRepository;

  AdminBloc({
    required this.employeeRepository,
    required this.attendanceRepository,
  }) : super(const AdminInitial()) {
    on<AdminDashboardLoadRequested>(_onLoadDashboard);
    on<AdminRefreshRequested>(_onRefreshDashboard);
  }

  Future<void> _onLoadDashboard(
    AdminDashboardLoadRequested event,
    Emitter<AdminState> emit,
  ) async {
    emit(const AdminLoading());
    await _fetchAndEmitMetrics(emit);
  }

  Future<void> _onRefreshDashboard(
    AdminRefreshRequested event,
    Emitter<AdminState> emit,
  ) async {
    await _fetchAndEmitMetrics(emit);
  }

  Future<void> _fetchAndEmitMetrics(Emitter<AdminState> emit) async {
    try {
      final todayDate = DateTimeUtils.todayDateString();

      // 1. Fetch all registered employees
      final allEmployees = await employeeRepository.getEmployees();
      // Filter only employees (exclude system administrators from attendance counts)
      final employees = allEmployees
          .where((emp) => emp.role == AppConstants.roleEmployee)
          .toList();

      // 2. Fetch today's attendance summary directly from SQLite
      final summary = await attendanceRepository.getAttendanceSummary(todayDate);

      // 3. Fetch today's records to map individual employee attendance states
      final todayRecordList = await attendanceRepository.getAllAttendanceRecords(
        date: todayDate,
      );

      final todayRecordsMap = <String, AttendanceRecordModel>{};
      for (final record in todayRecordList) {
        todayRecordsMap[record.employeeId] = record;
      }

      final totalEmployees = employees.length;
      final presentCount = summary['present'] ?? 0;
      final checkedInCount = summary['checked_in'] ?? 0;
      final notCheckedInCount = totalEmployees > presentCount
          ? (totalEmployees - presentCount)
          : 0;

      emit(AdminLoaded(
        totalEmployees: totalEmployees,
        presentCount: presentCount,
        checkedInCount: checkedInCount,
        notCheckedInCount: notCheckedInCount,
        employees: employees,
        todayRecords: todayRecordsMap,
        lastUpdated: DateTime.now(),
      ));
    } on Failure catch (e) {
      emit(AdminError(message: e.message));
    } catch (e) {
      emit(AdminError(message: 'Failed to load admin dashboard metrics: $e'));
    }
  }
}
