# VIS-P0-I07 · Hub 集成补全卡

- 日期：2026-10-19
- 分支：`feature/b6b838b4-5b81-4098-90e3-fe8c6bf2415c`
- 基线：`origin/main@ba0cb65`
- 运行截图：`docs/memory/2026-10-19/VIS-P0-I07-runtime.png`

## 结果

`is any single middleware missing` 可通过 `assembly.test.ts` 的运行时层栈断言发现；业务路由由 `mountRoutes()` 自动发现；HTTP Server、WebSocket 与优雅关停已接入 `main.ts`。

## 修改文件

- `backend/src/app.ts`
- `backend/src/config.ts`
- `backend/src/main.ts`
- `backend/src/__tests__/assembly.test.ts`（新增）
- `backend/vitest.config.ts`（新增）
- `backend/vitest.setup.ts`（新增）
- `frontend/src/App.vue`
- `frontend/src/layouts/AppLayout.vue`

`config.ts` 对齐共享内核契约的 uppercase 键名，供装配行直接读取 `config.CORS_ORIGIN` 与 `config.COOKIE_SECRET`。

## 16 步装配

`backend/src/app.ts`：

```ts
app.set('trust proxy', 1);
app.use(helmet());
app.use(cors({ origin: config.CORS_ORIGIN, credentials: true }));
app.use(compression());
app.use(cookieParser(config.COOKIE_SECRET));
app.use(express.json({ limit: '1mb' }));
app.use(responseEnvelope);
app.use(sessionMiddleware);
app.use(csrfProtection);
app.use(apiRateLimiter);
app.get(`${API_PREFIX}/health`, (_req, res) => res.json({ code: 0, message: '操作成功', data: { status: 'ok' } }));
mountRoutes(app);
app.use(auditMiddleware);
app.use(notFoundHandler);
app.use(errorHandler);
```

`backend/src/main.ts`：

```ts
const app = createApp();
await waitForRoutes();
const server = http.createServer(app);
const io = initRealtime(server, sessionMiddleware);
server.listen(config.PORT, ...);
if (config.ENABLE_JOBS === 'true') startJobs();
```

- `API_PREFIX = '/api/v1'`。`backend/src/app.ts` 的 `'/api/v1'` 字面量只在常量声明处出现一次。
- `mountRoutes()` 在步骤 12 挂载聚合 Router，随后异步扫描 `modules/*/api/*.routes.{ts,js}`、`await import()` 并追加 `export default router`。
- `waitForRoutes()` 让 `main.ts` 在 `listen` 前完成自动发现。
- 关停序：`stopAllJobs() → io.close() → server.close() → pool.end()`。

## 前端

- `AppLayout.vue` 在 `onMounted` 且 `authStore.user` 存在时 `connectRealtime()`，在 `onUnmounted` 时 `disconnectRealtime()`。
- `App.vue` 增加 Ant Design Vue `<a-app>` 全局消息容器，路由视图继续由 `AppLayout` / `H5Layout` / 空布局承载。

## 测试与构建

```text
$ cd backend && npx vitest run src/__tests__/assembly.test.ts

✓ src/__tests__/assembly.test.ts (7 tests) 500ms

Test Files  1 passed (1)
Tests       7 passed (7)
```

装配测试覆盖：16 步运行时层栈、health 信封、自动发现 ping、JSON 404、COPY-013 JSON 500、`main.ts` 启动顺序、未认证 WebSocket 拒绝与 `user:<id>` 房间通知。

```text
$ cd backend && npm test
Test Files  8 passed (8)
Tests       54 passed (54)

$ cd backend && npm run build
(tsc passed)

$ cd frontend && npm test
Test Files  5 passed (5)
Tests       35 passed (35)

$ cd frontend && npm run build
(vue-tsc + vite build passed)
```

`package.json` 未配置 `lint` 脚本；以 `typecheck` / `build` 为项目等效静态门禁。

## 运行验证

宿主已被其他工作区占用 `3000`，本次在 `127.0.0.1:56322` 启动真实 `main.ts`（同一配置/代码路径），独立 Postgres 为 `127.0.0.1:56321`。

```http
GET /api/v1/health
HTTP/1.1 200 OK
Content-Type: application/json; charset=utf-8

{"code":0,"message":"操作成功","data":{"status":"ok"}}
```

```http
GET /api/v1/no-such-path
HTTP/1.1 404 Not Found
Content-Type: application/json; charset=utf-8

{"code":40401,"message":"要查看的记录不存在或已被删除","data":null}
```

```http
POST /api/v1/no-such-path
Content-Type: application/json
Body: {"broken":

HTTP/1.1 500 Internal Server Error
Content-Type: application/json; charset=utf-8

{"code":50001,"message":"系统暂时无法处理，请稍后重试","data":null}
```

```http
GET /api/v1/ping   # 临时 route，验证后已删除
HTTP/1.1 200 OK
Content-Type: application/json; charset=utf-8

{"code":0,"message":"操作成功","data":{"pong":true}}
```

```text
$ grep -c "'/api/v1'" backend/src/app.ts
1

$ grep -n "createServer\|initRealtime\|listen" backend/src/main.ts
17:  const server = http.createServer(app);
18:  const io = initRealtime(server, sessionMiddleware);
20:  server.listen(config.PORT, ...)
```

实际 `SIGTERM` 后进程正常退出。前端 `vite --host 0.0.0.0 --port 8080` 启动正常；因仓库尚无业务页面路由，使用临时 Vite proof harness 渲染 `App.vue + AppLayout.vue` 后截图，验证完已删除 harness 文件。

## 剩余风险

- 业务模块路由与前端业务页面尚未由后续卡提供；本卡的自动发现已用临时 `ping.routes.ts` 验证并删除。
- 运行环境共享宿主占用 `3000`，本次运行验证使用 `56322`；应用默认配置仍为 `PORT=3000`。
- 自动发现使用动态 import，因此 `waitForRoutes()` 必须在 `listen` 前完成；`main.ts` 已显式等待，测试也覆盖该顺序。
