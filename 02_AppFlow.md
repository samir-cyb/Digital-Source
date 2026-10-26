# App flow
Status: LOCKED baseline. Draft features remain unchecked in 06_Plan.md.
## Global states
Boot → session check → login OR workspace loading → ready.
401 → sign in. 403 → permission explanation. Connection failure → retry; preserve input.
Mutation: idle → validation → saving (duplicate button disabled) → success/error.
## Routes
/login: email/password, submit, generic invalid credentials.
/today: overview, priorities, task actions, tomorrow preview, activity.
/projects: query/filter/list, create dialog, open detail.
/projects/:id: phases/progress/members/tasks, add task, task transitions.
/team: query/department filter, employee cards, open profile.
/team/:id: photo identity, title, department, assigned projects/tasks.
/sourcing: material list, new request, record partial delivery.
/finance: money list, create draft, approve/reverse (permission checked).
/reports: date, completed, remaining, help; submit/update.
/inbox: notification list, mark read, navigate to target.
/settings: profile, theme, timezone, sign out.
## Project dialog
Name/client/site/due date → search people → select photo cards → create.
Selected checkmark/border/chips. Search retains selection. Creator included.
At least one selected responsible member. Global role never changes through selection.
Cancel has no writes. Invalid fields inline. Failure retains form.
## Task transitions
todo → in_progress; in_progress → review; review → done by reviewer.
todo/in_progress/review → blocked (reason mandatory).
blocked → in_progress (resolution); review → in_progress (rejection note).
Manager can cancel/reopen with audit. Completed prerequisites required; reject cycles.
## Other state machines
Material request ordered → partially_received → received; over-receipt rejected.
Money pending → approved → reversed using linked correction.
Report draft → submitted; unique author/date.
Plan draft → published revision → acknowledgment; changes require new revision.
## Empty/error handling
No matching people/projects/tasks: explanatory empty state with clear-filter/create when permitted.
Image failure: initials. Deleted resource: 404 screen. All network errors have retry.
Desktop sidebar; mobile Today/Projects/Team/More. Forms scroll above keyboard.
48px actions, keyboard focus, readable scale, reduced motion respected.


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
