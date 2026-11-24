import 'package:equatable/equatable.dart';
import '../../../data/models/employee_model.dart';

/// States emitted by [AuthBloc]
abstract class AuthState extends Equatable {
  final bool isPasswordVisible;

  const AuthState({this.isPasswordVisible = false});

  @override
  List<Object?> get props => [isPasswordVisible];
}

/// Initial state before any session check or user interaction
class AuthInitial extends AuthState {
  const AuthInitial({super.isPasswordVisible = false});
}

/// State emitted while authenticating or checking session
class AuthLoading extends AuthState {
  const AuthLoading({super.isPasswordVisible = false});
}

/// State emitted upon successful authentication
class Authenticated extends AuthState {
  final EmployeeModel user;

  const Authenticated({
    required this.user,
    super.isPasswordVisible = false,
  });

  @override
  List<Object?> get props => [user, isPasswordVisible];
}

/// State emitted when user is not logged in or has logged out
class Unauthenticated extends AuthState {
  final bool logoutSuccess;

  const Unauthenticated({
    super.isPasswordVisible = false,
    this.logoutSuccess = false,
  });

  @override
  List<Object?> get props => [isPasswordVisible, logoutSuccess];
}

/// State emitted when authentication fails (invalid credentials, db error, etc.)
class AuthFailureState extends AuthState {
  final String message;

  const AuthFailureState({
    required this.message,
    super.isPasswordVisible = false,
  });

  @override
  List<Object?> get props => [message, isPasswordVisible];
}
