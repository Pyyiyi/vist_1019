import { writeAudit } from '../../../shared/audit/writeAudit.js';
import { MESSAGES } from '../../../shared/constants/messages.js';
import { INCIDENT_TYPES as ALL_INCIDENT_TYPES } from '../../../shared/constants/status.js';
import { query, withTransaction } from '../../../shared/db/pool.js';
import { conflict, notFound, unprocessable } from '../../../shared/http/errors.js';
import { parsePagination } from '../../../shared/http/pagination.js';
import { localDayRange, newUuid } from '../../../shared/utils/ids.js';
import { generateShortCode, nextAppointmentNo } from '../../../shared/utils/appointmentNo.js';
import { getActiveGates, getActiveHosts, getActiveVisitorTypes, getDictionaryItems, checkBlacklist } from '../../master/index.js';
import * as repo from './repo.js';
import { validateAppointmentPayload, configNumber } from './appointment.service.js';
import { insertConsents, assertConsents } from './consent.service.js';
import {
  COPY,
  assertTransition,
  inVerifyWindow,
  parseDateValue,
  sameShanghaiDayAsNow,
} from './domain/rules.js';
import { notifyBlacklist, safeNotify } from './notifications.js';
import type { Actor, AppointmentRow, CredentialRow, IncidentRow } from './types.js';
import {
  iso,
  toAppointmentDto,
  toCompanionDto,
  toIncidentDto,
  toCredentialDto,
} from './types.js';

type GateContext = { actor: Actor; ip: string | null };

type Enrichment = { hostNames: Map<string, string>; visitorTypeNames: Map<string, string>; gateNames: Map<string, string> };

async function enrichment(): Promise<Enrichment> {
  const [hosts, types, gates] = await Promise.all([getActiveHosts(), getActiveVisitorTypes(), getActiveGates()]);
  return {
    hostNames: new Map(hosts.map((x) => [x.id, x.name])),
    visitorTypeNames: new Map(types.map((x) => [x.id, x.name])),
    gateNames: new Map(gates.map((x) => [x.id, x.name])),
  };
}

async function appointmentDto(row: AppointmentRow, map?: Enrichment) {
  const data = map ?? (await enrichment());
  return toAppointmentDto(row, {
    host_name: data.hostNames.get(row.host_id) ?? row.host_id,
    visitor_type_name: data.visitorTypeNames.get(row.visitor_type_id) ?? row.visitor_type_id,
    gate_name: row.expected_gate_id ? data.gateNames.get(row.expected_gate_id) ?? row.expected_gate_id : null,
  });
}

async function assertGate(gateId: string): Promise<void> {
  if (!gateId) throw unprocessable('请选择校门', 'gate_id');
  const gates = await getActiveGates();
  if (!gates.some((gate) => gate.id === gateId)) throw unprocessable('请选择校门', 'gate_id');
}

async function auditVerify(row: AppointmentRow | null, actor: Actor, ip: string | null, result: '通过' | '失败', note: string, code: string): Promise<void> {
  await writeAudit({
    userId: actor.id,
    userName: actor.displayName,
    objectType: 'appointment',
    objectId: row?.id ?? null,
    action: '核验',
    result: result as '成功' | '失败' | '拒绝',
    before: { code },
    after: row ? { status: row.status, appoint_no: row.appoint_no } : null,
    note,
    ip,
  });
}

async function allIdNos(row: AppointmentRow): Promise<string[]> {
  const companions = await repo.findCompanions(row.id);
  return [row.visitor_id_no, ...companions.map((item) => item.id_no)].filter((value): value is string => Boolean(value));
}

export async function verifyCode(input: Record<string, unknown>, context: GateContext) {
  const code = typeof input.code === 'string' ? input.code.trim() : '';
  if (!code) throw unprocessable('请输入预约编号或 6 位短码', 'code');
  const gateId = typeof input.gate_id === 'string' ? input.gate_id.trim() : '';
  await assertGate(gateId);
  const row = await repo.findAppointmentByCode(code);
  if (!row) {
    await auditVerify(null, context.actor, context.ip, '失败', '凭证未找到', code);
    throw notFound(MESSAGES.NOT_FOUND);
  }
  const credential = await repo.findCredential(row.id);
  const blacklist = await checkBlacklist(await allIdNos(row));
  if (blacklist.hit) {
    await auditVerify(row, context.actor, context.ip, '失败', '黑名单命中', code);
    return { allowed: false, reason: 'blacklist', message: COPY.GATE_BLACKLIST, mode: 'blocked', appointment: await appointmentDto(row), credential: credential ? toCredentialDto(credential) : null };
  }

  if (row.status === '已到访(在校中)') {
    await auditVerify(row, context.actor, context.ip, '失败', '重复核销', code);
    throw conflict(MESSAGES.DUPLICATE_CHECKIN);
  }
  if (row.status === '已过期') {
    await auditVerify(row, context.actor, context.ip, '失败', '预约已过期', code);
    throw conflict(COPY.GATE_EXPIRED);
  }
  if (row.status === '已离校') {
    if (!sameShanghaiDayAsNow(row.visit_end instanceof Date ? row.visit_end : new Date(row.visit_end), new Date())) {
      await auditVerify(row, context.actor, context.ip, '失败', '已离校跨日再次核验', code);
      throw conflict(MESSAGES.DUPLICATE_CHECKIN);
    }
    await auditVerify(row, context.actor, context.ip, '通过', '当日再次进校核验', code);
    return { allowed: true, reason: 'reenter', message: COPY.GATE_PASS, mode: 'reenter', appointment: await appointmentDto(row), credential: credential ? toCredentialDto(credential) : null, gate_id: gateId };
  }
  if (!['已通过', '待审核', '已改期'].includes(row.status)) {
    await auditVerify(row, context.actor, context.ip, '失败', `状态不允许核验：${row.status}`, code);
    throw conflict(COPY.STATE_CONFLICT);
  }
  let buffer = 15;
  try { buffer = await configNumber('verification_buffer_minutes', 15); } catch { buffer = 15; }
  const now = new Date();
  const start = row.visit_start instanceof Date ? row.visit_start : new Date(row.visit_start);
  const end = row.visit_end instanceof Date ? row.visit_end : new Date(row.visit_end);
  if (!inVerifyWindow(start, end, now, buffer)) {
    await auditVerify(row, context.actor, context.ip, '失败', '不在核验窗口', code);
    throw conflict(COPY.GATE_OUT_OF_WINDOW);
  }
  if (row.status !== '已通过') {
    await auditVerify(row, context.actor, context.ip, '失败', '预约尚未审核通过', code);
    throw conflict(COPY.GATE_NOT_APPROVED);
  }
  if (credential?.usage_status === '已使用') {
    await auditVerify(row, context.actor, context.ip, '失败', '凭证已核销', code);
    throw conflict(MESSAGES.DUPLICATE_CHECKIN);
  }
  await auditVerify(row, context.actor, context.ip, '通过', '核验窗口内', code);
  return { allowed: true, reason: 'verified', message: COPY.GATE_PASS, mode: 'admit', appointment: await appointmentDto(row), credential: credential ? toCredentialDto(credential) : null, gate_id: gateId };
}

export async function admitCode(input: Record<string, unknown>, context: GateContext) {
  const code = typeof input.code === 'string' ? input.code.trim() : '';
  if (!code) throw unprocessable('请输入预约编号或 6 位短码', 'code');
  const gateId = typeof input.gate_id === 'string' ? input.gate_id.trim() : '';
  await assertGate(gateId);
  const row = await withTransaction(async (client) => {
    const current = await repo.findAppointmentByCode(code, client, true);
    if (!current) throw notFound(MESSAGES.NOT_FOUND);
    const blacklist = await checkBlacklist(await allIdNos(current));
    if (blacklist.hit) {
      await writeAudit(client, { userId: context.actor.id, userName: context.actor.displayName, objectType: 'appointment', objectId: current.id, action: '放行', result: '拒绝', before: { status: current.status }, note: '黑名单硬拦截', ip: context.ip });
      throw conflict(COPY.GATE_BLACKLIST);
    }
    const credential = await repo.findCredential(current.id, client);
    const now = new Date();
    if (current.status === '已到访(在校中)') throw conflict(MESSAGES.DUPLICATE_CHECKIN);
    if (current.status === '待审核') throw conflict(COPY.GATE_NOT_APPROVED);
    if (current.status === '已过期') throw conflict(COPY.GATE_EXPIRED);
    if (current.status === '已离校') {
      if (!sameShanghaiDayAsNow(current.visit_end instanceof Date ? current.visit_end : new Date(current.visit_end), now)) {
        throw conflict(MESSAGES.DUPLICATE_CHECKIN);
      }
      const updated = await client.query<AppointmentRow>(
        `UPDATE appointments SET status = '已到访(在校中)', checkin_at = $2, checkout_at = NULL, updated_at = now() WHERE id = $1 RETURNING *`,
        [current.id, now],
      );
      await client.query(
        `INSERT INTO passage_records (id, appointment_id, gate_id, record_type, occurred_at, operator_id) VALUES ($1, $2, $3, '进校', $4, $5)`,
        [newUuid(), current.id, gateId, now, context.actor.id],
      );
      await repo.insertStatusHistory(client, { id: newUuid(), appointmentId: current.id, fromStatus: current.status, toStatus: '已到访(在校中)', changedBy: context.actor.id, reason: '再次进校' });
      await writeAudit(client, { userId: context.actor.id, userName: context.actor.displayName, objectType: 'appointment', objectId: current.id, action: '放行', result: '成功', before: { status: current.status, checkout_at: iso(current.checkout_at) }, after: { status: '已到访(在校中)', checkin_at: now.toISOString(), gate_id: gateId, reenter: true }, ip: context.ip });
      return updated.rows[0];
    }
    if (current.status !== '已通过') throw conflict(COPY.STATE_CONFLICT);
    if (!credential || credential.usage_status !== '未使用') throw conflict(MESSAGES.DUPLICATE_CHECKIN);
    let buffer = 15;
    try { buffer = await configNumber('verification_buffer_minutes', 15); } catch { buffer = 15; }
    const start = current.visit_start instanceof Date ? current.visit_start : new Date(current.visit_start);
    const end = current.visit_end instanceof Date ? current.visit_end : new Date(current.visit_end);
    if (!inVerifyWindow(start, end, now, buffer)) throw conflict(COPY.GATE_OUT_OF_WINDOW);
    await client.query(`UPDATE visit_credentials SET usage_status = '已使用', used_at = $2 WHERE appointment_id = $1`, [current.id, now]);
    const updated = await client.query<AppointmentRow>(
      `UPDATE appointments SET status = '已到访(在校中)', checkin_at = $2, updated_at = now() WHERE id = $1 RETURNING *`,
      [current.id, now],
    );
    await client.query(
      `INSERT INTO passage_records (id, appointment_id, gate_id, record_type, occurred_at, operator_id) VALUES ($1, $2, $3, '进校', $4, $5)`,
      [newUuid(), current.id, gateId, now, context.actor.id],
    );
    await repo.insertStatusHistory(client, { id: newUuid(), appointmentId: current.id, fromStatus: current.status, toStatus: '已到访(在校中)', changedBy: context.actor.id, reason: '核验放行' });
    await writeAudit(client, { userId: context.actor.id, userName: context.actor.displayName, objectType: 'appointment', objectId: current.id, action: '放行', result: '成功', before: { status: current.status, usage_status: credential.usage_status }, after: { status: '已到访(在校中)', checkin_at: now.toISOString(), gate_id: gateId, usage_status: '已使用' }, ip: context.ip });
    return updated.rows[0];
  });
  return { status: row.status, checkin_at: iso(row.checkin_at), appointment: await appointmentDto(row) };
}

export async function departCode(input: Record<string, unknown>, context: GateContext) {
  const code = typeof input.code === 'string' ? input.code.trim() : '';
  if (!code) throw unprocessable('请输入预约编号或 6 位短码', 'code');
  const gateId = typeof input.gate_id === 'string' ? input.gate_id.trim() : '';
  await assertGate(gateId);
  const row = await withTransaction(async (client) => {
    const current = await repo.findAppointmentByCode(code, client, true);
    if (!current) throw notFound(MESSAGES.NOT_FOUND);
    if (current.status !== '已到访(在校中)') throw conflict(COPY.STATE_CONFLICT);
    assertTransition(current.status, '已离校');
    const now = new Date();
    const updated = await client.query<AppointmentRow>(
      `UPDATE appointments SET status = '已离校', checkout_at = $2, updated_at = now() WHERE id = $1 RETURNING *`,
      [current.id, now],
    );
    await client.query(
      `INSERT INTO passage_records (id, appointment_id, gate_id, record_type, occurred_at, operator_id) VALUES ($1, $2, $3, '离校', $4, $5)`,
      [newUuid(), current.id, gateId, now, context.actor.id],
    );
    await repo.insertStatusHistory(client, { id: newUuid(), appointmentId: current.id, fromStatus: current.status, toStatus: '已离校', changedBy: context.actor.id, reason: '离校登记' });
    await writeAudit(client, { userId: context.actor.id, userName: context.actor.displayName, objectType: 'appointment', objectId: current.id, action: '离校', result: '成功', before: { status: current.status, checkin_at: iso(current.checkin_at) }, after: { status: '已离校', checkout_at: now.toISOString(), gate_id: gateId }, ip: context.ip });
    return updated.rows[0];
  });
  return { status: row.status, checkout_at: iso(row.checkout_at), appointment: await appointmentDto(row) };
}

export async function walkIn(input: Record<string, unknown>, context: GateContext) {
  const gateId = typeof input.gate_id === 'string' ? input.gate_id.trim() : '';
  await assertGate(gateId);
  assertConsents((input.consent ?? input.consents) as { safety?: unknown; privacy?: unknown } | undefined);
  const now = new Date();
  const end = new Date(now.getTime() + 60 * 60_000);
  const validated = await validateAppointmentPayload(
    { ...input, visit_start: now.toISOString(), visit_end: end.toISOString() },
    { allowPast: true, skipSchedule: true, now },
  );
  if (validated.blackHit) {
    await writeAudit({ userId: context.actor.id, userName: context.actor.displayName, objectType: 'appointment', objectId: null, action: '现场登记', result: '拒绝', after: { visitor_name: validated.visitorName, visitor_id_no: validated.visitorIdNo, gate_id: gateId }, note: '黑名单硬拦截', ip: context.ip });
    throw conflict(COPY.GATE_BLACKLIST);
  }
  const row = await withTransaction(async (client) => {
    await client.query('SELECT pg_advisory_xact_lock(hashtext($1))', [`appointment:${validated.visitorIdNo}`]);
    const overlap = await repo.findOverlappingOpenAppointment(client, validated.visitorIdNo, now, end);
    if (overlap) throw unprocessable(COPY.DUPLICATE, 'visit_start');
    const id = newUuid();
    const appointNo = await nextAppointmentNo(client);
    const shortCode = await generateShortCode(client);
    const inserted = await client.query<AppointmentRow>(
      `INSERT INTO appointments (
         id, appoint_no, visitor_type_id, visitor_name, visitor_phone, visitor_id_no,
         host_id, reviewer_id, expected_gate_id, visit_start, visit_end, reason, plate_no,
         status, people_count, black_hit, checkin_at, created_by
       ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, '已到访(在校中)', $14, false, $15, $16)
       RETURNING *`,
      [id, appointNo, validated.visitorTypeId, validated.visitorName, validated.visitorPhone, validated.visitorIdNo, validated.hostId, validated.reviewerId, gateId, now, end, validated.reason, validated.plateNo, validated.companions.length + 1, now, context.actor.id],
    );
    for (const companion of validated.companions) {
      await client.query(
        `INSERT INTO companions (id, appointment_id, name, relation, id_no, sort_order) VALUES ($1, $2, $3, $4, $5, $6)`,
        [newUuid(), id, companion.name, companion.relation, companion.id_no, companion.sort_order],
      );
    }
    const credential = await client.query<CredentialRow>(
      `INSERT INTO visit_credentials (id, appointment_id, short_code, usage_status, used_at)
       VALUES ($1, $2, $3, '已使用', $4) RETURNING *`,
      [newUuid(), id, shortCode, now],
    );
    await insertConsents(client, id, '现场登记', now);
    await client.query(
      `INSERT INTO passage_records (id, appointment_id, gate_id, record_type, occurred_at, operator_id) VALUES ($1, $2, $3, '进校', $4, $5)`,
      [newUuid(), id, gateId, now, context.actor.id],
    );
    await repo.insertStatusHistory(client, { id: newUuid(), appointmentId: id, fromStatus: null, toStatus: '已到访(在校中)', changedBy: context.actor.id, reason: '现场登记' });
    await writeAudit(client, { userId: context.actor.id, userName: context.actor.displayName, objectType: 'appointment', objectId: id, action: '现场登记', result: '成功', before: { existed: false }, after: { appoint_no: appointNo, visitor_name: validated.visitorName, visitor_id_no: validated.visitorIdNo, gate_id: gateId, status: '已到访(在校中)', short_code: shortCode }, ip: context.ip });
    return { appointment: inserted.rows[0], credential: credential.rows[0] };
  });
  const dto = {
    ...(await appointmentDto(row.appointment)),
    short_code: row.credential.short_code,
    credential: toCredentialDto(row.credential),
    status: row.appointment.status,
  };
  return dto;
}

export async function getGateToday() {
  const now = new Date();
  const range = localDayRange(now);
  const rows = await repo.listTodayAppointments(range.start, range.end);
  const map = await enrichment();
  const ids = rows.map((row) => row.id);
  const latestPassages = ids.length
    ? (await query<{ appointment_id: string; gate_id: string; record_type: string; occurred_at: Date | string }>(
        `SELECT DISTINCT ON (appointment_id) appointment_id, gate_id, record_type, occurred_at
           FROM passage_records
          WHERE appointment_id = ANY($1::varchar[])
          ORDER BY appointment_id, occurred_at DESC, id DESC`,
        [ids],
      )).rows
    : [];
  const passageByAppointment = new Map(latestPassages.map((item) => [item.appointment_id, item]));
  const items = await Promise.all(rows.map(async (row) => {
    const passage = passageByAppointment.get(row.id);
    return {
      ...(await appointmentDto(row, map)),
      last_gate_id: passage?.gate_id ?? null,
      last_gate_name: passage ? map.gateNames.get(passage.gate_id) ?? passage.gate_id : null,
      last_record_type: passage?.record_type ?? null,
      last_passage_at: iso(passage?.occurred_at ?? null),
      on_campus_minutes: row.status === '已到访(在校中)' && row.checkin_at
        ? Math.max(0, Math.floor((now.getTime() - new Date(row.checkin_at).getTime()) / 60_000))
        : null,
    };
  }));
  return {
    kpi: {
      today_appointments: rows.length,
      pending_verification: rows.filter((row) => row.status === '已通过').length,
      on_campus: rows.filter((row) => row.status === '已到访(在校中)').length,
      pending_incidents: await repo.countIncidents('待处理'),
    },
    appointments: items,
  };
}

export async function getGateFormOptions() {
  const [gates, relations, visitorTypes, hosts] = await Promise.all([
    getActiveGates(),
    getDictionaryItems('随行关系'),
    getActiveVisitorTypes(),
    getActiveHosts(),
  ]);
  return { gates, incident_types: [...ALL_INCIDENT_TYPES], relations, visitor_types: visitorTypes, hosts };
}

export async function listIncidents(queryParams: Record<string, unknown>) {
  const pagination = parsePagination(queryParams, 20, 100);
  const result = await repo.listIncidents({
    pageSize: pagination.pageSize,
    offset: pagination.offset,
    status: typeof queryParams.status === 'string' ? queryParams.status : null,
    type: typeof queryParams.type === 'string' ? queryParams.type : null,
  });
  return { items: result.rows.map(toIncidentDto), total: result.total, page: pagination.page, page_size: pagination.pageSize };
}

export async function createIncident(input: Record<string, unknown>, context: GateContext) {
  const type = typeof input.incident_type === 'string' ? input.incident_type : '';
  if (!(ALL_INCIDENT_TYPES as readonly string[]).includes(type)) throw unprocessable('请选择异常类型', 'incident_type');
  const description = typeof input.description === 'string' ? input.description.trim() : '';
  if (!description) throw unprocessable('请描述现场情况', 'description');
  if (Array.from(description).length > 500) throw unprocessable('异常说明不能超过 500 个字符', 'description');
  const code = typeof input.code === 'string' ? input.code.trim() : '';
  const appointment = code ? await repo.findAppointmentByCode(code) : null;
  const incident = await withTransaction(async (client) => {
    const inserted = await client.query<IncidentRow>(
      `INSERT INTO incidents (id, appointment_id, incident_type, status, description, reported_by)
       VALUES ($1, $2, $3, '待处理', $4, $5) RETURNING *`,
      [newUuid(), appointment?.id ?? null, type, description, context.actor.id],
    );
    await writeAudit(client, { userId: context.actor.id, userName: context.actor.displayName, objectType: 'incident', objectId: inserted.rows[0].id, action: '异常上报', result: '成功', after: { incident_type: type, description, appointment_id: appointment?.id ?? null }, ip: context.ip });
    return inserted.rows[0];
  });
  await safeNotify(async () => {
    if (type === '黑名单命中' && appointment) {
      await notifyBlacklist(appointment, appointment.visitor_id_no ? appointment.visitor_id_no.slice(0, 4) + '**********' + appointment.visitor_id_no.slice(-4) : '已脱敏');
    }
  });
  return toIncidentDto(incident);
}

export async function disposeIncident(id: string, input: Record<string, unknown>, context: GateContext) {
  const status = input.status === '已处理' || input.status === '已忽略' ? input.status : null;
  if (!status) throw unprocessable('请选择处置结果', 'status');
  const note = typeof input.disposition_note === 'string' ? input.disposition_note.trim() : '';
  if (!note) throw unprocessable('请填写处置说明', 'disposition_note');
  if (Array.from(note).length > 200) throw unprocessable('处置说明不能超过 200 个字符', 'disposition_note');
  const incident = await withTransaction(async (client) => {
    const before = await repo.findIncidentById(id, client, true);
    if (!before) throw notFound(MESSAGES.NOT_FOUND);
    if (before.status !== '待处理') throw conflict(COPY.STATE_CONFLICT);
    const updated = await client.query<IncidentRow>(
      `UPDATE incidents SET status = $2, disposition_note = $3, handled_by = $4, handled_at = now(), updated_at = now() WHERE id = $1 RETURNING *`,
      [id, status, note, context.actor.id],
    );
    await writeAudit(client, { userId: context.actor.id, userName: context.actor.displayName, objectType: 'incident', objectId: id, action: '异常处置', result: '成功', before: { status: before.status }, after: { status, disposition_note: note }, ip: context.ip });
    return updated.rows[0];
  });
  return toIncidentDto(incident);
}
