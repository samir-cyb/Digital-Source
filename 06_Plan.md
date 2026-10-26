# Implementation checklist and verification
Read the six specs and AGENTS.md before work. Update after each completed step.
Checked items describe verified local-development behavior, not production readiness.

## Foundation
- [x] F01 Inspect starter, instructions and SDK: Flutter 3.47.4, Dart 3.13.3, Python 3.14.
- [x] F02 Write the six approved specification baselines and root AGENTS contract.
- [x] F03 Install exact dependencies, lock Python/Flutter resolution, initialize Git and safe ignores.

## Phase 1 — DB & Auth
- [x] A01a Persistent local-only SQLite development database, fictional staff/projects, random bootstrap password.
- [x] A02a Relational models, foreign keys/checks/indexes, empty-database-only seed.
- [x] A02b Generate versioned PostgreSQL schema in backend/migrations/001_initial.sql.
- [ ] A01b Start PostgreSQL and apply/verify migration against it. Docker daemon unavailable here.
- [x] A03 Argon2id passwords, hashed opaque sessions, cookie/memory auth, expiry/revoke, rate limit and origin guard.
- [x] A04a API role and project isolation verified in local backend tests.
- [ ] A04b PostgreSQL least-privilege role, RLS policies and real database isolation tests.

## Phase 2 — Core API
- [x] B01 Employee directory, project creation and explicit photo-card membership selection.
- [x] B02a Start/review/approve/reject/block/resume tasks with reason validation and optimistic version checks.
- [ ] B02b Dependency editing/cycle detection API, audited cancellation/reopen, project phase editor.
- [x] B03 Daily report upsert with audit; owner report history; inbox read state and task-change notifications.
- [ ] B03b Project-scoped manager report view (reports currently personal/owner only to avoid leaking cross-project details).
- [x] B04 Material requests, supplier links and atomic partial delivery with over-receipt rejection.
- [ ] B04b Supplier editing, rejected/damaged receipts and evidence attachments.
- [x] B05 Pending decimal money entries, idempotency, separate-person approval and linked reversal.
- [ ] B05b Advance allocation/settlement view, custom entry dates and receipt attachments.
- [x] B06 Published date/project plans, current revision acknowledgments and stale revision rejection.
- [x] B07 Durable deduplicated inbox reminders for daily reports, 09:00 meetings and unacknowledged tomorrow plans; one running backend required.
- [ ] B08 OS background push provider, configurable reminder settings/leave calendar.

## Phase 3 — UI Integration
- [x] C01 Teal design system, bundled Manrope/portraits/interior photos, responsive shell, branded web/Android icons.
- [x] C02 Login, session restore/expiry, loading/error/retry, local-development labeling.
- [x] C03 Today dashboard, filters, global search, task action dialogs and project detail.
- [x] C04 New project form with searchable identity cards, retained selection and chips; real API save.
- [x] C05 People directory/search/department filter, profile, task workload and project memberships.
- [x] C06 Connected sourcing, money, reports, inbox, planning and settings screens.
- [x] C07a Light/dark appearance, reduced-motion card selection, 200% mobile text test.
- [x] C08 Workspace refresh every 30 seconds while open; mutations refresh immediately.
- [ ] C07b Bengali localization, full keyboard/screen-reader audit, all-route text-scale checks.
- [ ] C09 Account provisioning, real profile photo management, secure native session storage.

## Phase 4 — Edge cases and release verification
- [x] D01 Twelve isolated local backend tests pass: auth/logout, permissions/project isolation,
  task transition/concurrency, duplicate money/self-approval, partial delivery bounds,
  plan revision acknowledgment, report upsert, approval/reversal, origin guard, reminder deduplication.
- [x] D02 Five Flutter widget tests pass: desktop navigation, mobile More/Money,
  card selection retained during search and saved IDs, dark mode + 200% text size, session restore preserving deep links.
- [x] D03 Real Chrome browser inspection/screenshots: login, Today, People, project selector,
  mobile layouts and planning route; final evidence in work/browser-verification.json.
- [x] D04a flutter analyze: no issues. Release web build successful; served by FastAPI on localhost:8000.
- [ ] D04b Android APK: build attempted; Flutter process crashed with Windows exit -1073741816 during SDK artifact acquisition; no APK verified.
- [ ] D04c iOS build requires macOS/Xcode; no iOS device verification in this environment.
- [ ] D05 Production gates: PostgreSQL RLS, MFA, private uploads, TLS, encrypted backup/restore,
  persistent native sessions, stricter audit retention and multiworker concurrency validation.

## Verification evidence (2026-10-26)
- python -m pytest backend/tests -q: 12 passed; one upstream Starlette/httpx deprecation warning.
- flutter analyze --no-pub: No issues found.
- flutter test --no-pub: 5 passed.
- flutter build web --release --no-pub --no-wasm-dry-run: built build/web.
- Browser console/runtime check: no captured runtime exception events.
- No real staff/client information used. No public deployment or external notification sending.

## Recorded decisions
- Docker daemon unavailable: SQLite is explicitly temporary, local-only development storage.
  PostgreSQL is still the target; SQLite tests do not prove RLS.
- Web and backend share localhost:8000 for preview. FastAPI serves the release web assets.
- JWT not needed for opaque server-side sessions; browser tokens are never saved in localStorage.
- Native session stays in memory until OS-protected storage is implemented.
- Production startup fails closed while production security gates remain incomplete.

Regression fix: preserve the requested internal route through loading/login/session restore;
covered by a failing-then-passing deep-link widget test and final browser reload check.

Repository note: source files are saved in the selected project. Git staging was blocked
by sandbox protection on .git/index.lock; no commit or push was made.

## Signup increment — user requested 2026-10-26
- [x] S01 Add signup tests for persistence, duplicate email, password validation and server-controlled roles.
- [x] S02 Local SQLite signup API, unique owner setup claim, session creation and migration.
- [x] S03 Responsive signup page, login links, password confirmation and error handling.
- [x] S04 Signup widget/browser flow, full tests, analyze, rebuild and local server update.

S01/S02 verification: backend suite 16 passed, including four new signup cases.
Accounts persist in the existing local SQLite database; no rows reset.

S03 verification: signup navigation, successful account submission, mismatched-password
validation and duplicate-error form retention covered; Flutter suite 7 passed.

S04 verification: analyze clean; 7 Flutter tests pass; web release build successful.
Signup inspected in Chrome desktop/mobile; required-field validation verified.
Local SQLite server updated; owner setup remains available for the user.

## Signup visibility/cache fix — user screenshot report
- [x] V01 Prevent old login bundles through revisioned entrypoint and legacy Flutter cache cleanup.
- [x] V02 Keep a Sign up action visible in login header, including short/scrolled viewports.
- [x] V03 Regression tests, rebuild, restart local server and verify served browser entrypoint.

Visibility fix verified: 17 backend tests and 8 Flutter tests pass; analysis clean;
web release build successful. Fresh Chrome page at 900x768 shows Sign up in header,
clicking opens signup, and compiled JS URL contains the served content revision.
No browser runtime exceptions captured. Evidence: work/login-visibility-verification.json.

## Three-actor revision — requested by user
- [x] R01 Regression tests for role signup/code, landing routes, financial isolation and temporary lead scope.
- [x] R02 Migrate legacy roles, enforce one project lead, update server authorization and signup.
- [x] R03 Role selector/code field, three dashboards, guarded routes and role-specific navigation.
- [x] R04 Project lead assignment UI with immediate revocation/replacement behavior.
- [x] R05 Full backend/Flutter tests, analyze/build, restart and real browser checks.

R01–R04 local verification: three role signup/routing, Manager code checks, scoped
lead replacement/revocation and manager lead-selector widget verified. Backend suite
24 passed before the additional unique-index and role-aware reminder checks; Flutter
suite 16 passed before final authorization polish. Production data migration pending restart.

Local deployment: a SQLite backup was created before migration. User/project/task/money
record counts are unchanged, and only manager/member/finance roles remain.
Full verification: 25 backend tests and 16 Flutter tests pass, analyze clean,
release web build successful. Browser checks in progress.

R05 complete: 25 backend tests and 16 Flutter tests pass; analysis clean; release
web build successful. Current local server includes three-role migration,
server-side Manager code validation (including Unicode rejection), scoped lead
authorization and role-aware navigation/reminders. Real Chrome verified Manager,
Team member and Finance landing pages with no runtime exceptions.
Evidence: work/role-browser-verification.json; screenshots role-manager/member/finance.
SQLite backup remains private under work/backups.

## Repository documentation and ignore rules — 2026-10-26
- [x] DOC01 Refresh README with project description, three role dashboards, signup, local SQLite setup, build/test commands, folder guide, asset credits and current limitations.
- [x] DOC02 Extend existing .gitignore for environment variants, Python caches/environments, SQLite sidecars/backups, signing keys and local editor artifacts; retain shareable environment templates and dependency lockfiles.

Verification: git check-ignore --no-index confirmed 13 private/generated paths are ignored
and 11 source/template paths remain eligible for version control. README file references
and role/setup details were checked against the current scripts and source. Documentation
and ignore rules only; application test/build suites were not rerun. No database or runtime
behavior changed, and no files were staged, committed or pushed.
