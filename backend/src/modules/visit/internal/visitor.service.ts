import { createHash, randomBytes } from 'node:crypto';

import { writeAudit } from '../../../shared/audit/writeAudit.js';
import { MESSAGES } from '../../../shared/constants/messages.js';
import { query, withTransaction } from '../../../shared/db/pool.js';
import { conflict, forbidden, notFound, unprocessable } from '../../../shared/http/errors.js';
import { newUuid } from '../../../shared/utils/ids.js';
import { listNotificationsForVisitor } from '../../notify/index.js';
import { getActiveGates, getActiveHosts, getActiveVisitorTypes, getDictionaryItems } from '../../master/index.js';
import { createAppointment, configNumber, validateSchedule } from './appointment.service.js';
import * as repo from './repo.js';
import {
  COPY,
  assertRescheduleEligible,
  assertTransition,
  isRescheduleExpired,
  parseDateValue,
  rescheduleDeadline,
  validateVisitWindow,
} from './domain/rules.js';
import { notifyReviewer, notifyReviewerTemplate, safeNotify } from './notifications.js';
import { assertConsents } from './consent.service.js';
import type { AppointmentRow } from './types.js';
import {
  iso,
  toAppointmentDto,
  toCompanionDto,
  toCredentialDto,
  toHistoryDto,
} from './types.js';

type VisitorTokenRow = { appointment_id: string };

export function hashVisitorToken(token: string): string {
  return createHash('sha256').update(token).digest('hex');
}

export function newVisitorToken(): string {
  return randomBytes(32).toString('base64url');
}

export async function issueVisitorToken(appointmentId: string): Promise<string> {
  const token = newVisitorToken();
  const expiresAt = new Date(Date.now() + 90 * 24 * 3_600_000);
  await query(
    `INSERT INTO visitor_tokens (id, appointment_id, token_hash, expires_at)
     VALUES ($1, $2, $3, $4)`,
    [newUuid(), appointmentId, hashVisitorToken(token), expiresAt],
  );
  return token;
}

export async function submitVisitorAppointment(input: Record<string, unknown>) {
  assertConsents((input.consent ?? input.consents) as { safety?: unknown; privacy?: unknown } | undefined);
  const result = await createAppointment(input, {
    actor: null,
    createdBy: null,
    channel: 'H5',
    ip: null,
  });
  const visitorToken = await issueVisitorToken(String(result.id));
  return { ...result, visitor_token: visitorToken };
}

async function boundAppointment(visitorAppointmentId: string): Promise<AppointmentRow> {
  const row = await repo.findAppointmentById(visitorAppointmentId);
  if (!row) throw notFound(MESSAGES.NOT_FOUND);
  return row;
}

export async function listVisitorAppointments(visitorAppointmentId: string) {
  const bound = await boundAppointment(visitorAppointmentId);
  const rows = bound.visitor_id_no
    ? (await query<AppointmentRow>(
        `SELECT * FROM appointments WHERE visitor_id_no = $1 ORDER BY visit_start DESC, created_at DESC`,
        [bound.visitor_id_no],
      )).rows
    : [bound];
  const [hosts, types, gates] = await Promise.all([getActiveHosts(), getActiveVisitorTypes(), getActiveGates()]);
  const hostNames = new Map(hosts.map((x) => [x.id, x.name]));
  const typeNames = new Map(types.map((x) => [x.id, x.name]));
  const gateNames = new Map(gates.map((x) => [x.id, x.name]));
  return {
    items: rows.map((row) => toAppointmentDto(row, {
      host_name: hostNames.get(row.host_id) ?? row.host_id,
      visitor_type_name: typeNames.get(row.visitor_type_id) ?? row.visitor_type_id,
      gate_name: row.expected_gate_id ? gateNames.get(row.expected_gate_id) ?? row.expected_gate_id : null,
    })),
  };
}

async function auditVisitorDenied(row: AppointmentRow, path?: string): Promise<void> {
  await writeAudit({
    userId: null,
    userName: row.visitor_name ?? '访客',
    objectType: 'appointment',
    objectId: row.id,
    action: '越权拦截',
    result: '拒绝',
    before: { path: path ?? null },
    note: '访客令牌越权访问预约',
  });
}

async function assertOwnedByToken(row: AppointmentRow, bound: AppointmentRow, path?: string): Promise<void> {
  if (row.id === bound.id || (bound.visitor_id_no && row.visitor_id_no === bound.visitor_id_no)) return;
  await auditVisitorDenied(row, path);
  throw forbidden(MESSAGES.OBJECT_FORBIDDEN);
}

export async function getVisitorAppointmentDetail(
  id: string,
  visitorAppointmentId: string,
  path?: string,
) {
  const [bound, row] = await Promise.all([
    boundAppointment(visitorAppointmentId),
    repo.findAppointmentById(id),
  ]);
  if (!row) throw notFound(MESSAGES.NOT_FOUND);
  await assertOwnedByToken(row, bound, path);
  const [companions, history, credential, notifications, hosts, types, gates] = await Promise.all([
    repo.findCompanions(id),
    repo.findHistory(id),
    repo.findCredential(id),
    listNotificationsForVisitor(id, { page_size: 50 }),
    getActiveHosts(),
    getActiveVisitorTypes(),
    getActiveGates(),
  ]);
  const hostNames = new Map(hosts.map((x) => [x.id, x.name]));
  const typeNames = new Map(types.map((x) => [x.id, x.name]));
  const gateNames = new Map(gates.map((x) => [x.id, x.name]));
  return {
    ...toAppointmentDto(row, {
      host_name: hostNames.get(row.host_id) ?? row.host_id,
      visitor_type_name: typeNames.get(row.visitor_type_id) ?? row.visitor_type_id,
      gate_name: row.expected_gate_id ? gateNames.get(row.expected_gate_id) ?? row.expected_gate_id : null,
    }),
    companions: companions.map(toCompanionDto),
    history: history.map(toHistoryDto),
    credential: credential ? toCredentialDto(credential) : null,
    messages: notifications.items.map((item) => ({
      id: item.id,
      title: item.title,
      content: item.content,
      template_type: item.templateType,
      is_security: item.isSecurity,
      created_at: item.createdAt,
      read_at: item.readAt,
    })),
  };
}

export async function confirmVisitorReschedule(id: string, visitorAppointmentId: string, path?: string) {
  const bound = await boundAppointment(visitorAppointmentId);
  const result = await withTransaction(async (client) => {
    const current = await repo.findAppointmentById(id, client, true);
    if (!current) throw notFound(MESSAGES.NOT_FOUND);
    await assertOwnedByToken(current, bound, path);
    if (current.status !== '已改期') throw conflict(COPY.STATE_CONFLICT);
    const proposedAt = current.reschedule_proposed_at ? new Date(current.reschedule_proposed_at) : null;
    if (!proposedAt || isRescheduleExpired(proposedAt, new Date())) {
      const updated = await client.query<AppointmentRow>(
        `UPDATE appointments SET status = '已过期', updated_at = now() WHERE id = $1 RETURNING *`,
        [id],
      );
      await repo.insertStatusHistory(client, { id: newUuid(), appointmentId: id, fromStatus: current.status, toStatus: '已过期', changedBy: null, reason: '改期确认超时' });
      return { expired: true, row: updated.rows[0] } as const;
    }
    const updated = await client.query<AppointmentRow>(
      `UPDATE appointments SET status = '待审核', reschedule_proposed_at = NULL, updated_at = now() WHERE id = $1 RETURNING *`,
      [id],
    );
    await repo.insertStatusHistory(client, { id: newUuid(), appointmentId: id, fromStatus: current.status, toStatus: '待审核', changedBy: null, reason: '访客确认改期' });
    await writeAudit(client, {
      userId: null, userName: current.visitor_name ?? '访客', objectType: 'appointment', objectId: id,
      action: '改期', result: '成功', before: { status: current.status, reschedule_proposed_at: iso(current.reschedule_proposed_at) }, after: { status: '待审核' }, note: '访客确认改期',
    });
    return { expired: false, row: updated.rows[0] } as const;
  });
  if (result.expired) throw conflict(COPY.STATE_CONFLICT);
  await safeNotify(() => notifyReviewerTemplate(result.row, '改期确认结果', { visitorName: result.row.visitor_name ?? '访客' }));
  return { status: result.row.status };
}

export async function rescheduleVisitorAppointment(
  id: string,
  input: Record<string, unknown>,
  visitorAppointmentId: string,
  path?: string,
) {
  const bound = await boundAppointment(visitorAppointmentId);
  const start = parseDateValue(input.visit_start);
  if (!start) throw unprocessable(COPY.START_REQUIRED, 'visit_start');
  const end = parseDateValue(input.visit_end);
  if (!end) throw unprocessable(COPY.END_REQUIRED, 'visit_end');
  const row = await withTransaction(async (client) => {
    const current = await repo.findAppointmentById(id, client, true);
    if (!current) throw notFound(MESSAGES.NOT_FOUND);
    await assertOwnedByToken(current, bound, path);
    assertRescheduleEligible(current.status);
    const minMinutes = await configNumber('min_stay_minutes', 15);
    const maxMinutes = await configNumber('max_stay_minutes', 240);
    validateVisitWindow(start, end, new Date(), minMinutes, maxMinutes, false);
    await validateSchedule(start, end, new Date());
    if (current.visitor_id_no) {
      const overlap = await repo.findOverlappingOpenAppointment(client, current.visitor_id_no, start, end, id);
      if (overlap) throw unprocessable(COPY.DUPLICATE, 'visit_start');
    }
    const updated = await client.query<AppointmentRow>(
      `UPDATE appointments SET visit_start = $2, visit_end = $3, status = '待审核', reschedule_proposed_at = NULL, updated_at = now() WHERE id = $1 RETURNING *`,
      [id, start, end],
    );
    await repo.insertStatusHistory(client, { id: newUuid(), appointmentId: id, fromStatus: current.status, toStatus: '待审核', changedBy: null, reason: '访客发起改期' });
    await writeAudit(client, {
      userId: null, userName: current.visitor_name ?? '访客', objectType: 'appointment', objectId: id,
      action: '改期', result: '成功', before: { visit_start: iso(current.visit_start), visit_end: iso(current.visit_end), status: current.status }, after: { visit_start: start.toISOString(), visit_end: end.toISOString(), status: '待审核', path: path ?? null },
    });
    return updated.rows[0];
  });
  await safeNotify(() => notifyReviewer(row, { visitorName: row.visitor_name ?? '访客' }));
  return { status: row.status, visit_start: iso(row.visit_start), visit_end: iso(row.visit_end), reschedule_deadline: null };
}

export async function cancelVisitorAppointment(
  id: string,
  input: Record<string, unknown>,
  visitorAppointmentId: string,
  path?: string,
) {
  const bound = await boundAppointment(visitorAppointmentId);
  const reason = typeof input.reason === 'string' && input.reason.trim() ? input.reason.trim().slice(0, 200) : null;
  const row = await withTransaction(async (client) => {
    const current = await repo.findAppointmentById(id, client, true);
    if (!current) throw notFound(MESSAGES.NOT_FOUND);
    await assertOwnedByToken(current, bound, path);
    assertTransition(current.status, '已取消');
    const updated = await client.query<AppointmentRow>(
      `UPDATE appointments SET status = '已取消', cancel_reason = $2, updated_at = now() WHERE id = $1 RETURNING *`,
      [id, reason],
    );
    await repo.insertStatusHistory(client, { id: newUuid(), appointmentId: id, fromStatus: current.status, toStatus: '已取消', changedBy: null, reason: reason ?? '访客取消预约' });
    await writeAudit(client, {
      userId: null, userName: current.visitor_name ?? '访客', objectType: 'appointment', objectId: id,
      action: '取消预约', result: '成功', before: { status: current.status }, after: { status: '已取消', cancel_reason: reason, path: path ?? null },
    });
    return updated.rows[0];
  });
  await safeNotify(() => notifyReviewer(row, { visitorName: row.visitor_name ?? '访客' }));
  return { status: row.status, cancel_reason: row.cancel_reason };
}

export async function getVisitorFormOptions() {
  const [visitorTypes, hosts, gates, relations] = await Promise.all([
    getActiveVisitorTypes(),
    getActiveHosts(),
    getActiveGates(),
    getDictionaryItems('随行关系'),
  ]);
  return { visitor_types: visitorTypes, hosts, gates, relations };
}

export function rescheduleInfo(row: AppointmentRow) {
  if (!row.reschedule_proposed_at) return null;
  return {
    proposed_at: iso(row.reschedule_proposed_at),
    deadline: rescheduleDeadline(new Date(row.reschedule_proposed_at)).toISOString(),
  };
}
