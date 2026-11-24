import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/admin/screens/admin_dashboard_screen.dart';
import '../features/admin/screens/admin_records_screen.dart';
import '../features/attendance/screens/attendance_status_screen.dart';
import '../features/attendance/screens/employee_dashboard_screen.dart';
import '../features/auth/bloc/auth_bloc.dart';
import '../features/auth/bloc/auth_state.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/splash_screen.dart';
import '../features/history/screens/history_screen.dart';
import '../features/qr_scanner/screens/qr_scanner_screen.dart';
import '../features/qr_session/screens/qr_session_screen.dart';
import 'app_routes.dart';
import 'go_router_refresh_stream.dart';

/// Central GoRouter configuration with role-based access guards
class AppRouter {
  AppRouter._();

  static final GlobalKey<NavigatorState> rootNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'root');

  static GoRouter createRouter(AuthBloc authBloc) {
    return GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: AppRoutes.splash,
      refreshListenable: GoRouterRefreshStream(authBloc.stream),
      redirect: (BuildContext context, GoRouterState state) {
        final authState = authBloc.state;
        final currentLocation = state.matchedLocation;
        final isSplash = currentLocation == AppRoutes.splash;
        final isLogin = currentLocation == AppRoutes.login;

        // While initializing or checking session on launch, allow splash screen
        if (authState is AuthInitial || (authState is AuthLoading && isSplash)) {
          return null;
        }

        // Unauthenticated users are redirected to login (unless already on login or splash)
        if (authState is Unauthenticated || authState is AuthFailureState) {
          return isLogin ? null : AppRoutes.login;
        }

        // Authenticated users
        if (authState is Authenticated) {
          final user = authState.user;
          final isAdmin = user.isAdmin;

          // If currently on splash or login, redirect to role-specific dashboard
          if (isSplash || isLogin) {
            return isAdmin ? AppRoutes.adminDashboard : AppRoutes.employeeDashboard;
          }

          // Strict Role Guard: prevent employees from accessing any admin route
          final isAdminRoute = currentLocation.startsWith('/admin');
          if (!isAdmin && isAdminRoute) {
            return AppRoutes.employeeDashboard;
          }

          // Strict Role Guard: prevent admins from accessing employee routes
          final isEmployeeRoute = currentLocation.startsWith('/employee');
          if (isAdmin && isEmployeeRoute) {
            return AppRoutes.adminDashboard;
          }
        }

        return null;
      },
      routes: [
        GoRoute(
          path: AppRoutes.splash,
          name: AppRoutes.splashName,
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: AppRoutes.login,
          name: AppRoutes.loginName,
          builder: (context, state) => LoginScreen(),
        ),
        GoRoute(
          path: AppRoutes.adminDashboard,
          name: AppRoutes.adminDashboardName,
          builder: (context, state) => const AdminDashboardScreen(),
        ),
        GoRoute(
          path: AppRoutes.employeeDashboard,
          name: AppRoutes.employeeDashboardName,
          builder: (context, state) => const EmployeeDashboardScreen(),
        ),
        GoRoute(
          path: AppRoutes.qrSession,
          name: AppRoutes.qrSessionName,
          builder: (context, state) => const QrSessionScreen(),
        ),
        GoRoute(
          path: AppRoutes.qrScanner,
          name: AppRoutes.qrScannerName,
          builder: (context, state) => const QrScannerScreen(),
        ),
        GoRoute(
          path: AppRoutes.attendanceStatus,
          name: AppRoutes.attendanceStatusName,
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>?;
            return AttendanceStatusScreen(
              isSuccess: extra?['isSuccess'] as bool? ?? true,
              message: extra?['message'] as String? ?? 'Attendance verified successfully.',
              timestamp: extra?['timestamp'] as String?,
              employeeId: extra?['employeeId'] as String?,
              isWithinGeofence: extra?['isWithinGeofence'] as bool?,
              distanceToOfficeMeters: extra?['distanceToOfficeMeters'] as double?,
              locationAccuracy: extra?['locationAccuracy'] as double?,
              locationFailureMessage: extra?['locationFailureMessage'] as String?,
            );
          },
        ),
        GoRoute(
          path: AppRoutes.attendanceHistory,
          name: AppRoutes.attendanceHistoryName,
          builder: (context, state) => const HistoryScreen(),
        ),
        GoRoute(
          path: AppRoutes.adminRecords,
          name: AppRoutes.adminRecordsName,
          builder: (context, state) => const AdminRecordsScreen(),
        ),
      ],
      errorBuilder: (context, state) => Scaffold(
        appBar: AppBar(title: const Text('Page Not Found')),
        body: Center(
          child: Text('No route defined for ${state.uri.path}'),
        ),
      ),
    );
  }
}
