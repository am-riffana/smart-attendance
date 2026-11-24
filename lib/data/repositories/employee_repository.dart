
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;
import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../datasources/employee_local_data_source.dart';
import '../datasources/employee_remote_data_source.dart';
import '../models/employee_model.dart';

abstract class EmployeeRepository {
  Future<List<EmployeeModel>> getEmployees();
  Future<EmployeeModel?> getEmployeeById(String employeeId);
  Future<EmployeeModel> authenticate(String identifier, String password);
  Future<EmployeeModel?> getActiveSession();
  Future<void> saveActiveSession(String employeeId);
  Future<void> clearActiveSession();
}

class EmployeeRepositoryImpl implements EmployeeRepository {
  final EmployeeLocalDataSource _localDataSource;
  final EmployeeRemoteDataSource? _remoteDataSource;

  SupabaseClient get _supabase => Supabase.instance.client;

  EmployeeRepositoryImpl({
    EmployeeLocalDataSource? localDataSource,
    EmployeeRemoteDataSource? remoteDataSource,
  })  : _localDataSource = localDataSource ?? EmployeeLocalDataSource(),
        _remoteDataSource = remoteDataSource ?? EmployeeRemoteDataSource();

  // Existing local employee list — kept for the current AdminBloc.
  @override
  Future<List<EmployeeModel>> getEmployees() async {
    try {
      return await _localDataSource.getAllEmployees();
    } on LocalDatabaseException catch (e) {
      throw DatabaseFailure(e.message);
    } catch (e) {
      throw DatabaseFailure('Unexpected error fetching employees: $e');
    }
  }

  @override
  Future<EmployeeModel?> getEmployeeById(String employeeId) async {
    try {
      return await _localDataSource.getEmployeeById(employeeId);
    } on LocalDatabaseException catch (e) {
      throw DatabaseFailure(e.message);
    } catch (e) {
      throw DatabaseFailure('Unexpected error retrieving employee: $e');
    }
  }

  // Supabase email/password authentication.
  @override
  Future<EmployeeModel> authenticate(
    String identifier,
    String password,
  ) async {
    try {
      if (!identifier.contains('@')) {
        throw const AuthFailure(
          'Please use your registered email address to log in.',
        );
      }

      final response = await _supabase.auth.signInWithPassword(
        email: identifier.trim(),
        password: password,
      );

      final user = response.user;

      if (user == null) {
        throw const AuthFailure('Login failed. Please try again.');
      }

      return await _fetchEmployeeProfile(user.id);
    } on AuthFailure {
      rethrow;
    } on AuthApiException catch (e) {
  throw AuthFailure(e.message);
} catch (e) {
      throw AuthFailure('Authentication failed: $e');
    }
  }

  // Fetch the logged-in user's own profile and role.
  Future<EmployeeModel> _fetchEmployeeProfile(String userId) async {
    final profile = await _supabase
        .from('employee_profiles')
        .select('employee_id, full_name, email, role')
        .eq('id', userId)
        .maybeSingle();

    if (profile == null) {
      throw const AuthFailure(
        'Employee profile not found. Please contact the administrator.',
      );
    }

    return EmployeeModel(
      employeeId: profile['employee_id'] as String,
      name: profile['full_name'] as String,
      email: profile['email'] as String,
      password: '',
      role: profile['role'] as String,
    );
  }

  // Supabase automatically persists and restores its authentication session.
  @override
  Future<EmployeeModel?> getActiveSession() async {
    try {
      final user = _supabase.auth.currentUser;

      if (user == null) return null;

      return await _fetchEmployeeProfile(user.id);
    } on AuthFailure {
      rethrow;
    } catch (e) {
      throw DatabaseFailure('Unable to restore Supabase session: $e');
    }
  }

  // No SQLite session save is needed anymore.
  @override
  Future<void> saveActiveSession(String employeeId) async {
    // Supabase Auth manages the session automatically.
  }

  // Sign out from Supabase.
  @override
  Future<void> clearActiveSession() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      throw AuthFailure('Unable to log out: $e');
    }
  }

  // Existing mock REST API methods.
  Future<EmployeeModel?> fetchRemoteEmployee(String employeeId) async {
    if (_remoteDataSource == null) return null;
    return await _remoteDataSource.fetchEmployee(employeeId);
  }

  Future<List<EmployeeModel>> fetchRemoteEmployees() async {
    if (_remoteDataSource == null) return [];
    return await _remoteDataSource.fetchEmployees();
  }
}
