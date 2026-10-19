import { registerJob } from '../../shared/jobs/scheduler.js';
import { query, withTransaction } from '../../shared/db/pool.js';
import { writeAudit } from '../../shared/audit/writeAudit.js';
import { newUuid } from '../../shared/utils/ids.js';
import { getConfigNumber } from '../master/index.js';
import { type AppointmentRow, iso } from './internal/types.js';

export type AppointmentSummaryDto = {
  id: string;
  appointNo: string;
  visitorName: string | null;
  status: string;
  visitStart: string;
  visitEnd: string;
  hostId: string;
  reviewerId: string | null;
};

export async function getAppointmentForCompliance(id: string): Promise<AppointmentSummaryDto | null> {
  const result = await query<AppointmentRow>('SELECT * FROM appointments WHERE id = $1', [id]);
  const row = result.rows[0];
  if (!row) return null;
  return {
    id: row.id,
    appointNo: row.appoint_no,
    visitorName: row.visitor_name,
    status: row.status,
    visitStart: iso(row.visit_start)!,
    visitEnd: iso(row.visit_end)!,
    hostId: row.host_id,
    reviewerId: row.reviewer_id,
  };
}

export async function eraseAppointmentPii(id: string, actorId: string, reason: string): Promise<boolean> {
  return withTransaction(async (client) => {
    const before = await client.query<AppointmentRow>('SELECT * FROM appointments WHERE id = $1 FOR UPDATE', [id]);
    const row = before.rows[0];
    if (!row) return false;
    await client.query(
      `UPDATE appointments
          SET visitor_name = NULL, visitor_phone = NULL, visitor_id_no = NULL, updated_at = now()
        WHERE id = $1`,
      [id],
    );
    await client.query(
      `UPDATE companions SET name = NULL, id_no = NULL WHERE appointment_id = $1`,
      [id],
    );
    await writeAudit(client, {
      userId: actorId,
      userName: actorId,
      objectType: 'appointment',
      objectId: id,
      action: '人工清除',
      result: '成功',
      before: { visitor_name: row.visitor_name, visitor_phone: row.visitor_phone, visitor_id_no: row.visitor_id_no },
      after: { visitor_name: null, visitor_phone: null, visitor_id_no: null },
      note: reason,
    });
    return true;
  });
}

async function expireWhere(now: Date, predicate: (row: AppointmentRow) => boolean): Promise<number> {
  return withTransaction(async (client) => {
    const result = await client.query<AppointmentRow>(
      `SELECT * FROM appointments
        WHERE status IN ('待审核', '已改期', '已通过')
        FOR UPDATE`,
    );
    let count = 0;
    for (const row of result.rows) {
      if (!predicate(row)) continue;
      await client.query(
        `UPDATE appointments SET status = '已过期', updated_at = now() WHERE id = $1`,
        [row.id],
      );
      await client.query(
        `INSERT INTO appointment_status_history
           (id, appointment_id, from_status, to_status, changed_by, change_reason, occurred_at)
         VALUES ($1, $2, $3, '已过期', NULL, $4, $5)`,
        [newUuid(), row.id, row.status, '预约已过期', now],
      );
      count += 1;
    }
    return count;
  });
}

export async function expireAppointments(now: Date): Promise<number> {
  return expireWhere(now, (row) => {
    const start = new Date(row.visit_start);
    const end = new Date(row.visit_end);
    if (row.status === '已通过') return end.getTime() < now.getTime();
    return start.getTime() < now.getTime();
  });
}

export async function confirmRescheduleTimeout(now: Date): Promise<number> {
  let timeoutHours = 3;
  try {
    timeoutHours = await getConfigNumber('reschedule_confirm_timeout_hours');
  } catch {
    timeoutHours = 3;
  }
  return expireWhere(now, (row) => {
    if (row.status !== '已改期' || !row.reschedule_proposed_at) return false;
    const proposed = new Date(row.reschedule_proposed_at);
    return now.getTime() > proposed.getTime() + timeoutHours * 3_600_000;
  });
}

registerJob({
  name: 'appointment-expire',
  cron: '* * * * *',
  runOnStart: false,
  handler: async () => {
    const now = new Date();
    await expireAppointments(now);
    await confirmRescheduleTimeout(now);
  },
});
