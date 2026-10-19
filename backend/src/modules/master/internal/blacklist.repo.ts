import type { QueryResultRow } from 'pg';

import { query } from '../../../shared/db/pool.js';
import type {
  BlacklistEntryDto,
  BlacklistStatus,
  Queryable,
} from './master.types.js';

type BlacklistRow = QueryResultRow & {
  id: string;
  id_no: string;
  name: string;
  reason: string;
  expire_at: Date | string;
  status: BlacklistStatus;
  created_at: Date | string;
};

function toDto(row: BlacklistRow): BlacklistEntryDto {
  return {
    id: row.id,
    idNo: row.id_no,
    name: row.name,
    reason: row.reason,
    expireAt: row.expire_at,
    status: row.status,
    createdAt: row.created_at,
  };
}

export async function listBlacklist(options: {
  pageSize: number;
  offset: number;
  keyword: string;
  status: BlacklistStatus | null;
}): Promise<{ items: BlacklistEntryDto[]; total: number }> {
  const values: unknown[] = [];
  const where: string[] = ["status <> '已删除'"];
  if (options.status) {
    values.push(options.status);
    where.push(`status = $${values.length}`);
  }
  if (options.keyword) {
    values.push(`%${options.keyword}%`);
    where.push(`(id_no ILIKE $${values.length} OR name ILIKE $${values.length})`);
  }
  const whereSql = where.join(' AND ');
  const countResult = await query<QueryResultRow & { count: number }>(
    `SELECT count(*)::int AS count FROM blacklist_entries WHERE ${whereSql}`,
    values,
  );
  const listValues = [...values, options.pageSize, options.offset];
  const result = await query<BlacklistRow>(
    `SELECT id, id_no, name, reason, expire_at, status, created_at
       FROM blacklist_entries
      WHERE ${whereSql}
      ORDER BY created_at DESC, id DESC
      LIMIT $${listValues.length - 1} OFFSET $${listValues.length}`,
    listValues,
  );
  return {
    items: result.rows.map(toDto),
    total: countResult.rows[0]?.count ?? 0,
  };
}

export async function findBlacklistById(
  client: Queryable,
  id: string,
  forUpdate = false,
): Promise<BlacklistEntryDto | null> {
  const result = await client.query<BlacklistRow>(
    `SELECT id, id_no, name, reason, expire_at, status, created_at
       FROM blacklist_entries WHERE id = $1 ${forUpdate ? 'FOR UPDATE' : ''}`,
    [id],
  );
  return result.rows[0] ? toDto(result.rows[0]) : null;
}

export async function findEffectiveBlacklistByIdNo(
  client: Queryable,
  idNo: string,
  now: Date,
): Promise<BlacklistEntryDto | null> {
  const result = await client.query<BlacklistRow>(
    `SELECT id, id_no, name, reason, expire_at, status, created_at
       FROM blacklist_entries
      WHERE id_no = $1 AND status = '有效' AND expire_at >= $2
      LIMIT 1`,
    [idNo, now],
  );
  return result.rows[0] ? toDto(result.rows[0]) : null;
}

export async function insertBlacklist(
  client: Queryable,
  row: { id: string; idNo: string; name: string; reason: string; expireAt: Date },
): Promise<BlacklistEntryDto> {
  const result = await client.query<BlacklistRow>(
    `INSERT INTO blacklist_entries (id, id_no, name, reason, expire_at, status)
     VALUES ($1, $2, $3, $4, $5, '有效')
     RETURNING id, id_no, name, reason, expire_at, status, created_at`,
    [row.id, row.idNo, row.name, row.reason, row.expireAt],
  );
  return toDto(result.rows[0]);
}

export async function softDeleteBlacklist(client: Queryable, id: string): Promise<void> {
  await client.query(
    `UPDATE blacklist_entries
        SET status = '已删除', deleted_at = now(), updated_at = now()
      WHERE id = $1`,
    [id],
  );
}

export async function expireBlacklistRows(now: Date): Promise<number> {
  const result = await query(
    `UPDATE blacklist_entries
        SET status = '已过期', updated_at = now()
      WHERE status = '有效' AND expire_at < $1`,
    [now],
  );
  return result.rowCount ?? 0;
}

export async function findMatchingEffectiveBlacklist(idNos: string[], now: Date): Promise<string[]> {
  if (idNos.length === 0) {
    return [];
  }
  const result = await query<QueryResultRow & { id_no: string }>(
    `SELECT DISTINCT id_no
       FROM blacklist_entries
      WHERE id_no = ANY($1::varchar[]) AND status = '有效' AND expire_at >= $2
      ORDER BY id_no ASC`,
    [idNos, now],
  );
  return result.rows.map((row) => row.id_no);
}
