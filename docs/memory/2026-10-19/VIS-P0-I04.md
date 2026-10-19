# VIS-P0-I04 · 认证与会话中间件卡

- 执行日期：2026-10-19
- 卡片：VIS-P0-I04（Plane `337f0cc4-12cc-4936-906c-d4037ecb5a70`）
- 结果：完成；会话、CSRF、权限闸门、访客令牌、登录限流与密码工具已实现，五类单测全部通过。

## 交付文件

### 认证原语

- `backend/src/shared/auth/session.ts`
- `backend/src/shared/auth/password.ts`
- `backend/src/shared/auth/permissions.ts`
- `backend/src/shared/auth/types.ts`

### 请求闸门

- `backend/src/shared/middleware/requireAuth.ts`
- `backend/src/shared/middleware/requirePermission.ts`
- `backend/src/shared/middleware/csrfProtection.ts`
- `backend/src/shared/middleware/visitorTokenAuth.ts`
- `backend/src/shared/middleware/rateLimiter.ts`

### 常量、测试与依赖

- `backend/src/shared/constants/messages.ts`
- `backend/src/shared/__tests__/auth.test.ts`
- `backend/package.json`
- `backend/package-lock.json`

## 实现摘要

- `sessionMiddleware` 使用 `express-session` + `connect-pg-simple`，表 `sessions`，Cookie `vs.sid`，8 小时过期；默认 Store 在首次请求时装配，测试可注入 MemoryStore。
- `csrfProtection` 下发 `vs.csrf`（`HttpOnly=false`、`SameSite=Lax`），写请求逐字比对 `X-CSRF-Token`；无会话的 `POST /auth/login` 豁免。
- `requireAuth` 读取 `req.session.user`，缺失返回 401 COPY-001；`requirePermission`/`requireAdmin` 不足返回 403 COPY-005，并写 `action='越权拦截'`、`result='拒绝'` 审计。
- `visitorTokenAuth` 优先读取 Bearer，再读 `vs.visitor`；SHA-256 摘要查询 `visitor_tokens` 并校验 `expires_at`；6 位短码不查库并写越权审计。
- `loginRateLimiter` 与 `apiRateLimiter` 使用进程内分钟窗口，分别为 20 次/IP 和 600 次/IP；超限 429 COPY-012。
- `hashPassword`/`verifyPassword` 使用 bcrypt cost 10；`PERMISSIONS` 与权限种子逐字一致，共 33 项。

## 验证证据

### 指定单测与探针

```text
$ cd backend && npx vitest run src/shared/__tests__/auth.test.ts
Test Files  1 passed (1)
Tests       17 passed (17)

$ npx tsx -e "import {hasPermission} from './src/shared/auth/permissions'; console.log(hasPermission('guard','system:params:read'))"
false

$ npx tsx -e "import {hashPassword,verifyPassword} from './src/shared/auth/password'; (async()=>{const h=await hashPassword('abc@123'); console.log(await verifyPassword('abc@123',h), await verifyPassword('wrong',h))})()"
true false

$ grep -c "COPY-103" backend/src/shared/middleware/csrfProtection.ts
1
$ grep -c "COPY-005" backend/src/shared/middleware/requirePermission.ts
1
```

### 全量测试、类型检查与构建

```text
$ cd backend && npm test
Test Files  7 passed (7)
Tests       47 passed (47)

$ cd backend && npm run typecheck
退出码 0

$ cd backend && npm run build
退出码 0
```

### CSRF、403 与真实审计落库

在隔离 PostgreSQL 容器上执行真实中间件与 `writeAudit`：

```text
CSRF {"status":403,"body":{"code":40301,"message":"安全校验已失效，请刷新页面后重试","data":null}}
PERMISSION {"status":403,"body":{"code":40301,"message":"您没有执行该操作的权限","data":null}}
VISITOR {"status":403,"body":{"code":40303,"message":"该申请链接已失效，请重新扫码申请","data":null}}
AUDITS [{"action":"越权拦截","result":"拒绝","object_type":"param","user_name":"门卫张师傅","note":"缺少权限点 system:param:manage"},{"action":"越权拦截","result":"拒绝","object_type":"visitor_token","user_name":"","note":"访客令牌无效或已过期"}]
```

### 运行时启动

隔离 PostgreSQL 容器、独立端口 `13011`：

```text
数据库迁移完成，已应用 5 个文件
visitor-system-backend listening on port 13011
GET /api/v1/health -> {"code":0,"message":"操作成功","data":{"status":"ok"}}
_migrations=5; sessions 表存在; visitor_tokens 表存在
```

隔离容器与临时日志在验证后已清理。

## 账号锁定边界

本卡不实现登录服务与账号锁定。连续失败 5 次锁定 10 分钟、成功登录清零、锁定按账号判定均由 `VIS-P1-I04` 的登录服务实现，不在本卡重复实现。

## 环境约束

- `backend/package.json` 未配置 `lint` 脚本；使用 `npm run typecheck`、`npm run build` 与完整测试作为静态/构建闸门。
- 运行时与审计证据使用临时 PostgreSQL 容器和独立端口，未读写其他工作区数据库。

## 剩余风险

- 本卡只提供可装配中间件，尚未在 `backend/src/app.ts` 装配会话/CSRF/限流；按 `shared-kernel-manifest.yaml` 该装配归 Hub 集成补全卡。
- 登录端点、登录成功后的 `session.regenerate()`、失败计数/锁定与登出销毁会话由 `VIS-P1-I04` 实现并做端到端验证。
- 限流状态当前存于单进程内存；多实例部署若需全局 20 次/分钟，需在部署卡中切换共享存储或网关限流。
- 访客令牌终态失效还依赖预约状态写入路径与 `visitor_tokens.expires_at` 的业务维护；本卡只校验令牌摘要与过期时间。
