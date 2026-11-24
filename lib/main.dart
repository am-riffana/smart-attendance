import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants/app_constants.dart';
import 'core/database/database_helper.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/app_bloc_observer.dart';
import 'data/repositories/attendance_repository.dart';
import 'data/repositories/employee_repository.dart';
import 'data/repositories/qr_session_repository.dart';
import 'features/admin/bloc/admin_bloc.dart';
import 'features/admin/bloc/admin_records_bloc.dart';
import 'features/attendance/bloc/attendance_bloc.dart';
import 'features/auth/bloc/auth_bloc.dart';
import 'features/auth/bloc/auth_event.dart';
import 'features/history/bloc/history_bloc.dart';
import 'features/qr_scanner/bloc/qr_scanner_bloc.dart';
import 'features/qr_session/bloc/qr_session_bloc.dart';

import 'routes/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://novtsetapzxzxhoxyhsv.supabase.co',
    publishableKey: 'sb_publishable_SoZvux4ih5O9cHVxpiZrxQ_Jp-O1qNU',
  );

  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  }

  Bloc.observer = AppBlocObserver();

  try {
    await DatabaseHelper.instance.database;
  } catch (e) {
    debugPrint('[Main] SQLite initialization notice: $e');
  }

  final employeeRepository = EmployeeRepositoryImpl();
  final attendanceRepository = AttendanceRepositoryImpl();
  final qrSessionRepository = QrSessionRepositoryImpl();

  final authBloc = AuthBloc(
    employeeRepository: employeeRepository,
  );

  final adminBloc = AdminBloc(
    employeeRepository: employeeRepository,
    attendanceRepository: attendanceRepository,
  );

  final qrSessionBloc = QRSessionBloc(
    qrSessionRepository: qrSessionRepository,
  );

  final qrScannerBloc = QRScannerBloc(
    qrSessionRepository: qrSessionRepository,
  );

  final attendanceBloc = AttendanceBloc(
    attendanceRepository: attendanceRepository,
  );

  final historyBloc = HistoryBloc(
    attendanceRepository: attendanceRepository,
  );

  final adminRecordsBloc = AdminRecordsBloc(
    attendanceRepository: attendanceRepository,
  );

  authBloc.add(const AuthCheckSessionRequested());

  final router = AppRouter.createRouter(authBloc);

  runApp(
    SmartAttendanceApp(
      authBloc: authBloc,
      adminBloc: adminBloc,
      qrSessionBloc: qrSessionBloc,
      qrScannerBloc: qrScannerBloc,
      attendanceBloc: attendanceBloc,
      historyBloc: historyBloc,
      adminRecordsBloc: adminRecordsBloc,
      router: router,
    ),
  );
}

class SmartAttendanceApp extends StatelessWidget {
  final AuthBloc authBloc;
  final AdminBloc adminBloc;
  final QRSessionBloc qrSessionBloc;
  final QRScannerBloc qrScannerBloc;
  final AttendanceBloc attendanceBloc;
  final HistoryBloc? historyBloc;
  final AdminRecordsBloc? adminRecordsBloc;
  final GoRouter router;

  const SmartAttendanceApp({
    super.key,
    required this.authBloc,
    required this.adminBloc,
    required this.qrSessionBloc,
    required this.qrScannerBloc,
    required this.attendanceBloc,
    this.historyBloc,
    this.adminRecordsBloc,
    required this.router,
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: authBloc),
        BlocProvider<AdminBloc>.value(value: adminBloc),
        BlocProvider<QRSessionBloc>.value(value: qrSessionBloc),
        BlocProvider<QRScannerBloc>.value(value: qrScannerBloc),
        BlocProvider<AttendanceBloc>.value(value: attendanceBloc),

        if (historyBloc != null)
          BlocProvider<HistoryBloc>.value(value: historyBloc!)
        else
          BlocProvider<HistoryBloc>(
            create: (_) => HistoryBloc(
              attendanceRepository: AttendanceRepositoryImpl(),
            ),
          ),

        if (adminRecordsBloc != null)
          BlocProvider<AdminRecordsBloc>.value(
            value: adminRecordsBloc!,
          )
        else
          BlocProvider<AdminRecordsBloc>(
            create: (_) => AdminRecordsBloc(
              attendanceRepository: AttendanceRepositoryImpl(),
            ),
          ),
      ],
      child: MaterialApp.router(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        routerConfig: router,
      ),
    );
  }
}
