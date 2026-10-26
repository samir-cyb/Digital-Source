# Digital Source PRD
Status: LOCKED approved baseline, 2026-10-26. Implementation evidence: 06_Plan.md.
## Problem
20–30 employees coordinate interior projects, sourcing, reporting and money through calls.
Members forget ownership and next steps; directors lack a shared picture.
## Actors
manager, member, finance. Exactly one global role per account.
Titles (Designer/Carpenter/Engineer) are separate. Projects have manager/lead/member membership.
Client and supplier are records, not login actors in MVP.
## Capability map
identity → projects → execution → sourcing/finance → coordination.
identity owns accounts/profiles; projects owns membership; execution owns tasks/reviews/reports;
sourcing owns suppliers/materials/deliveries; finance owns ledger; coordination owns plans/inbox.
## User stories and acceptance
- Owner creates project with client/site/deadline and employee photo-card selection.
- Profiles show photo/initials, employee ID, title, department, active workload; private information protected.
- Every task has one primary assignee, deadline, status, and optional prerequisite.
- Assignee starts work, reports blocker with reason and submits for review.
- Manager/lead verifies completion; only verified completion counts toward progress.
- Manager or project lead records requests, suppliers, partial receipts and due dates.
- Finance records payer, payee, exact BDT amount, purpose, project, method, evidence reference.
- Advances never count as project expenses. Approved entries immutable; corrections use reversal.
- One daily report per member/day; editable with audit.
- Tomorrow plan is explicitly published; acknowledgment binds to revision.
- Notifications deep-link to actionable items. No promise of background delivery while PC is off.
## Rules
Progress = done / non-cancelled tasks; zero tasks explicitly shown.
UTC timestamps; Asia/Dhaka business dates. Defaults: report 17:00, plan 19:00,
digest 20:00, meeting 09:00. Quiet hours and workdays configurable in later increment.
## Pilot targets
90% plans before cutoff; 90% reports on time; 100% task/blocker ownership;
100% approved money traceability. Compare coordination calls over four-week pilot.
## Strict non-goals
Payments, bank integrations, full accounting/tax/payroll, HR suite, warehouse ERP,
biometrics, continuous GPS, AI decisions, client/supplier login, public SEO website.
Full offline conflict resolution and production rollout are separate gates.


## Approved change — local signup (2026-10-26)
The user explicitly requested a signup page and local database. This supersedes
the earlier administrator-only provisioning assumption. /signup is reachable from login.
Name, normalized unique email, password (12–128 characters), confirmation and optional
title/department and selected position. Manager signup requires server-side code 1234.
No automatic first-owner role remains. Only manager/member/finance are accepted.
Role selection is validated on the server. Successful signup signs in; duplicates/errors
retain entered data. SQLite persistence and existing records must be preserved.


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
