# 共享内核 API（shared-kernel-api）

> 本文件给出全部共享内核导出的完整签名。卡片中的 import 必须逐字使用 `shared-kernel-manifest.yaml` 的路径与本文件的符号名。
> 未在此登记的符号视为不存在；新增符号先回写本文件与 manifest，再实现。

---

## 一、HTTP 响应

### `backend/src/shared/http/envelope.ts`

```ts
import type { Response } from 'express';

export function success<T>(res: Response, data: T, message?: string): Response;
// HTTP 200；body { code: 0, message: message ?? '操作成功', data }

export function fail(
  res: Response,
  httpStatus: number,
  code: number,
  message: string,
  field?: string
): Response;
// body { code, message, data: null, field? }

export function paginated<T>(
  res: Response,
  items: T[],
  total: number,
  page: number,
  pageSize: number
): Response;
// body { code: 0, message: '操作成功', data: { items, total, page, page_size } }
```

### `backend/src/shared/http/errors.ts`

```ts
export class AppError extends Error {
  constructor(
    public httpStatus: number,
    public code: number,
    message: string,
    public field?: string
  );
}

export function badRequest(message: string, field?: string): AppError;        // 400
export function unauthorized(message?: string): AppError;                    // 401 / 40101
export function forbidden(message?: string, field?: string): AppError;       // 403 / 40301
export function notFound(message?: string): AppError;                        // 404 / 40401
export function conflict(message?: string): AppError;                        // 409 / 40901
export function methodNotAllowed(message?: string): AppError;                // 405 / 40501
export function unprocessable(message: string, field: string): AppError;     // 422 / 42201
```

### `backend/src/shared/http/pagination.ts`

```ts
export type Pagination = { page: number; pageSize: number; offset: number };

export function parsePagination(
  query: Record<string, unknown>,
  defaultPageSize?: number,
  maxPageSize?: number
): Pagination;
// 入参 query 读取 page / page_size（snake_case）
// page 默认 1，最小 1；page_size 默认 20，最大 100；超限静默截断；非数字回退默认值
```

### `backend/src/shared/http/responseEnvelope.ts`（装配点）

```ts
import type { RequestHandler } from 'express';

export const responseEnvelope: RequestHandler;
// 在 res 上挂载 res.success / res.fail / res.paginated 便捷方法；
// 必须挂载在全部业务路由之前。
```

### `backend/src/shared/http/errorHandler.ts`（装配点）

```ts
import type { ErrorRequestHandler } from 'express';

export const errorHandler: ErrorRequestHandler;
// 4 参数；AppError → { code, message, field }；
// 未知异常 → 500 / 50001 / COPY-013；日志记录 stack，不返回 stack。
```

### `backend/src/shared/http/notFoundHandler.ts`（装配点）

```ts
import type { RequestHandler } from 'express';

export const notFoundHandler: RequestHandler;
// 未匹配路由 → 404 / 40401 / COPY-008
```

### `backend/src/shared/http/asyncHandler.ts`

```ts
import type { RequestHandler } from 'express';

export function asyncHandler(
  fn: (req: Request, res: Response, next: NextFunction) => Promise<unknown>
): RequestHandler;
// 捕获 Promise 拒绝并 next(error)，交 errorHandler
```

### `backend/src/shared/middleware/requestContext.ts`

```ts
import type { RequestHandler } from 'express';

export type RequestContext = { requestId: string; startedAt: number; ip: string };

export const requestContext: RequestHandler;
// 生成 requestId，挂 req.context；记录来源 IP（含 trust proxy）
```

---

## 二、认证与授权

### `backend/src/shared/auth/session.ts`（装配点）

```ts
import type { RequestHandler } from 'express';

export const sessionMiddleware: RequestHandler;
// express-session + connect-pg-simple
// cookie: { name: 'vs.sid', httpOnly: true, sameSite: 'lax', secure: COOKIE_SECURE, maxAge: 8h }
// tableName: 'sessions'
```

### `backend/src/shared/auth/password.ts`

```ts
export async function hashPassword(plain: string): Promise<string>;
// bcryptjs，盐轮数 10

export async function verifyPassword(plain: string, hash: string): Promise<boolean>;
// 兼容 pgcrypto 生成的 $2a$ / $2b$ 前缀
```

### `backend/src/shared/auth/permissions.ts`

```ts
export const PERMISSIONS: readonly string[];
// 与 schema-shared.sql 权限种子逐字一致，共 33 项

export function hasPermission(roleCode: string, permissionCode: string): boolean;
// admin 恒 true；其他角色查 role_permissions 缓存
```

### `backend/src/shared/middleware/requireAuth.ts`

```ts
import type { RequestHandler } from 'express';

export const requireAuth: RequestHandler;
// 读取 req.session.userId；无会话 → 401 COPY-001
// 挂 req.currentUser: { id, username, displayName, roleCode, hostId }
```

### `backend/src/shared/middleware/requirePermission.ts`

```ts
import type { RequestHandler } from 'express';

export function requirePermission(permissionCode: string): RequestHandler;
// 未登录 → 401；无权限 → 403 COPY-005；写 action='越权拦截' 审计

export const requireAdmin: RequestHandler;
// roleCode !== 'admin' → 403 COPY-005 + 越权审计
```

### `backend/src/shared/middleware/visitorTokenAuth.ts`

```ts
import type { RequestHandler } from 'express';

export const visitorTokenAuth: RequestHandler;
// 从 Authorization: Bearer 或 vs.visitor Cookie 取令牌
// SHA-256 后查 visitor_tokens；无效/过期 → 403 COPY-007
// 挂 req.visitorAppointmentId: string
// 6 位短码冒充 → 403 COPY-007 + 越权审计
```

### `backend/src/shared/middleware/csrfProtection.ts`（装配点）

```ts
import type { RequestHandler } from 'express';

export const csrfProtection: RequestHandler;
// 非 GET/HEAD/OPTIONS 校验 X-CSRF-Token 与 vs.csrf 一致
// 不一致 → 403 COPY-103；POST /auth/login 无会话时豁免
```

### `backend/src/shared/middleware/rateLimiter.ts`

```ts
import type { RequestHandler } from 'express';

export const loginRateLimiter: RequestHandler;
// 同一 IP 每分钟 20 次；超出 429 COPY-012

export const apiRateLimiter: RequestHandler;
// 同一 IP 每分钟 600 次；超出 429 COPY-012
```

### `backend/src/shared/middleware/auditMiddleware.ts`（装配点）

```ts
import type { RequestHandler } from 'express';

export const auditMiddleware: RequestHandler;
// 在 req 上挂 req.audit: (entry: AuditEntry) => Promise<void>
// 仅负责收集与写库；业务 service 主动调用
```

---

## 三、审计

### `backend/src/shared/audit/writeAudit.ts`

```ts
export type AuditEntry = {
  userId: string | null;
  userName: string;
  objectType: string;
  objectId: string | null;
  action: string;
  result: '成功' | '失败' | '拒绝';
  before?: unknown;
  after?: unknown;
  ip?: string | null;
  note?: string;
};

export async function writeAudit(entry: AuditEntry): Promise<void>;
// INSERT operation_logs；before/after 序列化为 JSONB；失败只记日志，不阻断业务
```

---

## 四、数据库

### `backend/src/shared/db/pool.ts`

```ts
import type { Pool, PoolClient, QueryResult, QueryResultRow } from 'pg';

export function getPool(): Pool;
export async function query<T extends QueryResultRow = QueryResultRow>(
  sql: string,
  params?: unknown[]
): Promise<QueryResult<T>>;
export async function withTransaction<T>(
  fn: (client: PoolClient) => Promise<T>
): Promise<T>;
```

### `backend/src/shared/db/migrate.ts`

```ts
export async function runMigrations(): Promise<{ applied: string[] }>;
// 读取 backend/db/migrations/*.sql，按文件名排序
// 确保 _migrations(filename TEXT PRIMARY KEY, applied_at TIMESTAMPTZ)
// 每个文件一个事务；已存在则跳过
```

### `backend/src/shared/db/seed.ts`

```ts
export async function runSeeds(): Promise<{ applied: string[] }>;
// 读取 backend/db/seeds/*.sql，按文件名排序，逐文件执行
// 不写 _migrations；由 npm run seed 手动触发
```

---

## 五、配置

### `backend/src/config.ts`（进程环境配置）

```ts
export type AppConfig = {
  PORT: number;
  DATABASE_URL: string;
  CORS_ORIGIN: string;
  COOKIE_SECRET: string;
  COOKIE_SECURE: boolean;
  ENABLE_JOBS: string;
  LOG_LEVEL: 'debug' | 'info' | 'warn' | 'error';
};

export function loadConfig(): AppConfig;
// 读取 process.env、校验并写入 config；缺失必填项（DATABASE_URL、COOKIE_SECRET）时打印缺失键并 process.exit(1)

export let config: AppConfig;
// 由 loadConfig() 赋值；未调用 loadConfig() 前为 undefined，读取即运行期错误
```

### `backend/src/shared/config/configService.ts`

```ts
export async function getConfig(key: string): Promise<string>;
// 查 system_config；不存在抛 AppError 500

export async function getConfigNumber(key: string): Promise<number>;
// 解析为数字；非数字抛 AppError 500

export async function setConfig(key: string, value: string, actorId: string): Promise<void>;
// 更新 system_config 并写审计
```

---

## 六、工具

### `backend/src/shared/utils/mask.ts`

```ts
export function maskIdNo(value: string | null | undefined): string;
// 长度 ≥ 11：前 4 + (len-8) 个 * + 后 4
// 长度 9–10：前 4 + (len-8) 个 * + 后 4
// 长度 ≤ 8 且 ≥ 3：前 1 + max(1, len-2) 个 * + 后 1
// 长度 0–2：全部 *（长度保持）
// null/undefined → ''
```

### `backend/src/shared/utils/ids.ts`

```ts
export function newUuid(): string;
// crypto.randomUUID()

export function formatMinute(date: Date): string;
// YYYY-MM-DD HH:mm（Asia/Shanghai）

export function formatSecond(date: Date): string;
// YYYY-MM-DD HH:mm:ss（Asia/Shanghai）

export function localDayRange(now: Date): { start: Date; end: Date };
// 本地 00:00:00.000 – 23:59:59.999
```

### `backend/src/shared/utils/appointmentNo.ts`

```ts
export async function nextAppointmentNo(client: PoolClient): Promise<string>;
// AP + YYYYMMDD + 3 位当日序号；在事务内以 advisory lock 串行

export async function generateShortCode(client: PoolClient): Promise<string>;
// 6 位数字，查重后返回；最多重试 10 次
```

### `backend/src/shared/validation/validators.ts`

```ts
import type { RequestHandler } from 'express';

export function validateBody(rules: ValidationChain[]): RequestHandler;
// 失败 → 422，message 逐字取自 .withMessage()，field 取首个失败字段

export function validateQuery(rules: ValidationChain[]): RequestHandler;

export function isValidIdCard(value: string): boolean;
// 18 位，GB 11643-1999 校验码

export function isValidPhone(value: string): boolean;
// ^1\d{10}$

export function isValidOtherId(value: string): boolean;
// 5–20 位，字母数字

export function normalizeIdNo(value: string): string;
// 去空格、转大写
```

### `backend/src/shared/constants/status.ts`

```ts
export const APPOINTMENT_STATUSES: readonly string[];
// ['待审核','已通过','已拒绝','已改期','已过期','已到访(在校中)','已离校','已取消']

export const TERMINAL_STATUSES: readonly string[];
// ['已拒绝','已过期','已取消']

export const OPEN_STATUSES: readonly string[];
// ['待审核','已改期','已通过','已到访(在校中)']

export const ATTENDED_STATUSES: readonly string[];
// ['已通过','已到访(在校中)','已离校']

export const INCIDENT_STATUSES: readonly string[];
// ['待处理','已处理','已忽略']

export const INCIDENT_TYPES: readonly string[];
// ['黑名单命中','信息不符','强行闯入','超时未离']
```

### `backend/src/shared/constants/messages.ts`

```ts
export const MESSAGES: Record<string, string>;
// 键为 COPY 编号（如 'COPY-002'），值为 conventions.md §12.2 的逐字文案
```

### `backend/src/shared/logger.ts`

```ts
export const logger: {
  debug(message: string, meta?: Record<string, unknown>): void;
  info(message: string, meta?: Record<string, unknown>): void;
  warn(message: string, meta?: Record<string, unknown>): void;
  error(message: string, meta?: Record<string, unknown>): void;
};
// JSON 行日志；禁止输出密码、令牌、完整证件号
```

---

## 七、定时任务

### `backend/src/shared/jobs/scheduler.ts`

```ts
export type JobDefinition = {
  name: string;
  cron: string;           // 5 段标准 cron，按 Asia/Shanghai 解释
  runOnStart: boolean;
  handler: () => Promise<void>;
};

export function registerJob(definition: JobDefinition): void;
// 只登记不启动；各业务模块在装配阶段注册
// 同名任务重复注册时后注册覆盖先注册

export function startJobs(): void;
// 统一启动全部已登记任务；ENABLE_JOBS !== 'true' 时为 no-op

export function stopAllJobs(): void;
```

---

## 八、实时通道

### `backend/src/realtime/io.ts`（装配点）

```ts
import type { Server } from 'http';
import type { RequestHandler } from 'express';
import type { Server as SocketServer } from 'socket.io';

export function initRealtime(server: Server, sessionMw: RequestHandler): SocketServer;
// 命名空间 /ws；握手解析会话 Cookie；未认证断开
// 连接后加入 user:<userId> 房间

export function emitNotification(
  userId: string,
  payload: { id: string; title: string; templateType: string; createdAt: string }
): void;
// 向 user:<userId> 房间发送 notification:new
```

---

## 九、前端共享

### `frontend/src/api/client.ts`

```ts
import type { AxiosInstance } from 'axios';

declare const apiClient: AxiosInstance;
export default apiClient;
// baseURL = import.meta.env.VITE_API_BASE ?? '/api/v1'
// withCredentials = true
// 请求拦截：camelCase → snake_case；写请求附加 X-CSRF-Token
// 响应拦截：不解包信封；data.data 内 snake_case → camelCase
// 401：清空 auth store 并跳 /login
```

### `frontend/src/stores/auth.ts`

```ts
export type AuthUser = {
  id: string;
  username: string;
  displayName: string;
  roleCode: 'admin' | 'guard' | 'host';
  hostId: string | null;
};

export const useAuthStore: () => {
  user: AuthUser | null;
  role: string | null;
  isLoggedIn: boolean;
  login(username: string, password: string): Promise<void>;
  logout(): Promise<void>;
  fetchMe(): Promise<void>;
  changePassword(oldPassword: string, newPassword: string): Promise<void>;
};
```

### `frontend/src/stores/notification.ts`

```ts
export const useNotificationStore: () => {
  unreadCount: number;
  items: Array<{ id: string; title: string; templateType: string; createdAt: string; readAt: string | null }>;
  fetchUnreadCount(): Promise<void>;
  fetchItems(unreadOnly?: boolean): Promise<void>;
  markRead(id: string): Promise<void>;
  markAllRead(): Promise<void>;
};
```

### `frontend/src/realtime/socket.ts`

```ts
export function connectRealtime(): void;
export function disconnectRealtime(): void;
// socket.io-client；路径 /ws；断线重连；收到 notification:new 时更新 notification store
```

### `frontend/src/nav/navigation.ts`

```ts
export type NavItem = {
  key: string;
  title: string;
  path: string;
  roles: string[];
  icon: string;
  children?: NavItem[];
};

export const navigation: NavItem[];
export function filterNavigation(items: NavItem[], role: string): NavItem[];
```

### `frontend/src/nav/icons.ts`

```ts
import type { Component } from 'vue';

export const iconMap: Record<string, Component>;
// navigation.ts 中每个 icon 字符串（含子菜单）对应的 Ant Design 图标组件；
// 未登记的 key 由 AppLayout 回退到 AppstoreOutlined
```

### `frontend/src/styles/print.css`

```css
/* 打印：隐藏 .no-print、侧边栏与顶栏；保留表格全部列与 .print-only */
```

### 共享组件

| 文件 | 导出 | 用途 |
|------|------|------|
| `frontend/src/components/PageHeader.vue` | `default`（props: `title: string`, `subtitle?: string`, `breadcrumbs?: Array<{ title: string; path?: string }>`；slot `actions`） | 页面标题区 |
| `frontend/src/components/StatusTag.vue` | `default`（props: `status: string`, `kind?: 'appointment' \| 'incident' \| 'soft'`） | 状态标签 |
| `frontend/src/components/EmptyState.vue` | `default`（props: `description: string`, `actionText?: string`；emit `action`） | 空态 |
| `frontend/src/components/LoadingState.vue` | `default`（props: `rows?: number`，默认 5） | 加载骨架屏 + COPY-357 |
| `frontend/src/components/ErrorState.vue` | `default`（props: `message?: string`，默认 COPY-355；emit `retry`） | 错误提示 + COPY-356 重试 |
| `frontend/src/components/ConfirmDialog.vue` | `default`（props: `title: string`, `content: string`, `okText?: string`, `cancelText?: string`, `danger?: boolean`；emit `confirm` \| `cancel`） | 二次确认 |
| `frontend/src/components/CopyButton.vue` | `default`（props: `text: string`, `successMessage?: string`，默认 COPY-046） | 复制链接 |

### 布局

| 文件 | 导出 | 用途 |
|------|------|------|
| `frontend/src/layouts/AppLayout.vue` | `default` | 后台侧边栏 + 顶栏 + 通知徽标 |
| `frontend/src/layouts/H5Layout.vue` | `default` | H5 窄屏容器 |

---

## 十、Hub 导出（由 Hub 集成补全卡写入）

### `backend/src/app.ts`

```ts
import type { Express } from 'express';

export function createApp(): Express;
// 按 spac.md §8.1 的 16 步装配；供 main.ts 与接口测试使用

export function mountRoutes(app: Express): void;
// 自动发现 modules/*/api/*.routes.ts，统一挂载到 /api/v1
```

### `backend/src/main.ts`

```ts
// 启动序：loadConfig → getPool → runMigrations → createApp → http.createServer(app)
//        → initRealtime(server, sessionMiddleware) → server.listen(PORT) → startJobs
// 不导出符号；作为进程入口
```

### `frontend/src/router/index.ts`

```ts
import type { Router } from 'vue-router';

declare const router: Router;
export default router;
```

### `frontend/src/router/shared.routes.ts`

```ts
import type { RouteRecordRaw } from 'vue-router';

// 根记录 name 固定为 'root'，供 addRoute('root', record) 使用
export const sharedRoutes: RouteRecordRaw[];
```

### `frontend/src/components/RouterContainer.vue`

```vue
<!-- 仅含 <router-view /> 的容器，作为 name: 'root' 的页面组件 -->
```

### `frontend/src/App.vue`

```vue
<!-- 按 route.meta.layout 选择 AppLayout / H5Layout / 空布局 -->
```
