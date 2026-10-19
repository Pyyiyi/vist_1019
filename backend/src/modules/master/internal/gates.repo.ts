import type { QueryResultRow } from 'pg';

import { query } from '../../../shared/db/pool.js';
import type { GateDto, Queryable, SoftStatus } from './master.types.js';

type GateRow = QueryResultRow & {
  id: string;
  code: string;
  name: string;
  status: SoftStatus;
  sort_order: number;
  created_at: Date | string;
};

function toDto(row: GateRow): GateDto {
  return {
    id: row.id,
    code: row.code,
    name: row.name,
    status: row.status,
    sortOrder: row.sort_order,
    createdAt: row.created_at,
  };
}

export async function listGates(options: {
  status?: SoftStatus;
  includeInactive: boolean;
}): Promise<GateDto[]> {
  const values: unknown[] = [];
  const where: string[] = [];
  if (options.status) {
    values.push(options.status);
    where.push(`status = $${values.length}`);
  } else if (!options.includeInactive) {
    where.push("status = 'active'");
  }
  const result = await query<GateRow>(
    `SELECT id, code, name, status, sort_order, created_at
       FROM gates
      ${where.length ? `WHERE ${where.join(' AND ')}` : ''}
      ORDER BY sort_order ASC, name ASC, id ASC`,
    values,
  );
  return result.rows.map(toDto);
}

export async function findGateById(
  client: Queryable,
  id: string,
  forUpdate = false,
): Promise<GateDto | null> {
  const result = await client.query<GateRow>(
    `SELECT id, code, name, status, sort_order, created_at
       FROM gates WHERE id = $1 ${forUpdate ? 'FOR UPDATE' : ''}`,
    [id],
  );
  return result.rows[0] ? toDto(result.rows[0]) : null;
}

export async function findGateByName(
  client: Queryable,
  name: string,
  excludeId: string | null = null,
): Promise<GateDto | null> {
  const result = await client.query<GateRow>(
    `SELECT id, code, name, status, sort_order, created_at
       FROM gates
      WHERE lower(name) = lower($1) AND ($2::varchar IS NULL OR id <> $2)
      LIMIT 1`,
    [name, excludeId],
  );
  return result.rows[0] ? toDto(result.rows[0]) : null;
}

export async function insertGate(
  client: Queryable,
  row: { id: string; code: string; name: string; sortOrder: number },
): Promise<GateDto> {
  const result = await client.query<GateRow>(
    `INSERT INTO gates (id, code, name, status, sort_order)
     VALUES ($1, $2, $3, 'active', $4)
     RETURNING id, code, name, status, sort_order, created_at`,
    [row.id, row.code, row.name, row.sortOrder],
  );
  return toDto(result.rows[0]);
}

export async function updateGateName(
  client: Queryable,
  id: string,
  name: string,
): Promise<GateDto> {
  const result = await client.query<GateRow>(
    `UPDATE gates SET name = $2, updated_at = now() WHERE id = $1
     RETURNING id, code, name, status, sort_order, created_at`,
    [id, name],
  );
  return toDto(result.rows[0]);
}

export async function updateGateStatus(
  client: Queryable,
  id: string,
  status: SoftStatus,
): Promise<void> {
  await client.query('UPDATE gates SET status = $2, updated_at = now() WHERE id = $1', [id, status]);
}
