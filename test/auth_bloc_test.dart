import 'package:flutter_application_1/core/errors/failures.dart';
import 'package:flutter_application_1/data/models/employee_model.dart';
import 'package:flutter_application_1/data/repositories/employee_repository.dart';
import 'package:flutter_application_1/features/auth/bloc/auth_bloc.dart';
import 'package:flutter_application_1/features/auth/bloc/auth_event.dart';
import 'package:flutter_application_1/features/auth/bloc/auth_state.dart';
import 'package:flutter_test/flutter_test.dart';

class MockEmployeeRepository implements EmployeeRepository {
  EmployeeModel? activeSession;

  final Map<String, EmployeeModel> users = {
    'ADM001': const EmployeeModel(
      employeeId: 'ADM001',
      name: 'System Admin',
      email: 'admin@company.com',
      password: 'admin123',
      role: 'admin',
    ),
    'admin@company.com': const EmployeeModel(
      employeeId: 'ADM001',
      name: 'System Admin',
      email: 'admin@company.com',
      password: 'admin123',
      role: 'admin',
    ),
    'EMP001': const EmployeeModel(
      employeeId: 'EMP001',
      name: 'John Doe',
      email: 'john.doe@company.com',
      password: 'employee123',
      role: 'employee',
    ),
    'john.doe@company.com': const EmployeeModel(
      employeeId: 'EMP001',
      name: 'John Doe',
      email: 'john.doe@company.com',
      password: 'employee123',
      role: 'employee',
    ),
  };

  @override
  Future<List<EmployeeModel>> getEmployees() async => users.values.toList();

  @override
  Future<EmployeeModel?> getEmployeeById(String employeeId) async => users[employeeId];

  @override
  Future<EmployeeModel> authenticate(String identifier, String password) async {
    final user = users[identifier];
    if (user != null && user.password == password) {
      return user;
    }
    throw const AuthFailure('Invalid credentials. Please verify your ID/Email and password.');
  }

  @override
  Future<EmployeeModel?> getActiveSession() async => activeSession;

  @override
  Future<void> saveActiveSession(String employeeId) async {
    activeSession = users[employeeId];
  }

  @override
  Future<void> clearActiveSession() async {
    activeSession = null;
  }
}

void main() {
  group('AuthBloc Unit & Scenario Tests', () {
    late MockEmployeeRepository repository;
    late AuthBloc authBloc;

    setUp(() {
      repository = MockEmployeeRepository();
      authBloc = AuthBloc(employeeRepository: repository);
    });

    tearDown(() {
      authBloc.close();
    });

    test('1. Valid Admin Login emits [AuthLoading, Authenticated(admin)]', () async {
      expectLater(
        authBloc.stream,
        emitsInOrder([
          const AuthLoading(),
          predicate<AuthState>(
            (state) => state is Authenticated && state.user.isAdmin,
          ),
        ]),
      );

      authBloc.add(const AuthLoginRequested(
        identifier: 'admin@company.com',
        password: 'admin123',
      ));
    });

    test('2. Valid Employee Login emits [AuthLoading, Authenticated(employee)]', () async {
      expectLater(
        authBloc.stream,
        emitsInOrder([
          const AuthLoading(),
          predicate<AuthState>(
            (state) => state is Authenticated && state.user.isEmployee,
          ),
        ]),
      );

      authBloc.add(const AuthLoginRequested(
        identifier: 'EMP001',
        password: 'employee123',
      ));
    });

    test('3. Invalid Employee ID emits [AuthLoading, AuthFailureState]', () async {
      expectLater(
        authBloc.stream,
        emitsInOrder([
          const AuthLoading(),
          predicate<AuthState>(
            (state) => state is AuthFailureState && state.message.contains('Invalid credentials'),
          ),
        ]),
      );

      authBloc.add(const AuthLoginRequested(
        identifier: 'EMP999',
        password: 'employee123',
      ));
    });

    test('4. Invalid Email emits [AuthLoading, AuthFailureState]', () async {
      expectLater(
        authBloc.stream,
        emitsInOrder([
          const AuthLoading(),
          predicate<AuthState>(
            (state) => state is AuthFailureState && state.message.contains('Invalid credentials'),
          ),
        ]),
      );

      authBloc.add(const AuthLoginRequested(
        identifier: 'unknown@company.com',
        password: 'employee123',
      ));
    });

    test('5. Incorrect Password emits [AuthLoading, AuthFailureState]', () async {
      expectLater(
        authBloc.stream,
        emitsInOrder([
          const AuthLoading(),
          predicate<AuthState>(
            (state) => state is AuthFailureState && state.message.contains('Invalid credentials'),
          ),
        ]),
      );

      authBloc.add(const AuthLoginRequested(
        identifier: 'EMP001',
        password: 'wrong_password',
      ));
    });

    test('6. Empty input fields emits [AuthFailureState] without loading', () async {
      expectLater(
        authBloc.stream,
        emitsInOrder([
          predicate<AuthState>(
            (state) => state is AuthFailureState && state.message.contains('Please enter both'),
          ),
        ]),
      );

      authBloc.add(const AuthLoginRequested(
        identifier: '',
        password: '',
      ));
    });

    test('7. Logout emits [AuthLoading, Unauthenticated(logoutSuccess: true)]', () async {
      expectLater(
        authBloc.stream,
        emitsInOrder([
          const AuthLoading(),
          const Unauthenticated(logoutSuccess: true),
        ]),
      );

      authBloc.add(const AuthLogoutRequested());
    });

    test('8. Session restoration restores Authenticated state when active session exists', () async {
      repository.activeSession = repository.users['EMP001'];

      expectLater(
        authBloc.stream,
        emitsInOrder([
          const AuthLoading(),
          predicate<AuthState>(
            (state) => state is Authenticated && state.user.employeeId == 'EMP001',
          ),
        ]),
      );

      authBloc.add(const AuthCheckSessionRequested());
    });

    test('Password visibility toggle updates isPasswordVisible state without setState', () async {
      expect(authBloc.state.isPasswordVisible, false);

      authBloc.add(const AuthTogglePasswordVisibility());
      await expectLater(
        authBloc.stream,
        emits(predicate<AuthState>((state) => state.isPasswordVisible == true)),
      );

      authBloc.add(const AuthTogglePasswordVisibility());
      await expectLater(
        authBloc.stream,
        emits(predicate<AuthState>((state) => state.isPasswordVisible == false)),
      );
    });
  });
}
