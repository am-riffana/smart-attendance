import 'package:equatable/equatable.dart';

/// Events processed by [HistoryBloc]
abstract class HistoryEvent extends Equatable {
  const HistoryEvent();

  @override
  List<Object?> get props => [];
}

/// Dispatched to load an employee's personal attendance history
class LoadHistoryRequested extends HistoryEvent {
  final String employeeId;
  final String? role;

  const LoadHistoryRequested({
    required this.employeeId,
    this.role,
  });

  @override
  List<Object?> get props => [employeeId, role];
}

/// Dispatched to refresh an employee's personal attendance history
class RefreshHistoryRequested extends HistoryEvent {
  final String employeeId;
  final String? role;

  const RefreshHistoryRequested({
    required this.employeeId,
    this.role,
  });

  @override
  List<Object?> get props => [employeeId, role];
}
