import { writeAudit } from '../../../shared/audit/writeAudit.js';
import { forbidden } from '../../../shared/http/errors.js';
import { MESSAGES } from '../../../shared/constants/messages.js';
import type { Actor, AppointmentRow } from './types.js';

export function canReadAppointment(actor: Actor, row: AppointmentRow): boolean {
  if (actor.roleCode === 'admin') return true;
  if (actor.roleCode !== 'host') return false;
  return row.host_id === actor.hostId || row.reviewer_id === actor.id || row.created_by === actor.id;
}

export function canReviewAppointment(actor: Actor, row: AppointmentRow): boolean {
  if (actor.roleCode === 'admin') return true;
  return row.reviewer_id === actor.id || (row.reviewer_id === null && row.host_id === actor.hostId);
}

export async function assertCanRead(
  actor: Actor,
  row: AppointmentRow,
  ip: string | null,
  path?: string,
): Promise<void> {
  if (canReadAppointment(actor, row)) return;
  await writeAudit({
    userId: actor.id,
    userName: actor.displayName,
    objectType: 'appointment',
    objectId: row.id,
    action: '越权拦截',
    result: '拒绝',
    before: { path: path ?? null },
    note: '对象级数据范围拒绝',
    ip,
  });
  throw forbidden(MESSAGES.OBJECT_FORBIDDEN);
}

export async function assertCanReview(
  actor: Actor,
  row: AppointmentRow,
  ip: string | null,
  path?: string,
): Promise<void> {
  if (canReviewAppointment(actor, row)) return;
  await writeAudit({
    userId: actor.id,
    userName: actor.displayName,
    objectType: 'appointment',
    objectId: row.id,
    action: '越权拦截',
    result: '拒绝',
    before: { path: path ?? null },
    note: '审核对象级数据范围拒绝',
    ip,
  });
  throw forbidden(MESSAGES.OBJECT_FORBIDDEN);
}
