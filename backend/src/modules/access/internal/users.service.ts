import type { PoolClient } from 'pg';

import type { AuthenticatedUser } from '../../../shared/auth/types.js';
import { hashPassword } from '../../../shared/auth/password.js';
import { writeAudit } from '../../../shared/audit/writeAudit.js';
import { MESSAGES } from '../../../shared/constants/messages.js';
import { query, withTransaction } from '../../../shared/db/pool.js';
import { parsePagination } from '../../../shared/http/pagination.js';
import { conflict, notFound, unprocessable } from '../../../shared/http/errors.js';
import { newUuid } from '../../../shared/utils/ids.js';
import { ACCESS_COPY } from './copy.js';
import {
  isAccountRole,
  isSelfDeactivation,
  normalizeHostBinding,
  wouldRemoveLastAdmin,
} from './users.rules.js';

export type UserDto = {
  id: string;
  username: string;
  displayName: string;
  roleCode: string;
  hostId: string | null;
  employeeNo: string | null;
  department: string;
  phone: string | null;
  status: 'active' | 'inactive';
  createdAt: Date | string;
};

type UserRow = {
  id: string;
  username: string;
  display_name: string;
  role_code: string;
  host_id: string | null;
  phone: string | null;
  status: 'active' | 'inactive';
  created_at: Date | string;
  employee_no: string | null;
  department: string | null;
};

type CountRow = { count: number };

type HostRow = {
  id: string;
  name: string;
  employee_no: string;
  department: string;
  status: string;
};

export type ListUsersQuery = {
  page?: unknown;
  page_size?: unknown;
  keyword?: unknown;
  role?: unknown;
  role_code?: unknown;
  status?: unknown;
};

export type CreateUserInput = {
  username?: unknown;
  password?: unknown;
  display_name?: unknown;
  role_code?: unknown;
  host_id?: unknown;
  department?: unknown;
  phone?: unknown;
};

export type UpdateUserInput = {
  display_name?: unknown;
  department?: unknown;
  role_code?: unknown;
  host_id?: unknown;
  phone?: unknown;
};

function stringValue(value: unknown): string {
  return typeof value === 'string' ? value.trim() : '';
}

function nullableString(value: unknown): string | null {
  if (value === null || value === undefined) {
    return null;
  }
  const normalized = stringValue(value);
  return normalized === '' ? null : normalized;
}

function toUserDto(row: UserRow): UserDto {
  return {
    id: row.id,
    username: row.username,
    displayName: row.display_name,
    roleCode: row.role_code,
    hostId: row.host_id,
    employeeNo: row.employee_no,
    department: row.department ?? '',
    phone: row.phone,
    status: row.status,
    createdAt: row.created_at,
  };
}

async function findUserRow(
  client: Pick<PoolClient, 'query'>,
  id: string,
  forUpdate = false,
): Promise<UserRow | null> {
  const result = await client.query<UserRow>(
    `SELECT u.id, u.username, u.display_name, u.role_code, u.host_id, u.phone,
            u.status, u.created_at, h.employee_no, h.department
       FROM users u
       LEFT JOIN hosts h ON h.id = u.host_id
      WHERE u.id = $1
      ${forUpdate ? 'FOR UPDATE OF u' : ''}`,
    [id],
  );
  return result.rows[0] ?? null;
}

async function requireUserRow(
  client: Pick<PoolClient, 'query'>,
  id: string,
  forUpdate = false,
): Promise<UserRow> {
  const row = await findUserRow(client, id, forUpdate);
  if (!row) {
    throw notFound(MESSAGES.NOT_FOUND);
  }
  return row;
}

async function validateHostBinding(
  client: Pick<PoolClient, 'query'>,
  hostId: string,
  userId: string | null,
): Promise<HostRow> {
  const hostResult = await client.query<HostRow>(
    'SELECT id, name, employee_no, department, status FROM hosts WHERE id = $1',
    [hostId],
  );
  const host = hostResult.rows[0];
  if (!host) {
    throw unprocessable('绑定教职工不存在', 'host_id');
  }
  if (host.status !== 'active') {
    throw unprocessable('绑定教职工已停用', 'host_id');
  }

  const bound = await client.query<{ id: string }>(
    'SELECT id FROM users WHERE host_id = $1 AND ($2::varchar IS NULL OR id <> $2) LIMIT 1',
    [hostId, userId],
  );
  if (bound.rows[0]) {
    throw conflict('该教职工已绑定其他账号');
  }
  return host;
}

async function activeAdminCount(client: Pick<PoolClient, 'query'>): Promise<number> {
  const result = await client.query<CountRow>(
    "SELECT COUNT(*)::int AS count FROM users WHERE role_code = 'admin' AND status = 'active'",
  );
  return result.rows[0]?.count ?? 0;
}

export async function listUsers(input: ListUsersQuery): Promise<{
  items: UserDto[];
  total: number;
  page: number;
  pageSize: number;
}> {
  const pagination = parsePagination(input as Record<string, unknown>);
  const conditions: string[] = [];
  const params: unknown[] = [];

  const keyword = stringValue(input.keyword);
  if (keyword) {
    params.push(`%${keyword}%`);
    const index = params.length;
    conditions.push(
      `(u.username ILIKE $${index} OR u.display_name ILIKE $${index} OR h.employee_no ILIKE $${index})`,
    );
  }

  const role = stringValue(input.role_code ?? input.role);
  if (role) {
    params.push(role);
    conditions.push(`u.role_code = $${params.length}`);
  }

  const status = stringValue(input.status);
  if (status) {
    params.push(status);
    conditions.push(`u.status = $${params.length}`);
  }

  const where = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';
  const countResult = await query<CountRow>(
    `SELECT COUNT(*)::int AS count
       FROM users u
       LEFT JOIN hosts h ON h.id = u.host_id
       ${where}`,
    params,
  );

  const itemParams = [...params, pagination.pageSize, pagination.offset];
  const result = await query<UserRow>(
    `SELECT u.id, u.username, u.display_name, u.role_code, u.host_id, u.phone,
            u.status, u.created_at, h.employee_no, h.department
       FROM users u
       LEFT JOIN hosts h ON h.id = u.host_id
       ${where}
      ORDER BY u.created_at DESC, u.username ASC
      LIMIT $${params.length + 1} OFFSET $${params.length + 2}`,
    itemParams,
  );

  return {
    items: result.rows.map(toUserDto),
    total: countResult.rows[0]?.count ?? 0,
    page: pagination.page,
    pageSize: pagination.pageSize,
  };
}

export async function createUser(
  input: CreateUserInput,
  actor: AuthenticatedUser,
  ip: string | null,
): Promise<UserDto> {
  const username = stringValue(input.username);
  const password = typeof input.password === 'string' ? input.password : '';
  const displayName = stringValue(input.display_name);
  const roleCode = stringValue(input.role_code);

  if (!username) {
    throw unprocessable('请输入账号', 'username');
  }
  if (password.length < 6) {
    throw unprocessable(ACCESS_COPY.passwordTooShort, 'password');
  }
  if (!displayName) {
    throw unprocessable('请输入姓名', 'display_name');
  }
  if (!isAccountRole(roleCode)) {
    throw unprocessable('请选择角色', 'role_code');
  }

  return withTransaction(async (client) => {
    const duplicate = await client.query<{ id: string }>(
      'SELECT id FROM users WHERE username = $1 LIMIT 1',
      [username],
    );
    if (duplicate.rows[0]) {
      throw conflict('账号已存在');
    }

    let hostId = normalizeHostBinding(roleCode, nullableString(input.host_id));
    if (roleCode === 'host') {
      if (!hostId) {
        throw unprocessable('请选择绑定教职工', 'host_id');
      }
      const host = await validateHostBinding(client, hostId, null);
      const department = nullableString(input.department);
      if (department) {
        await client.query(
          'UPDATE hosts SET department = $2, updated_at = now() WHERE id = $1',
          [hostId, department],
        );
      } else {
        input.department = host.department;
      }
    } else {
      hostId = null;
    }

    const id = newUuid();
    const passwordHash = await hashPassword(password);
    await client.query(
      `INSERT INTO users (
         id, username, password_hash, display_name, role_code, host_id, phone, status
       ) VALUES ($1, $2, $3, $4, $5, $6, $7, 'active')`,
      [id, username, passwordHash, displayName, roleCode, hostId, nullableString(input.phone)],
    );

    const created = await requireUserRow(client, id);
    await writeAudit(client, {
      userId: actor.id,
      userName: actor.displayName,
      objectType: 'users',
      objectId: id,
      action: '新增账号',
      result: '成功',
      after: {
        username: created.username,
        display_name: created.display_name,
        role_code: created.role_code,
        host_id: created.host_id,
      },
      ip,
    });
    return toUserDto(created);
  });
}

export async function updateUser(
  id: string,
  input: UpdateUserInput,
  actor: AuthenticatedUser,
): Promise<UserDto> {
  if (!id) {
    throw notFound(MESSAGES.NOT_FOUND);
  }

  return withTransaction(async (client) => {
    const row = await requireUserRow(client, id, true);
    const nextDisplayName =
      input.display_name === undefined ? row.display_name : stringValue(input.display_name);
    if (!nextDisplayName) {
      throw unprocessable('请输入姓名', 'display_name');
    }

    const nextRole =
      input.role_code === undefined ? row.role_code : stringValue(input.role_code);
    if (!isAccountRole(nextRole)) {
      throw unprocessable('请选择角色', 'role_code');
    }

    let nextHostId: string | null;
    if (input.host_id !== undefined) {
      nextHostId = normalizeHostBinding(nextRole, nullableString(input.host_id));
    } else {
      nextHostId = normalizeHostBinding(nextRole, row.host_id);
    }

    if (nextRole === 'host' && !nextHostId) {
      throw unprocessable('请选择绑定教职工', 'host_id');
    }
    if (nextHostId && nextHostId !== row.host_id) {
      await validateHostBinding(client, nextHostId, id);
    }

    if (
      wouldRemoveLastAdmin({
        targetRole: row.role_code,
        targetStatus: row.status,
        nextRole,
        nextStatus: row.status,
        activeAdminCount: await activeAdminCount(client),
      })
    ) {
      throw conflict(ACCESS_COPY.lastActiveAdmin);
    }

    await client.query(
      `UPDATE users
          SET display_name = $2,
              role_code = $3,
              host_id = $4,
              phone = CASE WHEN $5::boolean THEN $6::varchar ELSE phone END,
              updated_at = now()
        WHERE id = $1`,
      [
        id,
        nextDisplayName,
        nextRole,
        nextHostId,
        Object.prototype.hasOwnProperty.call(input, 'phone'),
        nullableString(input.phone),
      ],
    );

    const department = nullableString(input.department);
    if (nextHostId && department !== null) {
      await client.query(
        'UPDATE hosts SET department = $2, updated_at = now() WHERE id = $1',
        [nextHostId, department],
      );
    }

    const updated = await requireUserRow(client, id);
    return toUserDto(updated);
  });
}

export async function changeUserStatus(
  id: string,
  status: 'active' | 'inactive',
  actor: AuthenticatedUser,
  ip: string | null,
): Promise<{ id: string; status: 'active' | 'inactive' }> {
  return withTransaction(async (client) => {
    const row = await requireUserRow(client, id, true);

    if (isSelfDeactivation(actor.id, id, status)) {
      throw conflict(ACCESS_COPY.selfProtection);
    }

    if (row.status === status) {
      return { id, status };
    }

    if (
      wouldRemoveLastAdmin({
        targetRole: row.role_code,
        targetStatus: row.status,
        nextStatus: status,
        activeAdminCount: await activeAdminCount(client),
      })
    ) {
      throw conflict(ACCESS_COPY.lastActiveAdmin);
    }

    await client.query(
      'UPDATE users SET status = $2, updated_at = now() WHERE id = $1',
      [id, status],
    );
    await writeAudit(client, {
      userId: actor.id,
      userName: actor.displayName,
      objectType: 'users',
      objectId: id,
      action: status === 'inactive' ? '停用账号' : '启用账号',
      result: '成功',
      before: { status: row.status },
      after: { status },
      ip,
    });
    return { id, status };
  });
}

export async function resetUserPassword(
  id: string,
  password: string,
  actor: AuthenticatedUser,
  ip: string | null,
): Promise<void> {
  if (password.length < 6) {
    throw unprocessable(ACCESS_COPY.passwordTooShort, 'password');
  }

  await withTransaction(async (client) => {
    const row = await requireUserRow(client, id, true);
    const passwordHash = await hashPassword(password);
    await client.query(
      `UPDATE users
          SET password_hash = $2,
              failed_login_count = 0,
              locked_until = NULL,
              updated_at = now()
        WHERE id = $1`,
      [id, passwordHash],
    );
    await writeAudit(client, {
      userId: actor.id,
      userName: actor.displayName,
      objectType: 'users',
      objectId: id,
      action: '重置密码',
      result: '成功',
      after: { failed_login_count: 0, locked_until: null },
      ip,
    });
  });
}

export async function activeAdmins(): Promise<number> {
  return query<CountRow>(
    "SELECT COUNT(*)::int AS count FROM users WHERE role_code = 'admin' AND status = 'active'",
  ).then((result) => result.rows[0]?.count ?? 0);
}
