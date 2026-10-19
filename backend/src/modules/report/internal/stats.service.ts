import { INCIDENT_TYPES, ATTENDED_STATUSES } from '../../../shared/constants/status.js';
import { query } from '../../../shared/db/pool.js';
import { unprocessable } from '../../../shared/http/errors.js';
import { localDayRange } from '../../../shared/utils/ids.js';

export type Granularity = 'day' | 'week' | 'month';
export type VisitBucket = { period: string; type: string; count: number };
export type IncidentTypeCount = { type: string; count: number };

type VisitDbRow = { period: string; type: string; count: number };
type TypeRow = { id: string; code: string; name: string };
type IncidentRow = { incident_type: string; count: number };
type CountRow = { count: number };

type DateRange = { from: Date; to: Date };

type VisitsQuery = Record<string, unknown>;

function stringValue(value: unknown): string {
  return typeof value === 'string' ? value.trim() : '';
}

function localDateKey(value: Date): string {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Shanghai',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(value);
}

function dateFromKey(key: string): Date {
  return new Date(`${key}T00:00:00+08:00`);
}

function addUtcDays(base: Date, days: number): Date {
  const copy = new Date(base.getTime());
  copy.setUTCDate(copy.getUTCDate() + days);
  return copy;
}

function parseRangeBoundary(value: string, field: string, endOfDay: boolean): Date {
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

export function parseGranularity(value: unknown): Granularity {
  const raw = stringValue(value) || 'day';
  if (raw !== 'day' && raw !== 'week' && raw !== 'month') {
    throw unprocessable('统计粒度不正确', 'granularity');
  }
  return raw;
}

export function resolveDateRange(input: VisitsQuery, now: Date = new Date()): DateRange {
  const fromValue = stringValue(input.date_from);
  const toValue = stringValue(input.date_to);
  const defaultTo = localDayRange(now).end;
  const defaultFrom = localDayRange(addUtcDays(now, -29)).start;
  const from = fromValue
    ? parseRangeBoundary(fromValue, 'date_from', false)
    : defaultFrom;
  const to = toValue ? parseRangeBoundary(toValue, 'date_to', true) : defaultTo;

  if (from > to) {
    throw unprocessable('开始日期不能晚于结束日期', 'date_from');
  }
  return { from, to };
}

function startOfPeriod(dayKey: string, granularity: Granularity): Date {
  const date = dateFromKey(dayKey);
  const y = Number(dayKey.slice(0, 4));
  const m = Number(dayKey.slice(5, 7));
  const d = Number(dayKey.slice(8, 10));

  if (granularity === 'week') {
    const utcDay = new Date(Date.UTC(y, m - 1, d));
    const weekday = utcDay.getUTCDay() || 7;
    return dateFromKey(localDateKey(new Date(Date.UTC(y, m - 1, d - weekday + 1))));
  }
  if (granularity === 'month') {
    return dateFromKey(`${dayKey.slice(0, 7)}-01`);
  }
  return date;
}

function nextPeriod(period: Date, granularity: Granularity): Date {
  if (granularity === 'month') {
    const key = localDateKey(period);
    const y = Number(key.slice(0, 4));
    const m = Number(key.slice(5, 7));
    return dateFromKey(`${m === 12 ? y + 1 : y}-${String(m === 12 ? 1 : m + 1).padStart(2, '0')}-01`);
  }
  return new Date(period.getTime() + (granularity === 'week' ? 7 : 1) * 86400000);
}

export function visitPeriods(range: DateRange, granularity: Granularity): string[] {
  const periods: string[] = [];
  let cursor = startOfPeriod(localDateKey(range.from), granularity);
  const endKey = localDateKey(range.to);

  while (localDateKey(cursor) <= endKey) {
    periods.push(localDateKey(cursor));
    cursor = nextPeriod(cursor, granularity);
  }
  return periods;
}

export function expandVisitBuckets(
  rows: VisitDbRow[],
  types: string[],
  granularity: Granularity,
  range: DateRange,
): VisitBucket[] {
  const counts = new Map<string, number>();
  for (const row of rows) {
    counts.set(`${row.period}|${row.type}`, Number(row.count));
  }

  const buckets: VisitBucket[] = [];
  for (const period of visitPeriods(range, granularity)) {
    for (const type of types) {
      buckets.push({ period, type, count: counts.get(`${period}|${type}`) ?? 0 });
    }
  }
  return buckets;
}

export function normalizeIncidentCounts(rows: IncidentRow[]): IncidentTypeCount[] {
  const counts = new Map(rows.map((row) => [row.incident_type, Number(row.count)]));
  return INCIDENT_TYPES.map((type) => ({ type, count: counts.get(type) ?? 0 }));
}

export async function getVisitStats(input: VisitsQuery, now: Date = new Date()) {
  const granularity = parseGranularity(input.granularity);
  const range = resolveDateRange(input, now);
  const type = stringValue(input.type);
  const typeRows = await query<TypeRow>(
    `SELECT id, code, name FROM visitor_types
     ${type ? 'WHERE id = $1 OR code = $1 OR name = $1' : ''}
     ORDER BY sort_order, name`,
    type ? [type] : [],
  );
  const typeNames = typeRows.rows.map((row) => row.name);
  if (typeNames.length === 0) {
    return { buckets: [] };
  }

  const params: unknown[] = [granularity, range.from, range.to, [...ATTENDED_STATUSES]];
  let typeClause = '';
  if (type) {
    params.push(type);
    typeClause = 'AND (vt.id = $5 OR vt.code = $5 OR vt.name = $5)';
  }

  const result = await query<VisitDbRow>(
    `SELECT
       to_char(date_trunc($1, a.visit_start AT TIME ZONE 'Asia/Shanghai'), 'YYYY-MM-DD') AS period,
       vt.name AS type,
       SUM(a.people_count)::int AS count
     FROM appointments a
     JOIN visitor_types vt ON vt.id = a.visitor_type_id
     WHERE a.status = ANY($4::text[])
       AND a.visit_start >= $2
       AND a.visit_start <= $3
       ${typeClause}
     GROUP BY period, vt.name
     ORDER BY period, vt.name`,
    params,
  );

  return { buckets: expandVisitBuckets(result.rows, typeNames, granularity, range) };
}

export async function getIncidentStats(input: VisitsQuery, now: Date = new Date()) {
  const range = resolveDateRange(input, now);
  const result = await query<IncidentRow>(
    `SELECT incident_type, COUNT(*)::int AS count
     FROM incidents
     WHERE created_at >= $1 AND created_at <= $2
     GROUP BY incident_type`,
    [range.from, range.to],
  );
  const timeout = await query<CountRow>(
    `SELECT COUNT(*)::int AS count
     FROM appointments
     WHERE status = '已到访(在校中)'
       AND visit_end + INTERVAL '60 minutes' < $3
       AND visit_start >= $1 AND visit_start <= $2`,
    [range.from, range.to, now],
  );

  return {
    types: normalizeIncidentCounts(result.rows),
    timeoutCount: timeout.rows[0]?.count ?? 0,
  };
}
