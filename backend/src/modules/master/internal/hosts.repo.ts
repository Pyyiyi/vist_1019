import type { QueryResultRow } from 'pg';

import { query } from '../../../shared/db/pool.js';
import type { HostDto, Queryable, SoftStatus } from './master.types.js';

type HostRow = QueryResultRow & {
  id: string;
  name: string;
  employee_no: string;
  department: string;
  phone: string | null;
  status: SoftStatus;
  created_at: Date | string;
};

function toDto(row: HostRow): HostDto {
  return {
    id: row.id,
    name: row.name,
    employeeNo: row.employee_no,
    department: row.department ?? '',
    phone: row.phone,
    status: row.status,
    createdAt: row.created_at,
  };
}

export async function listHosts(options: {
  status?: SoftStatus;
  includeInactive: boolean;
}): Promise<HostDto[]> {
  const values: unknown[] = [];
  const where: string[] = [];
  if (options.status) {
    values.push(options.status);
    where.push(`status = $${values.length}`);
  } else if (!options.includeInactive) {
    where.push("status = 'active'");
  }
  const result = await query<HostRow>(
    `SELECT id, name, employee_no, department, phone, status, created_at
       FROM hosts
      ${where.length ? `WHERE ${where.join(' AND ')}` : ''}
      ORDER BY department ASC, employee_no ASC, id ASC`,
    values,
  );
  return result.rows.map(toDto);
}

export async function findHostById(
  client: Queryable,
  id: string,
  forUpdate = false,
): Promise<HostDto | null> {
  const result = await client.query<HostRow>(
    `SELECT id, name, employee_no, department, phone, status, created_at
       FROM hosts WHERE id = $1 ${forUpdate ? 'FOR UPDATE' : ''}`,
    [id],
  );
  return result.rows[0] ? toDto(result.rows[0]) : null;
}

export async function findHostByEmployeeNo(
  client: Queryable,
  employeeNo: string,
  excludeId: string | null = null,
): Promise<HostDto | null> {
  const result = await client.query<HostRow>(
    `SELECT id, name, employee_no, department, phone, status, created_at
       FROM hosts
      WHERE lower(employee_no) = lower($1) AND ($2::varchar IS NULL OR id <> $2)
      LIMIT 1`,
    [employeeNo, excludeId],
  );
  return result.rows[0] ? toDto(result.rows[0]) : null;
}

export async function insertHost(
  client: Queryable,
  row: {
    id: string;
    name: string;
    employeeNo: string;
    department: string;
    phone: string | null;
  },
): Promise<HostDto> {
  const result = await client.query<HostRow>(
    `INSERT INTO hosts (id, name, employee_no, department, phone, status)
     VALUES ($1, $2, $3, $4, $5, 'active')
     RETURNING id, name, employee_no, department, phone, status, created_at`,
    [row.id, row.name, row.employeeNo, row.department, row.phone],
  );
  return toDto(result.rows[0]);
}

export async function updateHost(
  client: Queryable,
  id: string,
  row: { name: string; employeeNo: string; department: string; phone: string | null },
): Promise<HostDto> {
  const result = await client.query<HostRow>(
    `UPDATE hosts
        SET name = $2, employee_no = $3, department = $4, phone = $5, updated_at = now()
      WHERE id = $1
      RETURNING id, name, employee_no, department, phone, status, created_at`,
    [id, row.name, row.employeeNo, row.department, row.phone],
  );
  return toDto(result.rows[0]);
}

export async function updateHostStatus(
  client: Queryable,
  id: string,
  status: SoftStatus,
): Promise<void> {
  await client.query('UPDATE hosts SET status = $2, updated_at = now() WHERE id = $1', [id, status]);
}
