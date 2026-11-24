import 'package:equatable/equatable.dart';

/// Events processed by [AuthBloc]
abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// Dispatched on application startup to restore any active session from SQLite
class AuthCheckSessionRequested extends AuthEvent {
  const AuthCheckSessionRequested();
}

/// Dispatched when the user submits credentials on the login screen
class AuthLoginRequested extends AuthEvent {
  final String identifier;
  final String password;

  const AuthLoginRequested({
    required this.identifier,
    required this.password,
  });

  @override
  List<Object?> get props => [identifier, password];
}

/// Dispatched when the user logs out from Admin or Employee dashboard
class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}

/// Dispatched to toggle password visibility without using setState
class AuthTogglePasswordVisibility extends AuthEvent {
  const AuthTogglePasswordVisibility();
}
