import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/errors/failures.dart';
import '../../../data/repositories/employee_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final EmployeeRepository employeeRepository;

  AuthBloc({required this.employeeRepository})
      : super(const AuthInitial()) {
    on<AuthCheckSessionRequested>(_onCheckSession);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthTogglePasswordVisibility>(_onTogglePasswordVisibility);
  }

  Future<void> _onCheckSession(
    AuthCheckSessionRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading(isPasswordVisible: state.isPasswordVisible));
    try {
      final activeUser = await employeeRepository.getActiveSession();
      if (activeUser != null) {
        emit(Authenticated(
          user: activeUser,
          isPasswordVisible: state.isPasswordVisible,
        ));
      } else {
        emit(Unauthenticated(isPasswordVisible: state.isPasswordVisible));
      }
    } catch (_) {
      emit(Unauthenticated(isPasswordVisible: state.isPasswordVisible));
    }
  }

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    final identifier = event.identifier.trim();
    final password = event.password;

    if (identifier.isEmpty || password.isEmpty) {
      emit(AuthFailureState(
        message: 'Please enter both Employee ID/Email and password.',
        isPasswordVisible: state.isPasswordVisible,
      ));
      return;
    }

    emit(AuthLoading(isPasswordVisible: state.isPasswordVisible));

    try {
      final user = await employeeRepository.authenticate(identifier, password);

      emit(Authenticated(
        user: user,
        isPasswordVisible: state.isPasswordVisible,
      ));
    } on AuthFailure catch (e) {
      emit(AuthFailureState(
        message: e.message,
        isPasswordVisible: state.isPasswordVisible,
      ));
    } on DatabaseFailure catch (e) {
      emit(AuthFailureState(
        message: 'Database error: ${e.message}',
        isPasswordVisible: state.isPasswordVisible,
      ));
    } catch (e) {
      emit(AuthFailureState(
        message: 'Unexpected login error: $e',
        isPasswordVisible: state.isPasswordVisible,
      ));
    }
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading(isPasswordVisible: state.isPasswordVisible));
    try {
      await employeeRepository.clearActiveSession();
      emit(const Unauthenticated(logoutSuccess: true));
    } catch (e) {
      emit(AuthFailureState(
        message: 'Failed to complete logout: $e',
        isPasswordVisible: state.isPasswordVisible,
      ));
    }
  }

  void _onTogglePasswordVisibility(
    AuthTogglePasswordVisibility event,
    Emitter<AuthState> emit,
  ) {
    final nextVisible = !state.isPasswordVisible;
    if (state is Authenticated) {
      emit(Authenticated(
        user: (state as Authenticated).user,
        isPasswordVisible: nextVisible,
      ));
    } else if (state is AuthFailureState) {
      emit(AuthFailureState(
        message: (state as AuthFailureState).message,
        isPasswordVisible: nextVisible,
      ));
    } else if (state is AuthLoading) {
      emit(AuthLoading(isPasswordVisible: nextVisible));
    } else if (state is Unauthenticated) {
      emit(Unauthenticated(
        isPasswordVisible: nextVisible,
        logoutSuccess: (state as Unauthenticated).logoutSuccess,
      ));
    } else {
      emit(AuthInitial(isPasswordVisible: nextVisible));
    }
  }
}
