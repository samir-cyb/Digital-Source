# Technical requirements
Status: LOCKED baseline. Versions verified from local SDK/package registries 2026-10-26.
## Stack
Flutter 3.47.4 stable; Dart 3.13.3; http 1.6.0; go_router 18.1.1.
ChangeNotifier state, Material widgets customized with bundled Manrope font.
Python 3.14; FastAPI 0.141.1; Uvicorn 0.53.0; Pydantic 2.13.5;
SQLAlchemy 2.1.6; psycopg 3.3.6; argon2-cffi 25.1.0;
pytest 9.1.1; httpx 0.28.1. Transitive versions recorded in backend lock.
SQLite is the active local database. PostgreSQL is a deferred option, not a current setup requirement. No external API credentials.
## Local database decision (user clarification, 2026-10-26)
Use SQLite on this computer now; no Docker/PostgreSQL requirement for signup or use.
Persist accounts/projects in work/digital_source.db. Preserve existing data.
PostgreSQL/RLS remains deferred production work, not a blocker for local development.
## Folders
lib/core: theme/API/store; lib/models: typed models; lib/ui: shared components/shell;
lib/screens: feature screens; assets/fonts and images; test;
backend/app: DB/auth/API/models/seed; backend/tests; backend/migrations; scripts.
## Commands
flutter pub get; flutter analyze; flutter test; flutter build web --release.
python -m pip install --target backend/.deps -r backend/requirements.txt
Set PYTHONPATH=backend/.deps; python -m uvicorn backend.app.main:app --host 127.0.0.1 --port 8000
Tests: python -m pytest backend/tests -q
Web development port 5173; backend 8000. Phone requires reachable API_BASE_URL.
Production Flutter app + API same HTTPS origin.
## Security constraints
Argon2id hashes; random opaque sessions stored as SHA256; expiry and revocation;
active-user lookup every request; explicit roles and resource membership.
Web HttpOnly SameSite=Strict cookie, production Secure and CSRF origin checks.
Mobile session memory-only until secure-storage increment; no localStorage tokens.
Login rate limiting; generic errors; no password/token logging; local signup with server-assigned roles.
Exact decimals, idempotency, audit history, bounded input, safe file storage.
App PostgreSQL role cannot own tables or bypass RLS; authenticated identity transaction-local.
No production launch until RLS isolation tests, MFA, private uploads, TLS and backup restore pass.
## Sources
https://docs.flutter.dev/ui/adaptive-responsive
https://fastapi.tiangolo.com/tutorial/security/oauth2-jwt/
https://www.postgresql.org/docs/current/ddl-rowsecurity.html
https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html


## Approved change — local signup (2026-10-26)
The user explicitly requested a signup page and local database. This supersedes
the earlier administrator-only provisioning assumption. /signup is reachable from login.
Name, normalized unique email, password (12–128 characters), confirmation and optional
title/department and selected position. Manager signup requires server-side code 1234.
No automatic first-owner role remains. Only manager/member/finance are accepted.
Role selection is validated on the server. Successful signup signs in; duplicates/errors
retain entered data. SQLite persistence and existing records must be preserved.

## Login visibility and build freshness fix
The login page has a persistent header Sign up action, visible while scrolling.
The local HTML entrypoint injects a content revision into bootstrap and compiled JS URLs.
A custom Flutter bootstrap avoids legacy service-worker registration. Only known Flutter
static-asset caches and this app root worker are retired; account data is untouched.


## Current approved contract — three actors (supersedes earlier roles/signup rules)
Global roles are exactly manager, member, finance; one role per account.
Signup selects position. Manager signup requires the server-side hardcoded code 1234,
as explicitly requested for this local software. Finance/member signup require no manager code.
The first-signup automatic owner rule is removed. Existing owner→manager;
lead/procurement→member; finance retained. Preserve accounts, password hashes, projects and history.
Login/signup landing: manager→/manager, member→/my-work, finance→/finance.
Manager manages all projects, people, planning and operational reviews. Finance owns the ledger
and has read-only project context. Members see assigned projects/tasks, reports and plans.
One optional temporary project lead is selected/replaced/removed by a manager from that
project's team members. Project lead remains a member globally; authority is confined to
that project. A partial unique index enforces at most one lead per project.
Role restrictions apply to APIs and routes, not only navigation. The local SQLite database stays active.
The 4-digit shared code is a user-requested local enrollment gate, not strong production identity proof.
