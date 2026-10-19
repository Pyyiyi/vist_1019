import { writeAudit } from '../../../shared/audit/writeAudit.js';
import { MESSAGES } from '../../../shared/constants/messages.js';
import { withTransaction } from '../../../shared/db/pool.js';
import { conflict, notFound, unprocessable } from '../../../shared/http/errors.js';
import { parsePagination } from '../../../shared/http/pagination.js';
import { nextAppointmentNo, generateShortCode } from '../../../shared/utils/appointmentNo.js';
import { newUuid } from '../../../shared/utils/ids.js';
import {
  checkBlacklist,
  getActiveGates,
  getActiveHosts,
  getActiveVisitorTypes,
  getConfigNumber,
  getDictionaryItems,
  getTimeRules,
  resolveReviewer,
  timeRuleDecision,
} from '../../master/index.js';
import * as repo from './repo.js';
import { insertConsents } from './consent.service.js';
import {
  COPY,
  assertRescheduleEligible,
  assertTransition,
  parseDateValue,
  shanghaiDateKey,
  shanghaiHms,
  shanghaiWeekday,
  validateMainVisitor,
  validateReason,
  validateVisitWindow,
  normalizeCompanions,
} from './domain/rules.js';
import { assertCanRead } from './scope.js';
import { notifyBlacklist, notifyReviewer, notifyVisitor, safeNotify } from './notifications.js';
import type { Actor, AppointmentRow } from './types.js';
import { iso, toAppointmentDto, toCompanionDto, toCredentialDto, toHistoryDto } from './types.js';

type AppointmentPayload = Record<string, unknown>;
type ValidationOptions = { allowPast?: boolean; skipSchedule?: boolean; now?: Date };
type Enrichment = {
  hostNames: Map<string, string>;
  visitorTypeNames: Map<string, string>;
  gateNames: Map<string, string>;
};

async function loadEnrichment(): Promise<Enrichment> {
  const [hosts, types, gates] = await Promise.all([
    getActiveHosts(),
    getActiveVisitorTypes(),
    getActiveGates(),
  ]);
  return {
    hostNames: new Map(hosts.map((item) => [item.id, item.name])),
    visitorTypeNames: new Map(types.map((item) => [item.id, item.name])),
    gateNames: new Map(gates.map((item) => [item.id, item.name])),
  };
}

function enrich(row: AppointmentRow, enrichment: Enrichment): AppointmentRow & { host_name: string; visitor_type_name: string; gate_name: string | null } {
  return Object.assign(row, {
    host_name: enrichment.hostNames.get(row.host_id) ?? row.host_id,
    visitor_type_name: enrichment.visitorTypeNames.get(row.visitor_type_id) ?? row.visitor_type_id,
    gate_name: row.expected_gate_id ? enrichment.gateNames.get(row.expected_gate_id) ?? row.expected_gate_id : null,
  });
}

function publicDto(row: AppointmentRow, enrichment: Enrichment): ReturnType<typeof toAppointmentDto> {
  const enriched = enrich(row, enrichment);
  return toAppointmentDto(row, {
    host_name: enriched.host_name,
    visitor_type_name: enriched.visitor_type_name,
    gate_name: enriched.gate_name,
  });
}

export async function getFormOptions() {
  const [visitorTypes, hosts, gates, relations] = await Promise.all([
    getActiveVisitorTypes(),
    getActiveHosts(),
    getActiveGates(),
    getDictionaryItems('随行关系'),
  ]);
  return { visitor_types: visitorTypes, hosts, gates, relations };
}

export async function configNumber(key: string, fallback: number): Promise<number> {
  try {
    const value = await getConfigNumber(key);
    return Number.isFinite(value) && value > 0 ? value : fallback;
  } catch {
    return fallback;
  }
}

export async function validateSchedule(start: Date, end: Date, now: Date): Promise<void> {
  const rules = await getTimeRules();
  const decision = timeRuleDecision(rules, {
    weekday: shanghaiWeekday(start),
    startTime: shanghaiHms(start),
    endTime: shanghaiHms(end),
  });
  if (!decision.allowed) {
    throw unprocessable(decision.reason === 'deny' ? COPY.DENY_RULE : COPY.OUTSIDE_ALLOWED, 'visit_start');
  }
}

type ValidatedAppointment = {
  visitorName: string;
  visitorPhone: string;
  visitorIdNo: string;
  visitorTypeId: string;
  hostId: string;
  expectedGateId: string | null;
  visitStart: Date;
  visitEnd: Date;
  reason: string;
  plateNo: string | null;
  companions: Array<{ name: string; relation: string; id_no: string; sort_order: number }>;
  reviewerId: string | null;
  blackHit: boolean;
};

export async function validateAppointmentPayload(
  input: AppointmentPayload,
  options: ValidationOptions = {},
): Promise<ValidatedAppointment> {
  const now = options.now ?? new Date();
  const visitor = validateMainVisitor(input);
  const visitorTypeId = typeof input.visitor_type_id === 'string' ? input.visitor_type_id.trim() : '';
  if (!visitorTypeId) throw unprocessable(COPY.TYPE_REQUIRED, 'visitor_type_id');
  const hostId = typeof input.host_id === 'string' ? input.host_id.trim() : '';
  if (!hostId) throw unprocessable(COPY.HOST_REQUIRED, 'host_id');
  const start = parseDateValue(input.visit_start);
  if (!start) throw unprocessable(COPY.START_REQUIRED, 'visit_start');
  const end = parseDateValue(input.visit_end);
  if (!end) throw unprocessable(COPY.END_REQUIRED, 'visit_end');
  const minMinutes = await configNumber('min_stay_minutes', 15);
  const maxMinutes = await configNumber('max_stay_minutes', 240);
  validateVisitWindow(start, end, now, minMinutes, maxMinutes, options.allowPast ?? false);
  if (!options.skipSchedule) await validateSchedule(start, end, now);
  const reason = validateReason(input.reason);
  const plateNo = typeof input.plate_no === 'string' && input.plate_no.trim() ? input.plate_no.trim() : null;
  if (plateNo && Array.from(plateNo).length > 20) throw unprocessable('车牌号不能超过 20 个字符', 'plate_no');
  const maxCompanions = await configNumber('max_companions', 10);
  const companions = normalizeCompanions(input.companions, maxCompanions);
  const expectedGateId = typeof input.expected_gate_id === 'string' && input.expected_gate_id.trim()
    ? input.expected_gate_id.trim()
    : null;
  const blacklist = await checkBlacklist([visitor.idNo, ...companions.map((item) => item.id_no)], now);
  const reviewerId = await resolveReviewer({
    visitorTypeId,
    expectedGateId,
    visitStart: start.toISOString(),
    hostId,
  });
  return {
    visitorName: visitor.name,
    visitorPhone: visitor.phone,
    visitorIdNo: visitor.idNo,
    visitorTypeId,
    hostId,
    expectedGateId,
    visitStart: start,
    visitEnd: end,
    reason,
    plateNo,
    companions,
    reviewerId,
    blackHit: blacklist.hit,
  };
}

export type CreateAppointmentContext = {
  actor: Actor | null;
  createdBy: string | null;
  channel: 'H5' | '后台代提';
  ip: string | null;
};

export async function createAppointment(input: AppointmentPayload, context: CreateAppointmentContext) {
  const validated = await validateAppointmentPayload(input);
  const { row, credential } = await withTransaction(async (client) => {
    await client.query('SELECT pg_advisory_xact_lock(hashtext($1))', [`appointment:${validated.visitorIdNo}`]);
    const overlap = await repo.findOverlappingOpenAppointment(
      client,
      validated.visitorIdNo,
      validated.visitStart,
      validated.visitEnd,
    );
    if (overlap) throw unprocessable(COPY.DUPLICATE, 'visit_start');

    const id = newUuid();
    const appointNo = await nextAppointmentNo(client);
    const shortCode = await generateShortCode(client);
    const inserted = await client.query<AppointmentRow>(
      `INSERT INTO appointments (
         id, appoint_no, visitor_type_id, visitor_name, visitor_phone, visitor_id_no,
         host_id, reviewer_id, expected_gate_id, visit_start, visit_end, reason, plate_no,
         status, people_count, black_hit, created_by
       ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, '待审核', $14, $15, $16)
       RETURNING *`,
      [
        id, appointNo, validated.visitorTypeId, validated.visitorName, validated.visitorPhone,
        validated.visitorIdNo, validated.hostId, validated.reviewerId, validated.expectedGateId,
        validated.visitStart, validated.visitEnd, validated.reason, validated.plateNo,
        validated.companions.length + 1, validated.blackHit, context.createdBy,
      ],
    );
    for (const companion of validated.companions) {
      await client.query(
        `INSERT INTO companions (id, appointment_id, name, relation, id_no, sort_order)
         VALUES ($1, $2, $3, $4, $5, $6)`,
        [newUuid(), id, companion.name, companion.relation, companion.id_no, companion.sort_order],
      );
    }
    const insertedCredential = await client.query(
      `INSERT INTO visit_credentials (id, appointment_id, short_code, usage_status)
       VALUES ($1, $2, $3, '未使用') RETURNING *`,
      [newUuid(), id, shortCode],
    );
    await insertConsents(client, id, context.channel);
    await repo.insertStatusHistory(client, {
      id: newUuid(), appointmentId: id, fromStatus: null, toStatus: '待审核',
      changedBy: context.actor?.id ?? null, reason: '提交预约',
    });
    await writeAudit(client, {
      userId: context.actor?.id ?? null,
      userName: context.actor?.displayName ?? validated.visitorName,
      objectType: 'appointment',
      objectId: id,
      action: '新增预约',
      result: '成功',
      before: { existed: false },
      after: {
        appoint_no: appointNo,
        visitor_name: validated.visitorName,
        visitor_id_no: validated.visitorIdNo,
        host_id: validated.hostId,
        visit_start: validated.visitStart.toISOString(),
        visit_end: validated.visitEnd.toISOString(),
        status: '待审核',
        black_hit: validated.blackHit,
      },
      ip: context.ip,
    });
    return { row: inserted.rows[0], credential: insertedCredential.rows[0] };
  }).catch((error: unknown) => {
    const pgError = error as { code?: string; constraint?: string };
    if (pgError.code === '23505') {
      if (pgError.constraint === 'uq_appointments_visitor_slot') throw unprocessable(COPY.DUPLICATE, 'visit_start');
      throw conflict(COPY.STATE_CONFLICT);
    }
    throw error;
  });

  const enrichment = await loadEnrichment();
  const dto = {
    ...publicDto(row, enrichment),
    short_code: credential?.short_code ?? null,
    credential: credential ? toCredentialDto(credential) : null,
    black_hit: validated.blackHit,
  };
  await safeNotify(async () => {
    if (validated.blackHit) {
      await notifyBlacklist(row, validated.visitorIdNo.slice(0, 4) + '**********' + validated.visitorIdNo.slice(-4));
    }
    await notifyReviewer(row, {
      visitorName: validated.visitorName,
      visitStart: iso(row.visit_start) ?? undefined,
      visitEnd: iso(row.visit_end) ?? undefined,
    });
  });
  return dto;
}

export async function listAppointments(query: Record<string, unknown>, actor: Actor) {
  const pagination = parsePagination(query, 20, 100);
  const result = await repo.listAppointments({
    pageSize: pagination.pageSize,
    offset: pagination.offset,
    status: typeof query.status === 'string' && query.status ? query.status : null,
    visitorName: typeof query.visitor_name === 'string' ? query.visitor_name.trim() : '',
    dateFrom: typeof query.date_from === 'string' && query.date_from ? query.date_from : null,
    dateTo: typeof query.date_to === 'string' && query.date_to ? query.date_to : null,
    actor,
  });
  const enrichment = await loadEnrichment();
  return {
    items: result.rows.map((row) => publicDto(row, enrichment)),
    total: result.total,
    page: pagination.page,
    page_size: pagination.pageSize,
  };
}

export async function getAppointmentDetail(
  id: string,
  actor: Actor,
  ip: string | null,
  path?: string,
  options: { enforceScope?: boolean } = { enforceScope: true },
) {
  const row = await repo.findAppointmentById(id);
  if (!row) throw notFound(MESSAGES.NOT_FOUND);
  if (options.enforceScope !== false) await assertCanRead(actor, row, ip, path);
  const [companions, history, credential, enrichment] = await Promise.all([
    repo.findCompanions(id),
    repo.findHistory(id),
    repo.findCredential(id),
    loadEnrichment(),
  ]);
  return {
    ...publicDto(row, enrichment),
    companions: companions.map(toCompanionDto),
    history: history.map(toHistoryDto),
    credential: credential ? toCredentialDto(credential) : null,
  };
}

export async function rescheduleAppointment(
  id: string,
  input: AppointmentPayload,
  actor: Actor,
  ip: string | null,
  mode: 'proposal' | 'visitor',
  path?: string,
) {
  const start = parseDateValue(input.visit_start);
  if (!start) throw unprocessable(COPY.START_REQUIRED, 'visit_start');
  const end = parseDateValue(input.visit_end);
  if (!end) throw unprocessable(COPY.END_REQUIRED, 'visit_end');
  const result = await withTransaction(async (client) => {
    const row = await repo.findAppointmentById(id, client, true);
    if (!row) throw notFound(MESSAGES.NOT_FOUND);
    await assertCanRead(actor, row, ip, path);
    const target = mode === 'proposal' ? '已改期' : '待审核';
    assertRescheduleEligible(row.status);
    const minMinutes = await configNumber('min_stay_minutes', 15);
    const maxMinutes = await configNumber('max_stay_minutes', 240);
    validateVisitWindow(start, end, new Date(), minMinutes, maxMinutes, false);
    await validateSchedule(start, end, new Date());
    if (row.visitor_id_no) {
      const overlap = await repo.findOverlappingOpenAppointment(client, row.visitor_id_no, start, end, id);
      if (overlap) throw unprocessable(COPY.DUPLICATE, 'visit_start');
    }
    const proposedAt = mode === 'proposal' ? new Date() : null;
    const updated = await client.query<AppointmentRow>(
      `UPDATE appointments
          SET visit_start = $2, visit_end = $3, status = $4,
              reschedule_proposed_at = $5, updated_at = now()
        WHERE id = $1 RETURNING *`,
      [id, start, end, target, proposedAt],
    );
    await repo.insertStatusHistory(client, {
      id: newUuid(), appointmentId: id, fromStatus: row.status, toStatus: target,
      changedBy: actor.id, reason: mode === 'proposal' ? COPY.RESCHEDULE_REASON : '访客发起改期',
    });
    await writeAudit(client, {
      userId: actor.id, userName: actor.displayName, objectType: 'appointment', objectId: id,
      action: '改期', result: '成功',
      before: {
        visit_start: iso(row.visit_start), visit_end: iso(row.visit_end), status: row.status,
        reschedule_proposed_at: iso(row.reschedule_proposed_at),
      },
      after: {
        visit_start: start.toISOString(), visit_end: end.toISOString(), status: target,
        reschedule_proposed_at: proposedAt?.toISOString() ?? null,
      },
      ip,
    });
    return updated.rows[0];
  });
  const enrichment = await loadEnrichment();
  await safeNotify(async () => {
    if (mode === 'proposal') await notifyVisitor(result, '改期提议', { timeoutHours: 3 });
    else await notifyReviewer(result, { visitorName: result.visitor_name ?? '访客' });
  });
  return publicDto(result, enrichment);
}

export async function cancelAppointment(
  id: string,
  reason: unknown,
  actor: Actor,
  ip: string | null,
  path?: string,
  actorKind: 'staff' | 'visitor' = 'staff',
) {
  const cancelReason = typeof reason === 'string' && reason.trim() ? reason.trim().slice(0, 200) : null;
  const row = await withTransaction(async (client) => {
    const current = await repo.findAppointmentById(id, client, true);
    if (!current) throw notFound(MESSAGES.NOT_FOUND);
    await assertCanRead(actor, current, ip, path);
    assertTransition(current.status, '已取消');
    const updated = await client.query<AppointmentRow>(
      `UPDATE appointments SET status = '已取消', cancel_reason = $2, updated_at = now()
        WHERE id = $1 RETURNING *`,
      [id, cancelReason],
    );
    await repo.insertStatusHistory(client, {
      id: newUuid(), appointmentId: id, fromStatus: current.status, toStatus: '已取消',
      changedBy: actor.id, reason: cancelReason ?? '取消预约',
    });
    await writeAudit(client, {
      userId: actor.id, userName: actor.displayName, objectType: 'appointment', objectId: id,
      action: '取消预约', result: '成功',
      before: { status: current.status, cancel_reason: current.cancel_reason },
      after: { status: '已取消', cancel_reason: cancelReason }, ip,
    });
    return updated.rows[0];
  });
  await safeNotify(async () => {
    if (actorKind === 'staff') await notifyVisitor(row, '审核结果', { result: '拒绝', reason: cancelReason ?? '预约已取消' });
    else await notifyReviewer(row, { visitorName: row.visitor_name ?? '访客' });
  });
  return { status: row.status, cancel_reason: row.cancel_reason };
}
