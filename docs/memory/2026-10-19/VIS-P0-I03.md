# VIS-P0-I03 · 共享内核卡

- 执行日期：2026-10-19
- 卡片：VIS-P0-I03（Plane `33cb93ab-b049-49f7-89a4-e424d31c1de9`）
- 结果：完成；20 个源文件、5 个共享内核测试套件、响应/错误/分页/校验/掩码/编号/审计/配置/调度/日志/实时通道均已实现并通过验证。

## 交付文件

### HTTP 与中间件

- `backend/src/shared/http/envelope.ts`
- `backend/src/shared/http/errors.ts`
- `backend/src/shared/http/pagination.ts`
- `backend/src/shared/http/asyncHandler.ts`
- `backend/src/shared/http/responseEnvelope.ts`
- `backend/src/shared/http/errorHandler.ts`
- `backend/src/shared/http/notFoundHandler.ts`
- `backend/src/shared/middleware/requestContext.ts`
- `backend/src/shared/middleware/auditMiddleware.ts`

### 审计、配置与工具

- `backend/src/shared/audit/writeAudit.ts`
- `backend/src/shared/config/configService.ts`
- `backend/src/shared/utils/mask.ts`
- `backend/src/shared/utils/ids.ts`
- `backend/src/shared/utils/appointmentNo.ts`
- `backend/src/shared/validation/validators.ts`

### 常量、日志与调度

- `backend/src/shared/constants/status.ts`
- `backend/src/shared/constants/messages.ts`
- `backend/src/shared/logger.ts`
- `backend/src/shared/jobs/scheduler.ts`

### 实时通道

- `backend/src/realtime/io.ts`

### 测试与依赖

- `backend/src/shared/__tests__/envelope.test.ts`
- `backend/src/shared/__tests__/pagination.test.ts`
- `backend/src/shared/__tests__/mask.test.ts`
- `backend/src/shared/__tests__/validators.test.ts`
- `backend/src/shared/__tests__/appointmentNo.test.ts`
- `backend/package.json`（新增 `node-cron@3`、`@types/node-cron`、测试用 `socket.io-client`）
- `backend/package-lock.json`

## 验证证据

### 指定单测

```text
$ cd backend && npx vitest run src/shared/__tests__

✓ src/shared/__tests__/appointmentNo.test.ts (5 tests)
✓ src/shared/__tests__/validators.test.ts (5 tests)
✓ src/shared/__tests__/envelope.test.ts (7 tests)
✓ src/shared/__tests__/pagination.test.ts (4 tests)
✓ src/shared/__tests__/mask.test.ts (8 tests)

Test Files  5 passed (5)
Tests       29 passed (29)
```

### 掩码逐字节验证

```text
$ npx tsx -e "import {maskIdNo} from './src/shared/utils/mask'; console.log(maskIdNo('320101198803034566'), maskIdNo('32010119880'), maskIdNo('32010119'))"
3201**********4566 3201***9880 3******9
```

### 404 与审计边界

```text
$ npx tsx -e "import {notFoundHandler} from './src/shared/http/notFoundHandler'; console.log(typeof notFoundHandler)"
function

$ grep -rn "req.audit" backend/src
(无命中)
```

### 全量与构建

```text
$ cd backend && npm test
Test Files  6 passed (6)
Tests       30 passed (30)

$ cd backend && npm run typecheck
退出码 0

$ cd backend && npm run build
退出码 0
```

### 运行时启动

在隔离 PostgreSQL 容器上使用 `npm run dev` 启动：

```text
数据库迁移完成，已应用 5 个文件
visitor-system-backend listening on port 13103
GET /api/v1/health -> {"code":0,"message":"操作成功","data":{"status":"ok"}}
```

隔离容器与临时日志在验证后已清理。

### 清单与边界

- 20 个 manifest 路径全部存在。
- 运行时导出名称与 `shared-kernel-manifest.yaml` 全部匹配；类型导出通过 `tsc --noEmit` 验证。
- `shared/` 与 `realtime/` 未 import `modules/`。
- `req.audit` 无命中；业务审计直接通过 `writeAudit` 写入。
- `maskIdNo` 的 18/11/10/9/8/5 位结果分别为 `3201**********4566`、`3201***9880`、`3201**1988`、`3201*1198`、`3******9`、`3***0`。

## 环境约束

- `backend/package.json` 未配置 `lint` 脚本；使用 `typecheck`、`build` 与完整测试作为静态/构建闸门。
- 运行时验证使用临时 PostgreSQL 容器和独立端口，未写入其他工作区数据库。

## 剩余风险

- 未认证 WebSocket 握手已由单测验证为 `connect_error: 请先登录`；真实会话 Cookie、反向代理与 Hub 启动序中的 `/ws` 挂载仍需由 VIS-P0-I07 集成补全卡验证。
- 预约编号的并发正确性依赖 PostgreSQL 事务与 `pg_advisory_xact_lock`；单测验证锁调用、格式与序号递增，真实并发压测由集成卡执行。
- 短码唯一性最终依赖 `visit_credentials.short_code` 唯一约束；本卡验证碰撞查询与 20 次重试，真实写入并发由领域卡闭环验证。
