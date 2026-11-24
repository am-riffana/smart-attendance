import 'package:equatable/equatable.dart';
import '../../core/constants/app_constants.dart';
import '../../core/database/database_constants.dart';

/// Employee model representing system users (Admin and Employees)
class EmployeeModel extends Equatable {
  final int? id;
  final String employeeId;
  final String name;
  final String email;
  final String password;
  final String role;

  const EmployeeModel({
    this.id,
    required this.employeeId,
    required this.name,
    required this.email,
    required this.password,
    required this.role,
  });

  bool get isAdmin => role == AppConstants.roleAdmin;
  bool get isEmployee => role == AppConstants.roleEmployee;

  /// Creates model from SQLite database record row
  factory EmployeeModel.fromMap(Map<String, dynamic> map) {
    return EmployeeModel(
      id: map[DatabaseConstants.colEmpId] as int?,
      employeeId: map[DatabaseConstants.colEmpEmployeeId] as String? ?? '',
      name: map[DatabaseConstants.colEmpName] as String? ?? '',
      email: map[DatabaseConstants.colEmpEmail] as String? ?? '',
      password: map[DatabaseConstants.colEmpPassword] as String? ?? '',
      role: map[DatabaseConstants.colEmpRole] as String? ?? AppConstants.roleEmployee,
    );
  }

  /// Converts model to SQLite column-value map
  Map<String, dynamic> toMap({bool includeId = false}) {
    final map = <String, dynamic>{
      DatabaseConstants.colEmpEmployeeId: employeeId,
      DatabaseConstants.colEmpName: name,
      DatabaseConstants.colEmpEmail: email,
      DatabaseConstants.colEmpPassword: password,
      DatabaseConstants.colEmpRole: role,
    };
    if (includeId && id != null) {
      map[DatabaseConstants.colEmpId] = id;
    }
    return map;
  }

  factory EmployeeModel.fromJson(Map<String, dynamic> json) => EmployeeModel.fromMap(json);
  Map<String, dynamic> toJson() => toMap(includeId: true);

  EmployeeModel copyWith({
    int? id,
    String? employeeId,
    String? name,
    String? email,
    String? password,
    String? role,
  }) {
    return EmployeeModel(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      name: name ?? this.name,
      email: email ?? this.email,
      password: password ?? this.password,
      role: role ?? this.role,
    );
  }

  @override
  List<Object?> get props => [id, employeeId, name, email, password, role];
}
