# System Architecture & Technical Specifications

Smart QR-Based Attendance Management System  
Architecture Documentation & Engineering Design Specifications

---

## 1. Architectural Overview: Clean Architecture

The application is structured strictly according to the principles of **Clean Architecture**, enforcing separation of concerns, high maintainability, and testability across independent layers:

```
┌────────────────────────────────────────────────────────┐
│               PRESENTATION LAYER (Features)            │
│      Screens, Reusable Widgets, BLoCs, Events, States  │
└───────────────────────────▲────────────────────────────┘
                            │ Depends on (Dependency Inversion)
┌───────────────────────────┴────────────────────────────┐
│                    DOMAIN / CORE LAYER                 │
│      Contracts, Failures, Value Objects, Utilities     │
└───────────────────────────▲────────────────────────────┘
                            │ Implements
┌───────────────────────────┴────────────────────────────┐
│                    DATA LAYER (Data)                   │
│   Repositories, SQLite Local DS, Mock REST Remote DS   │
└────────────────────────────────────────────────────────┘
```

### Layer Responsibilities

1. **Core Layer (`lib/core/`):**
   - Application-wide constants (`AppConstants`, `ApiConstants`, `DatabaseConstants`).
   - SQLite Database helper with version migration orchestration (`DatabaseHelper`).
   - Centralized network client with sensitive data masking (`ApiClient`).
   - Platform location and geofence calculation service (`LocationService`).
   - Pure cryptographic token generation and JSON serialization utilities (`QrTokenService`).
   - Material 3 theme palette (`AppTheme`, `AppColors`).
   - Equatable domain failures (`Failure`, `DatabaseFailure`, `ServerFailure`, `AuthFailure`).

2. **Data Layer (`lib/data/`):**
   - **Models:** Strongly-typed immutable models with `fromMap`, `toMap`, `fromJson`, `toJson`, and `copyWith` methods (`EmployeeModel`, `AttendanceSessionModel`, `AttendanceRecordModel`).
   - **Data Sources:** 
     - *Local:* `AttendanceLocalDataSource`, `EmployeeLocalDataSource`, `QrSessionLocalDataSource` executing raw parameterized SQLite queries.
     - *Remote:* `AttendanceRemoteDataSource`, `EmployeeRemoteDataSource` executing Dio mock REST API requests.
   - **Repositories:** `AttendanceRepositoryImpl`, `EmployeeRepositoryImpl`, `QrSessionRepositoryImpl` implementing domain contracts with offline-first local persistence and graceful remote sync.

3. **Features Layer (`lib/features/`):**
   - Modularized strictly by domain feature: `auth`, `admin`, `attendance`, `qr_session`, `qr_scanner`, and `history`.
   - Each feature encapsulates its own BLoC (`<feature>_bloc.dart`), events (`<feature>_event.dart`), states (`<feature>_state.dart`), and presentation screens.

4. **Routes Layer (`lib/routes/`):**
   - Centralized `GoRouter` declarative navigation with bidirectional role-based redirect guards (`AppRouter`).

---

## 2. BLoC State Management Pattern

The application exclusively uses the **BLoC (Business Logic Component)** pattern via `flutter_bloc`. No `Provider`, `GetX`, `Riverpod`, or mutable `setState()` calls are used for application state.

### BLoC Inventory & Flow

| BLoC | Triggering Events | Key Emitted States | Purpose |
|---|---|---|---|
| **`AuthBloc`** | `AuthCheckSessionRequested`, `AuthLoginRequested`, `AuthLogoutRequested`, `AuthTogglePasswordVisibility` | `AuthInitial`, `AuthLoading`, `Authenticated`, `Unauthenticated`, `AuthFailureState` | Handles credentials check, persistent SQLite session restoration, and password toggle. |
| **`AdminBloc`** | `AdminDashboardLoadRequested`, `AdminRefreshRequested` | `AdminInitial`, `AdminLoading`, `AdminLoaded`, `AdminError` | Computes live dashboard metrics (Total, Present, Checked-In, Not Checked-In) from SQLite. |
| **`QRSessionBloc`** | `GenerateQRSessionRequested`, `LoadActiveQRSessionRequested`, `QRSessionTimerTicked`, `ExpireQRSessionRequested` | `QRSessionInitial`, `QRSessionLoading`, `QRSessionActiveState`, `QRSessionExpiredState`, `QRSessionError` | Generates 128-bit secure session tokens and drives the 5-minute (300s) countdown timer. |
| **`QRScannerBloc`** | `StartScannerRequested`, `ResetScannerRequested`, `QRCodeDetected`, `CameraPermissionDeniedEvent`, `CameraErrorOccurred` | `QRScannerInitial`, `QRScannerScanning`, `QRScannerProcessing`, `QRScannerSuccess`, `QRScannerFailure`, `QRScannerPermissionDenied` | Debounces camera frames, parses JSON QR payloads, and validates tokens against SQLite. |
| **`AttendanceBloc`** | `LoadTodayAttendanceRequested`, `AttendanceCheckInRequested`, `AttendanceResetRequested` | `AttendanceInitial`, `AttendanceLoading`, `AttendanceCapturingLocation`, `AttendanceTodayStatusLoaded`, `AttendanceCheckInSuccess`, `AttendanceDuplicateError`, `AttendanceError` | Coordinates GPS acquisition, duplicate prevention checks, and SQLite check-in transactions. |
| **`HistoryBloc`** | `LoadHistoryRequested`, `RefreshHistoryRequested` | `HistoryInitial`, `HistoryLoading`, `HistoryLoaded`, `HistoryEmpty`, `HistoryError` | Retrieves and displays personal attendance history for the authenticated employee. |
| **`AdminRecordsBloc`**| `LoadAdminRecordsRequested`, `FilterAdminRecordsByDate`, `SearchAdminRecords`, `ClearAdminRecordsFilter` | `AdminRecordsInitial`, `AdminRecordsLoading`, `AdminRecordsLoaded`, `AdminRecordsEmpty`, `AdminRecordsError` | Queries, live-searches, and date-filters attendance records for all organization members. |

---

## 3. Data Sources & Repository Pattern

```
                       ┌────────────────────────────────────┐
                       │        AttendanceRepository        │
                       └─────────────────┬──────────────────┘
                                         │
                   ┌─────────────────────┴─────────────────────┐
                   ▼                                           ▼
      ┌─────────────────────────────┐             ┌─────────────────────────────┐
      │ AttendanceLocalDataSource   │             │ AttendanceRemoteDataSource  │
      │ (Local SQLite DB - SSOT)    │             │ (Dio Mock REST Client)      │
      └─────────────────────────────┘             └─────────────────────────────┘
```

### Offline-First Strategy
1. **Single Source of Truth (SSOT):** SQLite is the authoritative storage engine. All attendance records are committed to local SQLite first.
2. **Graceful Network Fallback:** In `AttendanceRepositoryImpl.checkIn(record)`:
   - Record is inserted into SQLite inside an atomic transaction.
   - If SQLite detects an existing record for the same employee on the same date, an immediate `DuplicateAttendanceException` is raised.
   - Once SQLite commit succeeds, an asynchronous remote sync is attempted via `_remoteDataSource.submitCheckIn(savedRecord)`.
   - If the remote API fails (network timeout, 500 error), the exception is logged without rolling back or failing the local check-in. The employee receives their verified check-in receipt regardless of network availability.

---

## 4. SQLite Database Architecture

- **Database File:** `smart_attendance.db`
- **Current Version:** `2`
- **Foreign Keys:** Enabled via `PRAGMA foreign_keys = ON;` in `_onConfigure`.

### Entity-Relationship Diagram (Logical)

```
┌────────────────────────┐         ┌────────────────────────┐
│       employees        │         │  attendance_sessions   │
├────────────────────────┤         ├────────────────────────┤
│ id (PK)                │         │ id (PK)                │
│ employee_id (UNIQUE)   │◄────┐   │ session_token (UNIQUE) │◄────┐
│ name                   │     │   │ created_at             │     │
│ email (UNIQUE)         │     │   │ expires_at             │     │
│ password               │     │   │ status                 │     │
│ role                   │     │   └────────────────────────┘     │
└────────────────────────┘     │                                  │
                               │                                  │
┌────────────────────────┐     │   ┌────────────────────────┐     │
│      app_session       │     │   │   attendance_records   │     │
├────────────────────────┤     │   ├────────────────────────┤     │
│ id (PK, CHECK=1)       │     │   │ id (PK)                │     │
│ employee_id (FK)       ├─────┘   │ employee_id (FK)       ├─────┘
│ logged_in_at           │         │ session_id (FK)        ├─────┘
└────────────────────────┘         │ date                   │
                                   │ check_in_time          │
                                   │ check_out_time         │
                                   │ check_in_latitude      │
                                   │ check_in_longitude     │
                                   │ check_in_accuracy      │
                                   │ location_captured_at   │
                                   │ is_within_geofence     │
                                   │ distance_to_office_m   │
                                   │ status                 │
                                   ├────────────────────────┤
                                   │ UNIQUE(emp_id, date)   │
                                   └────────────────────────┘
```

### Version Migration Strategy (v1 → v2)
When upgrading from Database Version 1 to Version 2, `DatabaseHelper._onUpgrade` executes non-destructive `ALTER TABLE` operations without dropping or recreating user records:
```sql
ALTER TABLE attendance_records ADD COLUMN check_in_accuracy REAL;
ALTER TABLE attendance_records ADD COLUMN location_captured_at TEXT;
ALTER TABLE attendance_records ADD COLUMN is_within_geofence INTEGER;
ALTER TABLE attendance_records ADD COLUMN distance_to_office_meters REAL;
```

---

## 5. QR Code Generation & Validation Pipeline

### Cryptographic Token Entropy
Dynamic QR tokens are generated via `Random.secure()` generating 16 bytes (128 bits) of cryptographic entropy, encoded as `ATT-` prefixed hex strings (e.g., `ATT-E8A42F90B1C2`).

### QR Payload Specification
The payload is encoded as a structured JSON object:
```json
{
  "session_id": 14,
  "token": "ATT-E8A42F90B1C2",
  "created_at": "2026-11-12T09:00:00.000Z",
  "expires_at": "2026-11-12T09:05:00.000Z"
}
```

### Validation Pipeline (Two-Tier Check)
1. **Tier 1 (Fast-Fail Payload Check):**
   - Decodes JSON; validates presence of `session_id`, `token`, and `expires_at`.
   - Rejects corrupted or malformed payloads immediately.
   - Verifies that `DateTime.now()` has not passed `expires_at`.
2. **Tier 2 (Authoritative SQLite Verification):**
   - Queries `attendance_sessions` by `session_id`.
   - Verifies that the scanned `token` exactly matches `session_token` in the database.
   - Checks that database status is `'active'`.
   - Verifies that SQLite expiration timestamp has not elapsed.
   - Rejects tampered, unknown, or expired session tokens with clear user messages.

---

## 6. GPS Geofencing & Location Validation

### Office Geofence Configuration (`AppConstants`)
- **Office Latitude:** `12.9716`
- **Office Longitude:** `77.5946`
- **Geofence Radius:** `150.0 meters`
- **Position Timeout:** `12 seconds`

### Haversine Distance Calculation
Distance from the office is computed using the Great-Circle distance via `Geolocator.distanceBetween()`:
$$\text{distance} \le 150.0\text{ m} \implies \text{isWithinGeofence} = \text{true}$$

### Non-Blocking Graceful Location Capture
Location capture is designed to be resilient:
- If location permissions are denied, GPS is disabled, or acquisition times out, `LocationService` returns a typed `LocationResult(failure: ...)` instead of throwing.
- Attendance check-in proceeds successfully to preserve employee punctuality records.
- The `AttendanceStatusScreen` displays a warning indicator explaining that location was unavailable while confirming check-in completion.

---

## 7. Dio Mock REST API Integration

`ApiClient` integrates `MockApiInterceptor` to simulate backend REST services without requiring a live remote server:

```
[ApiClient Request] ──► [MockApiInterceptor] ──► [Matches Route?]
                               │
            ┌──────────────────┴──────────────────┐
            ▼ Yes                                 ▼ No
    [Return Mock Response]                 [Forward to Network]
    - /employees/:id                       - Live Remote Host
    - /admin/employees
    - /attendance/history
    - /attendance/check-in
    - /admin/records
```

### Sensitive Data Masking in Logs
The development logging interceptor automatically sanitizes sensitive fields:
- `Authorization: Bearer <token>` $\to$ `Authorization: Bearer [PROTECTED]`
- Request body `password: <secret>` $\to$ `password: '******'`

---

## 8. Authentication & Role-Based Navigation

### GoRouter Declarative Routing Guards (`AppRouter`)
Navigation access is guarded bidirectionally on every route transition:

```
                    ┌───────────────────────────┐
                    │ Current Route Requested   │
                    └─────────────┬─────────────┘
                                  │
                 Is User Authenticated in AuthBloc?
                     /                         \
                   No                          Yes
                  /                             \
        Redirect to /login             Check User Role:
                                       /              \
                                   Admin             Employee
                                     │                  │
                         Starts with /employee?   Starts with /admin?
                                  │                     │
                             Redirect to            Redirect to
                                /admin               /employee
```

---

## 9. Actual Project Directory Tree

```text
flutter_application_1/
├── android/
│   └── app/src/main/AndroidManifest.xml       # Camera & GPS permission declarations
├── ios/
│   └── Runner/Info.plist                      # Camera & Location usage descriptions
├── lib/
│   ├── main.dart                              # App entrypoint & MultiBlocProvider setup
│   ├── core/
│   │   ├── constants/
│   │   │   ├── api_constants.dart             # API base URL & endpoints
│   │   │   ├── app_constants.dart             # App metadata & geofence coordinates
│   │   │   └── database_constants.dart        # SQLite table, column, and DDL constants
│   │   ├── database/
│   │   │   └── database_helper.dart           # SQLite singleton & v1→v2 migration logic
│   │   ├── errors/
│   │   │   ├── exceptions.dart                # Database & domain exceptions
│   │   │   └── failures.dart                  # Equatable presentation failure models
│   │   ├── network/
│   │   │   ├── api_client.dart                # Dio HTTP client with log masking
│   │   │   ├── mock_api_interceptor.dart      # Local Mock REST API interceptor
│   │   │   └── network_exceptions.dart        # DioException translator
│   │   ├── services/
│   │   │   └── location_service.dart          # GPS positioning & geofence validator
│   │   ├── theme/
│   │   │   ├── app_colors.dart                # Brand color definitions
│   │   │   └── app_theme.dart                 # Material 3 light/dark theme data
│   │   └── utils/
│   │       ├── app_bloc_observer.dart         # Global BLoC transition logger
│   │       ├── date_time_utils.dart           # Date, time & countdown string utils
│   │       ├── qr_token_service.dart          # Cryptographic token generator
│   │       └── validators.dart                # Form validation helpers
│   ├── data/
│   │   ├── datasources/
│   │   │   ├── attendance_local_data_source.dart
│   │   │   ├── attendance_remote_data_source.dart
│   │   │   ├── employee_local_data_source.dart
│   │   │   ├── employee_remote_data_source.dart
│   │   │   └── qr_session_local_data_source.dart
│   │   ├── models/
│   │   │   ├── attendance_record_model.dart
│   │   │   ├── attendance_session_model.dart
│   │   │   └── employee_model.dart
│   │   └── repositories/
│   │       ├── attendance_repository.dart
│   │       ├── employee_repository.dart
│   │       └── qr_session_repository.dart
│   ├── features/
│   │   ├── admin/
│   │   │   ├── bloc/                          # AdminBloc & AdminRecordsBloc
│   │   │   └── screens/                       # AdminDashboardScreen & AdminRecordsScreen
│   │   ├── attendance/
│   │   │   ├── bloc/                          # AttendanceBloc
│   │   │   └── screens/                       # EmployeeDashboardScreen & StatusScreen
│   │   ├── auth/
│   │   │   ├── bloc/                          # AuthBloc
│   │   │   └── screens/                       # SplashScreen & LoginScreen
│   │   ├── history/
│   │   │   ├── bloc/                          # HistoryBloc
│   │   │   └── screens/                       # HistoryScreen
│   │   ├── qr_scanner/
│   │   │   ├── bloc/                          # QRScannerBloc
│   │   │   └── screens/                       # QrScannerScreen
│   │   └── qr_session/
│   │       ├── bloc/                          # QRSessionBloc
│   │       └── screens/                       # QrSessionScreen
│   ├── routes/
│   │   ├── app_router.dart                    # GoRouter with role-based guards
│   │   ├── app_routes.dart                    # Route path string constants
│   │   └── go_router_refresh_stream.dart      # Stream-to-Listenable bridge
│   └── shared/                                # Reusable UI components
│       ├── app_button.dart
│       ├── app_card.dart
│       ├── app_text_field.dart
│       ├── confirmation_dialog.dart
│       ├── error_view.dart
│       ├── loading_indicator.dart
│       └── status_badge.dart
├── test/                                      # 90 Automated Tests (100% Pass)
│   ├── admin_and_qr_bloc_test.dart
│   ├── auth_bloc_test.dart
│   ├── dio_mock_api_test.dart
│   ├── history_and_admin_records_bloc_test.dart
│   ├── phase_9_comprehensive_audit_test.dart
│   ├── qr_scanner_and_attendance_bloc_test.dart
│   └── widget_test.dart
└── pubspec.yaml                               # Package dependencies & assets
```
