# Digital Source

A Flutter mobile and web workspace for an interior design company. Digital Source helps teams coordinate projects, tasks, sourcing, daily reports, tomorrow's work and financial records through a shared local workspace.

## Roles

| Position | Landing page | Main features |
| --- | --- | --- |
| Manager | `/manager` | Projects, employee selection, task reviews, planning and project lead assignments |
| Team member | `/my-work` | Assigned projects and tasks, blockers, daily reports and plan acknowledgments |
| Finance | `/finance` | Money records, approvals, reversals and read-only project context |

A manager can appoint one temporary team lead per project. The lead remains a team member globally and receives operational permissions only for that project.

## Requirements

- Flutter **3.47.4** / Dart **3.13.3**, available on PATH.
- Python **3.14**, available as `python`.
- PowerShell for the supplied Windows scripts.
- Internet access for the initial dependency download.

Flutter dependencies are locked in `pubspec.lock`; Python dependencies are locked in `backend/requirements.lock.txt`. SQLite is the active local database; Docker and PostgreSQL are not needed for local setup.

## Local setup

Run these commands from the repository root:

```powershell
# Resolve dependencies, analyze, test and build the web app.
.\scripts\Build-Web.ps1

# Install backend dependencies if missing, initialize the database and start the server.
.\scripts\Start-Local.ps1
```

Open [Digital Source](http://localhost:8000/) or [Create an account](http://localhost:8000/#/signup). Keep the server terminal open; press Ctrl+C to stop it.

Signup asks for a name, email, password, confirmation and position, with optional job title and department. Passwords must contain 12–128 characters. Manager signup requires the user-requested, server-side local enrollment code **1234**. Team member and Finance signup do not require that code. Login opens the dashboard for the account's role automatically.

On an empty database, startup creates fictional sample staff/projects and generates a random sample-account password in ignored `work/local-access.txt`. The startup script displays that local access information. Existing accounts and project history are preserved across restarts.

## Local data and security

- Persistent SQLite database: `work/digital_source.db`.
- Local credentials, backups and development artifacts: `work/` (ignored by Git).
- Backend dependency installation: `backend/.deps/` (ignored by Git).
- Passwords use Argon2id hashes; opaque session tokens are stored as digests on the server.
- Web sessions use HttpOnly cookies; native sessions currently remain in memory.
- Roles and project permissions are checked by the API as well as the UI.
- Approved financial records use linked reversals rather than destructive edits. Advances are separate from expenses.

The supplied server binds to `127.0.0.1:8000`. This is a local development setup. The shared manager code is an enrollment gate for this prototype; it is not strong production identity verification. Do not commit databases, credentials, uploads or signing keys. Git ignore rules do not protect files already tracked by Git.

## Development and verification

For Flutter hot reload, keep the backend running and use:

```powershell
flutter run -d chrome --web-port 5173
```

To run backend tests against isolated test data:

```powershell
$env:PYTHONPATH="$PWD;$PWD\backend\.deps"
$env:TEMP="$PWD\work"
$env:TMP=$env:TEMP
python -m pytest backend/tests -q
```

The web build script runs Flutter analysis and widget tests before creating `build/web`. Rebuild after source changes when using the web app served on port 8000.

Android emulators need `API_BASE_URL=http://10.0.2.2:8000/api/v1` supplied with `--dart-define`. Physical phones need a reachable private-network backend and a matching API address; the default loopback server is accessible only on this computer. Android APK verification remains pending. iOS builds require macOS/Xcode.

## Repository layout

| Path | Purpose |
| --- | --- |
| `lib/core/` | API client, state and theme |
| `lib/models/` | Typed application models |
| `lib/screens/` | Authentication and feature screens |
| `lib/ui/` | Shared components and responsive navigation |
| `backend/app/` | FastAPI routes, auth, models, migrations and reminders |
| `backend/tests/` | Backend regression tests |
| `backend/migrations/` | Versioned SQL references |
| `test/` | Flutter widget tests and fixtures |
| `assets/` | Bundled fonts and sample imagery |
| `scripts/` | Local startup and web build helpers |

## Project documentation

Read `AGENTS.md` and all six numbered specifications before making changes:

1. `01_PRD.md` — problem, users, scope and non-goals.
2. `02_AppFlow.md` — routes, actions and application states.
3. `03_UI_Spec.md` — palette, typography, components and motion.
4. `04_TRD.md` — stack, versions and security constraints.
5. `05_Schema.md` — relational schema and authorization design.
6. `06_Plan.md` — implementation progress, verification and outstanding work.

Update `06_Plan.md` after each completed implementation step. The latest approved three-actor contract supersedes historical role descriptions.

## Current limits

Production security gates, MFA, protected uploads, encrypted backup/restore verification, persistent native session storage, Bengali localization and OS push delivery remain unfinished. PostgreSQL/RLS is deferred and is not provided by the SQLite setup. Reminder delivery requires the local server to stay running. Production startup is gated while security work remains incomplete.

This app records financial activity; payment transfers, payroll and full accounting are outside the MVP scope. See `06_Plan.md` for the detailed status.

## Asset credits

Manrope uses the SIL Open Font License; see `assets/fonts/OFL.txt`. Sample interior and portrait image sources are listed in `assets/SOURCES.md`. Staff profiles are fictional, and sample photographs do not identify actual employees.

