import { writeAudit } from '../../../shared/audit/writeAudit.js';
import type { AuthenticatedUser } from '../../../shared/auth/types.js';
import { query } from '../../../shared/db/pool.js';
import { forbidden, unprocessable } from '../../../shared/http/errors.js';
import { parsePagination } from '../../../shared/http/pagination.js';
import { maskIdNo } from '../../../shared/utils/mask.js';
import { localDayRange } from '../../../shared/utils/ids.js';

export const EXACT_ID_FORBIDDEN_MESSAGE = '您无权使用完整证件号检索';
const ON_CAMPUS_STATUS = '已到访(在校中)';

export type LedgerQuery = Record<string, unknown>;

export type LedgerItem = {
  appointmentId: string;
  appointNo: string;
  visitorName: string | null;
  visitorType: string;
  visitorPhone: string | null;
  visitorIdNoMasked: string;
  hostName: string;
  visitStart: Date | string;
  visitEnd: Date | string;
  checkinAt: Date | string | null;
  checkoutAt: Date | string | null;
  status: string;
  reason: string;
};

export type LedgerRow = {
  appointment_id: string;
  appoint_no: string;
  visitor_name: string | null;
  visitor_type: string | null;
  visitor_phone: string | null;
  visitor_id_no: string | null;
  host_name: string | null;
  visit_start: Date | string;
  visit_end: Date | string;
  checkin_at: Date | string | null;
  checkout_at: Date | string | null;
  status: string;
  reason: string;
};

export type LedgerFilter = {
  clauses: string[];
  params: unknown[];
  dateFrom: Date | null;
  dateTo: Date | null;
};

type CountRow = { count: number };

function stringValue(value: unknown): string {
  return typeof value === 'string' ? value.trim() : '';
}

function addParam(filter: LedgerFilter, value: unknown): string {
  filter.params.push(value);
  return `$${filter.params.length}`;
}

function parseDateBoundary(value: string, field: string, endOfDay: boolean): Date {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    throw unprocessable('日期格式应为 YYYY-MM-DD', field);
  }

  try {
    const range = localDayRange(value);
    return endOfDay ? range.end : range.start;
  } catch {
    throw unprocessable('日期格式应为 YYYY-MM-DD', field);
  }
}

export function buildLedgerFilter(
  input: LedgerQuery,
  user: AuthenticatedUser,
  now: Date = new Date(),
): LedgerFilter {
  if (user.roleCode !== 'admin' && user.roleCode !== 'guard') {
    throw forbidden();
  }

  const filter: LedgerFilter = { clauses: [], params: [], dateFrom: null, dateTo: null };
  const name = stringValue(input.name);
  const idNo = stringValue(input.id_no);
  const phone = stringValue(input.phone);
  const host = stringValue(input.host);
  const type = stringValue(input.type);
  const status = stringValue(input.status);
  const dateFrom = stringValue(input.date_from);
  const dateTo = stringValue(input.date_to);

  if (user.roleCode !== 'admin' && idNo) {
    throw forbidden(EXACT_ID_FORBIDDEN_MESSAGE);
  }

  if (name) {
    filter.clauses.push(`a.visitor_name ILIKE ${addParam(filter, `%${name}%`)}`);
  }
  if (idNo) {
    filter.clauses.push(`a.visitor_id_no = ${addParam(filter, idNo)}`);
  }
  if (phone) {
    filter.clauses.push(`a.visitor_phone ILIKE ${addParam(filter, `%${phone}%`)}`);
  }
  if (host) {
    filter.clauses.push(`h.name ILIKE ${addParam(filter, `%${host}%`)}`);
  }
  if (type) {
    const placeholder = addParam(filter, type);
    filter.clauses.push(
      `(vt.name = ${placeholder} OR vt.code = ${placeholder} OR vt.id = ${placeholder})`,
    );
  }
  if (status) {
    filter.clauses.push(`a.status = ${addParam(filter, status)}`);
  }

  if (user.roleCode === 'guard') {
    const today = localDayRange(now);
    filter.dateFrom = today.start;
    filter.dateTo = today.end;
  } else {
    if (dateFrom) {
      filter.dateFrom = parseDateBoundary(dateFrom, 'date_from', false);
    }
    if (dateTo) {
      filter.dateTo = parseDateBoundary(dateTo, 'date_to', true);
    }
  }

  if (filter.dateFrom && filter.dateTo && filter.dateFrom > filter.dateTo) {
    throw unprocessable('开始日期不能晚于结束日期', 'date_from');
  }
  if (filter.dateFrom) {
    filter.clauses.push(`a.visit_start >= ${addParam(filter, filter.dateFrom)}`);
  }
  if (filter.dateTo) {
    filter.clauses.push(`a.visit_start <= ${addParam(filter, filter.dateTo)}`);
  }

  return filter;
}

export function whereSql(filter: LedgerFilter): string {
  return filter.clauses.length > 0 ? `WHERE ${filter.clauses.join(' AND ')}` : '';
}

export function toLedgerItem(row: LedgerRow): LedgerItem {
  return {
    appointmentId: row.appointment_id,
    appointNo: row.appoint_no,
    visitorName: row.visitor_name,
    visitorType: row.visitor_type ?? '',
    visitorPhone: row.visitor_phone,
    visitorIdNoMasked: maskIdNo(row.visitor_id_no),
    hostName: row.host_name ?? '',
    visitStart: row.visit_start,
    visitEnd: row.visit_end,
    checkinAt: row.checkin_at,
    checkoutAt: row.checkout_at,
    status: row.status,
    reason: row.reason,
  };
}

const SELECT_LEDGER = `
  SELECT
    a.id AS appointment_id,
    a.appoint_no,
    a.visitor_name,
    vt.name AS visitor_type,
    a.visitor_phone,
    a.visitor_id_no,
    h.name AS host_name,
    a.visit_start,
    a.visit_end,
    a.checkin_at,
    a.checkout_at,
    a.status,
    a.reason
  FROM appointments a
  LEFT JOIN visitor_types vt ON vt.id = a.visitor_type_id
  LEFT JOIN hosts h ON h.id = a.host_id
`;

async function auditExactIdDenial(input: LedgerQuery, user: AuthenticatedUser): Promise<void> {
  if (user.roleCode !== 'admin' && stringValue(input.id_no)) {
    await writeAudit({
      userId: user.id,
      userName: user.displayName,
      objectType: 'ledger',
      objectId: null,
      action: '越权拦截',
      result: '拒绝',
      before: { filter: 'id_no' },
      note: '非管理员使用完整证件号检索',
    });
  }
}

export async function listLedger(
  input: LedgerQuery,
  user: AuthenticatedUser,
  now: Date = new Date(),
) {
  await auditExactIdDenial(input, user);
  const pagination = parsePagination(input, 20, 100);
  const filter = buildLedgerFilter(input, user, now);
  const where = whereSql(filter);
  const countResult = await query<CountRow>(
    `SELECT COUNT(*)::int AS count
     FROM appointments a
     LEFT JOIN visitor_types vt ON vt.id = a.visitor_type_id
     LEFT JOIN hosts h ON h.id = a.host_id
     ${where}`,
    filter.params,
  );
  const total = countResult.rows[0]?.count ?? 0;

  if (total === 0) {
    return { items: [], total: 0, page: pagination.page, pageSize: pagination.pageSize };
  }

  const limitPlaceholder = `$${filter.params.length + 1}`;
  const offsetPlaceholder = `$${filter.params.length + 2}`;
  const rows = await query<LedgerRow>(
    `${SELECT_LEDGER}
     ${where}
     ORDER BY a.visit_start DESC, a.appoint_no DESC
     LIMIT ${limitPlaceholder} OFFSET ${offsetPlaceholder}`,
    [...filter.params, pagination.pageSize, pagination.offset],
  );

  return {
    items: rows.rows.map(toLedgerItem),
    total,
    page: pagination.page,
    pageSize: pagination.pageSize,
  };
}

export async function listLedgerForExport(
  input: LedgerQuery,
  user: AuthenticatedUser,
  now: Date = new Date(),
): Promise<LedgerItem[]> {
  await auditExactIdDenial(input, user);
  const filter = buildLedgerFilter(input, user, now);
  const rows = await query<LedgerRow>(
    `${SELECT_LEDGER}
     ${whereSql(filter)}
     ORDER BY a.visit_start DESC, a.appoint_no DESC`,
    filter.params,
  );
  return rows.rows.map(toLedgerItem);
}

export async function listOnCampus(
  user: AuthenticatedUser,
  now: Date = new Date(),
): Promise<LedgerItem[]> {
  const filter = buildLedgerFilter({}, user, now);
  filter.clauses.push(`a.status = ${addParam(filter, ON_CAMPUS_STATUS)}`);
  const rows = await query<LedgerRow>(
    `${SELECT_LEDGER}
     ${whereSql(filter)}
     ORDER BY a.checkin_at DESC NULLS LAST, a.visit_start DESC`,
    filter.params,
  );
  return rows.rows.map(toLedgerItem);
}
