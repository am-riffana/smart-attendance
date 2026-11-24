# Smart QR Attendance — Technical Assessment Demo Script

A step-by-step walkthrough script for video recording or live technical assessment presentation.

---

## Recording Guidelines
- **Device Setup:** Run on an Android emulator or iOS simulator (or dual devices/windows side-by-side: Admin on desktop/window 1, Employee on mobile window 2).
- **Target Video Duration:** 4 to 6 minutes.
- **Audio:** Clear commentary highlighting the Clean Architecture, BLoC state transitions, SQLite persistence, and security controls.

---

## Step-by-Step Walkthrough

### Step 1: Application Launch & Login Screen
- **On Screen:** Launch the app. The splash screen briefly displays the logo while `AuthBloc` checks for an active SQLite session, then smoothly redirects to `/login`.
- **Action:** Show the Material 3 login form with input validation and password visibility toggle.
- **Narration:**  
  > *"Welcome to the Smart QR-Based Attendance Management application. The app opens to a clean, responsive authentication screen driven by BLoC. Notice the password visibility toggle updating without calling `setState`. Credentials are authenticated directly against local SQLite tables seeded with secure test accounts."*

---

### Step 2: Employee Authentication
- **Action:** Enter `EMP001` (or `john.doe@company.com`) and password `employee123`. Click **Sign In**.
- **On Screen:** Shows loading state on the button, then redirects to `/employee` (Employee Dashboard).
- **Narration:**  
  > *"First, let's log in as Employee John Doe (EMP001). The login request is processed through `AuthBloc`, and the active session is persisted to SQLite so the employee stays signed in on subsequent app launches. The declarative router evaluates role-based guards and routes the employee strictly to their personal dashboard."*

---

### Step 3: Employee Dashboard & Initial Attendance State
- **On Screen:** Show employee dashboard with user greeting, today's status card showing `'absent'`, and action buttons.
- **Narration:**  
  > *"On the Employee Dashboard, today's status is read in real time from SQLite via `AttendanceBloc`. Because John has not checked in yet today, the status is marked as 'Absent' with placeholder timestamps for check-in and check-out. Notice the 'Scan QR' button is enabled."*

---

### Step 4: Admin Authentication & Dashboard Overview
- **Action:** Click Sign Out, confirm dialog. Log in with `ADM001` (or `admin@company.com`) / `admin123`.
- **On Screen:** Admin Dashboard (`/admin`) displaying live SQLite counters:
  - Total Employees: `4`
  - Present: `0`
  - Checked-In: `0`
  - Not Checked-In: `4`
  - Registered employee list
- **Narration:**  
  > *"Now let's switch to the Administrator portal. As an Admin, the router navigates us to `/admin`. `AdminBloc` aggregates today's attendance metrics directly from the local database: 4 registered employees, 0 checked in, and 4 not checked in. Administrators are strictly barred from recording employee attendance."*

---

### Step 5: Dynamic 5-Minute QR Code Generation
- **Action:** Click **Generate QR** button.
- **On Screen:** Navigates to `/admin/qr-session`. Displays a large dynamic QR code, unique session token (`ATT-XXXXXXXXXXXX`), circular progress bar, and a live countdown timer ticking down from `05:00`.
- **Narration:**  
  > *"Here the administrator generates a dynamic QR session. `QRSessionBloc` creates a cryptographically secure 128-bit random token stored in SQLite with an active status. A live countdown timer ticks down second by second. After exactly 5 minutes, the session expires automatically, preventing replay attacks or static code sharing."*

---

### Step 6: Employee QR Code Scanning
- **Action:** Switch to the Employee account (or open scanner). Click **Scan Attendance QR**.
- **On Screen:** Camera scanner opens with dark frosted overlay, animated scanning guide, torch toggle, and camera switcher.
- **Narration:**  
  > *"Switching back to Employee John Doe, we open the camera scanner. `QRScannerBloc` debounces incoming camera frames to prevent duplicate triggers. The custom painted viewfinder highlights the scan target. When the camera aligns with the QR code, the JSON payload is read and validated against the SQLite database."*

---

### Step 7: GPS Capture, Geofencing & Attendance Receipt
- **Action:** Scan the generated QR code.
- **On Screen:** Loading overlay briefly shows *"Capturing GPS location..."* followed by navigation to `/attendance/status` displaying:
  - Green checkmark: "Verification Success"
  - Captured timestamp
  - Employee ID: `EMP001`
  - Location Details card:
    - Office Geofence: **Within Office** (with green badge)
    - Distance to Office: `18 m`
    - GPS Accuracy: `±5 m`
- **Narration:**  
  > *"Check-in verified! `AttendanceBloc` coordinated with `LocationService` to acquire high-accuracy GPS coordinates and compute the Great-Circle distance to the Bangalore office coordinates. Because John is within the 150-meter radius, the record is tagged as 'Within Office Geofence' and atomically committed to SQLite."*

---

### Step 8: Multi-Level Duplicate Check-In Prevention
- **Action:** Return to scanner or dashboard, attempt to scan the QR code again.
- **On Screen:** Immediate warning modal: *"Already Checked In: You have already checked in today. Duplicate attendance check-ins are not permitted."*
- **Narration:**  
  > *"Now let's test security against duplicate attendance. If John tries to scan the QR code again today, `AttendanceBloc` immediately blocks the request at the business logic layer. Even if bypassed, the SQLite database enforces a table constraint of `UNIQUE(employee_id, date)` to guarantee complete data integrity."*

---

### Step 9: Employee Personal Attendance History
- **Action:** Click **Attendance History** on the Employee Dashboard.
- **On Screen:** Chronological list of daily attendance cards showing formatted date (`Today`, `Wed, Nov 11`), check-in time (`09:05 AM`), geofence verification badge, GPS coordinates, and accuracy.
- **Narration:**  
  > *"In the Attendance History screen, `HistoryBloc` loads all historical check-in records for John Doe. Each entry displays check-in time, location coordinates, accuracy radius, and whether the check-in occurred within the office geofence. Strict employee data isolation ensures employees can only view their own records."*

---

### Step 10: Admin Records Portal & Dio Mock API
- **Action:** Log back in as Admin. Open **All Records** (`/admin/records`).
- **On Screen:**
  - Shows updated dashboard metrics: `1 Present`, `1 Checked-In`, `3 Not Checked-In`.
  - In All Records: shows John Doe's check-in with name, ID, time, and geofence tag.
  - Type `"Jane"` in search bar $\to$ instant filter to Jane Smith.
  - Clear search, pick date $\to$ filters by chosen calendar date.
- **Narration:**  
  > *"Returning to the Admin Dashboard, the metrics have automatically updated in real time to reflect 1 checked-in employee. In the Admin Records portal, `AdminRecordsBloc` provides live text search across employee names and IDs, plus date-picker filtering. Behind the scenes, `ApiClient` utilizes a local Dio Mock REST API to simulate remote check-in synchronization, complete with 401, 500, and timeout fault tolerance without compromising local SQLite persistence."*

---

## Presentation Summary
- **Architecture:** Clean Architecture + 100% BLoC state management
- **Security:** 128-bit secure tokens, 5-minute expiry, bidirectional RBAC route guards
- **Integrity:** Multi-level duplicate check-in prevention (BLoC + SQLite `UNIQUE`)
- **Verification:** 90 passing automated tests, 0 analyzer issues, offline-first reliability
