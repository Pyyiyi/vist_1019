import { Router, type Request } from 'express';

import { requirePermission } from '../../../shared/middleware/requirePermission.js';
import { asyncHandler } from '../../../shared/http/asyncHandler.js';
import { paginated, success } from '../../../shared/http/envelope.js';
import { methodNotAllowed, unprocessable } from '../../../shared/http/errors.js';
import * as usersService from '../internal/users.service.js';
import type { UserDto } from '../internal/users.service.js';

const router = Router();
function requestIp(req: Request): string | null {
  return req.ip || req.socket.remoteAddress || null;
}

function apiUser(user: UserDto): Record<string, unknown> {
  return {
    id: user.id,
    username: user.username,
    display_name: user.displayName,
    role_code: user.roleCode,
    host_id: user.hostId,
    employee_no: user.employeeNo,
    department: user.department,
    phone: user.phone,
    status: user.status,
    created_at: user.createdAt,
  };
}

router.get(
  '/users',
  requirePermission('access:user:manage'),
  asyncHandler(async (req, res) => {
    const result = await usersService.listUsers(req.query);
    return paginated(
      res,
      result.items.map(apiUser),
      result.total,
      result.page,
      result.pageSize,
    );
  }),
);

router.post(
  '/users',
  requirePermission('access:user:manage'),
  asyncHandler(async (req, res) => {
    const user = await usersService.createUser(
      req.body,
      req.currentUser!,
      requestIp(req),
    );
    return success(res, apiUser(user), '新增成功');
  }),
);

router.put(
  '/users/:id',
  requirePermission('access:user:manage'),
  asyncHandler(async (req, res) => {
    const user = await usersService.updateUser(req.params.id, req.body, req.currentUser!);
    return success(res, apiUser(user));
  }),
);

router.put(
  '/users/:id/status',
  requirePermission('access:user:manage'),
  asyncHandler(async (req, res) => {
    const status = req.body.status;
    if (status !== 'active' && status !== 'inactive') {
      throw unprocessable('状态值不正确', 'status');
    }
    const result = await usersService.changeUserStatus(
      req.params.id,
      status,
      req.currentUser!,
      requestIp(req),
    );
    return success(res, result);
  }),
);

router.put(
  '/users/:id/password',
  requirePermission('access:user:manage'),
  asyncHandler(async (req, res) => {
    const password = typeof req.body.password === 'string' ? req.body.password : '';
    await usersService.resetUserPassword(
      req.params.id,
      password,
      req.currentUser!,
      requestIp(req),
    );
    return success(res, { reset: true });
  }),
);

router.delete(
  '/users/:id',
  requirePermission('access:user:manage'),
  asyncHandler(async () => {
    throw methodNotAllowed();
  }),
);

export default router;
