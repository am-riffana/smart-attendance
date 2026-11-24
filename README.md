# Smart QR-Based Attendance Management System

A production-grade, offline-first Flutter application implementing secure, dynamic QR code attendance management with GPS geofencing, multi-level duplicate check-in prevention, role-based access control, and mock REST API integration.

Built strictly using **Clean Architecture** and **BLoC (flutter_bloc)** state management.

---

## Table of Contents

1. [Overview & Problem Statement](#overview--problem-statement)
2. [Key Features](#key-features)
3. [Technology Stack & Packages](#technology-stack--packages)
4. [User Roles & Screens](#user-roles--screens)
5. [System Architecture](#system-architecture)
6. [SQLite Database & Schema](#sqlite-database--schema)
7. [Mock REST API Explanation](#mock-rest-api-explanation)
8. [Hardware Permissions (Camera & GPS)](#hardware-permissions-camera--gps)
9. [Installation & Setup](#installation--setup)
10. [Running the Application](#running-the-application)
11. [Testing Suite & Verification Results](#testing-suite--verification-results)
12. [Demo Video Walkthrough Plan](#demo-video-walkthrough-plan)
13. [Hardware Limitations & Physical Device Notes](#hardware-limitations--physical-device-notes)

---

## 1. Overview & Problem Statement

### Problem Statement
Traditional corporate attendance systems (biometrics, RFID cards, manual registers, or static printed QR codes) suffer from severe security and operational vulnerabilities:
- **Buddy Punching & Proxy Check-ins:** Static QR codes can be photographed, forwarded via messaging apps, and scanned remotely.
- **Physical Clutter & Hardware Costs:** Dedicated biometric scanners require expensive proprietary hardware and network cabling.
- **Lack of Geolocation Verification:** Employees can scan attendance codes offsite without being physically present at the workplace.
- **Single Point of Failure (Network Dependency):** Cloud-only systems fail completely when internet access or server availability is disrupted.

### The Solution
The **Smart QR-Based Attendance App** solves these challenges through:
1. **Time-Expiring Dynamic QR Sessions:** Admins generate cryptographically secure (128-bit entropy) QR codes that automatically expire after **5 minutes** with a live countdown timer.
2. **Authoritative SQLite Validation:** Expired or replayed QR tokens are rejected by the local SQLite database.
3. **GPS Geofence Validation:** Captures the employee's GPS coordinates upon scanning and verifies proximity against the configured office location (150m radius).
4. **Multi-Level Duplicate Prevention:** Check-ins on the same date are rejected at both the BLoC business logic layer and the SQLite database layer via `UNIQUE(employee_id, date)` constraints.
5. **Offline-First Architecture:** SQLite serves as the authoritative local Single Source of Truth (SSOT), synchronizing gracefully with a Dio Mock REST API without blocking attendance marking during network dropouts.

---

## 2. Key Features

- **Role-Based Access Control (RBAC):** Distinct dashboards, routes, and security permissions for **Admin** and **Employee** roles.
- **Dynamic 5-Minute QR Generation:** Admins generate time-limited QR sessions with real-time seconds countdown, circular progress bar, and session status tracking.
- **Real-Time QR Scanner:** Integrated camera scanner with custom frosted overlay, flashlight/torch toggle, camera flip, and debouncing.
- **GPS Location & Geofence Verification:** Automatically acquires high-accuracy GPS coordinates, accuracy radius (meters), device timestamp, and computes distance to office using the Haversine distance formula.
- **Personal Attendance History:** Employees view a complete history of their check-in/out records, location details, geofence badges, and timestamps.
- **Admin All-Records Portal:** Admins query, live-search (by employee name or ID), and filter records by date with active filter chips.
- **Dio Mock REST API:** Offline-first synchronization with simulated endpoints for employee profiles, check-in submission, attendance history, and admin records, including simulated 401 Unauthorized, 500 Server Error, and timeout fallbacks.

---

## 3. Technology Stack & Packages

| Layer / Capability | Package / Technology | Version | Purpose |
|---|---|---|---|
| **Framework** | Flutter | 3.44.4 (stable) | Cross-platform UI toolkit |
| **Language** | Dart | 3.12.2 | Strongly typed, null-safe language |
| **State Management** | `flutter_bloc` | ^9.1.1 | Predictable event-driven state management |
| **State Equality** | `equatable` | ^2.0.7 | Value-based equality without boilerplate |
| **Local Database** | `sqflite` | ^2.4.2 | SQLite database engine with migrations |
| **Path Utilities** | `path`, `path_provider` | ^1.9.1 / ^2.1.5 | Database file location resolution |
| **REST API Client** | `dio` | ^5.8.0+1 | HTTP client with interceptors and mock adapter |
| **Declarative Routing** | `go_router` | ^14.8.1 | Route guards and role-based redirection |
| **QR Code Generator** | `qr_flutter` | ^4.1.0 | Renders dynamic QR code images |
| **QR Code Scanner** | `mobile_scanner` | ^6.0.7 | Camera barcode scanning with MLKit engine |
| **GPS Geolocation** | `geolocator` | ^13.0.4 | Hardware GPS positioning & geofence math |
| **Permissions** | `permission_handler` | ^11.4.0 | Runtime permission checks |
| **Formatting** | `intl` | ^0.20.2 | Date/time and countdown string utilities |

> **Note on State Management:** No third-party state managers (`Provider`, `GetX`, `Riverpod`) or `setState` calls for application state are used. All business logic is driven strictly by BLoC.

---

## 4. User Roles & Screens

### Pre-Seeded Assessment Accounts (SQLite)
| Role | Identifier (ID or Email) | Password | Default Landing Screen |
|---|---|---|---|
| **System Admin** | `ADM001` or `admin@company.com` | `admin123` | `/admin` (Admin Dashboard) |
| **Employee 1** | `EMP001` or `john.doe@company.com` | `employee123` | `/employee` (Employee Dashboard) |
| **Employee 2** | `EMP002` or `jane.smith@company.com` | `employee123` | `/employee` (Employee Dashboard) |
| **Employee 3** | `EMP003` or `robert.b@company.com` | `employee123` | `/employee` (Employee Dashboard) |
| **Employee 4** | `EMP004` or `emily.d@company.com` | `employee123` | `/employee` (Employee Dashboard) |

### Application Screens
1. **Splash Screen (`/`):** Restores active session from SQLite `app_session` table and redirects to role dashboard.
2. **Login Screen (`/login`):** Validates credentials against SQLite, supports ID/Email authentication, password visibility toggle, and error handling.
3. **Admin Dashboard (`/admin`):** Real-time SQLite statistics (Total Registered, Present, Checked-In, Not Checked-In), quick actions, and employee list.
4. **QR Session Screen (`/admin/qr-session`):** Generates 5-minute dynamic QR codes with live countdown and regenerate controls.
5. **Employee Dashboard (`/employee`):** Live daily attendance card, "Scan QR" button, "Attendance History" button, and user profile header.
6. **QR Scanner Screen (`/employee/qr-scanner`):** Camera viewport with dark frosted cutout, flashlight toggle, camera switcher, and validation overlay.
7. **Attendance Status Screen (`/attendance/status`):** Post-scan verification receipt displaying status, timestamp, GPS accuracy, and geofence verification badge.
8. **Employee History Screen (`/history`):** Complete chronological history of the logged-in employee's daily check-in/out records with geofence badges.
9. **Admin All Records Screen (`/admin/records`):** Enterprise records table with real-time name/ID search and date picker filtering.

---

## 5. System Architecture

The project follows standard **Clean Architecture** principles divided into 4 clear layers:

```
lib/
├── core/                  # Core cross-cutting concerns
│   ├── constants/         # App constants, API endpoints, geofence coordinates
│   ├── database/          # SQLite DatabaseHelper (singleton) & migration DDLs
│   ├── errors/            # Exceptions & domain Failures (Equatable)
│   ├── network/           # Dio ApiClient & MockApiInterceptor
│   ├── services/          # LocationService (GPS & geofence validation)
│   ├── theme/             # Material 3 light/dark palette & typography
│   └── utils/             # QR token entropy generator & DateTimeUtils
├── data/                  # Data layer
│   ├── datasources/       # Local SQLite & Remote REST API datasources
│   ├── models/            # Serializable models (Employee, Session, Record)
│   └── repositories/      # Repository implementations with offline fallback
├── features/              # Feature modules (Clean presentation layer)
│   ├── admin/             # AdminBloc, AdminRecordsBloc & dashboard screens
│   ├── attendance/        # AttendanceBloc, employee dashboard & status screens
│   ├── auth/              # AuthBloc, login screen & splash screen
│   ├── history/           # HistoryBloc & employee attendance history screen
│   ├── qr_scanner/        # QRScannerBloc & camera scanning screen
│   └── qr_session/        # QRSessionBloc & dynamic QR generation screen
├── routes/                # GoRouter configuration & role-based redirect guards
└── shared/                # Reusable UI widgets (AppButton, AppCard, StatusBadge)
```

### BLoC State Management Separation
- **`AuthBloc`:** Handles login, logout, password visibility toggle, and persistent session restoration.
- **`AdminBloc`:** Aggregates dashboard metrics (Total, Present, Checked-In, Not Checked-In) from SQLite.
- **`QRSessionBloc`:** Manages 128-bit secure token generation and the 5-minute live timer.
- **`QRScannerBloc`:** Handles camera lifecycle, debouncing duplicate frames, and payload validation.
- **`AttendanceBloc`:** Manages check-in execution, GPS acquisition, and duplicate prevention.
- **`HistoryBloc`:** Manages personal attendance records for the authenticated employee.
- **`AdminRecordsBloc`:** Manages filtering and querying across all employee records.

---

## 6. SQLite Database & Schema

Database Name: `smart_attendance.db`  
Current Version: **2** (automatic migration from Version 1 via non-destructive `ALTER TABLE` statements)

### Database Tables
1. **`employees`:** Registered organization members and admin credentials.
   - Columns: `id` (PK), `employee_id` (UNIQUE), `name`, `email` (UNIQUE), `password`, `role`.
2. **`attendance_sessions`:** Dynamic QR sessions generated by admins.
   - Columns: `id` (PK), `session_token` (UNIQUE), `created_at`, `expires_at`, `status`.
3. **`attendance_records`:** Daily check-in records and location logs.
   - Columns: `id` (PK), `employee_id` (FK), `date`, `check_in_time`, `check_out_time`, `check_in_latitude`, `check_in_longitude`, `check_out_latitude`, `check_out_longitude`, `check_in_accuracy`, `location_captured_at`, `is_within_geofence`, `distance_to_office_meters`, `status`, `session_id` (FK).
   - Constraint: `UNIQUE(employee_id, date)` ensures an employee can check in at most once per calendar day.
4. **`app_session`:** Persisted single-row active user session for automatic app startup login.

---

## 7. Mock REST API Explanation

> **Important Disclosure:** This project integrates a **Local Mock REST API** via Dio's `MockApiInterceptor`. It does **not** rely on a remote cloud backend. All network calls are intercepted locally and return realistic JSON domain payloads.

### Mock Endpoints
- `GET /v1/employees/:id`: Returns employee profile by ID.
- `GET /v1/admin/employees`: Returns all registered organization employees.
- `GET /v1/attendance/history?employee_id=EMP001`: Returns employee's personal check-in history.
- `POST /v1/attendance/check-in`: Accepts check-in payload with coordinates and returns HTTP 201 Created.
- `GET /v1/admin/records?date=&search=`: Returns all attendance records with date and employee search filters.

### Simulated Failure Scenarios
- **401 Unauthorized:** Request with `X-Simulate-Unauthorized: true` or `Authorization: Bearer invalid_token`.
- **500 Server Error:** Request with `X-Simulate-Server-Error: true`.
- **Timeout (408):** Request with `X-Simulate-Timeout: true`.

---

## 8. Hardware Permissions (Camera & GPS)

### Android Configuration (`android/app/src/main/AndroidManifest.xml`)
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

### iOS Configuration (`ios/Runner/Info.plist`)
```xml
<key>NSCameraUsageDescription</key>
<string>Camera access is required to scan attendance QR codes.</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>Location access is required to verify office geofence proximity during attendance check-in.</string>
```

---

## 9. Installation & Setup

### Prerequisites
- **Flutter SDK:** 3.44.4 or higher (`flutter --version`)
- **Dart SDK:** 3.12.2 or higher
- **Android Studio / Xcode:** For mobile simulator or device debugging

### Setup Commands
```bash
# 1. Navigate to the project directory
cd flutter_application_1

# 2. Fetch dependencies
flutter pub get

# 3. Verify static analysis (target: 0 errors, 0 warnings)
flutter analyze

# 4. Run automated test suite
flutter test
```

---

## 10. Running the Application

### Chrome / Web (For UI & State Flow Verification)
```bash
flutter run -d chrome
```

### Android Emulator / Device
```bash
flutter run -d android
```

### iOS Simulator / Device
```bash
flutter run -d ios
```

---

## 11. Testing Suite & Verification Results

### Summary of Latest Test Run (Phase 9 Audit)
- **Static Analysis (`flutter analyze`):** `No issues found! (0 errors, 0 warnings)`
- **Automated Tests (`flutter test`):** **90/90 tests passed (100% pass rate)**

```text
Test Suites:
✓ test/auth_bloc_test.dart (11 tests)
  - Login validation (valid admin, valid employee, invalid ID, invalid email, wrong password, empty inputs)
  - Password visibility toggle without setState
  - Session restoration and logout

✓ test/admin_and_qr_bloc_test.dart (3 tests)
  - Dashboard metrics calculation excluding admin from employee counts
  - 5-minute expiry calculation
  - Cryptographically secure 128-bit random token uniqueness

✓ test/qr_scanner_and_attendance_bloc_test.dart (28 tests)
  - Camera permissions and error handling
  - Corrupted, empty, and malformed QR payload rejection
  - Expired session rejection (payload and SQLite)
  - Multi-level duplicate check-in prevention (BLoC + DB constraint)
  - Admin check-in rejection guard
  - GPS geofence validation (inside, outside, permission denied, GPS disabled, timeout)

✓ test/history_and_admin_records_bloc_test.dart (16 tests)
  - Employee history loading, empty state, and failure handling
  - Employee isolation (only requested employeeId returned)
  - Admin access rejection on employee history
  - Admin records querying, date filter, live search, and filter clearing
  - Non-admin access rejection on admin records

✓ test/dio_mock_api_test.dart (19 tests)
  - Dio configuration, timeouts, and headers
  - GET employee profile & all employees
  - POST check-in data and validation
  - GET admin records with date and search filters
  - 401 Unauthorized, 500 Server Error, and Timeout simulations
  - Offline-first SQLite persistence when remote API fails

✓ test/phase_9_comprehensive_audit_test.dart (13 tests)
  - Bidirectional role-based route guards
  - Tampered QR payload rejection
  - Multi-level duplicate check-in audit
  - GPS geofence coordinate persistence
  - Dio mock endpoints verification
```

---

## 12. Demo Video Walkthrough Plan

A 10-step recommended recording plan for technical assessment presentation:

| Step | Action | Narration Focus |
|---|---|---|
| **1** | Open app, show login screen | Highlight clean Material 3 UI, input validation, and password visibility toggle. |
| **2** | Log in as Employee (`EMP001` / `employee123`) | Show persistent session creation, role-based landing on Employee Dashboard. |
| **3** | View Today's Status | Explain live attendance status driven by `AttendanceBloc` (`absent` before scan). |
| **4** | Log out, log in as Admin (`ADM001` / `admin123`) | Show admin dashboard: SQLite KPI counters (Total, Present, Checked-in, Not Checked-in). |
| **5** | Generate QR Session | Click "Generate QR". Show 128-bit secure token, dynamic QR image, and live 5-minute countdown. |
| **6** | Switch to Employee & Scan QR | Open camera scanner. Point to generated QR. Show debouncing and animated cutout overlay. |
| **7** | Attendance Receipt (`AttendanceStatusScreen`) | Verify captured check-in timestamp, GPS coordinates, accuracy, and "Within Office Geofence" badge. |
| **8** | Duplicate Check-In Prevention | Attempt to scan QR a second time. Show immediate rejection: "Already Checked In Today". |
| **9** | Employee Attendance History | Open "Attendance History". Show chronological cards, check-in times, and geofence status. |
| **10** | Admin All Records & Live Filter | Switch to Admin, open "All Records". Demonstrate live name search ("Jane") and date picker filter. |

---

## 13. Hardware Limitations & Physical Device Notes

While all state transitions and business logic are 100% verified via automated tests, physical hardware is required for the following real-world features:
1. **Live Camera Sensor:** Mobile camera scanning (`mobile_scanner`) requires physical hardware or an emulator with a virtual scene camera. Headless automated tests feed barcode strings via `QRCodeDetected`.
2. **GPS Radio & Satellite Lock:** True GPS satellite acquisition (`geolocator`) requires a physical Android/iOS device with location services enabled. Headless tests use `FakeLocationService`.
3. **Camera Torch:** Hardware flashlight toggle requires a physical phone flash LED.
