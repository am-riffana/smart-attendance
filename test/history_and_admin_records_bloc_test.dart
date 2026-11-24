import 'package:flutter_application_1/core/constants/app_constants.dart';
import 'package:flutter_application_1/core/errors/failures.dart';
import 'package:flutter_application_1/data/models/attendance_record_model.dart';
import 'package:flutter_application_1/data/repositories/attendance_repository.dart';
import 'package:flutter_application_1/features/admin/bloc/admin_records_bloc.dart';
import 'package:flutter_application_1/features/admin/bloc/admin_records_event.dart';
import 'package:flutter_application_1/features/admin/bloc/admin_records_state.dart';
import 'package:flutter_application_1/features/history/bloc/history_bloc.dart';
import 'package:flutter_application_1/features/history/bloc/history_event.dart';
import 'package:flutter_application_1/features/history/bloc/history_state.dart';
import 'package:flutter_test/flutter_test.dart';

// ============================================================================
// TEST FAKES FOR PHASE 7
// ============================================================================

class FakePhase7AttendanceRepository implements AttendanceRepository {
  List<AttendanceRecordModel> employeeHistoryToReturn = [];
  List<AttendanceRecordModel> allRecordsToReturn = [];
  Failure? failureToThrow;

  String? lastHistoryEmployeeId;
  String? lastAllRecordsDate;
  String? lastAllRecordsSearchQuery;
  int getHistoryCallCount = 0;
  int getAllRecordsCallCount = 0;

  @override
  Future<List<AttendanceRecordModel>> getEmployeeHistory(String employeeId) async {
    getHistoryCallCount++;
    lastHistoryEmployeeId = employeeId;
    if (failureToThrow != null) {
      throw failureToThrow!;
    }
    return employeeHistoryToReturn;
  }

  @override
  Future<List<AttendanceRecordModel>> getAllAttendanceRecords({
    String? date,
    String? searchQuery,
  }) async {
    getAllRecordsCallCount++;
    lastAllRecordsDate = date;
    lastAllRecordsSearchQuery = searchQuery;
    if (failureToThrow != null) {
      throw failureToThrow!;
    }

    var filtered = List<AttendanceRecordModel>.from(allRecordsToReturn);
    if (date != null && date.isNotEmpty) {
      filtered = filtered.where((r) => r.date == date).toList();
    }
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final term = searchQuery.trim().toLowerCase();
      filtered = filtered.where((r) {
        final nameMatches = r.employeeName?.toLowerCase().contains(term) ?? false;
        final idMatches = r.employeeId.toLowerCase().contains(term);
        return nameMatches || idMatches;
      }).toList();
    }
    return filtered;
  }

  @override
  Future<AttendanceRecordModel?> getTodayRecord(String employeeId, String date) async => null;

  @override
  Future<AttendanceRecordModel> checkIn(AttendanceRecordModel record) async => record;

  @override
  Future<void> checkOut({
    required String employeeId,
    required String date,
    required String checkOutTime,
    required double latitude,
    required double longitude,
  }) async {}

  @override
  Future<Map<String, int>> getAttendanceSummary(String date) async => {
        'total': 4,
        'present': 1,
        'checked_in': 1,
        'checked_out': 0,
        'not_checked_in': 3,
      };
}

void main() {
  // ============================================================================
  // TASK 1: EMPLOYEE ATTENDANCE HISTORY TESTS
  // ============================================================================
  group('Phase 7 - Task 1: HistoryBloc (Employee Attendance History)', () {
    late FakePhase7AttendanceRepository fakeRepo;
    late HistoryBloc historyBloc;

    final sampleRecords = [
      const AttendanceRecordModel(
        id: 1,
        employeeId: 'EMP001',
        date: '2026-11-12',
        checkInTime: '09:05 AM',
        checkOutTime: null,
        status: AppConstants.statusCheckedIn,
        checkInLatitude: 12.9716,
        checkInLongitude: 77.5946,
        checkInAccuracy: 5.0,
        locationCapturedAt: '2026-11-12T09:05:00.000Z',
        isWithinGeofence: true,
        distanceToOfficeMeters: 18.0,
      ),
      const AttendanceRecordModel(
        id: 2,
        employeeId: 'EMP001',
        date: '2026-11-11',
        checkInTime: '09:10 AM',
        checkOutTime: '05:30 PM',
        status: AppConstants.statusCheckedOut,
        checkInLatitude: 12.9800,
        checkInLongitude: 77.6000,
        checkInAccuracy: 12.0,
        isWithinGeofence: false,
        distanceToOfficeMeters: 1200.0,
      ),
    ];

    setUp(() {
      fakeRepo = FakePhase7AttendanceRepository();
      historyBloc = HistoryBloc(attendanceRepository: fakeRepo);
    });

    tearDown(() {
      historyBloc.close();
    });

    test('1. Initial state is HistoryInitial', () {
      expect(historyBloc.state, equals(const HistoryInitial()));
    });

    test('2. LoadHistoryRequested fetches employee history and emits [HistoryLoading, HistoryLoaded]', () async {
      fakeRepo.employeeHistoryToReturn = sampleRecords;

      historyBloc.add(const LoadHistoryRequested(
        employeeId: 'EMP001',
        role: AppConstants.roleEmployee,
      ));

      await expectLater(
        historyBloc.stream,
        emitsInOrder([
          const HistoryLoading(),
          HistoryLoaded(records: sampleRecords),
        ]),
      );

      expect(fakeRepo.lastHistoryEmployeeId, equals('EMP001'));
      expect(fakeRepo.getHistoryCallCount, equals(1));
    });

    test('3. Employee isolation: only the requested employeeId is queried', () async {
      fakeRepo.employeeHistoryToReturn = [sampleRecords.first];

      historyBloc.add(const LoadHistoryRequested(
        employeeId: 'EMP002',
        role: AppConstants.roleEmployee,
      ));

      await expectLater(
        historyBloc.stream,
        emitsInOrder([
          const HistoryLoading(),
          HistoryLoaded(records: [sampleRecords.first]),
        ]),
      );

      // Verifies isolation — employee EMP002 was queried, never others
      expect(fakeRepo.lastHistoryEmployeeId, equals('EMP002'));
    });

    test('4. Empty records list emits [HistoryLoading, HistoryEmpty]', () async {
      fakeRepo.employeeHistoryToReturn = [];

      historyBloc.add(const LoadHistoryRequested(
        employeeId: 'EMP003',
        role: AppConstants.roleEmployee,
      ));

      await expectLater(
        historyBloc.stream,
        emitsInOrder([
          const HistoryLoading(),
          const HistoryEmpty(),
        ]),
      );
    });

    test('5. Repository failure emits [HistoryLoading, HistoryError]', () async {
      fakeRepo.failureToThrow = const DatabaseFailure('SQLite disk I/O error');

      historyBloc.add(const LoadHistoryRequested(
        employeeId: 'EMP001',
        role: AppConstants.roleEmployee,
      ));

      await expectLater(
        historyBloc.stream,
        emitsInOrder([
          const HistoryLoading(),
          predicate<HistoryState>((state) {
            return state is HistoryError && state.message.contains('SQLite disk I/O error');
          }),
        ]),
      );
    });

    test('6. Admin role is rejected with clear error message', () async {
      historyBloc.add(const LoadHistoryRequested(
        employeeId: 'ADM001',
        role: AppConstants.roleAdmin,
      ));

      await expectLater(
        historyBloc.stream,
        emits(predicate<HistoryState>((state) {
          return state is HistoryError &&
              state.message.contains('Administrators do not have personal employee attendance history');
        })),
      );

      expect(fakeRepo.getHistoryCallCount, equals(0));
    });

    test('7. RefreshHistoryRequested updates loaded records without re-emitting loading', () async {
      fakeRepo.employeeHistoryToReturn = sampleRecords;

      historyBloc.add(const RefreshHistoryRequested(
        employeeId: 'EMP001',
        role: AppConstants.roleEmployee,
      ));

      await expectLater(
        historyBloc.stream,
        emits(HistoryLoaded(records: sampleRecords)),
      );
    });

    test('8. History records preserve location and geofence attributes', () async {
      fakeRepo.employeeHistoryToReturn = sampleRecords;

      historyBloc.add(const LoadHistoryRequested(
        employeeId: 'EMP001',
        role: AppConstants.roleEmployee,
      ));

      await expectLater(
        historyBloc.stream,
        emitsInOrder([
          const HistoryLoading(),
          predicate<HistoryState>((state) {
            if (state is! HistoryLoaded) return false;
            final rec1 = state.records[0];
            final rec2 = state.records[1];
            return rec1.isWithinGeofence == true &&
                rec1.distanceToOfficeMeters == 18.0 &&
                rec1.checkInAccuracy == 5.0 &&
                rec2.isWithinGeofence == false &&
                rec2.distanceToOfficeMeters == 1200.0;
          }),
        ]),
      );
    });
  });

  // ============================================================================
  // TASK 2: ADMIN ATTENDANCE RECORDS TESTS
  // ============================================================================
  group('Phase 7 - Task 2: AdminRecordsBloc (Admin All Records & Filtering)', () {
    late FakePhase7AttendanceRepository fakeRepo;
    late AdminRecordsBloc adminRecordsBloc;

    final allSampleRecords = [
      const AttendanceRecordModel(
        id: 1,
        employeeId: 'EMP001',
        employeeName: 'John Doe',
        employeeEmail: 'john.doe@company.com',
        date: '2026-11-12',
        checkInTime: '09:05 AM',
        status: AppConstants.statusCheckedIn,
        checkInLatitude: 12.9716,
        checkInLongitude: 77.5946,
        isWithinGeofence: true,
        distanceToOfficeMeters: 14.0,
      ),
      const AttendanceRecordModel(
        id: 2,
        employeeId: 'EMP002',
        employeeName: 'Jane Smith',
        employeeEmail: 'jane.smith@company.com',
        date: '2026-11-12',
        checkInTime: '09:15 AM',
        status: AppConstants.statusCheckedIn,
        checkInLatitude: 12.9800,
        checkInLongitude: 77.6000,
        isWithinGeofence: false,
        distanceToOfficeMeters: 1500.0,
      ),
      const AttendanceRecordModel(
        id: 3,
        employeeId: 'EMP001',
        employeeName: 'John Doe',
        employeeEmail: 'john.doe@company.com',
        date: '2026-11-11',
        checkInTime: '08:55 AM',
        checkOutTime: '05:30 PM',
        status: AppConstants.statusCheckedOut,
      ),
    ];

    setUp(() {
      fakeRepo = FakePhase7AttendanceRepository();
      fakeRepo.allRecordsToReturn = allSampleRecords;
      adminRecordsBloc = AdminRecordsBloc(attendanceRepository: fakeRepo);
    });

    tearDown(() {
      adminRecordsBloc.close();
    });

    test('1. Initial state is AdminRecordsInitial', () {
      expect(adminRecordsBloc.state, equals(const AdminRecordsInitial()));
    });

    test('2. LoadAdminRecordsRequested loads all employee records for Admin', () async {
      adminRecordsBloc.add(const LoadAdminRecordsRequested(role: AppConstants.roleAdmin));

      await expectLater(
        adminRecordsBloc.stream,
        emitsInOrder([
          const AdminRecordsLoading(),
          AdminRecordsLoaded(records: allSampleRecords),
        ]),
      );

      expect(fakeRepo.getAllRecordsCallCount, equals(1));
    });

    test('3. Non-admin role is rejected with Unauthorized error', () async {
      adminRecordsBloc.add(const LoadAdminRecordsRequested(role: AppConstants.roleEmployee));

      await expectLater(
        adminRecordsBloc.stream,
        emits(predicate<AdminRecordsState>((state) {
          return state is AdminRecordsError &&
              state.message.contains('Unauthorized access: Only administrators can view all employee attendance records');
        })),
      );

      expect(fakeRepo.getAllRecordsCallCount, equals(0));
    });

    test('4. FilterAdminRecordsByDate queries by specific date', () async {
      adminRecordsBloc.add(const FilterAdminRecordsByDate(
        date: '2026-11-11',
        role: AppConstants.roleAdmin,
      ));

      await expectLater(
        adminRecordsBloc.stream,
        emitsInOrder([
          const AdminRecordsLoading(),
          predicate<AdminRecordsState>((state) {
            if (state is! AdminRecordsLoaded) return false;
            return state.selectedDate == '2026-11-11' &&
                state.records.length == 1 &&
                state.records.first.id == 3;
          }),
        ]),
      );

      expect(fakeRepo.lastAllRecordsDate, equals('2026-11-11'));
    });

    test('5. SearchAdminRecords filters records by employee name or ID', () async {
      adminRecordsBloc.add(const SearchAdminRecords(
        searchQuery: 'Jane',
        role: AppConstants.roleAdmin,
      ));

      await expectLater(
        adminRecordsBloc.stream,
        emitsInOrder([
          const AdminRecordsLoading(),
          predicate<AdminRecordsState>((state) {
            if (state is! AdminRecordsLoaded) return false;
            return state.searchQuery == 'Jane' &&
                state.records.length == 1 &&
                state.records.first.employeeName == 'Jane Smith';
          }),
        ]),
      );

      expect(fakeRepo.lastAllRecordsSearchQuery, equals('Jane'));
    });

    test('6. Search matching no records emits AdminRecordsEmpty with hasActiveFilter=true', () async {
      adminRecordsBloc.add(const SearchAdminRecords(
        searchQuery: 'NonExistentPerson',
        role: AppConstants.roleAdmin,
      ));

      await expectLater(
        adminRecordsBloc.stream,
        emitsInOrder([
          const AdminRecordsLoading(),
          predicate<AdminRecordsState>((state) {
            return state is AdminRecordsEmpty &&
                state.searchQuery == 'NonExistentPerson' &&
                state.hasActiveFilter == true;
          }),
        ]),
      );
    });

    test('7. ClearAdminRecordsFilter resets all filters and reloads all records', () async {
      adminRecordsBloc.add(const ClearAdminRecordsFilter(role: AppConstants.roleAdmin));

      await expectLater(
        adminRecordsBloc.stream,
        emitsInOrder([
          const AdminRecordsLoading(),
          predicate<AdminRecordsState>((state) {
            if (state is! AdminRecordsLoaded) return false;
            return state.selectedDate == null &&
                state.searchQuery == null &&
                state.records.length == 3;
          }),
        ]),
      );

      expect(fakeRepo.lastAllRecordsDate, isNull);
      expect(fakeRepo.lastAllRecordsSearchQuery, isNull);
    });

    test('8. Database failure emits [AdminRecordsLoading, AdminRecordsError]', () async {
      fakeRepo.failureToThrow = const DatabaseFailure('Failed to query SQLite');

      adminRecordsBloc.add(const LoadAdminRecordsRequested(role: AppConstants.roleAdmin));

      await expectLater(
        adminRecordsBloc.stream,
        emitsInOrder([
          const AdminRecordsLoading(),
          predicate<AdminRecordsState>((state) {
            return state is AdminRecordsError &&
                state.message.contains('Failed to query SQLite');
          }),
        ]),
      );
    });
  });
}
