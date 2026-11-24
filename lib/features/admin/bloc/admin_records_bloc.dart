import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/errors/failures.dart';
import '../../../data/repositories/attendance_repository.dart';
import 'admin_records_event.dart';
import 'admin_records_state.dart';

/// BLoC managing querying, searching, and filtering of all employee attendance records for Admins
class AdminRecordsBloc extends Bloc<AdminRecordsEvent, AdminRecordsState> {
  final AttendanceRepository attendanceRepository;

  AdminRecordsBloc({required this.attendanceRepository})
      : super(const AdminRecordsInitial()) {
    on<LoadAdminRecordsRequested>(_onLoadRecords);
    on<FilterAdminRecordsByDate>(_onFilterByDate);
    on<SearchAdminRecords>(_onSearch);
    on<ClearAdminRecordsFilter>(_onClearFilter);
  }

  Future<void> _onLoadRecords(
    LoadAdminRecordsRequested event,
    Emitter<AdminRecordsState> emit,
  ) async {
    if (!_verifyAdminRole(event.role, emit)) return;

    emit(const AdminRecordsLoading());
    await _queryAndEmit(
      date: event.date,
      searchQuery: event.searchQuery,
      emit: emit,
    );
  }

  Future<void> _onFilterByDate(
    FilterAdminRecordsByDate event,
    Emitter<AdminRecordsState> emit,
  ) async {
    if (!_verifyAdminRole(event.role, emit)) return;

    emit(const AdminRecordsLoading());
    await _queryAndEmit(
      date: event.date,
      searchQuery: event.searchQuery,
      emit: emit,
    );
  }

  Future<void> _onSearch(
    SearchAdminRecords event,
    Emitter<AdminRecordsState> emit,
  ) async {
    if (!_verifyAdminRole(event.role, emit)) return;

    emit(const AdminRecordsLoading());
    await _queryAndEmit(
      date: event.date,
      searchQuery: event.searchQuery,
      emit: emit,
    );
  }

  Future<void> _onClearFilter(
    ClearAdminRecordsFilter event,
    Emitter<AdminRecordsState> emit,
  ) async {
    if (!_verifyAdminRole(event.role, emit)) return;

    emit(const AdminRecordsLoading());
    await _queryAndEmit(
      date: null,
      searchQuery: null,
      emit: emit,
    );
  }

  bool _verifyAdminRole(String? role, Emitter<AdminRecordsState> emit) {
    if (role != null && role != AppConstants.roleAdmin) {
      emit(const AdminRecordsError(
        message: 'Unauthorized access: Only administrators can view all employee attendance records.',
      ));
      return false;
    }
    return true;
  }

  Future<void> _queryAndEmit({
    required String? date,
    required String? searchQuery,
    required Emitter<AdminRecordsState> emit,
  }) async {
    try {
      final records = await attendanceRepository.getAllAttendanceRecords(
        date: date,
        searchQuery: searchQuery,
      );

      if (records.isEmpty) {
        emit(AdminRecordsEmpty(
          selectedDate: date,
          searchQuery: searchQuery,
        ));
      } else {
        emit(AdminRecordsLoaded(
          records: records,
          selectedDate: date,
          searchQuery: searchQuery,
        ));
      }
    } on Failure catch (e) {
      emit(AdminRecordsError(message: e.message));
    } catch (e) {
      emit(AdminRecordsError(message: 'Failed to query attendance records: $e'));
    }
  }
}
