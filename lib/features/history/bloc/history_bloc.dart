import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/errors/failures.dart';
import '../../../data/repositories/attendance_repository.dart';
import 'history_event.dart';
import 'history_state.dart';

/// BLoC managing the retrieval and display of an employee's personal attendance history
class HistoryBloc extends Bloc<HistoryEvent, HistoryState> {
  final AttendanceRepository attendanceRepository;

  HistoryBloc({required this.attendanceRepository}) : super(const HistoryInitial()) {
    on<LoadHistoryRequested>(_onLoadHistory);
    on<RefreshHistoryRequested>(_onRefreshHistory);
  }

  Future<void> _onLoadHistory(
    LoadHistoryRequested event,
    Emitter<HistoryState> emit,
  ) async {
    // 0. Role Guard: prevent Admins from querying employee personal history
    if (event.role != null && event.role == AppConstants.roleAdmin) {
      emit(const HistoryError(
        message: 'Administrators do not have personal employee attendance history. '
            'Please access the Admin Attendance Records screen.',
      ));
      return;
    }

    emit(const HistoryLoading());
    await _fetchAndEmitHistory(event.employeeId, emit);
  }

  Future<void> _onRefreshHistory(
    RefreshHistoryRequested event,
    Emitter<HistoryState> emit,
  ) async {
    if (event.role != null && event.role == AppConstants.roleAdmin) {
      emit(const HistoryError(
        message: 'Administrators do not have personal employee attendance history. '
            'Please access the Admin Attendance Records screen.',
      ));
      return;
    }

    await _fetchAndEmitHistory(event.employeeId, emit);
  }

  Future<void> _fetchAndEmitHistory(
    String employeeId,
    Emitter<HistoryState> emit,
  ) async {
    try {
      final records = await attendanceRepository.getEmployeeHistory(employeeId);
      if (records.isEmpty) {
        emit(const HistoryEmpty());
      } else {
        emit(HistoryLoaded(records: records));
      }
    } on Failure catch (e) {
      emit(HistoryError(message: e.message));
    } catch (e) {
      emit(HistoryError(message: 'Failed to load attendance history: $e'));
    }
  }
}
