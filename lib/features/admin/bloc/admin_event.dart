import 'package:equatable/equatable.dart';

/// Events processed by [AdminBloc]
abstract class AdminEvent extends Equatable {
  const AdminEvent();

  @override
  List<Object?> get props => [];
}

/// Dispatched to load today's dashboard attendance metrics and registered employees
class AdminDashboardLoadRequested extends AdminEvent {
  const AdminDashboardLoadRequested();
}

/// Dispatched on pull-to-refresh or after creating/marking attendance
class AdminRefreshRequested extends AdminEvent {
  const AdminRefreshRequested();
}
