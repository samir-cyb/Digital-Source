# Design system
Status: LOCKED baseline. Direction: a calm interior studio operations desk.
## Palette
brand #0F5C5E; hover #124E50; soft #E6F0ED; canvas #F6F7F9;
surface #FFFFFF; text #17212B; secondary #66737C; border #E4E9E8;
success #15803D; warning #B45309; danger #B91C1C.
Dark canvas #101820; surface #18242F; text #EFF5F4;
secondary #AAB9C2; border #2D414C; accent #83C8BF.
Use dark accent on dark surfaces. Never color-only status.
## Typography
Bundled Manrope Latin variable font; fallback for Bengali until localization increment.
Display 32/40; page 28/36; section 20/28; title 16/24; body 14/22; helper 12/18.
Weights 400/500/600/700/800. Mobile page 26/34.
## Geometry
Spacing 4/8/12/16/20/24/32/40/48.
Gutters desktop 32 mobile 20. Radius control 12, card 18, feature 22, circle avatar.
1px borders, overlays have elevation; normal surfaces have subtle or no shadow.
Desktop sidebar 228; compact sidebar 84; mobile bottom navigation below 720px.
Main max-width 1500; Today uses 2:1 columns above 1100px; grid cards >=230px.
## Components
Employee card: bundled sample photo, ID/name/title/department, workload, selected check.
Project card: architectural photo, client, status, progress, team avatars, deadline.
Buttons: default/hover/focus/pressed/disabled/loading. Inputs: label/helper/error/focus.
Errors retain user input. Empty states direct next action. Loading never fakes data.
## Motion
180–220ms ease-out for purposeful page/selection changes. No looping decoration.
Respect MediaQuery.disableAnimations. Theme system default with manual override.
All routes tested light/dark and mobile/desktop before marking complete.
## Content
Clear sentence-case English initially. Fictional staff and sample projects are labelled demo.
No runtime external portrait calls; sample photos are not actual employee identities.



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
