import 'package:equatable/equatable.dart';
import '../../../data/models/attendance_record_model.dart';
import '../../../data/models/employee_model.dart';

/// States emitted by [AdminBloc]
abstract class AdminState extends Equatable {
  const AdminState();

  @override
  List<Object?> get props => [];
}

class AdminInitial extends AdminState {
  const AdminInitial();
}

class AdminLoading extends AdminState {
  const AdminLoading();
}

class AdminLoaded extends AdminState {
  final int totalEmployees;
  final int presentCount;
  final int checkedInCount;
  final int notCheckedInCount;
  final List<EmployeeModel> employees;
  final Map<String, AttendanceRecordModel> todayRecords;
  final DateTime lastUpdated;

  const AdminLoaded({
    required this.totalEmployees,
    required this.presentCount,
    required this.checkedInCount,
    required this.notCheckedInCount,
    required this.employees,
    required this.todayRecords,
    required this.lastUpdated,
  });

  @override
  List<Object?> get props => [
        totalEmployees,
        presentCount,
        checkedInCount,
        notCheckedInCount,
        employees,
        todayRecords,
        lastUpdated,
      ];
}

class AdminError extends AdminState {
  final String message;

  const AdminError({required this.message});

  @override
  List<Object?> get props => [message];
}
