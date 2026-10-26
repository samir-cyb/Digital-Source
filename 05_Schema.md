# Database schema
Status: LOCKED baseline. Versioned executable migration is schema source of truth.
IDs UUID represented as strings by API; UTC timestamps; business dates Asia/Dhaka.
NN = non-null; ? nullable. PK/unique constraints imply indexes.
## Tables
users: id PK; employee_id varchar(24) unique NN; name varchar(120) NN;
email varchar(254) unique lowercase NN; password_hash text NN; roles JSON NN;
title varchar(100) NN; department varchar(80) NN; avatar varchar(200)?;
phone varchar(40)?; active boolean NN true; created_at timestamp NN.
sessions: id PK; token_hash varchar(64) unique NN; user_id FK users NN;
expires_at timestamp NN; revoked_at timestamp?; created_at timestamp NN.
projects: id PK; name varchar(160) NN; client varchar(120) NN; site varchar(200) NN;
phase varchar(30) NN; due_date date NN; created_by FK users NN;
image varchar(200)?; created_at timestamp NN.
project_members: project_id FK projects + user_id FK users composite PK;
project_role varchar(20) NN manager/lead/member.
tasks: id PK; project_id FK projects NN; title varchar(200) NN; assignee_id FK users NN;
status varchar(20) NN todo/in_progress/blocked/review/done/cancelled;
due_date date NN; priority varchar(12) NN normal/high; blocker text?;
review_note text?; version integer NN 1; created_at timestamp NN.
task_dependencies: task_id FK tasks + prerequisite_id FK tasks composite PK;
CHECK unequal; service enforces same-project acyclic graph.
reports: id PK; author_id FK users NN; report_date date NN; completed text NN;
remaining text NN; help_needed text NN; created_at timestamp NN;
unique(author_id,report_date).
suppliers: id PK; name varchar(160) NN; contact varchar(160)?; category varchar(80) NN.
material_requests: id PK; project_id FK projects NN; supplier_id FK suppliers?;
owner_id FK users NN; item varchar(200) NN; unit varchar(20) NN;
quantity numeric(12,3) >0 NN; received numeric(12,3) >=0 <=quantity NN;
due_date date NN; status varchar(20) NN.
deliveries: id PK; request_id FK material_requests NN; quantity numeric(12,3) >0 NN;
created_by FK users NN; note text?; created_at timestamp NN.
money_entries: id PK; project_id FK projects NN; created_by FK users NN;
kind varchar(20) NN advance/expense/refund/client_receipt/reversal;
amount numeric(14,2) >0 NN; payer/payee varchar(160) NN; purpose text NN;
entry_date date NN; method varchar(20) NN; status varchar(20) NN pending/approved/reversed;
approved_by FK users?; reversal_of FK money_entries? unique;
idempotency_key varchar(80) unique NN; created_at timestamp NN.
daily_plans: id PK; project_id FK projects NN; plan_date date NN; revision int >0 NN;
status varchar(20) draft/published NN; published_by FK users?;
published_at timestamp?; unique(project_id,plan_date,revision).
plan_tasks: plan_id FK daily_plans + task_id FK tasks composite PK.
plan_acknowledgments: plan_id FK daily_plans + user_id FK users composite PK;
acknowledged_at timestamp NN.
notifications: id PK; user_id FK users NN; title varchar(160) NN; body text NN;
route varchar(200) NN; read_at timestamp?; created_at timestamp NN; dedupe_key unique NN.
files: id PK; project_id FK projects NN; uploaded_by FK users NN;
storage_key unique NN; filename NN; mime NN; size bigint >0 NN; created_at timestamp NN.
audit_events: id PK; actor_id FK users?; action varchar(80) NN; entity_type varchar(40) NN;
entity_id UUID?; details JSON NN; created_at timestamp NN.
## Indexes
sessions(user_id,expires_at); project_members(user_id,project_id);
tasks(project_id,status), tasks(assignee_id,due_date);
dependencies(prerequisite_id); reports(report_date);
materials(project_id,due_date), materials(supplier_id); deliveries(request_id);
money(project_id,entry_date), money(created_by); plans(project_id,plan_date);
notifications(user_id,read_at,created_at); files(project_id);
audit(entity_type,entity_id,created_at).
## Auth and RLS
Login creates random secret, stores only digest; web cookie/mobile memory session.
User is derived from verified session, never client-supplied roles or user IDs.
Postgres authenticated transaction sets app.user_id with set_config(...,true).
RLS helpers read stored roles, fixed search_path, restricted EXECUTE.
Owner/project members read projects; writes require owner/project manager as applicable.
Tasks/materials/files require project membership. Finance owner/finance only;
own submitted records can be exposed separately. Reports author/authorized managers;
notifications own user only. Public profile serializer excludes password/session data.
App role NOSUPERUSER NOBYPASSRLS and not table owner; FORCE ROW LEVEL SECURITY.
No audit UPDATE/DELETE grants. RLS isolation tests mandatory before production.
## Integrity
Financial records retained; disable accounts, do not delete history.
Atomic receipts and approvals; optimistic task versions; idempotent finance writes.
Approved expense cannot be edited; reversal unique and linked to original.
Local development mode does not implement PostgreSQL RLS: explicitly gated in plan.


## Approved change — local signup (2026-10-26)
The user explicitly requested a signup page and local database. This supersedes
the earlier administrator-only provisioning assumption. /signup is reachable from login.
Name, normalized unique email, password (12–128 characters), confirmation and optional
title/department and selected position. Manager signup requires server-side code 1234.
No automatic first-owner role remains. Only manager/member/finance are accepted.
Role selection is validated on the server. Successful signup signs in; duplicates/errors
retain entered data. SQLite persistence and existing records must be preserved.
workspace_registration: claim_key varchar(40) PK; owner_user_id FK users NN; created_at timestamp NN.
The unique first_owner claim and user creation are committed atomically to prevent duplicate setup owners.


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

Current migration table: schema_migrations(revision varchar(80) primary key, applied_at timestamp not null).
Unique partial index uq_project_single_lead on project_members(project_id) WHERE project_role=lead.
workspace_registration is retained only as legacy history; it grants no roles.
