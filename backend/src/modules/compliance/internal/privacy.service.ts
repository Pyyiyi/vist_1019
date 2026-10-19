import type { QueryResultRow } from 'pg';

import { writeAudit } from '../../../shared/audit/writeAudit.js';
import { MESSAGES } from '../../../shared/constants/messages.js';
import { query, withTransaction } from '../../../shared/db/pool.js';
import { AppError, notFound, unprocessable } from '../../../shared/http/errors.js';
import { parsePagination } from '../../../shared/http/pagination.js';
import type { AuthenticatedUser } from '../../../shared/auth/types.js';
import { maskIdNo } from '../../../shared/utils/mask.js';
import { newUuid } from '../../../shared/utils/ids.js';
import { eraseAppointmentPii, getAppointmentForCompliance } from '../../visit/index.js';

const RETENTION_ERROR = '留存期限必须是大于 0 的整数';
const PRIVACY_CONFIG_KEYS = ['privacy_retention_days', 'audit_retention_days'] as const;

type ConfigRow = QueryResultRow & { config_key: string; config_value: string };
type AppointmentRow = QueryResultRow & {
  id: string;
  appoint_no: string;
  visitor_name: string | null;
  visitor_phone: string | null;
  visitor_id_no: string | null;
  host_id: string;
  reviewer_id: string | null;
  visit_start: Date | string;
  visit_end: Date | string;
  status: string;
};
type CompanionRow = QueryResultRow & {
  id: string;
  appointment_id: string;
  name: string | null;
  relation: string;
  id_no: string | null;
  sort_order: number;
  created_at: Date | string;
};
type ConsentRow = QueryResultRow & {
  id: string;
  appointment_id: string;
  consent_type: string;
  confirmed_at: Date | string;
  channel: string;
  created_at: Date | string;
};
type PassageRow = QueryResultRow & {
  id: string;
  appointment_id: string;
  gate_id: string;
  record_type: string;
  occurred_at: Date | string;
  operator_id: string;
  created_at: Date | string;
};
type PrivacyCaseRow = QueryResultRow & {
  id: string;
  appointment_id: string | null;
  case_type: '信息副本' | '人工清除';
  requested_by: string | null;
  status: '已完成' | '失败';
  note: string;
  created_at: Date | string;
  completed_at: Date | string;
  appoint_no: string | null;
  requester_name: string | null;
};

function iso(value: Date | string): string {
  return value instanceof Date ? value.toISOString() : value;
}

function configReadError(): AppError {
  return new AppError(500, 50001, MESSAGES.INTERNAL_ERROR);
}

export function parseRetentionDays(value: unknown): number {
  const parsed = typeof value === 'number' ? value : Number(value);
  if (!Number.isInteger(parsed) || parsed <= 0) {
    throw unprocessable(RETENTION_ERROR, 'retention_days');
  }
  return parsed;
}

export function parseEraseReason(input: Record<string, unknown>): string {
  const reason = typeof input.reason === 'string' ? input.reason.trim() : '';
  if (!reason) throw unprocessable('请填写清除原因', 'reason');
  if (reason.length > 200) throw unprocessable('清除原因不能超过 200 个字符', 'reason');
  return reason;
}

export async function getPrivacyRetention() {
  const result = await query<ConfigRow>(
    'SELECT config_key, config_value FROM system_config WHERE config_key = ANY($1::text[])',
    [PRIVACY_CONFIG_KEYS],
  );
  const values = new Map(result.rows.map((row) => [row.config_key, row.config_value]));
  const retention = Number(values.get('privacy_retention_days'));
  const auditRetention = Number(values.get('audit_retention_days'));
  if (!Number.isInteger(retention) || !Number.isInteger(auditRetention)) throw configReadError();
  return { retention_days: retention, audit_retention_days: auditRetention };
}

export async function updatePrivacyRetention(
  input: Record<string, unknown>,
  actor: AuthenticatedUser,
  ip: string | null,
) {
  const retentionDays = parseRetentionDays(input.retention_days);
  await withTransaction(async (client) => {
    const previousResult = await client.query<ConfigRow>(
      'SELECT config_key, config_value FROM system_config WHERE config_key = $1 FOR UPDATE',
      ['privacy_retention_days'],
    );
    const previous = previousResult.rows[0]?.config_value;
    if (previous === undefined) throw configReadError();
    const next = String(retentionDays);
    await client.query(
      'UPDATE system_config SET config_value = $2, updated_at = now() WHERE config_key = $1',
      ['privacy_retention_days', next],
    );
    await writeAudit(client, {
      userId: actor.id,
      userName: actor.displayName,
      objectType: 'system_config',
      objectId: 'privacy_retention_days',
      action: '修改留存配置',
      result: '成功',
      before: { config_value: previous },
      after: { config_value: next },
      ip,
    });
  });
  return getPrivacyRetention();
}

async function recordPrivacyCase(
  appointmentId: string | null,
  caseType: '信息副本' | '人工清除',
  requestedBy: string | null,
  note: string,
): Promise<void> {
  await query(
    `INSERT INTO privacy_cases
       (id, appointment_id, case_type, requested_by, status, note, created_at, completed_at)
     VALUES ($1, $2, $3, $4, '已完成', $5, now(), now())`,
    [newUuid(), appointmentId, caseType, requestedBy, note.slice(0, 200)],
  );
}

export async function eraseAppointmentPrivacy(
  appointmentId: string,
  input: Record<string, unknown>,
  actor: AuthenticatedUser,
) {
  const reason = parseEraseReason(input);
  const appointment = await getAppointmentForCompliance(appointmentId);
  if (!appointment) throw notFound(MESSAGES.NOT_FOUND);
  const erased = await eraseAppointmentPii(appointmentId, actor.id, reason);
  if (!erased) throw notFound(MESSAGES.NOT_FOUND);
  await recordPrivacyCase(appointmentId, '人工清除', actor.id, reason);
  return { erased: true as const };
}

export async function listPrivacyCases(queryInput: Record<string, unknown>) {
  const pagination = parsePagination(queryInput, 20, 100);
  const [countResult, listResult] = await Promise.all([
    query<{ total: string }>('SELECT COUNT(*)::text AS total FROM privacy_cases'),
    query<PrivacyCaseRow>(
      `SELECT pc.id, pc.appointment_id, pc.case_type, pc.requested_by, pc.status, pc.note,
              pc.created_at, pc.completed_at, a.appoint_no, u.display_name AS requester_name
         FROM privacy_cases pc
         LEFT JOIN appointments a ON a.id = pc.appointment_id
         LEFT JOIN users u ON u.id = pc.requested_by
        ORDER BY pc.created_at DESC, pc.id DESC
        LIMIT $1 OFFSET $2`,
      [pagination.pageSize, pagination.offset],
    ),
  ]);
  return {
    items: listResult.rows.map((row) => ({
      id: row.id,
      appointment_id: row.appointment_id,
      object: row.appoint_no ?? row.appointment_id ?? '—',
      case_type: row.case_type,
      description: row.note,
      status: row.status,
      requested_by: row.requested_by,
      handled_by: row.requester_name ?? (row.requested_by ? row.requested_by : '访客'),
      handled_at: iso(row.completed_at),
      created_at: iso(row.created_at),
      completed_at: iso(row.completed_at),
    })),
    total: Number(countResult.rows[0]?.total ?? 0),
    page: pagination.page,
    page_size: pagination.pageSize,
  };
}

export async function getVisitorPrivacyCopy(visitorAppointmentId: string) {
  const boundResult = await query<AppointmentRow>('SELECT * FROM appointments WHERE id = $1', [visitorAppointmentId]);
  const bound = boundResult.rows[0];
  if (!bound) throw notFound(MESSAGES.NOT_FOUND);

  const appointmentsResult = bound.visitor_id_no
    ? await query<AppointmentRow>(
        `SELECT * FROM appointments
          WHERE id = $1 OR visitor_id_no = $2
          ORDER BY visit_start DESC, created_at DESC`,
        [bound.id, bound.visitor_id_no],
      )
    : { rows: [bound] };

  const [companionsResult, consentsResult, passagesResult] = await Promise.all([
    query<CompanionRow>(
      `SELECT id, appointment_id, name, relation, id_no, sort_order, created_at
         FROM companions WHERE appointment_id = $1 ORDER BY sort_order, created_at`,
      [bound.id],
    ),
    query<ConsentRow>(
      `SELECT id, appointment_id, consent_type, confirmed_at, channel, created_at
         FROM consent_records WHERE appointment_id = $1 ORDER BY confirmed_at`,
      [bound.id],
    ),
    query<PassageRow>(
      `SELECT id, appointment_id, gate_id, record_type, occurred_at, operator_id, created_at
         FROM passage_records WHERE appointment_id = $1 ORDER BY occurred_at DESC`,
      [bound.id],
    ),
  ]);

  const maskedIdNo = maskIdNo(bound.visitor_id_no);
  await recordPrivacyCase(bound.id, '信息副本', null, '访客获取本人信息副本');

  return {
    appointment: {
      id: bound.id,
      appoint_no: bound.appoint_no,
      visitor_name: bound.visitor_name,
      visitor_phone: bound.visitor_phone,
      visitor_id_no: maskedIdNo,
      visitor_id_no_masked: maskedIdNo,
      status: bound.status,
      visit_start: iso(bound.visit_start),
      visit_end: iso(bound.visit_end),
      host_id: bound.host_id,
      reviewer_id: bound.reviewer_id,
    },
    appointments: appointmentsResult.rows.map((row) => ({
      id: row.id,
      appoint_no: row.appoint_no,
      visitor_name: row.visitor_name,
      visitor_phone: row.visitor_phone,
      visitor_id_no: maskIdNo(row.visitor_id_no),
      visitor_id_no_masked: maskIdNo(row.visitor_id_no),
      status: row.status,
      visit_start: iso(row.visit_start),
      visit_end: iso(row.visit_end),
    })),
    companions: companionsResult.rows.map((row) => ({
      id: row.id,
      appointment_id: row.appointment_id,
      name: row.name,
      relation: row.relation,
      id_no: maskIdNo(row.id_no),
      sort_order: row.sort_order,
      created_at: iso(row.created_at),
    })),
    consents: consentsResult.rows.map((row) => ({
      id: row.id,
      appointment_id: row.appointment_id,
      consent_type: row.consent_type,
      confirmed_at: iso(row.confirmed_at),
      channel: row.channel,
      created_at: iso(row.created_at),
    })),
    passages: passagesResult.rows.map((row) => ({
      id: row.id,
      appointment_id: row.appointment_id,
      gate_id: row.gate_id,
      record_type: row.record_type,
      occurred_at: iso(row.occurred_at),
      operator_id: row.operator_id,
      created_at: iso(row.created_at),
    })),
  };
}
