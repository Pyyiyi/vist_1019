import { query } from '../../../shared/db/pool.js';
import type {
  AppointmentRow,
  CompanionRow,
  CredentialRow,
  DbClient,
  HistoryRow,
  IncidentRow,
} from './types.js';

function executor(client?: DbClient) {
  return client ?? { query };
}

export async function findAppointmentById(
  id: string,
  client?: DbClient,
  forUpdate = false,
): Promise<AppointmentRow | null> {
  const result = await executor(client).query<AppointmentRow>(
    `SELECT * FROM appointments WHERE id = $1 ${forUpdate ? 'FOR UPDATE' : ''}`,
    [id],
  );
  return result.rows[0] ?? null;
}

export async function findAppointmentByCode(
  code: string,
  client?: DbClient,
  forUpdate = false,
): Promise<AppointmentRow | null> {
  const result = await executor(client).query<AppointmentRow>(
    `SELECT a.*
       FROM appointments a
       LEFT JOIN visit_credentials c ON c.appointment_id = a.id
      WHERE a.id = $1 OR a.appoint_no = $1 OR c.short_code = $1
      ORDER BY CASE WHEN a.id = $1 THEN 0 WHEN a.appoint_no = $1 THEN 1 ELSE 2 END
      LIMIT 1 ${forUpdate ? 'FOR UPDATE OF a' : ''}`,
    [code],
  );
  return result.rows[0] ?? null;
}

export async function findCompanions(appointmentId: string, client?: DbClient): Promise<CompanionRow[]> {
  const result = await executor(client).query<CompanionRow>(
    'SELECT * FROM companions WHERE appointment_id = $1 ORDER BY sort_order ASC, id ASC',
    [appointmentId],
  );
  return result.rows;
}

export async function findHistory(appointmentId: string, client?: DbClient): Promise<HistoryRow[]> {
  const result = await executor(client).query<HistoryRow>(
    'SELECT * FROM appointment_status_history WHERE appointment_id = $1 ORDER BY occurred_at ASC, id ASC',
    [appointmentId],
  );
  return result.rows;
}

export async function findCredential(appointmentId: string, client?: DbClient): Promise<CredentialRow | null> {
  const result = await executor(client).query<CredentialRow>(
    'SELECT * FROM visit_credentials WHERE appointment_id = $1 LIMIT 1',
    [appointmentId],
  );
  return result.rows[0] ?? null;
}

export async function findIncidentById(id: string, client?: DbClient, forUpdate = false): Promise<IncidentRow | null> {
  const result = await executor(client).query<IncidentRow>(
    `SELECT * FROM incidents WHERE id = $1 ${forUpdate ? 'FOR UPDATE' : ''}`,
    [id],
  );
  return result.rows[0] ?? null;
}

export type AppointmentListOptions = {
  pageSize: number;
  offset: number;
  status?: string | null;
  visitorName?: string;
  dateFrom?: string | null;
  dateTo?: string | null;
  actor?: { id: string; roleCode: string; hostId: string | null } | null;
};

export async function listAppointments(options: AppointmentListOptions): Promise<{ rows: AppointmentRow[]; total: number }> {
  const where: string[] = [];
  const params: unknown[] = [];
  const add = (sql: string, value: unknown) => {
    params.push(value);
    where.push(sql.replace('?', `$${params.length}`));
  };

  if (options.status) add('status = ?', options.status);
  if (options.visitorName) add('visitor_name ILIKE ?', `%${options.visitorName}%`);
  if (options.dateFrom) add("visit_start >= ($?::date::timestamp AT TIME ZONE 'Asia/Shanghai')", options.dateFrom);
  if (options.dateTo) add("visit_start < (($?::date + 1)::timestamp AT TIME ZONE 'Asia/Shanghai')", options.dateTo);
  if (options.actor && options.actor.roleCode !== 'admin') {
    const hostId = options.actor.hostId;
    params.push(options.actor.id, hostId, options.actor.id);
    where.push(`(reviewer_id = $${params.length - 2} OR host_id = $${params.length - 1} OR created_by = $${params.length})`);
  }

  const filter = where.length > 0 ? `WHERE ${where.join(' AND ')}` : '';
  const count = await query<{ count: number }>(`SELECT COUNT(*)::int AS count FROM appointments ${filter}`, params);
  const result = await query<AppointmentRow>(
    `SELECT * FROM appointments ${filter}
      ORDER BY visit_start DESC, created_at DESC
      LIMIT $${params.length + 1} OFFSET $${params.length + 2}`,
    [...params, options.pageSize, options.offset],
  );
  return { rows: result.rows, total: count.rows[0]?.count ?? 0 };
}

export async function listPendingReviews(options: {
  pageSize: number;
  offset: number;
  actor: { id: string; roleCode: string; hostId: string | null };
}): Promise<{ rows: AppointmentRow[]; total: number }> {
  const params: unknown[] = [];
  const where = ["status = '待审核'"];
  if (options.actor.roleCode !== 'admin') {
    params.push(options.actor.id, options.actor.hostId);
    where.push(`(reviewer_id = $1 OR host_id = $2)`);
  }
  const filter = `WHERE ${where.join(' AND ')}`;
  const count = await query<{ count: number }>(`SELECT COUNT(*)::int AS count FROM appointments ${filter}`, params);
  const result = await query<AppointmentRow>(
    `SELECT * FROM appointments ${filter}
      ORDER BY visit_start ASC, created_at ASC
      LIMIT $${params.length + 1} OFFSET $${params.length + 2}`,
    [...params, options.pageSize, options.offset],
  );
  return { rows: result.rows, total: count.rows[0]?.count ?? 0 };
}

export async function findOverlappingOpenAppointment(
  client: DbClient,
  idNo: string,
  start: Date,
  end: Date,
  excludeId?: string,
): Promise<AppointmentRow | null> {
  const params: unknown[] = [idNo, start, end, ['待审核', '已改期', '已通过', '已到访(在校中)']];
  let exclude = '';
  if (excludeId) {
    params.push(excludeId);
    exclude = `AND id <> $${params.length}`;
  }
  const result = await client.query<AppointmentRow>(
    `SELECT * FROM appointments
      WHERE visitor_id_no = $1
        AND visit_start <= $3
        AND visit_end >= $2
        AND status = ANY($4::text[])
        ${exclude}
      LIMIT 1`,
    params,
  );
  return result.rows[0] ?? null;
}

export async function insertStatusHistory(
  client: DbClient,
  input: {
    id: string;
    appointmentId: string;
    fromStatus: string | null;
    toStatus: string;
    changedBy: string | null;
    reason: string;
    occurredAt?: Date;
  },
): Promise<void> {
  await client.query(
    `INSERT INTO appointment_status_history
       (id, appointment_id, from_status, to_status, changed_by, change_reason, occurred_at)
     VALUES ($1, $2, $3, $4, $5, $6, $7)`,
    [input.id, input.appointmentId, input.fromStatus, input.toStatus, input.changedBy, input.reason, input.occurredAt ?? new Date()],
  );
}

export async function listTodayAppointments(dayStart: Date, dayEnd: Date): Promise<AppointmentRow[]> {
  const result = await query<AppointmentRow>(
    `SELECT * FROM appointments
      WHERE (visit_start BETWEEN $1 AND $2)
         OR (checkin_at BETWEEN $1 AND $2)
         OR (checkout_at BETWEEN $1 AND $2)
      ORDER BY COALESCE(checkin_at, visit_start) DESC, created_at DESC`,
    [dayStart, dayEnd],
  );
  return result.rows;
}

export async function countIncidents(status?: string): Promise<number> {
  const result = status
    ? await query<{ count: number }>('SELECT COUNT(*)::int AS count FROM incidents WHERE status = $1', [status])
    : await query<{ count: number }>('SELECT COUNT(*)::int AS count FROM incidents');
  return result.rows[0]?.count ?? 0;
}

export async function listIncidents(options: {
  pageSize: number;
  offset: number;
  status?: string | null;
  type?: string | null;
}): Promise<{ rows: IncidentRow[]; total: number }> {
  const where: string[] = [];
  const params: unknown[] = [];
  if (options.status) { params.push(options.status); where.push(`status = $${params.length}`); }
  if (options.type) { params.push(options.type); where.push(`incident_type = $${params.length}`); }
  const filter = where.length ? `WHERE ${where.join(' AND ')}` : '';
  const count = await query<{ count: number }>(`SELECT COUNT(*)::int AS count FROM incidents ${filter}`, params);
  const result = await query<IncidentRow>(
    `SELECT * FROM incidents ${filter}
      ORDER BY created_at DESC, id DESC
      LIMIT $${params.length + 1} OFFSET $${params.length + 2}`,
    [...params, options.pageSize, options.offset],
  );
  return { rows: result.rows, total: count.rows[0]?.count ?? 0 };
}
