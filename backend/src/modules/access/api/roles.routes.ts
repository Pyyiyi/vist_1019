import { Router } from 'express';

import { MESSAGES } from '../../../shared/constants/messages.js';
import { PERMISSIONS, ROLE_PERMISSIONS } from '../../../shared/auth/permissions.js';
import { query } from '../../../shared/db/pool.js';
import { asyncHandler } from '../../../shared/http/asyncHandler.js';
import { success } from '../../../shared/http/envelope.js';
import { notFound } from '../../../shared/http/errors.js';
import { requirePermission } from '../../../shared/middleware/requirePermission.js';

type RoleRow = { code: string; name: string; description: string };
type PermissionRow = { code: string; name: string; resource: string; action: string; description: string };

const router = Router();
async function listPermissionRows(roleCode: string): Promise<PermissionRow[]> {
  if (roleCode === 'admin') {
    const result = await query<PermissionRow>(
      `SELECT code, name, resource, action, description
         FROM permissions
        WHERE code = ANY($1::varchar[])
        ORDER BY code ASC`,
      [PERMISSIONS],
    );
    if (result.rows.length > 0) {
      return result.rows;
    }
    return PERMISSIONS.map((code) => ({
      code,
      name: code,
      resource: code.split(':')[1] ?? '',
      action: code.split(':').slice(2).join(':'),
      description: '',
    }));
  }

  const result = await query<PermissionRow>(
    `SELECT p.code, p.name, p.resource, p.action, p.description
       FROM role_permissions rp
       JOIN permissions p ON p.code = rp.permission_code
      WHERE rp.role_code = $1
      ORDER BY p.code ASC`,
    [roleCode],
  );
  if (result.rows.length > 0) {
    return result.rows;
  }
  return (ROLE_PERMISSIONS[roleCode as keyof typeof ROLE_PERMISSIONS] ?? []).map((code) => ({
    code,
    name: code,
    resource: code.split(':')[1] ?? '',
    action: code.split(':').slice(2).join(':'),
    description: '',
  }));
}

router.get(
  '/roles',
  requirePermission('access:role:read'),
  asyncHandler(async (_req, res) => {
    const roles = await query<RoleRow>(
      'SELECT code, name, description FROM roles ORDER BY created_at ASC, code ASC',
    );
    const items = await Promise.all(
      roles.rows.map(async (role) => ({
        ...role,
        permissions: await listPermissionRows(role.code),
      })),
    );
    return success(res, items);
  }),
);

router.get(
  '/roles/:code/permissions',
  requirePermission('access:role:read'),
  asyncHandler(async (req, res) => {
    const roleResult = await query<RoleRow>(
      'SELECT code, name, description FROM roles WHERE code = $1 LIMIT 1',
      [req.params.code],
    );
    const role = roleResult.rows[0];
    if (!role) {
      throw notFound(MESSAGES.NOT_FOUND);
    }
    return success(res, {
      role,
      permissions: await listPermissionRows(role.code),
    });
  }),
);

export default router;
