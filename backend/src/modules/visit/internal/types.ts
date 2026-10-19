import type { PoolClient, QueryResult, QueryResultRow } from 'pg';

export type DbClient = Pick<PoolClient, 'query'>;
export type Queryable = DbClient | undefined;

export type Actor = { id: string; displayName: string; roleCode: string; hostId: string | null };

export type AppointmentRow = QueryResultRow & {
  id: string;
  appoint_no: string;
  visitor_type_id: string;
  visitor_name: string | null;
  visitor_phone: string | null;
  visitor_id_no: string | null;
  host_id: string;
  reviewer_id: string | null;
  expected_gate_id: string | null;
  visit_start: Date | string;
  visit_end: Date | string;
  reason: string;
  plate_no: string | null;
  status: string;
  people_count: number;
  black_hit: boolean;
  reschedule_proposed_at: Date | string | null;
  reject_reason: string | null;
  cancel_reason: string | null;
  checkin_at: Date | string | null;
  checkout_at: Date | string | null;
  created_by: string | null;
  created_at: Date | string;
  updated_at: Date | string;
};

export type CompanionRow = QueryResultRow & {
  id: string;
  appointment_id: string;
  name: string | null;
  relation: string;
  id_no: string | null;
  sort_order: number;
};

export type HistoryRow = QueryResultRow & {
  id: string;
  appointment_id: string;
  from_status: string | null;
  to_status: string;
  changed_by: string | null;
  change_reason: string;
  occurred_at: Date | string;
};

export type CredentialRow = QueryResultRow & {
  id: string;
  appointment_id: string;
  short_code: string;
  usage_status: '未使用' | '已使用';
  used_at: Date | string | null;
};

export type IncidentRow = QueryResultRow & {
  id: string;
  appointment_id: string | null;
  incident_type: string;
  status: string;
  description: string;
  reported_by: string;
  handled_by: string | null;
  disposition_note: string | null;
  handled_at: Date | string | null;
  created_at: Date | string;
  updated_at: Date | string;
};

export type AppointmentDto = ReturnType<typeof toAppointmentDto>;

export function iso(value: Date | string | null | undefined): string | null {
  if (value === null || value === undefined) return null;
  return value instanceof Date ? value.toISOString() : new Date(value).toISOString();
}

export function toAppointmentDto(row: AppointmentRow, extra: Record<string, unknown> = {}) {
  return {
    id: row.id,
    appoint_no: row.appoint_no,
    visitor_type_id: row.visitor_type_id,
    visitor_name: row.visitor_name,
    visitor_phone: row.visitor_phone,
    visitor_id_no: row.visitor_id_no,
    host_id: row.host_id,
    reviewer_id: row.reviewer_id,
    expected_gate_id: row.expected_gate_id,
    visit_start: iso(row.visit_start),
    visit_end: iso(row.visit_end),
    reason: row.reason,
    plate_no: row.plate_no,
    status: row.status,
    people_count: row.people_count,
    black_hit: row.black_hit,
    reschedule_proposed_at: iso(row.reschedule_proposed_at),
    reject_reason: row.reject_reason,
    cancel_reason: row.cancel_reason,
    checkin_at: iso(row.checkin_at),
    checkout_at: iso(row.checkout_at),
    created_by: row.created_by,
    created_at: iso(row.created_at),
    updated_at: iso(row.updated_at),
    ...extra,
  };
}

export function toCompanionDto(row: CompanionRow) {
  return {
    id: row.id,
    appointment_id: row.appointment_id,
    name: row.name,
    relation: row.relation,
    id_no: row.id_no,
    sort_order: row.sort_order,
  };
}

export function toHistoryDto(row: HistoryRow) {
  return {
    id: row.id,
    appointment_id: row.appointment_id,
    from_status: row.from_status,
    to_status: row.to_status,
    changed_by: row.changed_by,
    change_reason: row.change_reason,
    occurred_at: iso(row.occurred_at),
  };
}

export function toCredentialDto(row: CredentialRow) {
  return {
    id: row.id,
    appointment_id: row.appointment_id,
    short_code: row.short_code,
    usage_status: row.usage_status,
    used_at: iso(row.used_at),
  };
}

export function toIncidentDto(row: IncidentRow) {
  return {
    id: row.id,
    appointment_id: row.appointment_id,
    incident_type: row.incident_type,
    status: row.status,
    description: row.description,
    reported_by: row.reported_by,
    handled_by: row.handled_by,
    disposition_note: row.disposition_note,
    handled_at: iso(row.handled_at),
    created_at: iso(row.created_at),
    updated_at: iso(row.updated_at),
  };
}

export type QueryExecutor = <T extends QueryResultRow = QueryResultRow>(sql: string, params?: unknown[]) => Promise<QueryResult<T>>;
