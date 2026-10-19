import type { QueryResultRow } from 'pg';

import { query } from '../../../shared/db/pool.js';
import type { Queryable, SoftStatus, VisitorTypeDto } from './master.types.js';

type VisitorTypeRow = QueryResultRow & {
  id: string;
  code: string;
  name: string;
  status: SoftStatus;
  sort_order: number;
  created_at: Date | string;
};

function toDto(row: VisitorTypeRow): VisitorTypeDto {
  return {
    id: row.id,
    code: row.code,
    name: row.name,
    status: row.status,
    sortOrder: row.sort_order,
    createdAt: row.created_at,
  };
}

export async function listVisitorTypes(options: {
  status?: SoftStatus;
  includeInactive: boolean;
}): Promise<VisitorTypeDto[]> {
  const values: unknown[] = [];
  const where: string[] = [];
  if (options.status) {
    values.push(options.status);
    where.push(`status = $${values.length}`);
  } else if (!options.includeInactive) {
    where.push("status = 'active'");
  }
  const result = await query<VisitorTypeRow>(
    `SELECT id, code, name, status, sort_order, created_at
       FROM visitor_types
      ${where.length ? `WHERE ${where.join(' AND ')}` : ''}
      ORDER BY sort_order ASC, name ASC, id ASC`,
    values,
  );
  return result.rows.map(toDto);
}

export async function findVisitorTypeById(
  client: Queryable,
  id: string,
  forUpdate = false,
): Promise<VisitorTypeDto | null> {
  const result = await client.query<VisitorTypeRow>(
    `SELECT id, code, name, status, sort_order, created_at
       FROM visitor_types WHERE id = $1 ${forUpdate ? 'FOR UPDATE' : ''}`,
    [id],
  );
  return result.rows[0] ? toDto(result.rows[0]) : null;
}

export async function findVisitorTypeByName(
  client: Queryable,
  name: string,
  excludeId: string | null = null,
): Promise<VisitorTypeDto | null> {
  const result = await client.query<VisitorTypeRow>(
    `SELECT id, code, name, status, sort_order, created_at
       FROM visitor_types
      WHERE lower(name) = lower($1) AND ($2::varchar IS NULL OR id <> $2)
      LIMIT 1 ${excludeId ? 'FOR UPDATE' : ''}`,
    [name, excludeId],
  );
  return result.rows[0] ? toDto(result.rows[0]) : null;
}

export async function insertVisitorType(
  client: Queryable,
  row: { id: string; code: string; name: string; sortOrder: number },
): Promise<VisitorTypeDto> {
  const result = await client.query<VisitorTypeRow>(
    `INSERT INTO visitor_types (id, code, name, status, sort_order)
     VALUES ($1, $2, $3, 'active', $4)
     RETURNING id, code, name, status, sort_order, created_at`,
    [row.id, row.code, row.name, row.sortOrder],
  );
  return toDto(result.rows[0]);
}

export async function updateVisitorTypeName(
  client: Queryable,
  id: string,
  name: string,
): Promise<VisitorTypeDto> {
  const result = await client.query<VisitorTypeRow>(
    `UPDATE visitor_types SET name = $2, updated_at = now()
      WHERE id = $1
      RETURNING id, code, name, status, sort_order, created_at`,
    [id, name],
  );
  return toDto(result.rows[0]);
}

export async function updateVisitorTypeStatus(
  client: Queryable,
  id: string,
  status: SoftStatus,
): Promise<void> {
  await client.query(
    'UPDATE visitor_types SET status = $2, updated_at = now() WHERE id = $1',
    [id, status],
  );
}
