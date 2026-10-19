import type { PoolClient } from 'pg';

import type { AuthenticatedUser } from '../../../shared/auth/types.js';
import { hashPassword, verifyPassword } from '../../../shared/auth/password.js';
import { writeAudit } from '../../../shared/audit/writeAudit.js';
import { MESSAGES } from '../../../shared/constants/messages.js';
import { query, withTransaction } from '../../../shared/db/pool.js';
import { AppError, notFound, unauthorized, unprocessable } from '../../../shared/http/errors.js';
import { ACCESS_COPY } from './copy.js';
import { isLockActive, isPasswordLongEnough, nextFailureState } from './auth.rules.js';

export type AccessUserDto = AuthenticatedUser & {
  employeeNo: string | null;
  department: string | null;
};

type UserRow = {
  id: string;
  username: string;
  password_hash: string;
  display_name: string;
  role_code: string;
  host_id: string | null;
  status: 'active' | 'inactive';
  failed_login_count: number;
  locked_until: Date | null;
  employee_no: string | null;
  department: string | null;
};

type ConfigRow = { config_key: string; config_value: string };

function asDate(value: Date | string | null): Date | null {
  if (value === null) {
    return null;
  }
  return value instanceof Date ? value : new Date(value);
}

export function toAccessUser(row: UserRow): AccessUserDto {
  return {
    id: row.id,
    username: row.username,
    displayName: row.display_name,
    roleCode: row.role_code,
    hostId: row.host_id,
    employeeNo: row.employee_no,
    department: row.department,
  };
}

export function toSessionUser(user: AccessUserDto): AuthenticatedUser {
  return {
    id: user.id,
    username: user.username,
    displayName: user.displayName,
    roleCode: user.roleCode,
    hostId: user.hostId,
  };
}

export async function findLoginUser(
  client: Pick<PoolClient, 'query'>,
  username: string,
): Promise<UserRow | null> {
  const result = await client.query<UserRow>(
    `SELECT u.*, h.employee_no, h.department
       FROM users u
       LEFT JOIN hosts h ON h.id = u.host_id
      WHERE u.username = $1 OR h.employee_no = $1
      ORDER BY CASE WHEN u.username = $1 THEN 0 ELSE 1 END
      LIMIT 1
      FOR UPDATE OF u`,
    [username],
  );
  return result.rows[0] ?? null;
}

async function loadLoginPolicy(
  client: Pick<PoolClient, 'query'>,
): Promise<{ maxFailures: number; lockMinutes: number }> {
  const result = await client.query<ConfigRow>(
    `SELECT config_key, config_value
       FROM system_config
      WHERE config_key IN ('login_max_failures', 'login_lock_minutes')`,
  );
  const values = new Map(result.rows.map((row) => [row.config_key, Number(row.config_value)]));
  const maxFailures = values.get('login_max_failures');
  const lockMinutes = values.get('login_lock_minutes');
  return {
    maxFailures: Number.isInteger(maxFailures) && Number(maxFailures) > 0 ? Number(maxFailures) : 5,
    lockMinutes: Number.isInteger(lockMinutes) && Number(lockMinutes) > 0 ? Number(lockMinutes) : 10,
  };
}

type LoginResult =
  | { ok: true; user: AccessUserDto }
  | { ok: false; message: string };

export async function login(
  username: string,
  password: string,
  ip: string | null,
): Promise<AccessUserDto> {
  const result = await withTransaction<LoginResult>(async (client) => {
    const policy = await loadLoginPolicy(client);
    const user = await findLoginUser(client, username);

    if (!user) {
      await writeAudit(client, {
        userId: null,
        userName: username,
        objectType: 'auth',
        objectId: null,
        action: '登录',
        result: '失败',
        after: { username },
        ip,
        note: '账号不存在',
      });
      return { ok: false, message: MESSAGES.INVALID_CREDENTIALS };
    }

    if (user.status !== 'active') {
      await writeAudit(client, {
        userId: user.id,
        userName: user.display_name,
        objectType: 'auth',
        objectId: user.id,
        action: '登录',
        result: '拒绝',
        after: { username: user.username },
        ip,
        note: '账号已停用',
      });
      return { ok: false, message: MESSAGES.ACCOUNT_DISABLED };
    }

    const now = new Date();
    let lockedUntil = asDate(user.locked_until);
    if (isLockActive(lockedUntil, now)) {
      await writeAudit(client, {
        userId: user.id,
        userName: user.display_name,
        objectType: 'auth',
        objectId: user.id,
        action: '登录',
        result: '拒绝',
        after: { username: user.username },
        ip,
        note: '账号锁定中',
      });
      return { ok: false, message: MESSAGES.ACCOUNT_LOCKED };
    }

    if (lockedUntil && !isLockActive(lockedUntil, now)) {
      lockedUntil = null;
      await client.query(
        'UPDATE users SET failed_login_count = 0, locked_until = NULL, updated_at = now() WHERE id = $1',
        [user.id],
      );
    }

    if (!(await verifyPassword(password, user.password_hash))) {
      const failure = nextFailureState(
        user.failed_login_count,
        policy.maxFailures,
        policy.lockMinutes,
        now,
      );
      await client.query(
        `UPDATE users
            SET failed_login_count = $2,
                locked_until = CASE WHEN $3::boolean THEN $4::timestamptz ELSE NULL END,
                updated_at = now()
          WHERE id = $1`,
        [user.id, failure.failedLoginCount, failure.locked, failure.lockedUntil],
      );
      await writeAudit(client, {
        userId: user.id,
        userName: user.display_name,
        objectType: 'auth',
        objectId: user.id,
        action: '登录',
        result: '失败',
        before: { failed_login_count: user.failed_login_count, locked_until: user.locked_until },
        after: {
          failed_login_count: failure.failedLoginCount,
          locked_until: failure.lockedUntil,
        },
        ip,
        note: failure.locked ? '密码错误，账号已锁定' : '密码错误',
      });
      return {
        ok: false,
        message: failure.locked ? MESSAGES.ACCOUNT_LOCKED : MESSAGES.INVALID_CREDENTIALS,
      };
    }

    await client.query(
      `UPDATE users
          SET failed_login_count = 0,
              locked_until = NULL,
              last_login_at = now(),
              updated_at = now()
        WHERE id = $1`,
      [user.id],
    );
    await writeAudit(client, {
      userId: user.id,
      userName: user.display_name,
      objectType: 'auth',
      objectId: user.id,
      action: '登录',
      result: '成功',
      after: { last_login_at: now.toISOString() },
      ip,
    });

    return {
      ok: true,
      user: toAccessUser({
        ...user,
        failed_login_count: 0,
        locked_until: null,
      }),
    };
  });

  if (!result.ok) {
    throw unauthorized(result.message);
  }
  return result.user;
}

export async function logout(user: AuthenticatedUser, ip: string | null): Promise<void> {
  await withTransaction(async (client) => {
    await writeAudit(client, {
      userId: user.id,
      userName: user.displayName,
      objectType: 'auth',
      objectId: user.id,
      action: '退出登录',
      result: '成功',
      ip,
    });
  });
}

export async function changePassword(
  user: AuthenticatedUser,
  oldPassword: string,
  newPassword: string,
  ip: string | null,
): Promise<void> {
  if (!isPasswordLongEnough(newPassword)) {
    throw unprocessable(ACCESS_COPY.passwordTooShort, 'password');
  }

  await withTransaction(async (client) => {
    const result = await client.query<UserRow>(
      `SELECT u.*, h.employee_no, h.department
         FROM users u
         LEFT JOIN hosts h ON h.id = u.host_id
        WHERE u.id = $1
        FOR UPDATE OF u`,
      [user.id],
    );
    const row = result.rows[0];
    if (!row) {
      throw notFound(MESSAGES.NOT_FOUND);
    }

    if (!(await verifyPassword(oldPassword, row.password_hash))) {
      throw new AppError(422, 42201, ACCESS_COPY.oldPasswordIncorrect, 'old_password');
    }

    const passwordHash = await hashPassword(newPassword);
    await client.query(
      'UPDATE users SET password_hash = $2, updated_at = now() WHERE id = $1',
      [user.id, passwordHash],
    );
    await writeAudit(client, {
      userId: user.id,
      userName: user.displayName,
      objectType: 'auth',
      objectId: user.id,
      action: '修改密码',
      result: '成功',
      ip,
    });
  });
}

export async function getUserByHostId(hostId: string): Promise<AccessUserDto | null> {
  const result = await query<UserRow>(
    `SELECT u.*, h.employee_no, h.department
       FROM users u
       LEFT JOIN hosts h ON h.id = u.host_id
      WHERE u.host_id = $1
      ORDER BY u.created_at ASC
      LIMIT 1`,
    [hostId],
  );
  return result.rows[0] ? toAccessUser(result.rows[0]) : null;
}

export async function getUserById(id: string): Promise<AccessUserDto | null> {
  const result = await query<UserRow>(
    `SELECT u.*, h.employee_no, h.department
       FROM users u
       LEFT JOIN hosts h ON h.id = u.host_id
      WHERE u.id = $1
      LIMIT 1`,
    [id],
  );
  return result.rows[0] ? toAccessUser(result.rows[0]) : null;
}

export async function getFirstAdminUser(): Promise<AccessUserDto | null> {
  const result = await query<UserRow>(
    `SELECT u.*, h.employee_no, h.department
       FROM users u
       LEFT JOIN hosts h ON h.id = u.host_id
      WHERE u.role_code = 'admin' AND u.status = 'active'
      ORDER BY u.created_at ASC, u.id ASC
      LIMIT 1`,
  );
  return result.rows[0] ? toAccessUser(result.rows[0]) : null;
}
