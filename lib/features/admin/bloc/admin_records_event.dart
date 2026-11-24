import 'package:equatable/equatable.dart';

/// Events processed by [AdminRecordsBloc]
abstract class AdminRecordsEvent extends Equatable {
  const AdminRecordsEvent();

  @override
  List<Object?> get props => [];
}

/// Dispatched to load all attendance records with optional initial filters
class LoadAdminRecordsRequested extends AdminRecordsEvent {
  final String? role;
  final String? date;
  final String? searchQuery;

  const LoadAdminRecordsRequested({
    this.role,
    this.date,
    this.searchQuery,
  });

  @override
  List<Object?> get props => [role, date, searchQuery];
}

/// Dispatched to filter records by specific date
class FilterAdminRecordsByDate extends AdminRecordsEvent {
  final String? date;
  final String? searchQuery;
  final String? role;

  const FilterAdminRecordsByDate({
    required this.date,
    this.searchQuery,
    this.role,
  });

  @override
  List<Object?> get props => [date, searchQuery, role];
}

/// Dispatched to search records by employee name or ID
class SearchAdminRecords extends AdminRecordsEvent {
  final String? searchQuery;
  final String? date;
  final String? role;

  const SearchAdminRecords({
    required this.searchQuery,
    this.date,
    this.role,
  });

  @override
  List<Object?> get props => [searchQuery, date, role];
}

/// Dispatched to reset all search queries and date filters
class ClearAdminRecordsFilter extends AdminRecordsEvent {
  final String? role;

  const ClearAdminRecordsFilter({this.role});

  @override
  List<Object?> get props => [role];
}
