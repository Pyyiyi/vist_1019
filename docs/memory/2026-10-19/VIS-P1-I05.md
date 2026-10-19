# VIS-P1-I05 — visit 来访闭环全栈卡

## Outcome

- Delivered the visit backend context end to end: appointment create/list/detail/reschedule/cancel, review approve/reject/propose-reschedule/logs/assignment, gate verify/admit/depart/walk-in/today/incidents, visitor token issue/list/detail/confirm/reschedule/cancel, consent recording, blacklist handling, audit, expiry jobs, and compliance facade exports.
- Delivered `frontend/src/views/visit/`: appointments, review, gate, H5 apply, H5 my, H5 privacy, appointment form, routes and permissions.
- Added the required visitor fixture script and 54-case execution record at `docs/trace/runs/v1/test-results/VIS-P1-I05.md`.

## Key Decisions

- Object scope is enforced in services using bound IDs only: appointment host/reviewer/creator IDs and reviewer assignment IDs. Every denied object path writes `action='越权拦截'`.
- All state mutations lock the appointment/incident row with `SELECT ... FOR UPDATE`; duplicate submission additionally takes a per-visitor advisory lock and catches the unique-slot constraint.
- Reschedule is treated as its own operation with eligible source states `待审核`, `已改期`, `已通过`; this supports repeated proposals and visitor changes while keeping approve/reject transitions strict.
- Visitor public submission is CSRF-exempt only for an uninitialized `POST /visitor/appointments`; authenticated backend paths still require CSRF. This also makes the card’s documented H5 curl contract executable.
- H5 routing bypasses the backend auth bootstrap before it can call `/auth/me` and redirect to login. H5 token access remains enforced by `visitorTokenAuth`.
- Added facade reads `getTimeRules` and `getReviewerRules` in `backend/src/modules/master/index.ts` so visit does not import master internals.
- Walk-in uses the same validation domain as normal submissions but supplies the current window and explicitly exempts prior approval/expiry; consent and blacklist checks remain enforced.

## Validation

- Backend: typecheck/build pass; visit tests 14/14; full suite 115/115 on a fresh test DB with a temporary `vitest.setup.ts` DB override (reverted).
- Frontend: 45/45 tests; production build pass.
- API evidence: create + audit, duplicate 422, approval + notification, review scope, blacklist soft/hard paths, walk-in, depart/re-entry, visitor token isolation, consent 422, disposition role gates, time-window 409, incident types, object-level audit.
- UI evidence: Playwright desktop pages, deep-link drawer, error/retry state, guard blacklist-only result, three-step H5 submit with consent-422 recovery, H5 QR/short-code view, no horizontal overflow at 320/375/480.

## Screenshots

- `docs/trace/runs/v1/screenshots/VIS-P1-I05-appointments.png`
- `docs/trace/runs/v1/screenshots/VIS-P1-I05-appointment-detail.png`
- `docs/trace/runs/v1/screenshots/VIS-P1-I05-appointments-error.png`
- `docs/trace/runs/v1/screenshots/VIS-P1-I05-reviews.png`
- `docs/trace/runs/v1/screenshots/VIS-P1-I05-gate.png`
- `docs/trace/runs/v1/screenshots/VIS-P1-I05-gate-blacklist.png`
- `docs/trace/runs/v1/screenshots/VIS-P1-I05-h5-apply.png`
- `docs/trace/runs/v1/screenshots/VIS-P1-I05-h5-consent-error.png`
- `docs/trace/runs/v1/screenshots/VIS-P1-I05-h5-success.png`
- `docs/trace/runs/v1/screenshots/VIS-P1-I05-h5-my.png`

## Risks / Follow-ups

- Real iOS Safari, Android Chrome, WeChat browser compatibility and 10k-row performance remain for the integration closure card; local Chromium covered responsive geometry and interaction flow.
- `backend/vitest.setup.ts` still hardcodes `localhost:55432`; full suite needs a fresh DB override until the shared test environment is normalized.
- GitHub smart transport was unavailable (`Empty reply from server`); branch publish requires the authenticated GitHub API/archive fallback if it remains unavailable.
