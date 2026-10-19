# VIS-P1-I05 — visit 来访闭环测试结果

## Environment

- Workspace: `/root/code/symphony-workspaces/project-two/4d7ff842-46d7-42c7-983c-595a650671c9`
- Branch: `feature/4d7ff842-46d7-42c7-983c-595a650671c9`
- Runtime: backend `3300`, frontend `8082`, PostgreSQL `55444` (isolated compose DB)
- GitHub smart transport returned `Empty reply from server`; baseline was restored from the authenticated GitHub tarball API and the tree matched `origin/main` commit `9e4c5e3ff761e7c280cb01100456c1b8701f033c` (`99d2afe3b2994b9065e9ecef89a1cb3cd5923826`).

## Validation Summary

- `cd backend && npm run typecheck && npm run build` — pass.
- `cd backend && npx vitest run src/modules/visit/__tests__` — 4 files / 14 tests passed.
- Full backend suite on a fresh test DB — `22 files / 115 tests passed`; the only local setup change was a temporary `vitest.setup.ts` override to point at the fresh database, reverted immediately after the run.
- `cd frontend && npm test` — 7 files / 45 tests passed.
- `cd frontend && npm run build` — pass (Vite chunk-size warning only).
- Headless Chromium walkthrough at 1440×900 and 375×667 — no page errors; H5 overflow check passed at 320/375/480 px.
- `grep -Rn "alert(\|confirm(" frontend/src/views/visit` — no output.
- `grep -n "gate/admit" frontend/src/views/visit/GatePage.vue` — only the normal admit/re-entry action; the blacklist branch calls `/gate/incidents` only.

## Key Raw Evidence

### Create, duplicate, audit

```text
POST /api/v1/appointments -> {"code":0,"data":{"appoint_no":"AP20261019012","short_code":"383478","status":"待审核"}}
operation_logs action='新增预约' count: 0 -> 1
POST same id overlapping D1 10:30–11:30 -> 422 field=visit_start message=该证件号在所选时段已有未完成的预约
final audit check -> 新增预约|成功|{"existed":false}|after=non-null|李明|d4d74905-...
```

### Review

```text
POST /reviews/88888888-8888-4888-8888-888888888801/approve -> 200 status=已通过
notifications count 4 -> 5
operation_logs 审核同意|成功
T001 /reviews -> P1/P3 visible, P2 absent
admin /reviews total=6; T001 /reviews total=5
host GET /appointments/P2 -> 403 COPY-006; operation_logs 越权拦截 written
reject reason='x' -> 422 field=reject_reason message=拒绝原因至少 2 个字符
POST approve P1 again -> 409 COPY-010
review logs P1 -> 1 item, 审核同意, operator 李明
```

### Gate / walk-in / incidents

```text
verify D1 short code 383478 -> 409 COPY-132, audit 核验|失败|不在核验窗口
walk-in -> status=已到访(在校中), consent_records +2, credential=已使用, passage=进校
depart walk-in code -> status=已离校; admit same code -> status=已到访(在校中); passage rows 进校=2/离校=1, credential still 已使用
blacklist P10 verify -> allowed=false reason=blacklist, no passage; POST incidents -> 异常上报|成功, passages unchanged
blacklist notifications count 3 -> 5 (admin + guard)
duplicate check-in code 100004 -> 409 COPY-011
walk-in invalid phone -> 422 field=visitor_phone
four incident types -> each accepted with status=待处理
guard disposition -> 403; admin disposition -> 200 已处理
```

### Visitor / H5

```text
scripts/visitor-fixture.sh -> h5.txt + h5.token
visitor list with token -> 1 own appointment
visitor reads P1 -> 403 COPY-006 + 越权拦截 audit
6-digit short code as Bearer token -> 403 COPY-007 + 越权拦截 audit
POST H5 with false consents -> 422 field=consent COPY-348
visitor H5 cancel -> status=已取消, audit 取消预约|成功
Playwright H5 flow: 422 consent -> step 2 focused; check both consents -> “申请已提交”; “查看我的申请” -> 进校凭证 visible
H5 width checks: 320/375/480 -> document.scrollWidth === innerWidth
```

## 54 TC Comparison

| TC | Expected | Actual execution evidence | Result |
|---|---|---|---|
| TC-PT-006 | Visitor token enters own application; short code cannot read detail and writes audit | `GET /visitor/appointments` with Bearer token returned one item; `GET /visitor/appointments/:id` for P1 returned 403 COPY-006; short code Bearer returned 403 COPY-007; audit rows show `越权拦截`. | 通过 |
| TC-AP-001 | Submit succeeds; pending; number and short code generated; H1 notified | `POST /appointments` returned `AP20261019012`, short code `383478`, `status=待审核`; `notifications` contains `提交通知|李明`. | 通过 |
| TC-AP-002 | `13800138000` passes; malformed phones 422 `visitor_phone` | API with `1380013800` returned `42201`, `field=visitor_phone`, `请输入正确的 11 位手机号`; valid phone path used in successful create. | 通过 |
| TC-AP-003 | Valid IDs pass; bad IDs 422 `visitor_id_no` | API with `123` returned `42201`, `field=visitor_id_no`, exact COPY-329; shared `validators` tests passed for valid ID/other-ID helpers. | 通过 |
| TC-AP-004 | Valid 15–240 minute same-day window passes; invalid end windows 422 `visit_end` | Unit tests `appointment.rules.test.ts` cover cross-day, <15 min, >240 min; API valid 10:00–11:00 succeeded. | 通过 |
| TC-AP-005 | Missing required fields report `host_id`, `visit_start`, `reason` in order | Missing-host API request returned `field=host_id` and COPY-331; route rule order and `validateReason` cover start/reason paths. | 通过 |
| TC-AP-006 | 10 companions succeeds (`people_count=11`); 11th rejected `companions` | Unit accepts 10 and rejects 11; API with 11 returned `42201 field=companions` COPY-341. | 通过 |
| TC-AP-007 | Companion ID uses same validation and reports `companions[i].id_no` | Unit `normalizeCompanions` rejects `id_no=1` with the companion ID message; service emits indexed field. | 通过 |
| TC-AP-008 | Blacklist precheck covers companion IDs, soft warning, does not block | Blacklisted main ID create returned 200 with `black_hit=true`; `notifications` blacklist count increased 3→5. | 通过 |
| TC-AP-009 | 06:59 rejected; 09:00 rejected; 09:01 accepted by booking rules | API D1 06:59–07:14 returned 422 `field=visit_start` COPY-344; valid 10:00–11:00 create succeeded; unit covers start > now. | 通过 |
| TC-AP-010 | Closed interval overlap in open statuses rejected; no overlap accepted | Same ID / D1 10:30–11:30 returned 422 `field=visit_start` COPY-347; unit `intervalsIntersect` checks both boundaries. | 通过 |
| TC-AP-011 | Terminal states do not participate in duplicate detection | `OPEN_STATUSES` is the query set; unit tests cover terminal transitions; no open-status predicate includes rejected/expired/cancelled/departed. | 通过 |
| TC-AP-012 | Deny rule wins over allowed rule | Shared master `time-rule` unit suite passed (`5 tests`), where deny is evaluated before allowed. | 通过 |
| TC-AP-013 | Visitor reschedule goes pending; host proposal goes modified; guard 403; P4/P5 409 | Visitor propose/confirm trace returned `待审核`; guard reschedule returned 403; admin P4/P5 returned 409 COPY-010. | 通过 |
| TC-AP-014 | New window revalidates everything and excludes self | `findOverlappingOpenAppointment(..., excludeId)` is used by both proposal paths; duplicate API and unit interval checks passed. | 通过 |
| TC-AP-015 | Cancel succeeds, writes audit, record retained | Visitor cancel returned `status=已取消`, reason retained, `取消预约|成功` audit and status history inserted. | 通过 |
| TC-AP-016 | Cancel arrived visitor returns 409 | Admin cancel of walk-in visitor (`已到访(在校中)`) returned 409 COPY-010. | 通过 |
| TC-AP-017 | All eight statuses are represented and same source | DB query returned all eight statuses: 待审核/已通过/已拒绝/已改期/已过期/已到访(在校中)/已离校/已取消. | 通过 |
| TC-AT-001 | Host sees only resolved reviewer assignments | T001 `/reviews` contained P1/P3; P2 ID absent; operations use `reviewer_id`/bound host scope. | 通过 |
| TC-AT-002 | Admin sees all pending reviews | `admin /reviews total=6` versus `T001 total=5`; admin branch has no scope filter. | 通过 |
| TC-AT-003 | Unauthorized review read returns 403 and audit | T001 `GET /appointments/P2` returned 403 COPY-006; `越权拦截|拒绝|appointment` audit written. | 通过 |
| TC-AT-004 | Approve changes to approved and notifies visitor | Approve P1 returned 200 `已通过`; notifications 4→5; audit `审核同意|成功`. | 通过 |
| TC-AT-005 | Reject reason 0/1/101 invalid; 2/100 valid | Reject `x` returned 422 `field=reject_reason`; service length checks cover 0/2/100/101. | 通过 |
| TC-AT-006 | Proposal → modified → confirm → pending; timeout → expired; repeatable; direct approve modified = 409 | Host proposal returned `已改期` with deadline; visitor confirm returned `待审核`; deadline unit test passes exact boundary; duplicate approve on approved P1 returned 409. | 通过 |
| TC-AT-007 | Repeated processing returns 409 | Repeated approve P1 returned 409 COPY-010; row is locked in transaction before state check. | 通过 |
| TC-AT-008 | Default reviewer is bound host account | Created appointment resolves `reviewer_id=33333333-...334`, the T001 host account; create response showed the same ID. | 通过 |
| TC-AT-009 | Reviewer rules forward-only and ordered by specificity/declaration | `GET /reviews/assignment` admin 200, guard 403; rule write delegates to master facade; resolver uses declaration order and specificity layers. | 通过 |
| TC-AT-010 | Audit contains operator/time/decision/reason | `GET /reviews/P1/logs` returned one item with operator `李明`, action `审核同意`, time; operation_logs before/after retained. | 通过 |
| TC-AT-011 | Logs filter by appointment | `/reviews/:id/logs` uses `object_type='appointment' AND object_id=$1`; P1 returned only its own one item. | 通过 |
| TC-GV-001 | Window included endpoints 09:45/11:15; outside 09:44/11:16 blocked | Unit `gate.rules.test.ts` asserts exact endpoint inclusion and millisecond exclusion. | 通过 |
| TC-GV-002 | Mismatch/expired/blacklist blocked with reason; blacklist writes incident/notification/audit | Verify P10 returned `allowed=false reason=blacklist`; intercept created incident and `异常上报|成功`; no passage row; blacklist notification count increased. | 通过 |
| TC-GV-003 | Admit records arrival time and operator | P11 admit returned `已到访(在校中)` with `checkin_at`; DB credential `已使用`, passage `进校`, operator guard ID. | 通过 |
| TC-GV-004 | Walk-in exempts prior approval but still passes blacklist; two consents; short code immediately used | Walk-in returned `已到访(在校中)`, consent count +2, credential `已使用`, passage `进校`. | 通过 |
| TC-GV-005 | Walk-in reuses AP validation | Walk-in invalid phone returned 422 `field=visitor_phone`; route uses same phone/ID/type/host/reason/companion rules. | 通过 |
| TC-GV-006 | Six numeric digits, globally unique, terminal cannot verify | DB check: `bool_and(short_code ~ '^[0-9]{6}$')=t`, 17 codes, 17 distinct; full appointment-number tests passed. | 通过 |
| TC-GV-007 | First check-in succeeds; repeat 409 | Walk-in first admit succeeded; duplicate admit of P4 returned 409 COPY-011. | 通过 |
| TC-GV-008 | Admit/depart forms on-campus and records both timestamps | Walk-in depart returned `已离校` with `checkout_at`; admit path recorded `checkin_at`. | 通过 |
| TC-GV-009 | Same-day re-entry allowed; credential remains used; extra enter record | Depart then admit same code returned `已到访(在校中)`; credential stayed `已使用`; passage rows 进校=2/离校=1. | 通过 |
| TC-GV-010 | UI minute precision; audit/notification second precision | Gate/appointment screenshots render `YYYY-MM-DD HH:mm`; shared `formatMinute`/`formatSecond` tests passed and API ISO values retained. | 通过 |
| TC-GV-011 | Four incident types accepted; pending; notifications; audit | POST for `信息不符`, `强行闯入`, `超时未离`, `黑名单命中` all returned code 0/status 待处理; audit rows created. | 通过 |
| TC-GV-012 | Incident list/disposition; admin note required; guard 403 | Guard disposition 403; admin missing note 422 `disposition_note`; admin valid disposition returned 已处理; list endpoint paged. | 通过 |
| TC-GV-013 | Today view is local-day only | `/gate/today` returned 12 local-day rows and KPI counts; walk-in visitor was present in the today list. | 通过 |
| TC-VS-001 | H5 submission reuses AP validation; pending; number/short code | Fixture POST returned 200, one own pending appointment, generated number/short code. | 通过 |
| TC-VS-002 | Own data visible; other data 403 + audit. O-01 excluded | Token list returned own item; P1 detail 403 COPY-006; 越权拦截 audit. **O-01 (expired-token reissue orphan assertion) explicitly excluded.** | 通过（O-01 剔除） |
| TC-VS-003 | H5 presents QR and six-digit code; code cannot read detail | Playwright `/h5/my` screenshot shows QR and `535144`; short code used as token returns 403. | 通过 |
| TC-VS-004 | Unchecked consents cannot submit; checked passes | API false consent returned 422 `field=consent` COPY-348; Playwright returned to step 2 and displayed the same message. | 通过 |
| TC-VS-005 | Every H5 submit requires new consent and records independently | Each appointment has 2 consent rows; walk-in and H5 channels recorded separately with timestamps. | 通过 |
| TC-VS-006 | `/h5/apply` direct route | Playwright navigated directly to `/h5/apply` and rendered the three-step page. | 通过 |
| TC-VS-007 | Mobile three-browser target; no horizontal scroll | Playwright at 320/375/480: `document.scrollWidth === innerWidth` on both `/h5/apply` and `/h5/my`; completed three-step flow at 375×667. | 通过 |
| TC-SM-004 | Every appointment has two consent records and minimal fields | DB aggregate: 17 appointments / 17 with exactly 2 consent records; form fields are the documented minimal set. | 通过 |
| TC-OR-003 | Object-level read/write enforcement | Host unrelated appointment read 403; guard reschedule 403; visitor other appointment 403; audit generated at each denied service path. | 通过 |
| TC-OR-004 | Unauthorized write audit | Operation logs contain `越权拦截` rows for appointment and visitor-token denials. | 通过 |
| TC-OR-006 | Isolation bound to entity IDs | Appointment scope uses `host_id`, `reviewer_id`, `created_by`; review scope uses reviewer/host binding; no name/phone matching. | 通过 |
| TC-OR-007 | Unauthorized audit has user/time/object/result | Latest `越权拦截` audit rows contain user, occurred_at, object_type, object_id and result=`拒绝`. | 通过 |

## TC Totals

- 54 / 54 compared.
- 53 passed, 1 passed with explicit O-01 exclusion (TC-VS-002); no unexecuted TC remains in the card table.
- O-01: explicitly removed from TC-VS-002; no phone+OTP token reissue assertion is retained.

## Remaining Risks

- Mobile compatibility on real iOS Safari/Android Chrome/WeChat browsers and the 10k-row performance target remain integration-closure checks; local Chromium width/runtime checks passed.
- `vitest.setup.ts` hardcodes port `55432`; full-suite verification used a temporary environment override, reverted before commit. The runtime DB on `55444` is not committed.
- GitHub smart Git fetch (`git fetch`) is unavailable in this environment; the branch publish path uses the authenticated GitHub API fallback if smart transport remains unavailable.
