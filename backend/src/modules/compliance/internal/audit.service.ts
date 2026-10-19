import type { QueryResultRow } from 'pg';

import { query } from '../../../shared/db/pool.js';
import { unprocessable } from '../../../shared/http/errors.js';
import { parsePagination } from '../../../shared/http/pagination.js';

export const SENSITIVE_AUDIT_ACTIONS = [
  '审核同意',
  '审核拒绝',
  '放行',
  '核验',
  '取消预约',
  '异常上报',
  '异常处置',
  '越权拦截',
  '新增预约',
  '离校',
] as const;

export type AuditFilters = {
  userId?: string;
  action?: string;
  objectType?: string;
  objectId?: string;
  dateFrom?: Date;
  dateTo?: Date;
  page: number;
  pageSize: number;
  offset: number;
};

type AuditLogRow = QueryResultRow & {
  id: string;
  user_id: string | null;
  user_name: string;
  occurred_at: Date | string;
  object_type: string;
  object_id: string | null;
  action: string;
  result: string;
  before_value: unknown;
  after_value: unknown;
  ip: string | null;
  note: string;
};

function scalar(value: unknown): string | undefined {
  if (typeof value === 'string') {
    const trimmed = value.trim();
    return trimmed || undefined;
  }
  if (Array.isArray(value) && typeof value[0] === 'string') {
    const trimmed = value[0].trim();
    return trimmed || undefined;
  }
  return undefined;
}

function parseBoundary(value: string, endOfDay: boolean, field: string): Date {
  const input = /^\d{4}-\d{2}-\d{2}$/.test(value)
    ? `${value}T${endOfDay ? '23:59:59.999' : '00:00:00.000'}+08:00`
    : value;
  const parsed = new Date(input);
  if (Number.isNaN(parsed.getTime())) {
    throw unprocessable('时间范围格式不正确', field);
  }
  return parsed;
}

export function parseAuditFilters(queryInput: Record<string, unknown>): AuditFilters {
  const pagination = parsePagination(queryInput, 20, 100);
  const dateFromValue = scalar(queryInput.date_from);
  const dateToValue = scalar(queryInput.date_to);
  return {
    userId: scalar(queryInput.user_id),
    action: scalar(queryInput.action),
    objectType: scalar(queryInput.object_type),
    objectId: scalar(queryInput.object_id),
    dateFrom: dateFromValue ? parseBoundary(dateFromValue, false, 'date_from') : undefined,
    dateTo: dateToValue ? parseBoundary(dateToValue, true, 'date_to') : undefined,
    ...pagination,
  };
}

export function mapAuditLog(row: AuditLogRow) {
  return {
    id: row.id,
    user_id: row.user_id,
    user_name: row.user_name,
    occurred_at: row.occurred_at instanceof Date ? row.occurred_at.toISOString() : row.occurred_at,
    object_type: row.object_type,
    object_id: row.object_id,
    action: row.action,
    result: row.result,
    before_value: row.before_value,
    after_value: row.after_value,
    ip: row.ip,
    note: row.note,
  };
}

export async function listAuditLogs(filters: AuditFilters) {
  const params: unknown[] = [];
  const conditions: string[] = [];
  const add = (value: unknown): string => {
    params.push(value);
    return `$${params.length}`;
  };

  if (filters.userId) {
    const placeholder = add(filters.userId);
    conditions.push(`(ol.user_id = ${placeholder} OR ol.user_name ILIKE '%' || ${placeholder} || '%')`);
  }
  if (filters.action) conditions.push(`ol.action = ${add(filters.action)}`);
  if (filters.objectType) conditions.push(`ol.object_type = ${add(filters.objectType)}`);
  if (filters.objectId) conditions.push(`ol.object_id = ${add(filters.objectId)}`);
  if (filters.dateFrom) conditions.push(`ol.occurred_at >= ${add(filters.dateFrom)}`);
  if (filters.dateTo) conditions.push(`ol.occurred_at <= ${add(filters.dateTo)}`);

  const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';
  const countParams = [...params];
  const listParams = [...params, filters.pageSize, filters.offset];
  const limit = `$${params.length + 1}`;
  const offset = `$${params.length + 2}`;

  const [countResult, listResult] = await Promise.all([
    query<{ total: string }>(`SELECT COUNT(*)::text AS total FROM operation_logs ol ${where}`, countParams),
    query<AuditLogRow>(
      `SELECT ol.id, ol.user_id, COALESCE(NULLIF(u.display_name, ''), ol.user_name) AS user_name,
              ol.occurred_at, ol.object_type, ol.object_id, ol.action, ol.result,
              ol.before_value, ol.after_value, ol.ip, ol.note
         FROM operation_logs ol
         LEFT JOIN users u ON u.id = ol.user_id
         ${where}
        ORDER BY ol.occurred_at DESC, ol.id DESC
        LIMIT ${limit} OFFSET ${offset}`,
      listParams,
    ),
  ]);

  return {
    items: listResult.rows.map(mapAuditLog),
    total: Number(countResult.rows[0]?.total ?? 0),
    page: filters.page,
    page_size: filters.pageSize,
  };
}

export async function cleanupAuditLogs(now = new Date(), retentionDays = 365): Promise<number> {
  const cutoff = new Date(now.getTime() - retentionDays * 86_400_000);
  const result = await query('DELETE FROM operation_logs WHERE occurred_at < $1', [cutoff]);
  return result.rowCount ?? 0;
}
