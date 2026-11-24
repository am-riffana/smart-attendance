import 'package:equatable/equatable.dart';
import '../../../data/models/attendance_record_model.dart';

/// States emitted by [HistoryBloc]
abstract class HistoryState extends Equatable {
  const HistoryState();

  @override
  List<Object?> get props => [];
}

class HistoryInitial extends HistoryState {
  const HistoryInitial();
}

class HistoryLoading extends HistoryState {
  const HistoryLoading();
}

class HistoryLoaded extends HistoryState {
  final List<AttendanceRecordModel> records;

  const HistoryLoaded({required this.records});

  @override
  List<Object?> get props => [records];
}

class HistoryEmpty extends HistoryState {
  const HistoryEmpty();
}

class HistoryError extends HistoryState {
  final String message;

  const HistoryError({required this.message});

  @override
  List<Object?> get props => [message];
}
