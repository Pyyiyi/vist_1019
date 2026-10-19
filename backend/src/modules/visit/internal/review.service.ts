import { writeAudit } from '../../../shared/audit/writeAudit.js';
import { MESSAGES } from '../../../shared/constants/messages.js';
import { query, withTransaction } from '../../../shared/db/pool.js';
import { conflict, notFound, unprocessable } from '../../../shared/http/errors.js';
import { parsePagination } from '../../../shared/http/pagination.js';
import { newUuid } from '../../../shared/utils/ids.js';
import { getActiveGates, getActiveHosts, getActiveVisitorTypes, getReviewerRules, upsertReviewerRules } from '../../master/index.js';
import * as repo from './repo.js';
import { configNumber, validateSchedule } from './appointment.service.js';
import { COPY, assertRescheduleEligible, assertTransition, parseDateValue, validateRejectReason, validateVisitWindow } from './domain/rules.js';
import { assertCanReview } from './scope.js';
import { notifyVisitor, safeNotify } from './notifications.js';
import type { Actor, AppointmentRow } from './types.js';
import { iso, toAppointmentDto, toCompanionDto, toHistoryDto } from './types.js';

type Enrichment = { hostNames: Map<string, string>; visitorTypeNames: Map<string, string>; gateNames: Map<string, string> };

async function enrichment(): Promise<Enrichment> {
  const [hosts, types, gates] = await Promise.all([getActiveHosts(), getActiveVisitorTypes(), getActiveGates()]);
  return {
    hostNames: new Map(hosts.map((x) => [x.id, x.name])),
    visitorTypeNames: new Map(types.map((x) => [x.id, x.name])),
    gateNames: new Map(gates.map((x) => [x.id, x.name])),
  };
}

function dto(row: AppointmentRow, map: Enrichment) {
  return toAppointmentDto(row, {
    host_name: map.hostNames.get(row.host_id) ?? row.host_id,
    visitor_type_name: map.visitorTypeNames.get(row.visitor_type_id) ?? row.visitor_type_id,
    gate_name: row.expected_gate_id ? map.gateNames.get(row.expected_gate_id) ?? row.expected_gate_id : null,
  });
}

export async function listReviews(queryParams: Record<string, unknown>, actor: Actor) {
  const pagination = parsePagination(queryParams, 20, 100);
  const result = await repo.listPendingReviews({ pageSize: pagination.pageSize, offset: pagination.offset, actor });
  const map = await enrichment();
  return { items: result.rows.map((row) => dto(row, map)), total: result.total, page: pagination.page, page_size: pagination.pageSize };
}

export async function getReviewDetail(id: string, actor: Actor, ip: string | null, path?: string) {
  const row = await repo.findAppointmentById(id);
  if (!row) throw notFound(MESSAGES.NOT_FOUND);
  await assertCanReview(actor, row, ip, path);
  const [companions, history, map] = await Promise.all([repo.findCompanions(id), repo.findHistory(id), enrichment()]);
  return { ...dto(row, map), companions: companions.map(toCompanionDto), history: history.map(toHistoryDto) };
}

export async function approveReview(id: string, actor: Actor, ip: string | null, path?: string) {
  const row = await withTransaction(async (client) => {
    const current = await repo.findAppointmentById(id, client, true);
    if (!current) throw notFound(MESSAGES.NOT_FOUND);
    await assertCanReview(actor, current, ip, path);
    assertTransition(current.status, '已通过');
    const updated = await client.query<AppointmentRow>(
      `UPDATE appointments SET status = '已通过', reject_reason = NULL, updated_at = now() WHERE id = $1 RETURNING *`,
      [id],
    );
    await repo.insertStatusHistory(client, { id: newUuid(), appointmentId: id, fromStatus: current.status, toStatus: '已通过', changedBy: actor.id, reason: '审核同意' });
    await writeAudit(client, { userId: actor.id, userName: actor.displayName, objectType: 'appointment', objectId: id, action: '审核同意', result: '成功', before: { status: current.status }, after: { status: '已通过' }, ip });
    return updated.rows[0];
  });
  await safeNotify(() => notifyVisitor(row, '审核结果', { result: '通过' }));
  return { status: row.status };
}

export async function rejectReview(id: string, input: Record<string, unknown>, actor: Actor, ip: string | null, path?: string) {
  const reason = validateRejectReason(input.reason ?? input.reject_reason);
  const row = await withTransaction(async (client) => {
    const current = await repo.findAppointmentById(id, client, true);
    if (!current) throw notFound(MESSAGES.NOT_FOUND);
    await assertCanReview(actor, current, ip, path);
    assertTransition(current.status, '已拒绝');
    const updated = await client.query<AppointmentRow>(
      `UPDATE appointments SET status = '已拒绝', reject_reason = $2, updated_at = now() WHERE id = $1 RETURNING *`,
      [id, reason],
    );
    await repo.insertStatusHistory(client, { id: newUuid(), appointmentId: id, fromStatus: current.status, toStatus: '已拒绝', changedBy: actor.id, reason });
    await writeAudit(client, { userId: actor.id, userName: actor.displayName, objectType: 'appointment', objectId: id, action: '审核拒绝', result: '成功', before: { status: current.status }, after: { status: '已拒绝', reason }, ip });
    return updated.rows[0];
  });
  await safeNotify(() => notifyVisitor(row, '审核结果', { result: '拒绝', reason }));
  return { status: row.status, reject_reason: reason };
}

export async function proposeReschedule(id: string, input: Record<string, unknown>, actor: Actor, ip: string | null, path?: string) {
  const start = parseDateValue(input.visit_start);
  if (!start) throw unprocessable(COPY.START_REQUIRED, 'visit_start');
  const end = parseDateValue(input.visit_end);
  if (!end) throw unprocessable(COPY.END_REQUIRED, 'visit_end');
  const row = await withTransaction(async (client) => {
    const current = await repo.findAppointmentById(id, client, true);
    if (!current) throw notFound(MESSAGES.NOT_FOUND);
    await assertCanReview(actor, current, ip, path);
    assertRescheduleEligible(current.status);
    const minMinutes = await configNumber('min_stay_minutes', 15);
    const maxMinutes = await configNumber('max_stay_minutes', 240);
    validateVisitWindow(start, end, new Date(), minMinutes, maxMinutes, false);
    await validateSchedule(start, end, new Date());
    if (current.visitor_id_no) {
      const overlap = await repo.findOverlappingOpenAppointment(client, current.visitor_id_no, start, end, id);
      if (overlap) throw unprocessable(COPY.DUPLICATE, 'visit_start');
    }
    const proposedAt = new Date();
    const updated = await client.query<AppointmentRow>(
      `UPDATE appointments SET visit_start = $2, visit_end = $3, status = '已改期', reschedule_proposed_at = $4, updated_at = now() WHERE id = $1 RETURNING *`,
      [id, start, end, proposedAt],
    );
    await repo.insertStatusHistory(client, { id: newUuid(), appointmentId: id, fromStatus: current.status, toStatus: '已改期', changedBy: actor.id, reason: COPY.RESCHEDULE_REASON });
    await writeAudit(client, { userId: actor.id, userName: actor.displayName, objectType: 'appointment', objectId: id, action: '改期', result: '成功', before: { visit_start: iso(current.visit_start), visit_end: iso(current.visit_end), status: current.status }, after: { visit_start: start.toISOString(), visit_end: end.toISOString(), status: '已改期', reschedule_proposed_at: proposedAt.toISOString() }, ip });
    return updated.rows[0];
  });
  await safeNotify(() => notifyVisitor(row, '改期提议', { timeoutHours: 3 }));
  return { status: row.status, reschedule_proposed_at: iso(row.reschedule_proposed_at), reschedule_deadline: row.reschedule_proposed_at ? new Date(new Date(row.reschedule_proposed_at).getTime() + 3 * 3_600_000).toISOString() : null };
}

export async function listReviewLogs(id: string, actor: Actor, ip: string | null, path?: string) {
  const row = await repo.findAppointmentById(id);
  if (!row) throw notFound(MESSAGES.NOT_FOUND);
  await assertCanReview(actor, row, ip, path);
  const result = await query<{ id: string; user_name: string; occurred_at: Date | string; action: string; note: string; before_value: Record<string, unknown> | null; after_value: Record<string, unknown> | null }>(
    `SELECT id, user_name, occurred_at, action, note, before_value, after_value FROM operation_logs WHERE object_type = 'appointment' AND object_id = $1 AND action IN ('审核同意', '审核拒绝', '改期') ORDER BY occurred_at ASC, id ASC`,
    [id],
  );
  return { items: result.rows.map((log) => ({ id: log.id, time: iso(log.occurred_at), operator: log.user_name, decision: log.action, reason: String(log.after_value?.reason ?? log.after_value?.reject_reason ?? log.note ?? '') })) };
}

export async function getAssignmentRules() {
  return { rules: await getReviewerRules() };
}

export async function saveAssignmentRules(input: Record<string, unknown>) {
  const rules = Array.isArray(input.rules) ? input.rules : null;
  if (!rules) throw unprocessable('审核人规则格式不正确', 'rules');
  const saved = await upsertReviewerRules(rules.map((raw, index) => {
    const item = raw as Record<string, unknown>;
    return {
      visitorTypeId: typeof item.visitor_type_id === 'string' ? item.visitor_type_id : null,
      gateId: typeof item.gate_id === 'string' ? item.gate_id : null,
      startTime: typeof item.start_time === 'string' && item.start_time ? item.start_time : null,
      endTime: typeof item.end_time === 'string' && item.end_time ? item.end_time : null,
      reviewerKind: (item.reviewer_kind === 'admin' || item.reviewer_kind === 'designated' ? item.reviewer_kind : 'host') as 'host' | 'admin' | 'designated',
      reviewerUserId: typeof item.reviewer_user_id === 'string' ? item.reviewer_user_id : null,
      declarationOrder: Number(item.declaration_order ?? index + 1),
      status: item.status === 'inactive' ? 'inactive' : 'active',
    };
  }));
  return { rules: saved };
}

export async function assertReviewExists(id: string): Promise<void> {
  const row = await repo.findAppointmentById(id);
  if (!row) throw notFound(MESSAGES.NOT_FOUND);
  if (row.status !== '待审核') throw conflict(COPY.STATE_CONFLICT);
}
