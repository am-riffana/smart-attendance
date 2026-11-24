import 'package:equatable/equatable.dart';
import '../../../data/models/attendance_record_model.dart';

/// States emitted by [AdminRecordsBloc]
abstract class AdminRecordsState extends Equatable {
  const AdminRecordsState();

  @override
  List<Object?> get props => [];
}

class AdminRecordsInitial extends AdminRecordsState {
  const AdminRecordsInitial();
}

class AdminRecordsLoading extends AdminRecordsState {
  const AdminRecordsLoading();
}

class AdminRecordsLoaded extends AdminRecordsState {
  final List<AttendanceRecordModel> records;
  final String? selectedDate;
  final String? searchQuery;

  const AdminRecordsLoaded({
    required this.records,
    this.selectedDate,
    this.searchQuery,
  });

  bool get hasActiveFilter =>
      (selectedDate != null && selectedDate!.isNotEmpty) ||
      (searchQuery != null && searchQuery!.trim().isNotEmpty);

  @override
  List<Object?> get props => [records, selectedDate, searchQuery];
}

class AdminRecordsEmpty extends AdminRecordsState {
  final String? selectedDate;
  final String? searchQuery;

  const AdminRecordsEmpty({
    this.selectedDate,
    this.searchQuery,
  });

  bool get hasActiveFilter =>
      (selectedDate != null && selectedDate!.isNotEmpty) ||
      (searchQuery != null && searchQuery!.trim().isNotEmpty);

  @override
  List<Object?> get props => [selectedDate, searchQuery];
}

class AdminRecordsError extends AdminRecordsState {
  final String message;

  const AdminRecordsError({required this.message});

  @override
  List<Object?> get props => [message];
}
