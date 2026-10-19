# Phase 0 契约摘要（p0-contracts）

> 本文件是 Phase 1 领域卡消费的上游契约。表结构以 `schema-shared.sql` 与 `spac.md` §5 为准；端点以 `spac.md` §6 为准。
> Phase 0 结束时以下内容全部可用。

---

## 一、共享表

| 表 | 关键列 | 约束 |
|----|--------|------|
| `roles` | `code`, `name`, `description`, `is_system` | PK `code`；CHECK `code IN ('admin','guard','host','visitor')` |
| `permissions` | `code`, `name`, `resource`, `action`, `description` | PK `code` |
| `role_permissions` | `role_code`, `permission_code` | PK 两列；FK 到 `roles` / `permissions` |
| `users` | `id`, `username`, `password_hash`, `display_name`, `role_code`, `host_id`, `phone`, `status`, `failed_login_count`, `locked_until`, `last_login_at` | UNIQUE `username`；CHECK `status IN ('active','inactive')` |
| `auth_types` | `code`, `name`, `description`, `enabled` | PK `code` |
| `sessions` | `sid`, `sess`, `expire` | PK `sid`；索引 `expire` |
| `operation_logs` | `id`, `user_id`, `user_name`, `occurred_at`, `object_type`, `object_id`, `action`, `result`, `before_value`, `after_value`, `ip`, `note` | 索引 `occurred_at DESC`、`(object_type,object_id)` |
| `system_config` | `config_key`, `config_value`, `value_type`, `description`, `updated_at` | PK `config_key`；CHECK `value_type IN ('string','number','boolean','json')` |

迁移表：`_migrations(filename TEXT PRIMARY KEY, applied_at TIMESTAMPTZ NOT NULL DEFAULT now())`。

---

## 二、认证端点

### `GET /api/v1/auth/csrf`

- 认证：公开
- 响应：`{ code: 0, message: '操作成功', data: { csrf_token: string } }`
- Set-Cookie：`vs.csrf=<token>; Path=/; SameSite=Lax`

### `POST /api/v1/auth/login`

- 认证：公开；无会话时豁免 CSRF
- 请求：`{ "username": "admin", "password": "abc@123" }`
- 成功：`{ code: 0, message: '登录成功', data: { user: { id, username, display_name, role_code, host_id } } }`
- Set-Cookie：`vs.sid`
- 失败：
  - 401 `40102` COPY-002
  - 401 `40103` COPY-003
  - 401 `40104` COPY-004
  - 422 `42201`，`field=username` / `field=password`
  - 429 `42901` COPY-012

### `POST /api/v1/auth/logout`

- 认证：已登录
- 成功：`{ code: 0, message: '已退出登录', data: { logged_out: true } }`
- 失败：401 COPY-001

### `GET /api/v1/auth/me`

- 认证：已登录
- 成功：`data: { user: { id, username, display_name, role_code, host_id } }`
- 失败：401 COPY-001

### `PUT /api/v1/auth/password`

- 认证：已登录
- 请求：`{ "old_password": "...", "new_password": "..." }`
- 成功：`data: { changed: true }`，message COPY-029
- 失败：401 COPY-030；422 `field=new_password` COPY-031

---

## 三、共享内核可用符号

后端：

| 路径 | 符号 |
|------|------|
| `backend/src/shared/http/envelope.ts` | `success`, `fail`, `paginated` |
| `backend/src/shared/http/errors.ts` | `AppError`, `badRequest`, `unauthorized`, `forbidden`, `notFound`, `conflict`, `methodNotAllowed`, `unprocessable` |
| `backend/src/shared/http/pagination.ts` | `parsePagination`, `Pagination` |
| `backend/src/shared/http/asyncHandler.ts` | `asyncHandler` |
| `backend/src/shared/http/responseEnvelope.ts` | `responseEnvelope` |
| `backend/src/shared/http/errorHandler.ts` | `errorHandler` |
| `backend/src/shared/http/notFoundHandler.ts` | `notFoundHandler` |
| `backend/src/shared/middleware/requestContext.ts` | `requestContext`, `RequestContext` |
| `backend/src/shared/middleware/requireAuth.ts` | `requireAuth` |
| `backend/src/shared/middleware/requirePermission.ts` | `requirePermission`, `requireAdmin` |
| `backend/src/shared/middleware/visitorTokenAuth.ts` | `visitorTokenAuth` |
| `backend/src/shared/middleware/csrfProtection.ts` | `csrfProtection` |
| `backend/src/shared/middleware/rateLimiter.ts` | `loginRateLimiter`, `apiRateLimiter` |
| `backend/src/shared/middleware/auditMiddleware.ts` | `auditMiddleware` |
| `backend/src/shared/auth/session.ts` | `sessionMiddleware` |
| `backend/src/shared/auth/password.ts` | `hashPassword`, `verifyPassword` |
| `backend/src/shared/auth/permissions.ts` | `PERMISSIONS`, `hasPermission` |
| `backend/src/shared/audit/writeAudit.ts` | `writeAudit`, `AuditEntry` |
| `backend/src/shared/db/pool.ts` | `getPool`, `query`, `withTransaction` |
| `backend/src/shared/db/migrate.ts` | `runMigrations` |
| `backend/src/shared/db/seed.ts` | `runSeeds` |
| `backend/src/shared/config/configService.ts` | `getConfig`, `getConfigNumber`, `setConfig` |
| `backend/src/shared/utils/mask.ts` | `maskIdNo` |
| `backend/src/shared/utils/ids.ts` | `newUuid`, `formatMinute`, `formatSecond`, `localDayRange` |
| `backend/src/shared/utils/appointmentNo.ts` | `nextAppointmentNo`, `generateShortCode` |
| `backend/src/shared/validation/validators.ts` | `validateBody`, `validateQuery`, `isValidIdCard`, `isValidPhone`, `isValidOtherId`, `normalizeIdNo` |
| `backend/src/shared/constants/status.ts` | `APPOINTMENT_STATUSES`, `TERMINAL_STATUSES`, `OPEN_STATUSES`, `ATTENDED_STATUSES`, `INCIDENT_STATUSES`, `INCIDENT_TYPES` |
| `backend/src/shared/constants/messages.ts` | `MESSAGES` |
| `backend/src/shared/logger.ts` | `logger` |
| `backend/src/shared/jobs/scheduler.ts` | `registerJob`, `startJobs`, `stopAllJobs`, `JobDefinition` |
| `backend/src/realtime/io.ts` | `initRealtime`, `emitNotification` |

前端：

| 路径 | 符号 |
|------|------|
| `frontend/src/api/client.ts` | `default`（`apiClient`） |
| `frontend/src/stores/auth.ts` | `useAuthStore`, `AuthUser` |
| `frontend/src/stores/notification.ts` | `useNotificationStore` |
| `frontend/src/realtime/socket.ts` | `connectRealtime`, `disconnectRealtime` |
| `frontend/src/nav/navigation.ts` | `navigation`, `filterNavigation`, `NavItem` |
| `frontend/src/components/PageHeader.vue` | `default` |
| `frontend/src/components/StatusTag.vue` | `default` |
| `frontend/src/components/EmptyState.vue` | `default` |
| `frontend/src/components/ConfirmDialog.vue` | `default` |
| `frontend/src/components/CopyButton.vue` | `default` |
| `frontend/src/layouts/AppLayout.vue` | `default` |
| `frontend/src/layouts/H5Layout.vue` | `default` |

---

## 四、种子锚点

全部 UUID 与中文业务值见 `seed-anchors.sql`。Phase 1 卡必须逐字引用：

> 种子锚点日期 `D0` = 执行 `npm run seed` 的本地日期（Asia/Shanghai）。下表的预约编号按 `AP` + `D0` 的 `YYYYMMDD` + 二位序号生成；表内 `AP20261012001` 等为 `D0 = 2026-10-12` 时的示例值，运行时以 D0 实际日期为准。

| 实体 | UUID | 业务值 |
|------|------|--------|
| 管理员账号 | `11111111-1111-4111-8111-111111111111` | `admin` / 系统管理员 |
| 门卫账号 | `22222222-2222-4222-8222-222222222222` | `guard01` / 门卫张师傅 |
| 教职工 H1 | `33333333-3333-4333-8333-333333333333` | 李明 / T001 / 教务处 |
| H1 账号 | `33333333-3333-4333-8333-333333333334` | T001 / 李明 |
| 教职工 H2 | `44444444-4444-4444-8444-444444444444` | 王芳 / T002 / 学生处 |
| H2 账号 | `44444444-4444-4444-8444-444444444445` | T002 / 王芳 |
| 访客类型 家长 | `55555555-5555-4555-8555-555555555551` | 家长 |
| 访客类型 外来人员 | `55555555-5555-4555-8555-555555555552` | 外来人员 |
| 访客类型 公务来访 | `55555555-5555-4555-8555-555555555553` | 公务来访 |
| 校门 东门 | `66666666-6666-4666-8666-666666666661` | 东门 |
| 校门 南门 | `66666666-6666-4666-8666-666666666662` | 南门 |
| 黑名单 | `77777777-7777-4777-8777-777777777701` | 赵某某 / `320101198803034566` |
| 预约 P1 | `88888888-8888-4888-8888-888888888801` | `AP20261012001` / 陈晨 / 待审核 |
| 预约 P2 | `88888888-8888-4888-8888-888888888802` | `AP20261012002` / 刘洋 / 已通过 |
| 预约 P3 | `88888888-8888-4888-8888-888888888803` | `AP20261012003` / 周敏 / 待审核 |
| 预约 P4 | `88888888-8888-4888-8888-888888888804` | `AP20261012004` / 孙浩 / 已到访(在校中) |
| 预约 P5 | `88888888-8888-4888-8888-888888888805` | `AP20261012005` / 吴倩 / 已离校 |
| 预约 P6 | `88888888-8888-4888-8888-888888888806` | `AP20261012006` / 陈晨 / 已改期 |
| 预约 P7 | `88888888-8888-4888-8888-888888888807` | `AP20261012007` / 郑凯 / 已拒绝 |
| 预约 P8 | `88888888-8888-4888-8888-888888888808` | `AP20261012008` / 冯雪 / 已过期 |
| 预约 P9 | `88888888-8888-4888-8888-888888888809` | `AP20261012009` / 蒋涛 / 已取消 |
| 预约 P10 | `88888888-8888-4888-8888-888888888810` | `AP20261012010` / 韩梅 / 待审核 / 黑名单命中 |
| 预约 P11 | `88888888-8888-4888-8888-888888888811` | `AP20261012011` / 杨帆 / 已通过 |

短码：P1–P11 对应 `100001`–`100011`。

---

## 五、迁移与种子命令

```bash
cd backend
npm run migrate      # tsx src/db/migrate.ts
npm run seed         # tsx src/db/seed.ts
```

容器内：

```bash
docker compose exec backend npm run migrate
docker compose exec backend npm run seed
```

---

## 六、Phase 0 完成判据

- [ ] 三服务 healthy。
- [ ] `GET /api/v1/health` 返回 `{code:0,data:{status:'ok'}}`。
- [ ] `_migrations` 有 5 条记录；全部表存在。
- [ ] 4 个种子账号可登录。
- [ ] 11 条预约覆盖 8 个状态。
- [ ] 共享内核单测通过。
- [ ] `contracts/` 七件套存在。
