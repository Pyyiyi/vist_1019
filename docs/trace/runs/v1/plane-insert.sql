-- ============================================================
-- 校园访客系统 V1.0 — Plane Issue 全量插入
-- 卡片数: 18
-- Project: 2924e784-2228-4087-bec1-43a04de1df6f (VISY1019)
-- Workspace: 6c6a5a06-9043-425a-b19e-0003cd181fe9
-- 初始状态: 全部 Backlog
-- ============================================================

BEGIN;

-- ============ 获取项目级排他锁 ============
SELECT pg_advisory_xact_lock(hashtextextended('2924e784-2228-4087-bec1-43a04de1df6f', 0));

-- ============ issues (18) ============
INSERT INTO issues (id, created_at, updated_at, created_by_id, updated_by_id, project_id, workspace_id, name, description_json, description_html, description_stripped, state_id, parent_id, priority, sort_order, sequence_id, point, estimate_point_id, type_id, start_date, target_date, completed_at, archived_at, is_draft, external_source, external_id, description_binary, deleted_at) VALUES ('7bd3ad51-7dbc-47c2-93de-08eaa2ebc8eb', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', '[VIS-P0-I01] 项目脚手架与运行时闭环卡', '{}'::jsonb, '## 目标
建立可启动、可构建、可测试的前后端工程与 Docker Compose 运行闭环，`GET /api/v1/health` 返回 `{"code":0,"message":"操作成功","data":{"status":"ok"}}`。

承载需求：无（基础设施卡）；支撑 REQ-PT-001 的运行环境与健康检查前置。

## 验收标准
- [ ] `cd backend && npm run typecheck` 退出码 0。
- [ ] `cd backend && npm run build` 产出 `backend/dist/main.js`。
- [ ] `cd frontend && npm run build` 产出 `frontend/dist/index.html`。
- [ ] `cp .env.example .env && docker compose up -d --build` 后 `db`、`backend`、`frontend` 三服务均为 `healthy`。
- [ ] `curl -s http://localhost:3000/api/v1/health` 返回 `code=0`。
- [ ] `docker compose down` 后数据卷 `visitor_pgdata` 保留。
- [ ] `git rev-parse --is-inside-work-tree` → `true`；`git log --oneline -1` 有基线提交。

## 相关背景

### 必读文件
- `conventions.md` — 全局技术约定（约定 1 目录与边界、约定 2 中间件序、约定 14 配置）。
- `docs/trace/runs/v1/spac.md` §8.5 构建产物三元组、§8.6 Docker Compose。
- `docs/knowledge/config-contract.md` — 环境变量唯一真相。
- `docs/knowledge/module-template.md` — 目录模板。

### 共享内核 API（摘自 docs/knowledge/shared-kernel-api.md）
- 本卡为第一张执行卡，共享内核尚未建立；本卡只产出工程骨架与健康检查路由。
- 健康检查在本卡内直接写 `res.json({ code: 0, message: ''操作成功'', data: { status: ''ok'' } })`，共享内核卡建立后由 Hub 集成补全卡接入统一信封。

### 模块模板（摘自 docs/knowledge/module-template.md）
- 后端：`backend/src/`、`backend/db/migrations/`、`backend/db/seeds/`、`backend/src/modules/`。
- 前端：`frontend/src/`、`frontend/src/views/`、`frontend/src/api/`。
- 迁移编号：三位数字前缀，`001-shared.sql` 起。

## 约束

### 命名约束
- 目录：`backend/`、`frontend/`、`deploy/`、`docs/`。
- 包名：`visitor-system-backend`、`visitor-system-frontend`。
- TypeScript：`strict: true`、`target: ES2022`、`module: NodeNext`。
- 后端产物：`rootDir: "src"`、`outDir: "dist"`、入口 `dist/main.js`。

### 其他约束
- [依赖] `express@4`、`pg`、`express-session`、`connect-pg-simple`、`helmet`、`cors`、`compression`、`cookie-parser`、`express-validator`、`socket.io`、`qrcode`。
- [依赖] `vue@3`、`vue-router@4`、`pinia`、`ant-design-vue@4`、`axios`、`vite`。
- [依赖] 测试：`vitest`、`supertest`、`@vue/test-utils`。
- [边界] 本卡不创建任何业务表、不创建任何业务页面。
- [配置] 所有端口由 `HOST_DB_PORT` / `HOST_BACKEND_PORT` / `HOST_FRONTEND_PORT` 映射，容器内固定 5432/3000/80。

## 实施阶段
实现

## 任务

### 后端
1. 创建 `backend/package.json` — 脚本：`dev`(`tsx watch src/main.ts`)、`build`(`tsc -p tsconfig.json`)、`start`(`node dist/main.js`)、`typecheck`(`tsc --noEmit`)、`test`(`vitest run`)；`migrate` 由 `VIS-P0-I02` 增加，`seed` 由 `VIS-P0-I08` 增加。
2. 创建 `backend/tsconfig.json` — `strict`、`ES2022`、`rootDir src`、`outDir dist`、`include ["src/**/*.ts"]`。
3. 创建 `backend/src/main.ts` — 本卡只做最小启动：读取 `PORT`、`app.listen`；共享内核卡与 Hub 集成补全卡在此文件追加启动序。
4. 创建 `backend/src/app.ts` — 本卡只挂 `express.json()` 与 `GET /api/v1/health`；其余 15 步由 Hub 集成补全卡按序装配。
5. 创建 `backend/.env.example` — 与 `docs/knowledge/config-contract.md` 逐字一致。
6. 创建 `backend/Dockerfile` — 多阶段：`npm ci && npm run build` → 运行 `node dist/main.js`。
7. 创建 `backend/src/modules/.gitkeep` — 预留六个上下文目录。

### 前端
8. 创建 `frontend/package.json` — 脚本 `dev`(`vite`)、`build`(`vue-tsc --noEmit && vite build`)、`test`(`vitest run`)。
9. 创建 `frontend/vite.config.ts` — `resolve.alias[''@''] = path.resolve(__dirname, ''src'')`；`server.proxy[''/api'']` 指向 `http://localhost:${HOST_BACKEND_PORT}`；`server.proxy[''/ws'']` 同源并补 `X-Forwarded-Proto: https`。
10. 创建 `frontend/tsconfig.json` — `paths: { "@/*": ["src/*"] }`。
11. 创建 `frontend/index.html`、`frontend/public/favicon.svg`、`frontend/src/main.ts`、`frontend/src/App.vue` — `index.html` 含 `lang="zh-CN"`、`<title>校园访客系统</title>`、`<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">` 与 `<link rel="icon" href="/favicon.svg">`；`App.vue` 渲染页面标题「校园访客系统」；P0-I06 将其改为按 `route.meta.layout` 选择布局。
12. 创建 `frontend/Dockerfile` — 多阶段构建，产物复制到 `/usr/share/nginx/html`。
13. 创建 `deploy/nginx.conf` — SPA 回退 `try_files $uri $uri/ /index.html`；`/api` 代理到 `backend:3000`；`/ws` 升级代理。

### 根目录
14. 创建 `docker-compose.yml` — 三服务、健康检查、卷 `visitor_pgdata`；禁止挂载 `docker-entrypoint-initdb.d`。
15. 创建 `.env.example` — 含 `HOST_DB_PORT=55432`、`HOST_BACKEND_PORT=3000`、`HOST_FRONTEND_PORT=8080` 及 `docs/knowledge/config-contract.md` 全部键。
16. 创建 `docs/memory/MEMORY.md` 与 `docs/memory/2026-10-19/` — 初始化执行记忆目录。
17. 创建 `.gitignore` — 忽略 `node_modules/`、`dist/`、`.env`、`.npm-cache/`。
18. 创建 `backend/src/config.ts` — 导出 `loadConfig()` 与 `config`：读取 `PORT`、`DATABASE_URL`、`CORS_ORIGIN`、`COOKIE_SECRET`、`COOKIE_SECURE`、`ENABLE_JOBS`、`LOG_LEVEL`；缺失必需键时启动失败并打印键名。
19. 执行 `git init` 并创建基线提交 `chore: scaffold` — 供封版卡与状态刷新卡使用 `git tag` / `git status`。

### 用户可见文案清单（本卡必含，逐字）
| 类别 | 触发场景 | 逐字文案 | 渲染位置 |
|------|---------|---------|---------|
| 启动页标题 | 访问 `http://localhost:8080` | 校园访客系统 | 页面标题 |
| 健康检查成功 | `GET /api/v1/health` | 操作成功 | 响应 `message` |

## 验证
- [ ] `cd backend && npm ci && npm run typecheck && npm run build` → 退出码 0，存在 `dist/main.js`。
- [ ] `cd frontend && npm ci && npm run build` → 退出码 0，存在 `dist/index.html`。
- [ ] `cp .env.example .env && docker compose up -d --build && docker compose ps` → `db`、`backend`、`frontend` 均 `healthy`。
- [ ] `curl -s http://localhost:3000/api/v1/health` → `{"code":0,"message":"操作成功","data":{"status":"ok"}}`。
- [ ] `curl -s -o /dev/null -w ''%{http_code}'' http://localhost:8080/h5/apply` → `200`（SPA 回退生效）。
- [ ] `grep -n ''lang="zh-CN"'' frontend/index.html` 与 `grep -n ''viewport-fit=cover'' frontend/index.html` → 各命中 1 行；浏览器控制台无 404 资源请求。
- [ ] `grep -rn docker-entrypoint-initdb.d docker-compose.yml` → 0 命中。

## 在开始改动之前
1. 读取 `conventions.md`（约定 1、2、14）。
2. 读取 `docs/knowledge/config-contract.md` 与 `docs/trace/runs/v1/spac.md` §8.5/§8.6。
3. 确认本机 Docker 与 Docker Compose 可用。
4. 检查项目根是否已有 `backend/`、`frontend/`、`docker-compose.yml`；已存在则先读取再追加，禁止覆盖已有内容。

## 完成改动之后
1. 列出本卡创建/修改的全部文件路径。
2. 运行验证段全部命令并粘贴实际输出。
3. 确认全部验证通过；任一失败不得标记完成。
4. 列出剩余风险（例如本卡未接入统一信封，由 Hub 集成补全卡覆盖）。
5. 写入 `docs/memory/2026-10-19/VIS-P0-I01.md`。
', '## 目标
建立可启动、可构建、可测试的前后端工程与 Docker Compose 运行闭环，`GET /api/v1/health` 返回 `{"code":0,"message":"操作成功","data":{"status":"ok"}}`。

承载需求：无（基础设施卡）；支撑 REQ-PT-001 的运行环境与健康检查前置。

## 验收标准
- [ ] `cd backend && npm run typecheck` 退出码 0。
- [ ] `cd backend && npm run build` 产出 `backend/dist/main.js`。
- [ ] `cd frontend && npm run build` 产出 `frontend/dist/index.html`。
- [ ] `cp .env.example .env && docker compose up -d --build` 后 `db`、`backend`、`frontend` 三服务均为 `healthy`。
- [ ] `curl -s http://localhost:3000/api/v1/health` 返回 `code=0`。
- [ ] `docker compose down` 后数据卷 `visitor_pgdata` 保留。
- [ ] `git rev-parse --is-inside-work-tree` → `true`；`git log --oneline -1` 有基线提交。

## 相关背景

### 必读文件
- `conventions.md` — 全局技术约定（约定 1 目录与边界、约定 2 中间件序、约定 14 配置）。
- `docs/trace/runs/v1/spac.md` §8.5 构建产物三元组、§8.6 Docker Compose。
- `docs/knowledge/config-contract.md` — 环境变量唯一真相。
- `docs/knowledge/module-template.md` — 目录模板。

### 共享内核 API（摘自 docs/knowledge/shared-kernel-api.md）
- 本卡为第一张执行卡，共享内核尚未建立；本卡只产出工程骨架与健康检查路由。
- 健康检查在本卡内直接写 `res.json({ code: 0, message: ''操作成功'', data: { status: ''ok'' } })`，共享内核卡建立后由 Hub 集成补全卡接入统一信封。

### 模块模板（摘自 docs/knowledge/module-template.md）
- 后端：`backend/src/`、`backend/db/migrations/`、`backend/db/seeds/`、`backend/src/modules/`。
- 前端：`frontend/src/`、`frontend/src/views/`、`frontend/src/api/`。
- 迁移编号：三位数字前缀，`001-shared.sql` 起。

## 约束

### 命名约束
- 目录：`backend/`、`frontend/`、`deploy/`、`docs/`。
- 包名：`visitor-system-backend`、`visitor-system-frontend`。
- TypeScript：`strict: true`、`target: ES2022`、`module: NodeNext`。
- 后端产物：`rootDir: "src"`、`outDir: "dist"`、入口 `dist/main.js`。

### 其他约束
- [依赖] `express@4`、`pg`、`express-session`、`connect-pg-simple`、`helmet`、`cors`、`compression`、`cookie-parser`、`express-validator`、`socket.io`、`qrcode`。
- [依赖] `vue@3`、`vue-router@4`、`pinia`、`ant-design-vue@4`、`axios`、`vite`。
- [依赖] 测试：`vitest`、`supertest`、`@vue/test-utils`。
- [边界] 本卡不创建任何业务表、不创建任何业务页面。
- [配置] 所有端口由 `HOST_DB_PORT` / `HOST_BACKEND_PORT` / `HOST_FRONTEND_PORT` 映射，容器内固定 5432/3000/80。

## 实施阶段
实现

## 任务

### 后端
1. 创建 `backend/package.json` — 脚本：`dev`(`tsx watch src/main.ts`)、`build`(`tsc -p tsconfig.json`)、`start`(`node dist/main.js`)、`typecheck`(`tsc --noEmit`)、`test`(`vitest run`)；`migrate` 由 `VIS-P0-I02` 增加，`seed` 由 `VIS-P0-I08` 增加。
2. 创建 `backend/tsconfig.json` — `strict`、`ES2022`、`rootDir src`、`outDir dist`、`include ["src/**/*.ts"]`。
3. 创建 `backend/src/main.ts` — 本卡只做最小启动：读取 `PORT`、`app.listen`；共享内核卡与 Hub 集成补全卡在此文件追加启动序。
4. 创建 `backend/src/app.ts` — 本卡只挂 `express.json()` 与 `GET /api/v1/health`；其余 15 步由 Hub 集成补全卡按序装配。
5. 创建 `backend/.env.example` — 与 `docs/knowledge/config-contract.md` 逐字一致。
6. 创建 `backend/Dockerfile` — 多阶段：`npm ci && npm run build` → 运行 `node dist/main.js`。
7. 创建 `backend/src/modules/.gitkeep` — 预留六个上下文目录。

### 前端
8. 创建 `frontend/package.json` — 脚本 `dev`(`vite`)、`build`(`vue-tsc --noEmit && vite build`)、`test`(`vitest run`)。
9. 创建 `frontend/vite.config.ts` — `resolve.alias[''@''] = path.resolve(__dirname, ''src'')`；`server.proxy[''/api'']` 指向 `http://localhost:${HOST_BACKEND_PORT}`；`server.proxy[''/ws'']` 同源并补 `X-Forwarded-Proto: https`。
10. 创建 `frontend/tsconfig.json` — `paths: { "@/*": ["src/*"] }`。
11. 创建 `frontend/index.html`、`frontend/public/favicon.svg`、`frontend/src/main.ts`、`frontend/src/App.vue` — `index.html` 含 `lang="zh-CN"`、`<title>校园访客系统</title>`、`<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">` 与 `<link rel="icon" href="/favicon.svg">`；`App.vue` 渲染页面标题「校园访客系统」；P0-I06 将其改为按 `route.meta.layout` 选择布局。
12. 创建 `frontend/Dockerfile` — 多阶段构建，产物复制到 `/usr/share/nginx/html`。
13. 创建 `deploy/nginx.conf` — SPA 回退 `try_files $uri $uri/ /index.html`；`/api` 代理到 `backend:3000`；`/ws` 升级代理。

### 根目录
14. 创建 `docker-compose.yml` — 三服务、健康检查、卷 `visitor_pgdata`；禁止挂载 `docker-entrypoint-initdb.d`。
15. 创建 `.env.example` — 含 `HOST_DB_PORT=55432`、`HOST_BACKEND_PORT=3000`、`HOST_FRONTEND_PORT=8080` 及 `docs/knowledge/config-contract.md` 全部键。
16. 创建 `docs/memory/MEMORY.md` 与 `docs/memory/2026-10-19/` — 初始化执行记忆目录。
17. 创建 `.gitignore` — 忽略 `node_modules/`、`dist/`、`.env`、`.npm-cache/`。
18. 创建 `backend/src/config.ts` — 导出 `loadConfig()` 与 `config`：读取 `PORT`、`DATABASE_URL`、`CORS_ORIGIN`、`COOKIE_SECRET`、`COOKIE_SECURE`、`ENABLE_JOBS`、`LOG_LEVEL`；缺失必需键时启动失败并打印键名。
19. 执行 `git init` 并创建基线提交 `chore: scaffold` — 供封版卡与状态刷新卡使用 `git tag` / `git status`。

### 用户可见文案清单（本卡必含，逐字）
| 类别 | 触发场景 | 逐字文案 | 渲染位置 |
|------|---------|---------|---------|
| 启动页标题 | 访问 `http://localhost:8080` | 校园访客系统 | 页面标题 |
| 健康检查成功 | `GET /api/v1/health` | 操作成功 | 响应 `message` |

## 验证
- [ ] `cd backend && npm ci && npm run typecheck && npm run build` → 退出码 0，存在 `dist/main.js`。
- [ ] `cd frontend && npm ci && npm run build` → 退出码 0，存在 `dist/index.html`。
- [ ] `cp .env.example .env && docker compose up -d --build && docker compose ps` → `db`、`backend`、`frontend` 均 `healthy`。
- [ ] `curl -s http://localhost:3000/api/v1/health` → `{"code":0,"message":"操作成功","data":{"status":"ok"}}`。
- [ ] `curl -s -o /dev/null -w ''%{http_code}'' http://localhost:8080/h5/apply` → `200`（SPA 回退生效）。
- [ ] `grep -n ''lang="zh-CN"'' frontend/index.html` 与 `grep -n ''viewport-fit=cover'' frontend/index.html` → 各命中 1 行；浏览器控制台无 404 资源请求。
- [ ] `grep -rn docker-entrypoint-initdb.d docker-compose.yml` → 0 命中。

## 在开始改动之前
1. 读取 `conventions.md`（约定 1、2、14）。
2. 读取 `docs/knowledge/config-contract.md` 与 `docs/trace/runs/v1/spac.md` §8.5/§8.6。
3. 确认本机 Docker 与 Docker Compose 可用。
4. 检查项目根是否已有 `backend/`、`frontend/`、`docker-compose.yml`；已存在则先读取再追加，禁止覆盖已有内容。

## 完成改动之后
1. 列出本卡创建/修改的全部文件路径。
2. 运行验证段全部命令并粘贴实际输出。
3. 确认全部验证通过；任一失败不得标记完成。
4. 列出剩余风险（例如本卡未接入统一信封，由 Hub 集成补全卡覆盖）。
5. 写入 `docs/memory/2026-10-19/VIS-P0-I01.md`。
', '6fb41cb9-db51-4196-a359-19f915a20e19', NULL, 'urgent', 10000, 1, 5, NULL, NULL, NULL, NULL, NULL, NULL, false, NULL, NULL, NULL, NULL);
INSERT INTO issues (id, created_at, updated_at, created_by_id, updated_by_id, project_id, workspace_id, name, description_json, description_html, description_stripped, state_id, parent_id, priority, sort_order, sequence_id, point, estimate_point_id, type_id, start_date, target_date, completed_at, archived_at, is_draft, external_source, external_id, description_binary, deleted_at) VALUES ('2b04c45b-1ebd-489a-bfee-3685ee181656', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', '[VIS-P0-I02] 数据库 DDL 与迁移执行器卡', '{}'::jsonb, '## 目标
建立共享表与六个上下文的全部业务表，并提供启动时自动执行的迁移器；重复执行不产生重复记录。

承载需求：无（基础设施卡）；为 45 条 REQ 的数据落库提供表结构支撑。

## 验收标准
- [ ] `backend/db/migrations/001-shared.sql` … `005-compliance.sql` 五个文件存在且只含 DDL。
- [ ] 执行 `npm run migrate` 后 `_migrations` 表恰有 5 条记录。
- [ ] `docker compose exec -T db psql -U visitor -d visitor_system -c "\dt"` 可见 8 张共享表：`roles`、`permissions`、`role_permissions`、`users`、`auth_types`、`sessions`、`operation_logs`、`system_config`。
- [ ] 可见 master 7 表：`hosts`、`visitor_types`、`gates`、`blacklist_entries`、`time_rules`、`reviewer_rules`、`data_dictionary`。
- [ ] 可见 visit 8 表：`appointments`、`companions`、`visit_credentials`、`passage_records`、`consent_records`、`incidents`、`appointment_status_history`、`visitor_tokens`。
- [ ] 可见 notify 2 表：`notifications`、`notification_channels`；compliance 1 表：`privacy_cases`。
- [ ] 连续执行两次 `npm run migrate`，第二次应用 0 个文件且退出码 0。
- [ ] 所有枚举列带 CHECK 约束；跨上下文列无外键。

## 相关背景

### 必读文件
- `conventions.md` — 约定 6 命名、约定 8 数据库与迁移。
- `docs/trace/runs/v1/spac.md` §5 数据库设计（5.1–5.10）。
- `schema-shared.sql` — 8 张共享表完整 DDL，逐字使用。
- `docs/knowledge/module-template.md` §六 迁移文件模式。

### 共享内核 API（摘自 docs/knowledge/shared-kernel-api.md）
- `runMigrations(): Promise<{ applied: string[] }>` — 扫描 `backend/db/migrations/*.sql`，以 `_migrations` 去重，每文件一个事务。
- `getPool(): Pool`、`query<T>(sql, params): Promise<T[]>`、`withTransaction<T>(fn): Promise<T>` — 本卡创建 `pool.ts` 完整实现，连接池上限取 `DB_POOL_MAX`（默认 10）。

### 模块模板（摘自 docs/knowledge/module-template.md）
- 迁移目录：`backend/db/migrations/`；三位数字前缀；只放 DDL；`IF NOT EXISTS`。

### 种子数据来源（摘自 seed-anchors.sql）
- 本卡不产出种子；种子由 `VIS-P0-I08` 负责。

### 本域设计（摘自架构设计文档 §5）
- 共享 8 表结构见 `schema-shared.sql`。
- master 7 表、visit 8 表、notify 2 表、compliance 1 表的列、类型、CHECK、索引见 §5.3–§5.10。
- 预约状态 CHECK ∈ `{待审核,已通过,已拒绝,已改期,已过期,已到访(在校中),已离校,已取消}`。
- 异常状态 CHECK ∈ `{待处理,已处理,已忽略}`；异常类型为 4 类中文枚举。
- 时间列统一 `TIMESTAMPTZ`；业务表统一 `created_at`、`updated_at`。

## 约束

### 命名约束
- 表名 snake_case 复数；列名 snake_case；主键 `id VARCHAR(36)`。
- 枚举以中文入库；软状态 `active`/`inactive`。
- 索引命名：`idx_<table>_<columns>`。

### 其他约束
- [边界] 迁移文件禁止 INSERT；禁止 `docker-entrypoint-initdb.d`。
- [边界] 跨上下文不建外键；同上下文内允许外键。
- [依赖] `pg`。
- [编号] 预约编号 `AP` + `YYYYMMDD` + 3 位序号，由共享内核 `nextAppointmentNo` 生成，不在 DDL 内生成。

## 实施阶段
实现

## 任务

### 后端
1. 创建 `backend/db/migrations/001-shared.sql` — 逐字复制 `schema-shared.sql` 的 8 张表与索引。
2. 创建 `backend/db/migrations/002-master.sql` — `hosts`、`visitor_types`、`gates`、`blacklist_entries`、`time_rules`、`reviewer_rules`、`data_dictionary`。
3. 创建 `backend/db/migrations/003-visit.sql` — `appointments`、`companions`、`visit_credentials`、`passage_records`、`consent_records`、`incidents`、`appointment_status_history`、`visitor_tokens`；含 `UNIQUE(visitor_id_no, visit_start, visit_end)` 与三个查询索引。
4. 创建 `backend/db/migrations/004-notify.sql` — `notifications`、`notification_channels`。
5. 创建 `backend/db/migrations/005-compliance.sql` — `privacy_cases`。
6. 创建 `backend/src/shared/db/migrate.ts` — `runMigrations()`：建 `_migrations`、按文件名排序、逐个事务执行未应用文件、记录文件名。
7. 创建 `backend/src/shared/db/pool.ts` — `getPool`、`query`、`withTransaction` 完整实现，连接池上限 `DB_POOL_MAX=10`。
8. 在 `backend/src/main.ts` 启动序中加入 `await runMigrations()`（位置：`getPool` 之后、`app.listen` 之前；Hub 卡引入 `createApp` 后调整为 `getPool → runMigrations → createApp`）。
9. 在 `backend/package.json` 增加 `"migrate": "tsx src/shared/db/migrate.ts"`。

### 用户可见文案清单（本卡必含，逐字）
| 类别 | 触发场景 | 逐字文案 | 渲染位置 |
|------|---------|---------|---------|
| 迁移成功日志 | 迁移完成 | 数据库迁移完成，已应用 {n} 个文件 | 后端 stdout |
| 迁移失败日志 | 任一迁移文件失败 | 数据库迁移失败：{文件名} | 后端 stderr |

## 验证
- [ ] `cd backend && npm run migrate` → 退出码 0；`docker compose exec -T db psql -U visitor -d visitor_system -c "select count(*) from _migrations"` → `5`。
- [ ] `docker compose exec -T db psql -U visitor -d visitor_system -c "\dt"` → 列出 27 张表（26 张业务表 + `_migrations`；业务表为 8 共享 + 7 master + 8 visit + 2 notify + 1 compliance）。
- [ ] `cd backend && npm run migrate` 第二次 → 输出「已应用 0 个文件」，`_migrations` 仍为 5。
- [ ] `docker compose exec -T db psql -U visitor -d visitor_system -c "\d appointments"` → 状态列含 8 个中文枚举的 CHECK。
- [ ] `grep -n "INSERT" backend/db/migrations/*.sql` → 0 命中。

## 在开始改动之前
1. 读取 `schema-shared.sql` 全文与 `spac.md` §5。
2. 读取 `conventions.md` 约定 6、8。
3. 检查 `backend/src/main.ts` 当前启动序；本卡只插入迁移调用，不改变其他顺序。

## 完成改动之后
1. 列出创建的迁移文件与执行器文件。
2. 粘贴两次迁移的实际输出与 `_migrations` 计数。
3. 确认全部验证通过。
4. 列出剩余风险（例如领域表索引在真实数据量下的表现由集成闭环卡验证）。
5. 写入 `docs/memory/2026-10-19/VIS-P0-I02.md`。
', '## 目标
建立共享表与六个上下文的全部业务表，并提供启动时自动执行的迁移器；重复执行不产生重复记录。

承载需求：无（基础设施卡）；为 45 条 REQ 的数据落库提供表结构支撑。

## 验收标准
- [ ] `backend/db/migrations/001-shared.sql` … `005-compliance.sql` 五个文件存在且只含 DDL。
- [ ] 执行 `npm run migrate` 后 `_migrations` 表恰有 5 条记录。
- [ ] `docker compose exec -T db psql -U visitor -d visitor_system -c "\dt"` 可见 8 张共享表：`roles`、`permissions`、`role_permissions`、`users`、`auth_types`、`sessions`、`operation_logs`、`system_config`。
- [ ] 可见 master 7 表：`hosts`、`visitor_types`、`gates`、`blacklist_entries`、`time_rules`、`reviewer_rules`、`data_dictionary`。
- [ ] 可见 visit 8 表：`appointments`、`companions`、`visit_credentials`、`passage_records`、`consent_records`、`incidents`、`appointment_status_history`、`visitor_tokens`。
- [ ] 可见 notify 2 表：`notifications`、`notification_channels`；compliance 1 表：`privacy_cases`。
- [ ] 连续执行两次 `npm run migrate`，第二次应用 0 个文件且退出码 0。
- [ ] 所有枚举列带 CHECK 约束；跨上下文列无外键。

## 相关背景

### 必读文件
- `conventions.md` — 约定 6 命名、约定 8 数据库与迁移。
- `docs/trace/runs/v1/spac.md` §5 数据库设计（5.1–5.10）。
- `schema-shared.sql` — 8 张共享表完整 DDL，逐字使用。
- `docs/knowledge/module-template.md` §六 迁移文件模式。

### 共享内核 API（摘自 docs/knowledge/shared-kernel-api.md）
- `runMigrations(): Promise<{ applied: string[] }>` — 扫描 `backend/db/migrations/*.sql`，以 `_migrations` 去重，每文件一个事务。
- `getPool(): Pool`、`query<T>(sql, params): Promise<T[]>`、`withTransaction<T>(fn): Promise<T>` — 本卡创建 `pool.ts` 完整实现，连接池上限取 `DB_POOL_MAX`（默认 10）。

### 模块模板（摘自 docs/knowledge/module-template.md）
- 迁移目录：`backend/db/migrations/`；三位数字前缀；只放 DDL；`IF NOT EXISTS`。

### 种子数据来源（摘自 seed-anchors.sql）
- 本卡不产出种子；种子由 `VIS-P0-I08` 负责。

### 本域设计（摘自架构设计文档 §5）
- 共享 8 表结构见 `schema-shared.sql`。
- master 7 表、visit 8 表、notify 2 表、compliance 1 表的列、类型、CHECK、索引见 §5.3–§5.10。
- 预约状态 CHECK ∈ `{待审核,已通过,已拒绝,已改期,已过期,已到访(在校中),已离校,已取消}`。
- 异常状态 CHECK ∈ `{待处理,已处理,已忽略}`；异常类型为 4 类中文枚举。
- 时间列统一 `TIMESTAMPTZ`；业务表统一 `created_at`、`updated_at`。

## 约束

### 命名约束
- 表名 snake_case 复数；列名 snake_case；主键 `id VARCHAR(36)`。
- 枚举以中文入库；软状态 `active`/`inactive`。
- 索引命名：`idx_<table>_<columns>`。

### 其他约束
- [边界] 迁移文件禁止 INSERT；禁止 `docker-entrypoint-initdb.d`。
- [边界] 跨上下文不建外键；同上下文内允许外键。
- [依赖] `pg`。
- [编号] 预约编号 `AP` + `YYYYMMDD` + 3 位序号，由共享内核 `nextAppointmentNo` 生成，不在 DDL 内生成。

## 实施阶段
实现

## 任务

### 后端
1. 创建 `backend/db/migrations/001-shared.sql` — 逐字复制 `schema-shared.sql` 的 8 张表与索引。
2. 创建 `backend/db/migrations/002-master.sql` — `hosts`、`visitor_types`、`gates`、`blacklist_entries`、`time_rules`、`reviewer_rules`、`data_dictionary`。
3. 创建 `backend/db/migrations/003-visit.sql` — `appointments`、`companions`、`visit_credentials`、`passage_records`、`consent_records`、`incidents`、`appointment_status_history`、`visitor_tokens`；含 `UNIQUE(visitor_id_no, visit_start, visit_end)` 与三个查询索引。
4. 创建 `backend/db/migrations/004-notify.sql` — `notifications`、`notification_channels`。
5. 创建 `backend/db/migrations/005-compliance.sql` — `privacy_cases`。
6. 创建 `backend/src/shared/db/migrate.ts` — `runMigrations()`：建 `_migrations`、按文件名排序、逐个事务执行未应用文件、记录文件名。
7. 创建 `backend/src/shared/db/pool.ts` — `getPool`、`query`、`withTransaction` 完整实现，连接池上限 `DB_POOL_MAX=10`。
8. 在 `backend/src/main.ts` 启动序中加入 `await runMigrations()`（位置：`getPool` 之后、`app.listen` 之前；Hub 卡引入 `createApp` 后调整为 `getPool → runMigrations → createApp`）。
9. 在 `backend/package.json` 增加 `"migrate": "tsx src/shared/db/migrate.ts"`。

### 用户可见文案清单（本卡必含，逐字）
| 类别 | 触发场景 | 逐字文案 | 渲染位置 |
|------|---------|---------|---------|
| 迁移成功日志 | 迁移完成 | 数据库迁移完成，已应用 {n} 个文件 | 后端 stdout |
| 迁移失败日志 | 任一迁移文件失败 | 数据库迁移失败：{文件名} | 后端 stderr |

## 验证
- [ ] `cd backend && npm run migrate` → 退出码 0；`docker compose exec -T db psql -U visitor -d visitor_system -c "select count(*) from _migrations"` → `5`。
- [ ] `docker compose exec -T db psql -U visitor -d visitor_system -c "\dt"` → 列出 27 张表（26 张业务表 + `_migrations`；业务表为 8 共享 + 7 master + 8 visit + 2 notify + 1 compliance）。
- [ ] `cd backend && npm run migrate` 第二次 → 输出「已应用 0 个文件」，`_migrations` 仍为 5。
- [ ] `docker compose exec -T db psql -U visitor -d visitor_system -c "\d appointments"` → 状态列含 8 个中文枚举的 CHECK。
- [ ] `grep -n "INSERT" backend/db/migrations/*.sql` → 0 命中。

## 在开始改动之前
1. 读取 `schema-shared.sql` 全文与 `spac.md` §5。
2. 读取 `conventions.md` 约定 6、8。
3. 检查 `backend/src/main.ts` 当前启动序；本卡只插入迁移调用，不改变其他顺序。

## 完成改动之后
1. 列出创建的迁移文件与执行器文件。
2. 粘贴两次迁移的实际输出与 `_migrations` 计数。
3. 确认全部验证通过。
4. 列出剩余风险（例如领域表索引在真实数据量下的表现由集成闭环卡验证）。
5. 写入 `docs/memory/2026-10-19/VIS-P0-I02.md`。
', '6fb41cb9-db51-4196-a359-19f915a20e19', NULL, 'urgent', 20000, 2, 8, NULL, NULL, NULL, NULL, NULL, NULL, false, NULL, NULL, NULL, NULL);
INSERT INTO issues (id, created_at, updated_at, created_by_id, updated_by_id, project_id, workspace_id, name, description_json, description_html, description_stripped, state_id, parent_id, priority, sort_order, sequence_id, point, estimate_point_id, type_id, start_date, target_date, completed_at, archived_at, is_draft, external_source, external_id, description_binary, deleted_at) VALUES ('33cb93ab-b049-49f7-89a4-e424d31c1de9', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', '[VIS-P0-I03] 共享内核卡', '{}'::jsonb, '## 目标
建立全部上下文共用的响应信封、错误、分页、校验、掩码、编号、审计、配置、调度、日志与实时通道，并通过单元测试。

承载需求：无（基础设施卡）；支撑 REQ-SM-001 的审计字段与 REQ-LG-004 的证件号掩码。

## 验收标准
- [ ] `backend/src/shared/` 下 19 个文件全部存在（另含 `backend/src/realtime/io.ts`，本卡共 20 个源文件），导出符号与 `shared-kernel-manifest.yaml` 逐字一致。
- [ ] `maskIdNo` 对 18/11/10/9/8/5 位证件号分别产出正确掩码，任何长度都不返回完整号码。
- [ ] `parsePagination` 对缺省、超限、非数字输入分别回退 1/100/默认值。
- [ ] `nextAppointmentNo` 在同日并发下不产生重复编号（由唯一索引兜底）。
- [ ] `writeAudit` 写入 `operation_logs` 的 7 个最小字段齐全。
- [ ] `npx vitest run src/shared/__tests__` 全部通过。

## 相关背景

### 必读文件
- `conventions.md` — 约定 1.4 Import 三档、约定 3 响应信封、约定 7 时间、约定 11 审计、约定 12 文案。
- `docs/trace/runs/v1/spac.md` §6.1 通用约定、§8.1 中间件序、§11 决策 S-01/S-02/S-41–S-47。
- `docs/knowledge/shared-kernel-api.md` — 全部签名。
- `docs/knowledge/config-contract.md` — 配置键与默认值。

### 共享内核 API（摘自 docs/knowledge/shared-kernel-api.md）
```ts
// http/envelope.ts
export function success(res, data, message = ''操作成功''): Response;
export function fail(res, httpStatus, code, message, field?): Response;
export function paginated(res, items, total, page, pageSize): Response;
// http/responseEnvelope.ts
export const responseEnvelope: RequestHandler;
// http/errors.ts
export class AppError extends Error { constructor(httpStatus, code, message, field?); }
export function badRequest(message, field?): AppError;
export function unauthorized(message?): AppError;
export function forbidden(message?, field?): AppError;
export function notFound(message?): AppError;
export function conflict(message?): AppError;
export function methodNotAllowed(message?): AppError;
export function unprocessable(message, field): AppError;
// http/pagination.ts
export function parsePagination(query, defaultPageSize?, maxPageSize?): Pagination;
// http/asyncHandler.ts
export function asyncHandler(fn): RequestHandler;
// shared/utils/mask.ts
export function maskIdNo(idNo: string): string;
// shared/utils/ids.ts
export function newUuid(): string;
export function formatMinute(value: Date | string): string;
export function formatSecond(value: Date | string): string;
export function localDayRange(day: Date | string): { start: Date; end: Date };
// shared/utils/appointmentNo.ts
export function nextAppointmentNo(tx, now: Date): Promise<string>;
export function generateShortCode(tx): Promise<string>;
// shared/validation/validators.ts
export function validateBody(schema): RequestHandler;
export function validateQuery(schema): RequestHandler;
export function isValidIdCard(value: string): boolean;
export function isValidPhone(value: string): boolean;
export function isValidOtherId(value: string): boolean;
export function normalizeIdNo(value: string): string;
// shared/audit/writeAudit.ts
export type AuditEntry = { userId; userName; objectType; objectId; action; result; before?; after?; ip?; note? };
export async function writeAudit(tx, entry: AuditEntry): Promise<void>;
// shared/config/configService.ts
export async function getConfig(key: string): Promise<string>;
export async function getConfigNumber(key: string): Promise<number>;
export async function setConfig(key: string, value: string, actorId: string): Promise<void>;
// shared/constants/status.ts
export const APPOINTMENT_STATUSES, TERMINAL_STATUSES, OPEN_STATUSES, ATTENDED_STATUSES, INCIDENT_STATUSES, INCIDENT_TYPES;
// shared/jobs/scheduler.ts
export function registerJob(def: JobDefinition): void;
export function startJobs(): void;
export function stopAllJobs(): void;
export type JobDefinition = { name: string; cron: string; runOnStart: boolean; handler: () => Promise<void> };
// realtime/io.ts
export function initRealtime(server, sessionMiddleware): SocketServer;
export function emitNotification(userId: string, payload): void;
```

### 模块模板（摘自 docs/knowledge/module-template.md）
- 共享内核位于 `backend/src/shared/`；其他上下文只能 import 共享内核与目标上下文 `index.ts`。

### 本域设计（摘自架构设计文档 §6.1、§8.1）
- 信封：`{ code, message, data, field? }`，`code=0` 成功。
- 错误码分配：40101–40104、40301–40303、40401、40501、40901–40902、42201、42901、50001。
- 掩码 F-010：长度 ≥9 → 前 4 + `(len−8)` 个 `*` + 后 4；长度 ≤8 → 前 1 + `max(1,len−2)` 个 `*` + 后 1。
- 审计最小字段：`user_id`、`user_name`、`occurred_at`、`object_type`、`object_id`、`action`、`result`、`before_value`、`after_value`。
- 审计保留 365 天；清理任务每日 03:10 执行。
- 调度任务登记：`appointment-expire`（`VIS-P1-I05`，每分钟）、`reminder` 与 `overdue`（`VIS-P1-I02`，每分钟）、`blacklist-expire`（`VIS-P1-I01`，每日 00:10）、`audit-cleanup`（`VIS-P1-I06`，每日 03:10）；各领域卡在 `index.ts` 调用 `registerJob`，Hub 卡只调用 `startJobs`。个人信息留存由展示层按 `privacy_retention_days` 计算，不设定时任务。

## 约束

### 命名约束
- 导出函数 camelCase；类型 PascalCase；常量 UPPER_SNAKE。
- `MESSAGES` 键为大写枚举名，值为逐字中文；文案逐字取自 `conventions.md`。
- 状态常量集合使用中文枚举值。

### 其他约束
- [边界] 本卡不创建业务路由、不创建业务表。
- [边界] `shared/` 不得 import `modules/`。
- [依赖] `express-validator`、`pg`、`node:crypto`、`qrcode`、`node-cron@3`（仅实时、编号与定时任务使用）。
- [并发] `nextAppointmentNo` 在事务内用 `pg_advisory_xact_lock` 按日期加锁；`generateShortCode` 碰撞重试最多 20 次。

## 实施阶段
实现

## 任务

### 后端
1. 创建 `backend/src/shared/http/envelope.ts` — `success`、`fail`、`paginated`，输出 snake_case 的 `page_size`。
2. 创建 `backend/src/shared/http/errors.ts` — `AppError` 与 7 个工厂函数。
3. 创建 `backend/src/shared/http/pagination.ts` — `parsePagination` 读取 `page`/`page_size`，默认 1/20，上限 100，非数字回退。
4. 创建 `backend/src/shared/http/asyncHandler.ts` — 捕获 Promise 异常转 `next(err)`。
5. 创建 `backend/src/shared/http/responseEnvelope.ts` — 给 `res` 附加 `success` / `fail` 方法。
6. 创建 `backend/src/shared/http/errorHandler.ts` — 4 参错误处理：`AppError` 按状态码与 code 输出；未知错误 500 + COPY-013。
7. 创建 `backend/src/shared/http/notFoundHandler.ts` — 未匹配路由返回 404 + COPY-008。
8. 创建 `backend/src/shared/middleware/requestContext.ts` — 生成 `requestId`，记录 IP（`req.ip`）。
9. 创建 `backend/src/shared/middleware/auditMiddleware.ts` — 只记录请求级元数据，不改写请求；业务审计由 service 直接调用 `writeAudit`。
10. 创建 `backend/src/shared/audit/writeAudit.ts` — 写入 `operation_logs`。
11. 创建 `backend/src/shared/config/configService.ts` — 读取 `system_config`，缓存 60 秒，`setConfig` 后失效。
12. 创建 `backend/src/shared/utils/mask.ts` — `maskIdNo` 按 F-010。
13. 创建 `backend/src/shared/utils/ids.ts` — `newUuid`、`formatMinute`、`formatSecond`、`localDayRange`。
14. 创建 `backend/src/shared/utils/appointmentNo.ts` — `nextAppointmentNo`、`generateShortCode`。
15. 创建 `backend/src/shared/validation/validators.ts` — 基于 express-validator 的 `validateBody`/`validateQuery` 与证件/手机号校验。
16. 创建 `backend/src/shared/constants/status.ts` — 六个集合常量。
17. 创建 `backend/src/shared/constants/messages.ts` — `MESSAGES` 逐字中文。
18. 创建 `backend/src/shared/logger.ts` — 结构化 JSON 日志，级别取 `LOG_LEVEL`。
19. 创建 `backend/src/shared/jobs/scheduler.ts` — `registerJob` 去重登记（同名后注册覆盖先注册）；`startJobs` 用 `node-cron` 按 `JobDefinition.cron` 统一启动全部已登记任务，`runOnStart` 为 true 时先执行一次；`ENABLE_JOBS !== ''true''` 时 `startJobs` 为 no-op；`stopAllJobs` 停止并清空全部任务。
20. 创建 `backend/src/realtime/io.ts` — `initRealtime` 挂载 socket.io 到 `/ws` 并返回 `SocketServer` 实例；`emitNotification` 发往 `user:<id>`。
21. 创建 `backend/src/shared/__tests__/` 下五个测试文件：`envelope.test.ts`、`pagination.test.ts`、`mask.test.ts`、`validators.test.ts`、`appointmentNo.test.ts`。

### 用户可见文案清单（本卡必含，逐字）
| 类别 | 触发场景 | 逐字文案 | 渲染位置 |
|------|---------|---------|---------|
| 通用成功 | 未指定 message 的成功响应 | 操作成功 | 响应 `message` |
| 资源不存在 | 未匹配路由或对象不存在 | 要查看的记录不存在或已被删除 | 响应 `message` |
| 服务器异常 | 未捕获异常 | 系统暂时无法处理，请稍后重试 | 响应 `message` |
| 未登录 | 会话缺失 | 请先登录 | 响应 `message` |
| 无权限 | 权限点不足 | 您没有执行该操作的权限 | 响应 `message` |

## 验证
- [ ] `cd backend && npx vitest run src/shared/__tests__` → 全部通过。
- [ ] `npx tsx -e "import {maskIdNo} from ''./src/shared/utils/mask''; console.log(maskIdNo(''320101198803034566''), maskIdNo(''32010119880''), maskIdNo(''32010119''))"` → `3201**********4566`、`3201***9880`、`3******9`（逐字节核对位数）。
- [ ] `npx tsx -e "import {notFoundHandler} from ''./src/shared/http/notFoundHandler''; console.log(typeof notFoundHandler)"` → `function`；单测断言未匹配路由返回 JSON 404 与 COPY-008。
- [ ] `grep -rn "req.audit" backend/src` → 0 命中（业务审计走 `writeAudit`）。
- [ ] 单测断言 `initRealtime` 返回 `SocketServer` 实例；未认证握手断开。挂载验证由 `VIS-P0-I07` 执行。

## 在开始改动之前
1. 读取 `docs/knowledge/shared-kernel-api.md` 全文。
2. 读取 `conventions.md` 约定 3、4、7、11、12。
3. 读取 `shared-kernel-manifest.yaml` 中本卡拥有的全部文件与导出。
4. 检查 `backend/src/shared/` 已存在的文件；先读后改。

## 完成改动之后
1. 列出创建/修改的全部文件。
2. 粘贴共享内核单测输出。
3. 确认全部验证通过。
4. 列出剩余风险（实时通道在无会话时的握手行为由 Hub 集成补全卡验证）。
5. 写入 `docs/memory/2026-10-19/VIS-P0-I03.md`。
', '## 目标
建立全部上下文共用的响应信封、错误、分页、校验、掩码、编号、审计、配置、调度、日志与实时通道，并通过单元测试。

承载需求：无（基础设施卡）；支撑 REQ-SM-001 的审计字段与 REQ-LG-004 的证件号掩码。

## 验收标准
- [ ] `backend/src/shared/` 下 19 个文件全部存在（另含 `backend/src/realtime/io.ts`，本卡共 20 个源文件），导出符号与 `shared-kernel-manifest.yaml` 逐字一致。
- [ ] `maskIdNo` 对 18/11/10/9/8/5 位证件号分别产出正确掩码，任何长度都不返回完整号码。
- [ ] `parsePagination` 对缺省、超限、非数字输入分别回退 1/100/默认值。
- [ ] `nextAppointmentNo` 在同日并发下不产生重复编号（由唯一索引兜底）。
- [ ] `writeAudit` 写入 `operation_logs` 的 7 个最小字段齐全。
- [ ] `npx vitest run src/shared/__tests__` 全部通过。

## 相关背景

### 必读文件
- `conventions.md` — 约定 1.4 Import 三档、约定 3 响应信封、约定 7 时间、约定 11 审计、约定 12 文案。
- `docs/trace/runs/v1/spac.md` §6.1 通用约定、§8.1 中间件序、§11 决策 S-01/S-02/S-41–S-47。
- `docs/knowledge/shared-kernel-api.md` — 全部签名。
- `docs/knowledge/config-contract.md` — 配置键与默认值。

### 共享内核 API（摘自 docs/knowledge/shared-kernel-api.md）
```ts
// http/envelope.ts
export function success(res, data, message = ''操作成功''): Response;
export function fail(res, httpStatus, code, message, field?): Response;
export function paginated(res, items, total, page, pageSize): Response;
// http/responseEnvelope.ts
export const responseEnvelope: RequestHandler;
// http/errors.ts
export class AppError extends Error { constructor(httpStatus, code, message, field?); }
export function badRequest(message, field?): AppError;
export function unauthorized(message?): AppError;
export function forbidden(message?, field?): AppError;
export function notFound(message?): AppError;
export function conflict(message?): AppError;
export function methodNotAllowed(message?): AppError;
export function unprocessable(message, field): AppError;
// http/pagination.ts
export function parsePagination(query, defaultPageSize?, maxPageSize?): Pagination;
// http/asyncHandler.ts
export function asyncHandler(fn): RequestHandler;
// shared/utils/mask.ts
export function maskIdNo(idNo: string): string;
// shared/utils/ids.ts
export function newUuid(): string;
export function formatMinute(value: Date | string): string;
export function formatSecond(value: Date | string): string;
export function localDayRange(day: Date | string): { start: Date; end: Date };
// shared/utils/appointmentNo.ts
export function nextAppointmentNo(tx, now: Date): Promise<string>;
export function generateShortCode(tx): Promise<string>;
// shared/validation/validators.ts
export function validateBody(schema): RequestHandler;
export function validateQuery(schema): RequestHandler;
export function isValidIdCard(value: string): boolean;
export function isValidPhone(value: string): boolean;
export function isValidOtherId(value: string): boolean;
export function normalizeIdNo(value: string): string;
// shared/audit/writeAudit.ts
export type AuditEntry = { userId; userName; objectType; objectId; action; result; before?; after?; ip?; note? };
export async function writeAudit(tx, entry: AuditEntry): Promise<void>;
// shared/config/configService.ts
export async function getConfig(key: string): Promise<string>;
export async function getConfigNumber(key: string): Promise<number>;
export async function setConfig(key: string, value: string, actorId: string): Promise<void>;
// shared/constants/status.ts
export const APPOINTMENT_STATUSES, TERMINAL_STATUSES, OPEN_STATUSES, ATTENDED_STATUSES, INCIDENT_STATUSES, INCIDENT_TYPES;
// shared/jobs/scheduler.ts
export function registerJob(def: JobDefinition): void;
export function startJobs(): void;
export function stopAllJobs(): void;
export type JobDefinition = { name: string; cron: string; runOnStart: boolean; handler: () => Promise<void> };
// realtime/io.ts
export function initRealtime(server, sessionMiddleware): SocketServer;
export function emitNotification(userId: string, payload): void;
```

### 模块模板（摘自 docs/knowledge/module-template.md）
- 共享内核位于 `backend/src/shared/`；其他上下文只能 import 共享内核与目标上下文 `index.ts`。

### 本域设计（摘自架构设计文档 §6.1、§8.1）
- 信封：`{ code, message, data, field? }`，`code=0` 成功。
- 错误码分配：40101–40104、40301–40303、40401、40501、40901–40902、42201、42901、50001。
- 掩码 F-010：长度 ≥9 → 前 4 + `(len−8)` 个 `*` + 后 4；长度 ≤8 → 前 1 + `max(1,len−2)` 个 `*` + 后 1。
- 审计最小字段：`user_id`、`user_name`、`occurred_at`、`object_type`、`object_id`、`action`、`result`、`before_value`、`after_value`。
- 审计保留 365 天；清理任务每日 03:10 执行。
- 调度任务登记：`appointment-expire`（`VIS-P1-I05`，每分钟）、`reminder` 与 `overdue`（`VIS-P1-I02`，每分钟）、`blacklist-expire`（`VIS-P1-I01`，每日 00:10）、`audit-cleanup`（`VIS-P1-I06`，每日 03:10）；各领域卡在 `index.ts` 调用 `registerJob`，Hub 卡只调用 `startJobs`。个人信息留存由展示层按 `privacy_retention_days` 计算，不设定时任务。

## 约束

### 命名约束
- 导出函数 camelCase；类型 PascalCase；常量 UPPER_SNAKE。
- `MESSAGES` 键为大写枚举名，值为逐字中文；文案逐字取自 `conventions.md`。
- 状态常量集合使用中文枚举值。

### 其他约束
- [边界] 本卡不创建业务路由、不创建业务表。
- [边界] `shared/` 不得 import `modules/`。
- [依赖] `express-validator`、`pg`、`node:crypto`、`qrcode`、`node-cron@3`（仅实时、编号与定时任务使用）。
- [并发] `nextAppointmentNo` 在事务内用 `pg_advisory_xact_lock` 按日期加锁；`generateShortCode` 碰撞重试最多 20 次。

## 实施阶段
实现

## 任务

### 后端
1. 创建 `backend/src/shared/http/envelope.ts` — `success`、`fail`、`paginated`，输出 snake_case 的 `page_size`。
2. 创建 `backend/src/shared/http/errors.ts` — `AppError` 与 7 个工厂函数。
3. 创建 `backend/src/shared/http/pagination.ts` — `parsePagination` 读取 `page`/`page_size`，默认 1/20，上限 100，非数字回退。
4. 创建 `backend/src/shared/http/asyncHandler.ts` — 捕获 Promise 异常转 `next(err)`。
5. 创建 `backend/src/shared/http/responseEnvelope.ts` — 给 `res` 附加 `success` / `fail` 方法。
6. 创建 `backend/src/shared/http/errorHandler.ts` — 4 参错误处理：`AppError` 按状态码与 code 输出；未知错误 500 + COPY-013。
7. 创建 `backend/src/shared/http/notFoundHandler.ts` — 未匹配路由返回 404 + COPY-008。
8. 创建 `backend/src/shared/middleware/requestContext.ts` — 生成 `requestId`，记录 IP（`req.ip`）。
9. 创建 `backend/src/shared/middleware/auditMiddleware.ts` — 只记录请求级元数据，不改写请求；业务审计由 service 直接调用 `writeAudit`。
10. 创建 `backend/src/shared/audit/writeAudit.ts` — 写入 `operation_logs`。
11. 创建 `backend/src/shared/config/configService.ts` — 读取 `system_config`，缓存 60 秒，`setConfig` 后失效。
12. 创建 `backend/src/shared/utils/mask.ts` — `maskIdNo` 按 F-010。
13. 创建 `backend/src/shared/utils/ids.ts` — `newUuid`、`formatMinute`、`formatSecond`、`localDayRange`。
14. 创建 `backend/src/shared/utils/appointmentNo.ts` — `nextAppointmentNo`、`generateShortCode`。
15. 创建 `backend/src/shared/validation/validators.ts` — 基于 express-validator 的 `validateBody`/`validateQuery` 与证件/手机号校验。
16. 创建 `backend/src/shared/constants/status.ts` — 六个集合常量。
17. 创建 `backend/src/shared/constants/messages.ts` — `MESSAGES` 逐字中文。
18. 创建 `backend/src/shared/logger.ts` — 结构化 JSON 日志，级别取 `LOG_LEVEL`。
19. 创建 `backend/src/shared/jobs/scheduler.ts` — `registerJob` 去重登记（同名后注册覆盖先注册）；`startJobs` 用 `node-cron` 按 `JobDefinition.cron` 统一启动全部已登记任务，`runOnStart` 为 true 时先执行一次；`ENABLE_JOBS !== ''true''` 时 `startJobs` 为 no-op；`stopAllJobs` 停止并清空全部任务。
20. 创建 `backend/src/realtime/io.ts` — `initRealtime` 挂载 socket.io 到 `/ws` 并返回 `SocketServer` 实例；`emitNotification` 发往 `user:<id>`。
21. 创建 `backend/src/shared/__tests__/` 下五个测试文件：`envelope.test.ts`、`pagination.test.ts`、`mask.test.ts`、`validators.test.ts`、`appointmentNo.test.ts`。

### 用户可见文案清单（本卡必含，逐字）
| 类别 | 触发场景 | 逐字文案 | 渲染位置 |
|------|---------|---------|---------|
| 通用成功 | 未指定 message 的成功响应 | 操作成功 | 响应 `message` |
| 资源不存在 | 未匹配路由或对象不存在 | 要查看的记录不存在或已被删除 | 响应 `message` |
| 服务器异常 | 未捕获异常 | 系统暂时无法处理，请稍后重试 | 响应 `message` |
| 未登录 | 会话缺失 | 请先登录 | 响应 `message` |
| 无权限 | 权限点不足 | 您没有执行该操作的权限 | 响应 `message` |

## 验证
- [ ] `cd backend && npx vitest run src/shared/__tests__` → 全部通过。
- [ ] `npx tsx -e "import {maskIdNo} from ''./src/shared/utils/mask''; console.log(maskIdNo(''320101198803034566''), maskIdNo(''32010119880''), maskIdNo(''32010119''))"` → `3201**********4566`、`3201***9880`、`3******9`（逐字节核对位数）。
- [ ] `npx tsx -e "import {notFoundHandler} from ''./src/shared/http/notFoundHandler''; console.log(typeof notFoundHandler)"` → `function`；单测断言未匹配路由返回 JSON 404 与 COPY-008。
- [ ] `grep -rn "req.audit" backend/src` → 0 命中（业务审计走 `writeAudit`）。
- [ ] 单测断言 `initRealtime` 返回 `SocketServer` 实例；未认证握手断开。挂载验证由 `VIS-P0-I07` 执行。

## 在开始改动之前
1. 读取 `docs/knowledge/shared-kernel-api.md` 全文。
2. 读取 `conventions.md` 约定 3、4、7、11、12。
3. 读取 `shared-kernel-manifest.yaml` 中本卡拥有的全部文件与导出。
4. 检查 `backend/src/shared/` 已存在的文件；先读后改。

## 完成改动之后
1. 列出创建/修改的全部文件。
2. 粘贴共享内核单测输出。
3. 确认全部验证通过。
4. 列出剩余风险（实时通道在无会话时的握手行为由 Hub 集成补全卡验证）。
5. 写入 `docs/memory/2026-10-19/VIS-P0-I03.md`。
', '6fb41cb9-db51-4196-a359-19f915a20e19', NULL, 'urgent', 30000, 3, 8, NULL, NULL, NULL, NULL, NULL, NULL, false, NULL, NULL, NULL, NULL);
INSERT INTO issues (id, created_at, updated_at, created_by_id, updated_by_id, project_id, workspace_id, name, description_json, description_html, description_stripped, state_id, parent_id, priority, sort_order, sequence_id, point, estimate_point_id, type_id, start_date, target_date, completed_at, archived_at, is_draft, external_source, external_id, description_binary, deleted_at) VALUES ('337f0cc4-12cc-4936-906c-d4037ecb5a70', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', '[VIS-P0-I04] 认证与会话中间件卡', '{}'::jsonb, '## 目标
建立后台会话、CSRF、权限闸门、访客令牌与登录限流，使会话、CSRF 拒绝、权限拒绝与令牌隔离可独立验证；账号锁定由 `VIS-P1-I04` 的登录服务实现。

承载需求：无（基础设施卡）；支撑 REQ-PT-001 的登录限流与 REQ-OR-002 的服务端权限闸门。

## 验收标准
- [ ] `sessionMiddleware` 使用 `connect-pg-simple`、Cookie 名 `vs.sid`、8 小时过期。
- [ ] 非 `GET/HEAD/OPTIONS` 请求缺 `X-CSRF-Token` 返回 403 COPY-103。
- [ ] `requirePermission` 按 `context:resource:action` 判定；不足返回 403 COPY-005 并写「越权拦截」审计。
- [ ] 访客令牌无效返回 403 COPY-007。
- [ ] `loginRateLimiter` 对同一 IP 超过 20 次/分钟返回 429 COPY-012。
- [ ] 单测覆盖 CSRF、权限、令牌、会话、限流五类。

## 相关背景

### 必读文件
- `conventions.md` — 约定 4 认证与会话、约定 12 文案。
- `docs/trace/runs/v1/spac.md` §6.2 认证端点、§8.1 第 8–10 步、§11 S-45/S-46。
- `roles.md` — 角色、权限点、adminOnly 清单、会话与令牌差异。
- `docs/knowledge/shared-kernel-api.md` — 中间件签名。

### 共享内核 API（摘自 docs/knowledge/shared-kernel-api.md）
```ts
export function sessionMiddleware(req, res, next): void;       // connect-pg-simple, 8h, vs.sid
export function csrfProtection(req, res, next): void;          // vs.csrf + X-CSRF-Token
export function requireAuth(req, res, next): void;             // 401 COPY-001
export function requirePermission(code: string): RequestHandler;
export function requireAdmin(req, res, next): void;
export function visitorTokenAuth(req, res, next): void;
export function loginRateLimiter(req, res, next): void;        // 20/min/IP → 429 COPY-012
export function hashPassword(plain: string): Promise<string>;
export function verifyPassword(plain: string, hash: string): Promise<boolean>;
export const PERMISSIONS: readonly string[];   // 与权限种子逐字一致，共 33 项
export function hasPermission(roleCode: string, code: string): boolean;
```

### 模块模板（摘自 docs/knowledge/module-template.md）
- 中间件放 `backend/src/shared/middleware/`；路由文件顶部 `router.use(requireAuth)`。

### 上游契约（摘自 docs/knowledge/phase-contracts/p0-contracts.md）
- `users`：`id, username, password_hash, display_name, role_code, host_id, phone, status, failed_login_count, locked_until, last_login_at`。
- `sessions`：`sid, sess, expire`。
- 登录响应逐字：`{ code: 0, message: ''登录成功'', data: { user: { id, username, display_name, role_code, host_id } } }`。

## 约束

### 命名约束
- Cookie：会话 `vs.sid`、CSRF `vs.csrf`、访客 `vs.visitor`；均 `HttpOnly`（`vs.csrf` 需前端读取，设 `HttpOnly=false`、`SameSite=Lax`）。
- 权限点格式 `context:resource:action`，全小写。

### 其他约束
- [边界] 本卡不实现登录页面；页面在 `VIS-P1-I04`。
- [边界] 锁定按账号，不按 IP；成功登录清零。
- [依赖] `express-session`、`connect-pg-simple`、`bcryptjs`、`cookie-parser`。
- [安全] 密码使用 bcrypt cost 10；会话 8 小时；Cookie `Secure` 由 `COOKIE_SECURE` 控制。

## 实施阶段
实现

## 任务

### 后端
1. 创建 `backend/src/shared/auth/session.ts` — `sessionMiddleware` 使用 `connect-pg-simple`，表 `sessions`，`name: ''vs.sid''`，`maxAge: 8h`。
2. 创建 `backend/src/shared/auth/password.ts` — `hashPassword`、`verifyPassword`（bcrypt cost 10）。
3. 创建 `backend/src/shared/auth/permissions.ts` — 33 个权限点常量、角色映射、`hasPermission`。
4. 创建 `backend/src/shared/middleware/csrfProtection.ts` — 下发 `vs.csrf`；写请求校验 `X-CSRF-Token`；登录端点豁免。
5. 创建 `backend/src/shared/middleware/requireAuth.ts` — 读 `req.session.user`；缺失 401 COPY-001。
6. 创建 `backend/src/shared/middleware/requirePermission.ts` — `requirePermission(code)` 与 `requireAdmin`；失败 403 并写审计。
7. 创建 `backend/src/shared/middleware/visitorTokenAuth.ts` — 读取 `vs.visitor`，SHA-256 比对 `visitor_tokens.token_hash`，校验 `expires_at`。
8. 创建 `backend/src/shared/middleware/rateLimiter.ts` — `loginRateLimiter` 20 次/分钟/IP；`apiRateLimiter` 600 次/分钟/IP。
9. 创建 `backend/src/shared/__tests__/auth.test.ts` — 覆盖 CSRF、权限、令牌过期、会话、限流五类。
10. 在 `backend/package.json` 增加运行依赖 `bcryptjs` 与开发依赖 `@types/bcryptjs`。

### 用户可见文案清单（本卡必含，逐字）
| 类别 | 触发场景 | 逐字文案 | 渲染位置 |
|------|---------|---------|---------|
| 未登录 | 会话缺失 | 请先登录 | 响应 `message` |
| 无权限 | 权限点不足 | 您没有执行该操作的权限 | 响应 `message` |
| CSRF 缺失 | 写请求无令牌 | 安全校验已失效，请刷新页面后重试 | 响应 `message` |
| 令牌失效 | 访客令牌无效或过期 | 该申请链接已失效，请重新扫码申请 | 响应 `message` |
| 登录限流 | 同一 IP 超过 20 次/分钟 | 登录请求过于频繁，请 1 分钟后再试 | 响应 `message` |

## 验证
- [ ] `cd backend && npx vitest run src/shared/__tests__/auth.test.ts` → 全部通过（测试内自建最小 Express 实例挂载中间件，不依赖业务路由）。
- [ ] `cd backend && npx tsx -e "import {hasPermission} from ''./src/shared/auth/permissions''; console.log(hasPermission(''guard'',''system:params:read''))"` → `false`。
- [ ] `cd backend && npx tsx -e "import {hashPassword,verifyPassword} from ''./src/shared/auth/password''; (async()=>{const h=await hashPassword(''abc@123''); console.log(await verifyPassword(''abc@123'',h), await verifyPassword(''wrong'',h))})()"` → `true false`。
- [ ] `grep -c "COPY-103" backend/src/shared/middleware/csrfProtection.ts` → `1`；`grep -c "COPY-005" backend/src/shared/middleware/requirePermission.ts` → `1`。
- [ ] 测试断言：同一 IP 第 21 次登录请求返回 429 COPY-012。
- [ ] 测试断言：无 `X-CSRF-Token` 的写请求 403 COPY-103；无会话访问受保护中间件 401 COPY-001。

## 在开始改动之前
1. 读取 `roles.md` 权限矩阵与 `conventions.md` 约定 5。
2. 读取 `p0-contracts.md` 登录/登出/CSRF 契约。
3. 检查 `backend/src/shared/` 中已存在的文件；先读后改。

## 完成改动之后
1. 列出创建/修改的文件。
2. 粘贴锁定、CSRF、403 审计的实际输出。
3. 确认全部验证通过。
4. 列出剩余风险（登录页未实现，端到端登录在 `VIS-P1-I04` 验证）。
5. 写入 `docs/memory/2026-10-19/VIS-P0-I04.md`。
', '## 目标
建立后台会话、CSRF、权限闸门、访客令牌与登录限流，使会话、CSRF 拒绝、权限拒绝与令牌隔离可独立验证；账号锁定由 `VIS-P1-I04` 的登录服务实现。

承载需求：无（基础设施卡）；支撑 REQ-PT-001 的登录限流与 REQ-OR-002 的服务端权限闸门。

## 验收标准
- [ ] `sessionMiddleware` 使用 `connect-pg-simple`、Cookie 名 `vs.sid`、8 小时过期。
- [ ] 非 `GET/HEAD/OPTIONS` 请求缺 `X-CSRF-Token` 返回 403 COPY-103。
- [ ] `requirePermission` 按 `context:resource:action` 判定；不足返回 403 COPY-005 并写「越权拦截」审计。
- [ ] 访客令牌无效返回 403 COPY-007。
- [ ] `loginRateLimiter` 对同一 IP 超过 20 次/分钟返回 429 COPY-012。
- [ ] 单测覆盖 CSRF、权限、令牌、会话、限流五类。

## 相关背景

### 必读文件
- `conventions.md` — 约定 4 认证与会话、约定 12 文案。
- `docs/trace/runs/v1/spac.md` §6.2 认证端点、§8.1 第 8–10 步、§11 S-45/S-46。
- `roles.md` — 角色、权限点、adminOnly 清单、会话与令牌差异。
- `docs/knowledge/shared-kernel-api.md` — 中间件签名。

### 共享内核 API（摘自 docs/knowledge/shared-kernel-api.md）
```ts
export function sessionMiddleware(req, res, next): void;       // connect-pg-simple, 8h, vs.sid
export function csrfProtection(req, res, next): void;          // vs.csrf + X-CSRF-Token
export function requireAuth(req, res, next): void;             // 401 COPY-001
export function requirePermission(code: string): RequestHandler;
export function requireAdmin(req, res, next): void;
export function visitorTokenAuth(req, res, next): void;
export function loginRateLimiter(req, res, next): void;        // 20/min/IP → 429 COPY-012
export function hashPassword(plain: string): Promise<string>;
export function verifyPassword(plain: string, hash: string): Promise<boolean>;
export const PERMISSIONS: readonly string[];   // 与权限种子逐字一致，共 33 项
export function hasPermission(roleCode: string, code: string): boolean;
```

### 模块模板（摘自 docs/knowledge/module-template.md）
- 中间件放 `backend/src/shared/middleware/`；路由文件顶部 `router.use(requireAuth)`。

### 上游契约（摘自 docs/knowledge/phase-contracts/p0-contracts.md）
- `users`：`id, username, password_hash, display_name, role_code, host_id, phone, status, failed_login_count, locked_until, last_login_at`。
- `sessions`：`sid, sess, expire`。
- 登录响应逐字：`{ code: 0, message: ''登录成功'', data: { user: { id, username, display_name, role_code, host_id } } }`。

## 约束

### 命名约束
- Cookie：会话 `vs.sid`、CSRF `vs.csrf`、访客 `vs.visitor`；均 `HttpOnly`（`vs.csrf` 需前端读取，设 `HttpOnly=false`、`SameSite=Lax`）。
- 权限点格式 `context:resource:action`，全小写。

### 其他约束
- [边界] 本卡不实现登录页面；页面在 `VIS-P1-I04`。
- [边界] 锁定按账号，不按 IP；成功登录清零。
- [依赖] `express-session`、`connect-pg-simple`、`bcryptjs`、`cookie-parser`。
- [安全] 密码使用 bcrypt cost 10；会话 8 小时；Cookie `Secure` 由 `COOKIE_SECURE` 控制。

## 实施阶段
实现

## 任务

### 后端
1. 创建 `backend/src/shared/auth/session.ts` — `sessionMiddleware` 使用 `connect-pg-simple`，表 `sessions`，`name: ''vs.sid''`，`maxAge: 8h`。
2. 创建 `backend/src/shared/auth/password.ts` — `hashPassword`、`verifyPassword`（bcrypt cost 10）。
3. 创建 `backend/src/shared/auth/permissions.ts` — 33 个权限点常量、角色映射、`hasPermission`。
4. 创建 `backend/src/shared/middleware/csrfProtection.ts` — 下发 `vs.csrf`；写请求校验 `X-CSRF-Token`；登录端点豁免。
5. 创建 `backend/src/shared/middleware/requireAuth.ts` — 读 `req.session.user`；缺失 401 COPY-001。
6. 创建 `backend/src/shared/middleware/requirePermission.ts` — `requirePermission(code)` 与 `requireAdmin`；失败 403 并写审计。
7. 创建 `backend/src/shared/middleware/visitorTokenAuth.ts` — 读取 `vs.visitor`，SHA-256 比对 `visitor_tokens.token_hash`，校验 `expires_at`。
8. 创建 `backend/src/shared/middleware/rateLimiter.ts` — `loginRateLimiter` 20 次/分钟/IP；`apiRateLimiter` 600 次/分钟/IP。
9. 创建 `backend/src/shared/__tests__/auth.test.ts` — 覆盖 CSRF、权限、令牌过期、会话、限流五类。
10. 在 `backend/package.json` 增加运行依赖 `bcryptjs` 与开发依赖 `@types/bcryptjs`。

### 用户可见文案清单（本卡必含，逐字）
| 类别 | 触发场景 | 逐字文案 | 渲染位置 |
|------|---------|---------|---------|
| 未登录 | 会话缺失 | 请先登录 | 响应 `message` |
| 无权限 | 权限点不足 | 您没有执行该操作的权限 | 响应 `message` |
| CSRF 缺失 | 写请求无令牌 | 安全校验已失效，请刷新页面后重试 | 响应 `message` |
| 令牌失效 | 访客令牌无效或过期 | 该申请链接已失效，请重新扫码申请 | 响应 `message` |
| 登录限流 | 同一 IP 超过 20 次/分钟 | 登录请求过于频繁，请 1 分钟后再试 | 响应 `message` |

## 验证
- [ ] `cd backend && npx vitest run src/shared/__tests__/auth.test.ts` → 全部通过（测试内自建最小 Express 实例挂载中间件，不依赖业务路由）。
- [ ] `cd backend && npx tsx -e "import {hasPermission} from ''./src/shared/auth/permissions''; console.log(hasPermission(''guard'',''system:params:read''))"` → `false`。
- [ ] `cd backend && npx tsx -e "import {hashPassword,verifyPassword} from ''./src/shared/auth/password''; (async()=>{const h=await hashPassword(''abc@123''); console.log(await verifyPassword(''abc@123'',h), await verifyPassword(''wrong'',h))})()"` → `true false`。
- [ ] `grep -c "COPY-103" backend/src/shared/middleware/csrfProtection.ts` → `1`；`grep -c "COPY-005" backend/src/shared/middleware/requirePermission.ts` → `1`。
- [ ] 测试断言：同一 IP 第 21 次登录请求返回 429 COPY-012。
- [ ] 测试断言：无 `X-CSRF-Token` 的写请求 403 COPY-103；无会话访问受保护中间件 401 COPY-001。

## 在开始改动之前
1. 读取 `roles.md` 权限矩阵与 `conventions.md` 约定 5。
2. 读取 `p0-contracts.md` 登录/登出/CSRF 契约。
3. 检查 `backend/src/shared/` 中已存在的文件；先读后改。

## 完成改动之后
1. 列出创建/修改的文件。
2. 粘贴锁定、CSRF、403 审计的实际输出。
3. 确认全部验证通过。
4. 列出剩余风险（登录页未实现，端到端登录在 `VIS-P1-I04` 验证）。
5. 写入 `docs/memory/2026-10-19/VIS-P0-I04.md`。
', '6fb41cb9-db51-4196-a359-19f915a20e19', NULL, 'urgent', 40000, 4, 5, NULL, NULL, NULL, NULL, NULL, NULL, false, NULL, NULL, NULL, NULL);
INSERT INTO issues (id, created_at, updated_at, created_by_id, updated_by_id, project_id, workspace_id, name, description_json, description_html, description_stripped, state_id, parent_id, priority, sort_order, sequence_id, point, estimate_point_id, type_id, start_date, target_date, completed_at, archived_at, is_draft, external_source, external_id, description_binary, deleted_at) VALUES ('9324bf50-22d1-46cf-be45-76c9ceb28fb5', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', '[VIS-P0-I05] 前端基础卡', '{}'::jsonb, '## 目标
建立前端 API 客户端、认证与通知 Store、实时连接、共享组件、布局壳与设计令牌，使页面卡只写业务页面。

承载需求：无（基础设施卡）；支撑 REQ-PT-004 的通知未读状态。

## 验收标准
- [ ] `frontend/src/api/client.ts` 默认导出 axios 实例，`baseURL=''/api/v1''`，`withCredentials=true`。
- [ ] 请求拦截器把对象键 camelCase → snake_case，并注入 `X-CSRF-Token`。
- [ ] 响应拦截器把 `response.data.data` 内键 snake_case → camelCase，且不解包信封。
- [ ] 401 时清空 `useAuthStore` 并跳 `/login`。
- [ ] 7 个共享组件与 2 个布局壳存在并可渲染。
- [ ] `npm run build` 退出码 0。

## 相关背景

### 必读文件
- `conventions.md` — 约定 6 类型转换、约定 10 前端交互与视觉、约定 12 文案（COPY-355/356/357 等）。
- `docs/trace/runs/v1/spac.md` §7 前端结构、§7.7 视觉规范、§8.4 实时事件。
- `docs/knowledge/shared-kernel-api.md` 前端段。
- `docs/knowledge/module-template.md` 前端模式。

### 共享内核 API（摘自 docs/knowledge/shared-kernel-api.md）
```ts
// api/client.ts
const apiClient: AxiosInstance; // baseURL ''/api/v1''
// stores/auth.ts
export const useAuthStore: () => { user; role; isLoggedIn; login(); logout(); fetchMe(); changePassword(); };
export type AuthUser = { id: string; username: string; displayName: string; roleCode: string; hostId: string | null };
// stores/notification.ts
export const useNotificationStore: () => { unreadCount; items; fetchUnreadCount(); fetchItems(); markRead(); markAllRead(); };
// realtime/socket.ts
export function connectRealtime(): void;
export function disconnectRealtime(): void;
```
- 组件：`PageHeader.vue`、`StatusTag.vue`、`EmptyState.vue`、`LoadingState.vue`、`ErrorState.vue`、`ConfirmDialog.vue`、`CopyButton.vue`，均为默认导出。
- 布局：`AppLayout.vue`、`H5Layout.vue`，均为默认导出。
- `nav/icons.ts` 导出 `iconMap`。

### 模块模板（摘自 docs/knowledge/module-template.md）
- 页面组件放 `views/<context>/`；共享组件放 `components/`；Store 放 `stores/`。

## 约束

### 命名约束
- 前端变量/函数 camelCase；组件文件 PascalCase；路由文件 kebab-case。
- `StatusTag` 的 `status` 属性值为中文枚举原文。

### 其他约束
- [边界] 本卡不创建业务页面、不创建业务路由。
- [依赖] `axios`、`pinia`、`ant-design-vue@4`、`socket.io-client`、`dayjs`。
- [交互] 所有异步按钮至少两种状态：默认文案、进行中文案；成功/失败用 `message` 提示。
- [文案] 组件内建文案逐字取自 `conventions.md`；不在本卡新造文案。

## 实施阶段
实现

## 任务

### 前端
1. 创建 `frontend/src/api/client.ts` — axios 实例、双拦截器、401 处理、`X-CSRF-Token` 注入。
2. 创建 `frontend/src/stores/auth.ts` — `useAuthStore`、`AuthUser`。
3. 创建 `frontend/src/stores/notification.ts` — `useNotificationStore`。
4. 创建 `frontend/src/realtime/socket.ts` — `connectRealtime` 监听 `notification:new` 并更新未读数。
5. 创建 `frontend/src/components/PageHeader.vue` — props `title`、`subtitle`、`breadcrumbs`，`actions` 插槽；`breadcrumbs` 为空时不渲染面包屑。
6. 创建 `frontend/src/components/StatusTag.vue` — `kind=''appointment''` 渲染 8 个预约状态，`kind=''incident''` 渲染 3 个异常状态，`kind=''soft''` 渲染「在用/停用」。
7. 创建 `frontend/src/components/EmptyState.vue` — 图标 + 描述 + 可选操作按钮，点击操作 emit `action`。
8. 创建 `frontend/src/components/ConfirmDialog.vue` — props `title`、`content`、`okText`、`cancelText`、`danger`，emit `confirm`/`cancel`。
9. 创建 `frontend/src/components/CopyButton.vue` — props `text`、`successMessage`（默认 COPY-046），复制成功提示「入口链接已复制」。
10. 创建 `frontend/src/layouts/AppLayout.vue` — 侧边导航、顶栏、消息铃铛、用户菜单、退出确认；菜单图标通过 `iconMap` 解析，未登记时回退 `AppstoreOutlined`。
11. 创建 `frontend/src/layouts/H5Layout.vue` — 移动端容器，最大宽度 480px；吸底区域使用 `env(safe-area-inset-bottom)`。
12. 创建 `frontend/src/styles/reset.css`、`frontend/src/styles/tokens.css`、`frontend/src/styles/print.css` — 颜色、间距、字号令牌与打印规则。
13. 修改 `frontend/src/main.ts` — 挂载 Pinia、Ant Design Vue、`zh_CN` 语言包、`dayjs.locale(''zh-cn'')`、全局样式与 `App.vue`；`App.vue` 用 `a-config-provider :locale="zhCN"` 包裹。
14. 创建 `frontend/src/components/__tests__/StatusTag.test.ts` — 断言 8 个预约状态、3 个异常状态与 `kind=''soft''` 的「在用/停用」中文标签。
15. 创建 `frontend/src/api/__tests__/client.test.ts` — 用 `vi.mock(''axios'')` 拦截请求，断言请求键转 snake_case、响应键转 camelCase、信封不被解包。
16. 在 `frontend/package.json` 增加 `socket.io-client`、`dayjs` 与开发依赖 `@vue/test-utils`、`vitest`。
17. 创建 `frontend/src/components/LoadingState.vue` 与 `frontend/src/components/ErrorState.vue` — 前者渲染 `a-skeleton` 与 COPY-357，后者渲染 COPY-355 与 COPY-356 重试按钮并 emit `retry`。
18. 创建 `frontend/src/nav/icons.ts` — `iconMap` 覆盖 `navigation.ts` 的 11 个主项与 3 个子项图标键。

### 用户可见文案清单（本卡必含，逐字）
| COPY | 类别 | 触发场景 | 逐字文案 | 渲染位置 |
|------|------|---------|---------|---------|
| COPY-358 | 空态默认 | 未传描述的列表空态 | 暂无数据 | EmptyState |
| COPY-357 | 加载中 | 骨架屏 | 加载中... | LoadingState |
| COPY-355 | 加载失败 | 列表或详情请求失败 | 数据加载失败，请点击重试 | ErrorState |
| COPY-356 | 重试 | 错误态按钮 | 重试 | ErrorState |
| COPY-364/365 | 软状态标签 | 主数据/账号状态 | 在用、停用 | StatusTag kind=''soft'' |
| COPY-359 | 确认按钮 | 通用确认框 | 确定 | ConfirmDialog |
| COPY-360 | 取消按钮 | 通用确认框 | 取消 | ConfirmDialog |
| COPY-046 | 复制成功 | 点击复制入口链接 | 入口链接已复制 | Toast |
| COPY-023 | 退出确认标题 | 点击退出登录 | 确认退出登录 | ConfirmDialog title |
| COPY-024 | 退出确认正文 | 同上 | 退出后需要重新输入账号和密码才能继续使用，是否退出？ | ConfirmDialog content |
| COPY-280 | 未读消息 | 消息铃铛 | 未读消息 | 徽标说明 |
| COPY-366…373 | 状态标签 | 预约 8 态 | 待审核、已通过、已拒绝、已改期、已过期、已到访(在校中)、已离校、已取消 | StatusTag |
| COPY-374/375/376 | 异常状态 | 异常 3 态 | 待处理、已处理、已忽略 | StatusTag |

### UI 完整性检验结论（2026-10-19）
- 检验范围：7 个共享组件、2 个布局壳、3 个样式文件；本卡不承载路由。
- 通过项：四态组件绑定 COPY-355/356/357；`ConfirmDialog` 为唯一确认框并禁止 `Modal.confirm`；H5 最大宽度 480px 与 `env(safe-area-inset-bottom)`；打印样式；`zh_CN`、`dayjs(''zh-cn'')`、`iconMap` 回退；图标按钮 `aria-label`。
- 对应缺陷：U2、U3、U4、U9、U12。

## 验证
- [ ] `cd frontend && npm run build` → 退出码 0。
- [ ] `npx vitest run src/components/__tests__ src/api/__tests__` → 全部通过。
- [ ] `grep -rn "alert(\|confirm(" frontend/src --include=''*.vue'' --include=''*.ts''` → 0 命中；`grep -rn "Modal.confirm" frontend/src` → 0 命中。
- [ ] `grep -n "zh_CN\|zh-cn" frontend/src/main.ts frontend/src/App.vue` → 命中语言包与 dayjs 本地化各 1 处。
- [ ] `ls frontend/src/components/LoadingState.vue frontend/src/components/ErrorState.vue` → 两个文件均存在。
- [ ] 浏览器打开 `http://localhost:8080/` → 页面标题「校园访客系统」可见；控制台无报错。
- [ ] `client.test.ts` 断言：`/auth/me` 响应经拦截器后 `displayName` 为 camelCase，`response.data.code` 仍存在（信封未解包）。
- [ ] 点击退出登录 → 弹出 ConfirmDialog，标题与正文逐字为 COPY-023/COPY-024。

## 在开始改动之前
1. 读取 `conventions.md` 约定 6、10、12。
2. 读取 `docs/knowledge/shared-kernel-api.md` 前端段。
3. 检查 `frontend/src/` 已存在文件；先读后改。

## 完成改动之后
1. 列出创建/修改的文件。
2. 粘贴构建输出与组件测试输出。
3. 确认全部验证通过。
4. 列出剩余风险（apiClient 的深层数组键转换由集成闭环卡用真实响应验证）。
5. 写入 `docs/memory/2026-10-19/VIS-P0-I05.md`。
', '## 目标
建立前端 API 客户端、认证与通知 Store、实时连接、共享组件、布局壳与设计令牌，使页面卡只写业务页面。

承载需求：无（基础设施卡）；支撑 REQ-PT-004 的通知未读状态。

## 验收标准
- [ ] `frontend/src/api/client.ts` 默认导出 axios 实例，`baseURL=''/api/v1''`，`withCredentials=true`。
- [ ] 请求拦截器把对象键 camelCase → snake_case，并注入 `X-CSRF-Token`。
- [ ] 响应拦截器把 `response.data.data` 内键 snake_case → camelCase，且不解包信封。
- [ ] 401 时清空 `useAuthStore` 并跳 `/login`。
- [ ] 7 个共享组件与 2 个布局壳存在并可渲染。
- [ ] `npm run build` 退出码 0。

## 相关背景

### 必读文件
- `conventions.md` — 约定 6 类型转换、约定 10 前端交互与视觉、约定 12 文案（COPY-355/356/357 等）。
- `docs/trace/runs/v1/spac.md` §7 前端结构、§7.7 视觉规范、§8.4 实时事件。
- `docs/knowledge/shared-kernel-api.md` 前端段。
- `docs/knowledge/module-template.md` 前端模式。

### 共享内核 API（摘自 docs/knowledge/shared-kernel-api.md）
```ts
// api/client.ts
const apiClient: AxiosInstance; // baseURL ''/api/v1''
// stores/auth.ts
export const useAuthStore: () => { user; role; isLoggedIn; login(); logout(); fetchMe(); changePassword(); };
export type AuthUser = { id: string; username: string; displayName: string; roleCode: string; hostId: string | null };
// stores/notification.ts
export const useNotificationStore: () => { unreadCount; items; fetchUnreadCount(); fetchItems(); markRead(); markAllRead(); };
// realtime/socket.ts
export function connectRealtime(): void;
export function disconnectRealtime(): void;
```
- 组件：`PageHeader.vue`、`StatusTag.vue`、`EmptyState.vue`、`LoadingState.vue`、`ErrorState.vue`、`ConfirmDialog.vue`、`CopyButton.vue`，均为默认导出。
- 布局：`AppLayout.vue`、`H5Layout.vue`，均为默认导出。
- `nav/icons.ts` 导出 `iconMap`。

### 模块模板（摘自 docs/knowledge/module-template.md）
- 页面组件放 `views/<context>/`；共享组件放 `components/`；Store 放 `stores/`。

## 约束

### 命名约束
- 前端变量/函数 camelCase；组件文件 PascalCase；路由文件 kebab-case。
- `StatusTag` 的 `status` 属性值为中文枚举原文。

### 其他约束
- [边界] 本卡不创建业务页面、不创建业务路由。
- [依赖] `axios`、`pinia`、`ant-design-vue@4`、`socket.io-client`、`dayjs`。
- [交互] 所有异步按钮至少两种状态：默认文案、进行中文案；成功/失败用 `message` 提示。
- [文案] 组件内建文案逐字取自 `conventions.md`；不在本卡新造文案。

## 实施阶段
实现

## 任务

### 前端
1. 创建 `frontend/src/api/client.ts` — axios 实例、双拦截器、401 处理、`X-CSRF-Token` 注入。
2. 创建 `frontend/src/stores/auth.ts` — `useAuthStore`、`AuthUser`。
3. 创建 `frontend/src/stores/notification.ts` — `useNotificationStore`。
4. 创建 `frontend/src/realtime/socket.ts` — `connectRealtime` 监听 `notification:new` 并更新未读数。
5. 创建 `frontend/src/components/PageHeader.vue` — props `title`、`subtitle`、`breadcrumbs`，`actions` 插槽；`breadcrumbs` 为空时不渲染面包屑。
6. 创建 `frontend/src/components/StatusTag.vue` — `kind=''appointment''` 渲染 8 个预约状态，`kind=''incident''` 渲染 3 个异常状态，`kind=''soft''` 渲染「在用/停用」。
7. 创建 `frontend/src/components/EmptyState.vue` — 图标 + 描述 + 可选操作按钮，点击操作 emit `action`。
8. 创建 `frontend/src/components/ConfirmDialog.vue` — props `title`、`content`、`okText`、`cancelText`、`danger`，emit `confirm`/`cancel`。
9. 创建 `frontend/src/components/CopyButton.vue` — props `text`、`successMessage`（默认 COPY-046），复制成功提示「入口链接已复制」。
10. 创建 `frontend/src/layouts/AppLayout.vue` — 侧边导航、顶栏、消息铃铛、用户菜单、退出确认；菜单图标通过 `iconMap` 解析，未登记时回退 `AppstoreOutlined`。
11. 创建 `frontend/src/layouts/H5Layout.vue` — 移动端容器，最大宽度 480px；吸底区域使用 `env(safe-area-inset-bottom)`。
12. 创建 `frontend/src/styles/reset.css`、`frontend/src/styles/tokens.css`、`frontend/src/styles/print.css` — 颜色、间距、字号令牌与打印规则。
13. 修改 `frontend/src/main.ts` — 挂载 Pinia、Ant Design Vue、`zh_CN` 语言包、`dayjs.locale(''zh-cn'')`、全局样式与 `App.vue`；`App.vue` 用 `a-config-provider :locale="zhCN"` 包裹。
14. 创建 `frontend/src/components/__tests__/StatusTag.test.ts` — 断言 8 个预约状态、3 个异常状态与 `kind=''soft''` 的「在用/停用」中文标签。
15. 创建 `frontend/src/api/__tests__/client.test.ts` — 用 `vi.mock(''axios'')` 拦截请求，断言请求键转 snake_case、响应键转 camelCase、信封不被解包。
16. 在 `frontend/package.json` 增加 `socket.io-client`、`dayjs` 与开发依赖 `@vue/test-utils`、`vitest`。
17. 创建 `frontend/src/components/LoadingState.vue` 与 `frontend/src/components/ErrorState.vue` — 前者渲染 `a-skeleton` 与 COPY-357，后者渲染 COPY-355 与 COPY-356 重试按钮并 emit `retry`。
18. 创建 `frontend/src/nav/icons.ts` — `iconMap` 覆盖 `navigation.ts` 的 11 个主项与 3 个子项图标键。

### 用户可见文案清单（本卡必含，逐字）
| COPY | 类别 | 触发场景 | 逐字文案 | 渲染位置 |
|------|------|---------|---------|---------|
| COPY-358 | 空态默认 | 未传描述的列表空态 | 暂无数据 | EmptyState |
| COPY-357 | 加载中 | 骨架屏 | 加载中... | LoadingState |
| COPY-355 | 加载失败 | 列表或详情请求失败 | 数据加载失败，请点击重试 | ErrorState |
| COPY-356 | 重试 | 错误态按钮 | 重试 | ErrorState |
| COPY-364/365 | 软状态标签 | 主数据/账号状态 | 在用、停用 | StatusTag kind=''soft'' |
| COPY-359 | 确认按钮 | 通用确认框 | 确定 | ConfirmDialog |
| COPY-360 | 取消按钮 | 通用确认框 | 取消 | ConfirmDialog |
| COPY-046 | 复制成功 | 点击复制入口链接 | 入口链接已复制 | Toast |
| COPY-023 | 退出确认标题 | 点击退出登录 | 确认退出登录 | ConfirmDialog title |
| COPY-024 | 退出确认正文 | 同上 | 退出后需要重新输入账号和密码才能继续使用，是否退出？ | ConfirmDialog content |
| COPY-280 | 未读消息 | 消息铃铛 | 未读消息 | 徽标说明 |
| COPY-366…373 | 状态标签 | 预约 8 态 | 待审核、已通过、已拒绝、已改期、已过期、已到访(在校中)、已离校、已取消 | StatusTag |
| COPY-374/375/376 | 异常状态 | 异常 3 态 | 待处理、已处理、已忽略 | StatusTag |

### UI 完整性检验结论（2026-10-19）
- 检验范围：7 个共享组件、2 个布局壳、3 个样式文件；本卡不承载路由。
- 通过项：四态组件绑定 COPY-355/356/357；`ConfirmDialog` 为唯一确认框并禁止 `Modal.confirm`；H5 最大宽度 480px 与 `env(safe-area-inset-bottom)`；打印样式；`zh_CN`、`dayjs(''zh-cn'')`、`iconMap` 回退；图标按钮 `aria-label`。
- 对应缺陷：U2、U3、U4、U9、U12。

## 验证
- [ ] `cd frontend && npm run build` → 退出码 0。
- [ ] `npx vitest run src/components/__tests__ src/api/__tests__` → 全部通过。
- [ ] `grep -rn "alert(\|confirm(" frontend/src --include=''*.vue'' --include=''*.ts''` → 0 命中；`grep -rn "Modal.confirm" frontend/src` → 0 命中。
- [ ] `grep -n "zh_CN\|zh-cn" frontend/src/main.ts frontend/src/App.vue` → 命中语言包与 dayjs 本地化各 1 处。
- [ ] `ls frontend/src/components/LoadingState.vue frontend/src/components/ErrorState.vue` → 两个文件均存在。
- [ ] 浏览器打开 `http://localhost:8080/` → 页面标题「校园访客系统」可见；控制台无报错。
- [ ] `client.test.ts` 断言：`/auth/me` 响应经拦截器后 `displayName` 为 camelCase，`response.data.code` 仍存在（信封未解包）。
- [ ] 点击退出登录 → 弹出 ConfirmDialog，标题与正文逐字为 COPY-023/COPY-024。

## 在开始改动之前
1. 读取 `conventions.md` 约定 6、10、12。
2. 读取 `docs/knowledge/shared-kernel-api.md` 前端段。
3. 检查 `frontend/src/` 已存在文件；先读后改。

## 完成改动之后
1. 列出创建/修改的文件。
2. 粘贴构建输出与组件测试输出。
3. 确认全部验证通过。
4. 列出剩余风险（apiClient 的深层数组键转换由集成闭环卡用真实响应验证）。
5. 写入 `docs/memory/2026-10-19/VIS-P0-I05.md`。
', '6fb41cb9-db51-4196-a359-19f915a20e19', NULL, 'urgent', 50000, 5, 5, NULL, NULL, NULL, NULL, NULL, NULL, false, NULL, NULL, NULL, NULL);
INSERT INTO issues (id, created_at, updated_at, created_by_id, updated_by_id, project_id, workspace_id, name, description_json, description_html, description_stripped, state_id, parent_id, priority, sort_order, sequence_id, point, estimate_point_id, type_id, start_date, target_date, completed_at, archived_at, is_draft, external_source, external_id, description_binary, deleted_at) VALUES ('c8ad6233-7a8f-41c3-b2d9-ba2858513520', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', '[VIS-P0-I06] 前端路由与导航骨架卡', '{}'::jsonb, '## 目标
建立两阶段路由注册、根容器记录与唯一导航写入点，使六个上下文的 `routes.ts` 被自动发现并挂到 `root` 下。

承载需求：无（基础设施卡）；支撑 REQ-PT-002 的路由与导航骨架。

## 验收标准
- [ ] `sharedRoutes` 含 `{ path: ''/'', name: ''root'', component: RouterContainer, redirect: ''/login'' }`。
- [ ] `sharedRoutes` 只含根记录与 `/h5`（`redirect: ''/h5/apply''`）；`/login`、`/403` 由 `views/access/routes.ts` 提供并自动挂到 `root`。
- [ ] 根记录含 `/:pathMatch(.*)*` 兜底：已登录重定向 `/workbench`，未登录重定向 `/login`；`/h5/:pathMatch(.*)*` 重定向 `/h5/apply`。
- [ ] `router/index.ts` 先 `createRouter` + 逐条 `addRoute(sharedRoutes)`，再 `import.meta.glob(''@/views/*/routes.ts'', { eager: true })` 并用 `router.addRoute(''root'', record)` 挂载。
- [ ] 全局守卫：首次导航先 `await useAuthStore().fetchMe()`（仅一次），避免刷新时已登录用户被弹回 `/login`；未登录访问后台路由跳 `/login?redirect=<path>`；已登录访问 `/login` 跳 `/workbench`；无角色权限跳 `/403`；`meta.layout === ''h5''` 与 `/403` 不走登录守卫。
- [ ] `navigation.ts` 是唯一菜单来源；`filterNavigation(items, role)` 按角色过滤，递归处理 `children`，父项无可见子项时整体剔除；`icon` 键均能在 `iconMap` 中解析。
- [ ] `App.vue` 按 `route.meta.layout` 选择 `AppLayout` / `H5Layout` / 空布局。

## 相关背景

### 必读文件
- `conventions.md` — 约定 10 前端交互与视觉、约定 12 文案（COPY-397…407）。
- `docs/trace/runs/v1/spac.md` §4 路由表、§7.5 前端路由与导航。
- `docs/knowledge/shared-kernel-api.md` 路由段。
- `roles.md` — 三角色可见范围。

### 共享内核 API（摘自 docs/knowledge/shared-kernel-api.md）
```ts
// router/index.ts
const router: Router; export default router;
// router/shared.routes.ts
export const sharedRoutes: RouteRecordRaw[];
// components/RouterContainer.vue —— 仅含 <router-view />
// nav/navigation.ts
export type NavItem = { key: string; title: string; path: string; roles: string[]; icon: string; children?: NavItem[] };
export const navigation: NavItem[];
export function filterNavigation(items: NavItem[], role: string): NavItem[];
```

### 模块模板（摘自 docs/knowledge/module-template.md）
- `views/<context>/routes.ts` 导出路由数组；命名 kebab-case。

### 本域设计（摘自架构设计文档 §4、§7.5）
- 后台路由：`/workbench`、`/appointments`、`/reviews`、`/gate`、`/ledger`、`/on-campus`、`/statistics`、`/users`、`/master`、`/notifications`、`/system/settings`、`/system/audit`、`/system/privacy`。
- H5 路由：`/h5/apply`、`/h5/my`、`/h5/privacy`。
- 兜底：`/403`。
- 导航角色：工作台（admin/guard/host）、访客预约（admin/host）、被访人审核（admin/host）、门卫核验（admin/guard）、访客台账（admin/guard）、在校清单（admin/guard）、统计分析（admin）、用户与角色（admin）、主数据（admin）、通知中心（admin/guard/host）、系统管理（admin）。

## 约束

### 命名约束
- 路由 `name` 使用 kebab-case（如 `appointment-list`）。
- `meta.layout` ∈ `{''app'',''h5'',''blank''}`；`meta.roles` 为角色数组。
- `meta.title` 逐字取自 `navigation.ts`。

### 其他约束
- [边界] 本卡不创建业务页面；`views/*/routes.ts` 由各全栈卡提供。
- [边界] 页面内禁止写菜单；导航只在 `navigation.ts` 写入。
- [依赖] `vue-router@4`、`pinia`。

## 实施阶段
实现

## 任务

### 前端
1. 创建 `frontend/src/components/RouterContainer.vue` — 仅含 `<router-view />`。
2. 创建 `frontend/src/router/shared.routes.ts` — `sharedRoutes`：根记录 `name: ''root''`、根级 `/:pathMatch(.*)*` 兜底、`/h5`（`redirect: ''/h5/apply''`）与 `/h5/:pathMatch(.*)*` 兜底；不写 `/login`、`/403`，这两条由 `views/access/routes.ts` 提供。
3. 创建 `frontend/src/router/index.ts` — `createWebHistory`、注册共享路由、`import.meta.glob(''@/views/*/routes.ts'', { eager: true })`、`addRoute(''root'', record)`、全局守卫；守卫首帧 `await authStore.fetchMe()`，失败静默，仅对 `meta.layout !== ''h5''` 且非 `/login`、`/403` 的路径做登录判断。
4. 创建 `frontend/src/nav/navigation.ts` — `NavItem`、`navigation`、`filterNavigation`（递归过滤 `children`，父项无可见子项时剔除）；菜单标题逐字取自 COPY-397…407。
5. 修改 `frontend/src/App.vue` — 按 `route.meta.layout` 选择布局；H5 路由使用 `H5Layout`，登录/403 使用空布局，其余使用 `AppLayout`。
6. 创建 `frontend/src/router/__tests__/guard.test.ts` — 覆盖未登录跳转、已登录跳 `/workbench`、角色不足跳 `/403`、H5 公开路由放行、刷新后 `fetchMe` 成功不跳登录、未知路径兜底。
7. 创建 `frontend/src/nav/__tests__/navigation.test.ts` — 断言三角色菜单过滤、系统管理子菜单 3 条、父项无可见子项时剔除。

### 用户可见文案清单（本卡必含，逐字）
| COPY | 类别 | 触发场景 | 逐字文案 | 渲染位置 |
|------|------|---------|---------|---------|
| COPY-397…407 | 导航标题 | 侧边栏 | 工作台、访客预约、被访人审核、门卫核验、访客台账、在校清单、统计分析、用户与角色、主数据、通知中心、系统管理 | 菜单项 |

### UI 完整性检验结论（2026-10-19）
- 检验范围：路由注册、守卫、导航、两条兜底、`App.vue` 布局选择。
- 通过项：18 条路由由各全栈卡挂载；根级与 `/h5` 兜底；三角色菜单过滤；11 个导航标题逐字取 COPY-397…407；`/403` 与 H5 不走登录守卫。
- 对应缺陷：U13、U18。

## 验证
- [ ] `cd frontend && npm run build` → 退出码 0。
- [ ] `npx vitest run src/router/__tests__/guard.test.ts` → 全部通过；测试内以 stub 路由断言未登录访问 `/workbench` 跳转 `/login?redirect=/workbench`、已登录访问 `/login` 跳转 `/workbench`。
- [ ] `grep -rn "addRoute" frontend/src/router/index.ts` → 命中 `router.addRoute(''root'', record)`。
- [ ] `grep -rn "menu" frontend/src/views 2>/dev/null` → 0 命中。
- [ ] `grep -n "pathMatch" frontend/src/router/shared.routes.ts` → 命中根级与 H5 两条兜底。
- [ ] `grep -n "fetchMe" frontend/src/router/index.ts` → 命中守卫初始化调用。
- [ ] `npx vitest run src/nav/__tests__/navigation.test.ts` → `filterNavigation(navigation,''guard'')` 不含 `users`、`master`、`statistics`；`filterNavigation(navigation,''admin'')` 含 `system` 且其 `children` 为 3 条。

## 在开始改动之前
1. 读取 `spac.md` §4 与 §7.5。
2. 读取 `frontend/src/App.vue` 与已存在的 `frontend/src/router/`。
3. 检查 `navigation.ts` 是否已存在；存在则先读后改。

## 完成改动之后
1. 列出创建/修改的文件。
2. 粘贴守卫测试输出与路由跳转截图描述。
3. 确认全部验证通过。
4. 列出剩余风险（业务页面尚未存在，`views/*/routes.ts` 由六个领域全栈卡补齐）。
5. 写入 `docs/memory/2026-10-19/VIS-P0-I06.md`。
', '## 目标
建立两阶段路由注册、根容器记录与唯一导航写入点，使六个上下文的 `routes.ts` 被自动发现并挂到 `root` 下。

承载需求：无（基础设施卡）；支撑 REQ-PT-002 的路由与导航骨架。

## 验收标准
- [ ] `sharedRoutes` 含 `{ path: ''/'', name: ''root'', component: RouterContainer, redirect: ''/login'' }`。
- [ ] `sharedRoutes` 只含根记录与 `/h5`（`redirect: ''/h5/apply''`）；`/login`、`/403` 由 `views/access/routes.ts` 提供并自动挂到 `root`。
- [ ] 根记录含 `/:pathMatch(.*)*` 兜底：已登录重定向 `/workbench`，未登录重定向 `/login`；`/h5/:pathMatch(.*)*` 重定向 `/h5/apply`。
- [ ] `router/index.ts` 先 `createRouter` + 逐条 `addRoute(sharedRoutes)`，再 `import.meta.glob(''@/views/*/routes.ts'', { eager: true })` 并用 `router.addRoute(''root'', record)` 挂载。
- [ ] 全局守卫：首次导航先 `await useAuthStore().fetchMe()`（仅一次），避免刷新时已登录用户被弹回 `/login`；未登录访问后台路由跳 `/login?redirect=<path>`；已登录访问 `/login` 跳 `/workbench`；无角色权限跳 `/403`；`meta.layout === ''h5''` 与 `/403` 不走登录守卫。
- [ ] `navigation.ts` 是唯一菜单来源；`filterNavigation(items, role)` 按角色过滤，递归处理 `children`，父项无可见子项时整体剔除；`icon` 键均能在 `iconMap` 中解析。
- [ ] `App.vue` 按 `route.meta.layout` 选择 `AppLayout` / `H5Layout` / 空布局。

## 相关背景

### 必读文件
- `conventions.md` — 约定 10 前端交互与视觉、约定 12 文案（COPY-397…407）。
- `docs/trace/runs/v1/spac.md` §4 路由表、§7.5 前端路由与导航。
- `docs/knowledge/shared-kernel-api.md` 路由段。
- `roles.md` — 三角色可见范围。

### 共享内核 API（摘自 docs/knowledge/shared-kernel-api.md）
```ts
// router/index.ts
const router: Router; export default router;
// router/shared.routes.ts
export const sharedRoutes: RouteRecordRaw[];
// components/RouterContainer.vue —— 仅含 <router-view />
// nav/navigation.ts
export type NavItem = { key: string; title: string; path: string; roles: string[]; icon: string; children?: NavItem[] };
export const navigation: NavItem[];
export function filterNavigation(items: NavItem[], role: string): NavItem[];
```

### 模块模板（摘自 docs/knowledge/module-template.md）
- `views/<context>/routes.ts` 导出路由数组；命名 kebab-case。

### 本域设计（摘自架构设计文档 §4、§7.5）
- 后台路由：`/workbench`、`/appointments`、`/reviews`、`/gate`、`/ledger`、`/on-campus`、`/statistics`、`/users`、`/master`、`/notifications`、`/system/settings`、`/system/audit`、`/system/privacy`。
- H5 路由：`/h5/apply`、`/h5/my`、`/h5/privacy`。
- 兜底：`/403`。
- 导航角色：工作台（admin/guard/host）、访客预约（admin/host）、被访人审核（admin/host）、门卫核验（admin/guard）、访客台账（admin/guard）、在校清单（admin/guard）、统计分析（admin）、用户与角色（admin）、主数据（admin）、通知中心（admin/guard/host）、系统管理（admin）。

## 约束

### 命名约束
- 路由 `name` 使用 kebab-case（如 `appointment-list`）。
- `meta.layout` ∈ `{''app'',''h5'',''blank''}`；`meta.roles` 为角色数组。
- `meta.title` 逐字取自 `navigation.ts`。

### 其他约束
- [边界] 本卡不创建业务页面；`views/*/routes.ts` 由各全栈卡提供。
- [边界] 页面内禁止写菜单；导航只在 `navigation.ts` 写入。
- [依赖] `vue-router@4`、`pinia`。

## 实施阶段
实现

## 任务

### 前端
1. 创建 `frontend/src/components/RouterContainer.vue` — 仅含 `<router-view />`。
2. 创建 `frontend/src/router/shared.routes.ts` — `sharedRoutes`：根记录 `name: ''root''`、根级 `/:pathMatch(.*)*` 兜底、`/h5`（`redirect: ''/h5/apply''`）与 `/h5/:pathMatch(.*)*` 兜底；不写 `/login`、`/403`，这两条由 `views/access/routes.ts` 提供。
3. 创建 `frontend/src/router/index.ts` — `createWebHistory`、注册共享路由、`import.meta.glob(''@/views/*/routes.ts'', { eager: true })`、`addRoute(''root'', record)`、全局守卫；守卫首帧 `await authStore.fetchMe()`，失败静默，仅对 `meta.layout !== ''h5''` 且非 `/login`、`/403` 的路径做登录判断。
4. 创建 `frontend/src/nav/navigation.ts` — `NavItem`、`navigation`、`filterNavigation`（递归过滤 `children`，父项无可见子项时剔除）；菜单标题逐字取自 COPY-397…407。
5. 修改 `frontend/src/App.vue` — 按 `route.meta.layout` 选择布局；H5 路由使用 `H5Layout`，登录/403 使用空布局，其余使用 `AppLayout`。
6. 创建 `frontend/src/router/__tests__/guard.test.ts` — 覆盖未登录跳转、已登录跳 `/workbench`、角色不足跳 `/403`、H5 公开路由放行、刷新后 `fetchMe` 成功不跳登录、未知路径兜底。
7. 创建 `frontend/src/nav/__tests__/navigation.test.ts` — 断言三角色菜单过滤、系统管理子菜单 3 条、父项无可见子项时剔除。

### 用户可见文案清单（本卡必含，逐字）
| COPY | 类别 | 触发场景 | 逐字文案 | 渲染位置 |
|------|------|---------|---------|---------|
| COPY-397…407 | 导航标题 | 侧边栏 | 工作台、访客预约、被访人审核、门卫核验、访客台账、在校清单、统计分析、用户与角色、主数据、通知中心、系统管理 | 菜单项 |

### UI 完整性检验结论（2026-10-19）
- 检验范围：路由注册、守卫、导航、两条兜底、`App.vue` 布局选择。
- 通过项：18 条路由由各全栈卡挂载；根级与 `/h5` 兜底；三角色菜单过滤；11 个导航标题逐字取 COPY-397…407；`/403` 与 H5 不走登录守卫。
- 对应缺陷：U13、U18。

## 验证
- [ ] `cd frontend && npm run build` → 退出码 0。
- [ ] `npx vitest run src/router/__tests__/guard.test.ts` → 全部通过；测试内以 stub 路由断言未登录访问 `/workbench` 跳转 `/login?redirect=/workbench`、已登录访问 `/login` 跳转 `/workbench`。
- [ ] `grep -rn "addRoute" frontend/src/router/index.ts` → 命中 `router.addRoute(''root'', record)`。
- [ ] `grep -rn "menu" frontend/src/views 2>/dev/null` → 0 命中。
- [ ] `grep -n "pathMatch" frontend/src/router/shared.routes.ts` → 命中根级与 H5 两条兜底。
- [ ] `grep -n "fetchMe" frontend/src/router/index.ts` → 命中守卫初始化调用。
- [ ] `npx vitest run src/nav/__tests__/navigation.test.ts` → `filterNavigation(navigation,''guard'')` 不含 `users`、`master`、`statistics`；`filterNavigation(navigation,''admin'')` 含 `system` 且其 `children` 为 3 条。

## 在开始改动之前
1. 读取 `spac.md` §4 与 §7.5。
2. 读取 `frontend/src/App.vue` 与已存在的 `frontend/src/router/`。
3. 检查 `navigation.ts` 是否已存在；存在则先读后改。

## 完成改动之后
1. 列出创建/修改的文件。
2. 粘贴守卫测试输出与路由跳转截图描述。
3. 确认全部验证通过。
4. 列出剩余风险（业务页面尚未存在，`views/*/routes.ts` 由六个领域全栈卡补齐）。
5. 写入 `docs/memory/2026-10-19/VIS-P0-I06.md`。
', '6fb41cb9-db51-4196-a359-19f915a20e19', NULL, 'urgent', 60000, 6, 5, NULL, NULL, NULL, NULL, NULL, NULL, false, NULL, NULL, NULL, NULL);
INSERT INTO issues (id, created_at, updated_at, created_by_id, updated_by_id, project_id, workspace_id, name, description_json, description_html, description_stripped, state_id, parent_id, priority, sort_order, sequence_id, point, estimate_point_id, type_id, start_date, target_date, completed_at, archived_at, is_draft, external_source, external_id, description_binary, deleted_at) VALUES ('b6b838b4-5b81-4098-90e3-fe8c6bf2415c', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', '[VIS-P0-I07] Hub 集成补全卡', '{}'::jsonb, '## 目标
在 `backend/src/app.ts` 按 16 步顺序完成全部中间件装配与路由自动发现，在 `backend/src/main.ts` 完成 HTTP Server 与 WebSocket 挂载，使任何单个中间件漏挂都能被验证发现。

承载需求：无（基础设施卡）；支撑全部端点按 16 步中间件序装配。

## 验收标准
- [ ] `createApp()` 返回的 app 依次装配 16 个步骤，顺序与 `shared-kernel-manifest.yaml` 的 `assembly_order` 逐条一致。
- [ ] `GET /api/v1/health` 在鉴权前返回 `code=0`。
- [ ] 任意 `modules/<ctx>/api/*.routes.ts` 无需手工注册即挂到 `/api/v1`。
- [ ] `main.ts` 在 `http.createServer(app)` 之后调用 `initRealtime(server, sessionMiddleware)`，再 `server.listen(PORT)`。
- [ ] 未匹配路由返回 JSON 404（不是 HTML）。
- [ ] 未捕获异常返回 JSON 500 + COPY-013（不是 HTML 堆栈）。

## 相关背景

### 必读文件
- `conventions.md` — 约定 2 中间件 16 步、约定 14 配置。
- `docs/trace/runs/v1/spac.md` §8.1 装配表、§8.2 路由发现、§8.4 实时事件。
- `shared-kernel-manifest.yaml` — `assembly_order` 与 `assembly` 块。
- `docs/knowledge/shared-kernel-api.md` — `createApp`、`mountRoutes`、`initRealtime` 签名。

### 共享内核 API（摘自 docs/knowledge/shared-kernel-api.md）
```ts
// backend/src/config.ts
export function loadConfig(): Config;
export const config: Config;
// backend/src/app.ts
export function createApp(): Express;
export function mountRoutes(app: Express): void;
// backend/src/shared/http/responseEnvelope.ts
export function responseEnvelope(req, res, next): void;
// backend/src/shared/auth/session.ts
export function sessionMiddleware(req, res, next): void;
// backend/src/shared/middleware/csrfProtection.ts
export function csrfProtection(req, res, next): void;
// backend/src/shared/middleware/rateLimiter.ts
export function apiRateLimiter(req, res, next): void;
// backend/src/shared/middleware/auditMiddleware.ts
export function auditMiddleware(req, res, next): void;
// backend/src/shared/http/notFoundHandler.ts
export function notFoundHandler(req, res, next): void;
// backend/src/shared/http/errorHandler.ts
export function errorHandler(err, req, res, next): void;
// backend/src/shared/jobs/scheduler.ts
export function startJobs(): void;
// backend/src/realtime/io.ts
export function initRealtime(server: http.Server, sessionMiddleware: RequestHandler): SocketServer;
```

### 模块模板（摘自 docs/knowledge/module-template.md）
- 组合根 `app.ts` 扫描 `modules/*/api/*.routes.ts`，统一挂到 `/api/v1`。
- `/api/v1` 字面量在 `app.ts` 只出现一次。

## 约束

### 命名约束
- 挂载点：`/api/v1`；WebSocket 路径 `/ws`。
- 路由文件必须 `export default router`。

### 其他约束
- [边界] 本卡不改任何业务 service；只做装配。
- [边界] `auditMiddleware` 只做请求级兜底，不注入 `req.audit`；业务审计由 service 调用 `writeAudit`。
- [依赖] `helmet`、`cors`、`compression`、`cookie-parser`、`express-session`、`socket.io`。
- [顺序] `responseEnvelope` 必须在路由前；`cookieParser`、`session`、`csrf` 相邻且顺序固定；health 在鉴权前；errorHandler 最后。

## 实施阶段
实现

## 任务

### 后端
1. 修改 `backend/src/app.ts` — 导出常量 `API_PREFIX = ''/api/v1''`，实现 `createApp()`，逐字写入以下装配行（顺序不可调换）：
```ts
app.set(''trust proxy'', 1);
app.use(helmet());
app.use(cors({ origin: config.CORS_ORIGIN, credentials: true }));
app.use(compression());
app.use(cookieParser(config.COOKIE_SECRET));
app.use(express.json({ limit: ''1mb'' }));
app.use(responseEnvelope);
app.use(sessionMiddleware);
app.use(csrfProtection);
app.use(apiRateLimiter);
app.get(`${API_PREFIX}/health`, (_req, res) => res.json({ code: 0, message: ''操作成功'', data: { status: ''ok'' } }));
mountRoutes(app);
app.use(auditMiddleware);
app.use(notFoundHandler);
app.use(errorHandler);
```
2. 修改 `backend/src/app.ts` — 实现 `mountRoutes(app)`：`fs.readdirSync(modulesDir)` 遍历上下文，扫描 `api/*.routes.ts`，`await import()` 后 `app.use(API_PREFIX, router)`；本文件 `''/api/v1''` 字面量只在常量声明处出现一次。
3. 修改 `backend/src/main.ts` — 启动序：`loadConfig() → getPool → runMigrations → createApp → http.createServer(app) → const io = initRealtime(server, sessionMiddleware) → server.listen(PORT) → ENABLE_JOBS === ''true'' && startJobs()`。
4. 修改 `backend/src/main.ts` — 注册 `SIGTERM`/`SIGINT`：`stopAllJobs()`、`io.close()`、`server.close()`、`pool.end()`。
5. 创建 `backend/src/__tests__/assembly.test.ts` — 断言 16 步顺序、health 可达、404 JSON、500 JSON、`initRealtime` 在 `listen` 前。
6. 确认 `backend/src/shared/jobs/scheduler.ts` 由共享内核卡提供 `registerJob`/`startJobs`；本卡不登记业务任务。

### 前端
7. 修改 `frontend/src/layouts/AppLayout.vue` — `onMounted` 时若 `useAuthStore().user` 存在则调用 `connectRealtime()`；`onUnmounted` 调用 `disconnectRealtime()`。
8. 修改 `frontend/src/App.vue` — 挂载路由视图与全局消息容器。

### 用户可见文案清单（本卡必含，逐字）
| 类别 | 触发场景 | 逐字文案 | 渲染位置 |
|------|---------|---------|---------|
| 健康检查成功 | `GET /api/v1/health` | 操作成功 | 响应 `message` |
| 404 | 未匹配路由 | 要查看的记录不存在或已被删除 | 响应 `message` |
| 500 | 未捕获异常 | 系统暂时无法处理，请稍后重试 | 响应 `message` |

## 验证
- [ ] `cd backend && npx vitest run src/__tests__/assembly.test.ts` → 全部通过。
- [ ] `curl -s http://localhost:3000/api/v1/health` → `code=0`。
- [ ] `curl -s http://localhost:3000/api/v1/no-such-path` → HTTP 404 且 `Content-Type: application/json`。
- [ ] 新建 `backend/src/modules/ping/api/ping.routes.ts` 导出 `router.get(''/ping'')` 后重启 → `GET /api/v1/ping` 返回 200，无需修改 `app.ts`。
- [ ] `grep -c "''/api/v1''" backend/src/app.ts` → 1。
- [ ] `grep -n "initRealtime" backend/src/main.ts` → 位于 `http.createServer` 之后、`listen` 之前。
- [ ] 测试断言：未认证 WebSocket 握手被断开；已认证连接加入 `user:<id>` 房间，调用 `emitNotification` 后客户端收到 `notification:new`。

## 在开始改动之前
1. 读取 `shared-kernel-manifest.yaml` 的 `assembly_order` 全部 16 条。
2. 读取 `backend/src/app.ts`、`backend/src/main.ts` 当前内容。
3. 确认 `shared-kernel-api.md` 中 8 个装配符号均已由前序卡导出。

## 完成改动之后
1. 列出修改的文件与装配行。
2. 粘贴 assembly 测试输出、health/404/500 的 curl 输出。
3. 确认全部验证通过。
4. 列出剩余风险（业务路由尚未存在，自动发现用 ping 临时路由验证后删除）。
5. 写入 `docs/memory/2026-10-19/VIS-P0-I07.md`。
', '## 目标
在 `backend/src/app.ts` 按 16 步顺序完成全部中间件装配与路由自动发现，在 `backend/src/main.ts` 完成 HTTP Server 与 WebSocket 挂载，使任何单个中间件漏挂都能被验证发现。

承载需求：无（基础设施卡）；支撑全部端点按 16 步中间件序装配。

## 验收标准
- [ ] `createApp()` 返回的 app 依次装配 16 个步骤，顺序与 `shared-kernel-manifest.yaml` 的 `assembly_order` 逐条一致。
- [ ] `GET /api/v1/health` 在鉴权前返回 `code=0`。
- [ ] 任意 `modules/<ctx>/api/*.routes.ts` 无需手工注册即挂到 `/api/v1`。
- [ ] `main.ts` 在 `http.createServer(app)` 之后调用 `initRealtime(server, sessionMiddleware)`，再 `server.listen(PORT)`。
- [ ] 未匹配路由返回 JSON 404（不是 HTML）。
- [ ] 未捕获异常返回 JSON 500 + COPY-013（不是 HTML 堆栈）。

## 相关背景

### 必读文件
- `conventions.md` — 约定 2 中间件 16 步、约定 14 配置。
- `docs/trace/runs/v1/spac.md` §8.1 装配表、§8.2 路由发现、§8.4 实时事件。
- `shared-kernel-manifest.yaml` — `assembly_order` 与 `assembly` 块。
- `docs/knowledge/shared-kernel-api.md` — `createApp`、`mountRoutes`、`initRealtime` 签名。

### 共享内核 API（摘自 docs/knowledge/shared-kernel-api.md）
```ts
// backend/src/config.ts
export function loadConfig(): Config;
export const config: Config;
// backend/src/app.ts
export function createApp(): Express;
export function mountRoutes(app: Express): void;
// backend/src/shared/http/responseEnvelope.ts
export function responseEnvelope(req, res, next): void;
// backend/src/shared/auth/session.ts
export function sessionMiddleware(req, res, next): void;
// backend/src/shared/middleware/csrfProtection.ts
export function csrfProtection(req, res, next): void;
// backend/src/shared/middleware/rateLimiter.ts
export function apiRateLimiter(req, res, next): void;
// backend/src/shared/middleware/auditMiddleware.ts
export function auditMiddleware(req, res, next): void;
// backend/src/shared/http/notFoundHandler.ts
export function notFoundHandler(req, res, next): void;
// backend/src/shared/http/errorHandler.ts
export function errorHandler(err, req, res, next): void;
// backend/src/shared/jobs/scheduler.ts
export function startJobs(): void;
// backend/src/realtime/io.ts
export function initRealtime(server: http.Server, sessionMiddleware: RequestHandler): SocketServer;
```

### 模块模板（摘自 docs/knowledge/module-template.md）
- 组合根 `app.ts` 扫描 `modules/*/api/*.routes.ts`，统一挂到 `/api/v1`。
- `/api/v1` 字面量在 `app.ts` 只出现一次。

## 约束

### 命名约束
- 挂载点：`/api/v1`；WebSocket 路径 `/ws`。
- 路由文件必须 `export default router`。

### 其他约束
- [边界] 本卡不改任何业务 service；只做装配。
- [边界] `auditMiddleware` 只做请求级兜底，不注入 `req.audit`；业务审计由 service 调用 `writeAudit`。
- [依赖] `helmet`、`cors`、`compression`、`cookie-parser`、`express-session`、`socket.io`。
- [顺序] `responseEnvelope` 必须在路由前；`cookieParser`、`session`、`csrf` 相邻且顺序固定；health 在鉴权前；errorHandler 最后。

## 实施阶段
实现

## 任务

### 后端
1. 修改 `backend/src/app.ts` — 导出常量 `API_PREFIX = ''/api/v1''`，实现 `createApp()`，逐字写入以下装配行（顺序不可调换）：
```ts
app.set(''trust proxy'', 1);
app.use(helmet());
app.use(cors({ origin: config.CORS_ORIGIN, credentials: true }));
app.use(compression());
app.use(cookieParser(config.COOKIE_SECRET));
app.use(express.json({ limit: ''1mb'' }));
app.use(responseEnvelope);
app.use(sessionMiddleware);
app.use(csrfProtection);
app.use(apiRateLimiter);
app.get(`${API_PREFIX}/health`, (_req, res) => res.json({ code: 0, message: ''操作成功'', data: { status: ''ok'' } }));
mountRoutes(app);
app.use(auditMiddleware);
app.use(notFoundHandler);
app.use(errorHandler);
```
2. 修改 `backend/src/app.ts` — 实现 `mountRoutes(app)`：`fs.readdirSync(modulesDir)` 遍历上下文，扫描 `api/*.routes.ts`，`await import()` 后 `app.use(API_PREFIX, router)`；本文件 `''/api/v1''` 字面量只在常量声明处出现一次。
3. 修改 `backend/src/main.ts` — 启动序：`loadConfig() → getPool → runMigrations → createApp → http.createServer(app) → const io = initRealtime(server, sessionMiddleware) → server.listen(PORT) → ENABLE_JOBS === ''true'' && startJobs()`。
4. 修改 `backend/src/main.ts` — 注册 `SIGTERM`/`SIGINT`：`stopAllJobs()`、`io.close()`、`server.close()`、`pool.end()`。
5. 创建 `backend/src/__tests__/assembly.test.ts` — 断言 16 步顺序、health 可达、404 JSON、500 JSON、`initRealtime` 在 `listen` 前。
6. 确认 `backend/src/shared/jobs/scheduler.ts` 由共享内核卡提供 `registerJob`/`startJobs`；本卡不登记业务任务。

### 前端
7. 修改 `frontend/src/layouts/AppLayout.vue` — `onMounted` 时若 `useAuthStore().user` 存在则调用 `connectRealtime()`；`onUnmounted` 调用 `disconnectRealtime()`。
8. 修改 `frontend/src/App.vue` — 挂载路由视图与全局消息容器。

### 用户可见文案清单（本卡必含，逐字）
| 类别 | 触发场景 | 逐字文案 | 渲染位置 |
|------|---------|---------|---------|
| 健康检查成功 | `GET /api/v1/health` | 操作成功 | 响应 `message` |
| 404 | 未匹配路由 | 要查看的记录不存在或已被删除 | 响应 `message` |
| 500 | 未捕获异常 | 系统暂时无法处理，请稍后重试 | 响应 `message` |

## 验证
- [ ] `cd backend && npx vitest run src/__tests__/assembly.test.ts` → 全部通过。
- [ ] `curl -s http://localhost:3000/api/v1/health` → `code=0`。
- [ ] `curl -s http://localhost:3000/api/v1/no-such-path` → HTTP 404 且 `Content-Type: application/json`。
- [ ] 新建 `backend/src/modules/ping/api/ping.routes.ts` 导出 `router.get(''/ping'')` 后重启 → `GET /api/v1/ping` 返回 200，无需修改 `app.ts`。
- [ ] `grep -c "''/api/v1''" backend/src/app.ts` → 1。
- [ ] `grep -n "initRealtime" backend/src/main.ts` → 位于 `http.createServer` 之后、`listen` 之前。
- [ ] 测试断言：未认证 WebSocket 握手被断开；已认证连接加入 `user:<id>` 房间，调用 `emitNotification` 后客户端收到 `notification:new`。

## 在开始改动之前
1. 读取 `shared-kernel-manifest.yaml` 的 `assembly_order` 全部 16 条。
2. 读取 `backend/src/app.ts`、`backend/src/main.ts` 当前内容。
3. 确认 `shared-kernel-api.md` 中 8 个装配符号均已由前序卡导出。

## 完成改动之后
1. 列出修改的文件与装配行。
2. 粘贴 assembly 测试输出、health/404/500 的 curl 输出。
3. 确认全部验证通过。
4. 列出剩余风险（业务路由尚未存在，自动发现用 ping 临时路由验证后删除）。
5. 写入 `docs/memory/2026-10-19/VIS-P0-I07.md`。
', '6fb41cb9-db51-4196-a359-19f915a20e19', NULL, 'urgent', 70000, 7, 5, NULL, NULL, NULL, NULL, NULL, NULL, false, NULL, NULL, NULL, NULL);
INSERT INTO issues (id, created_at, updated_at, created_by_id, updated_by_id, project_id, workspace_id, name, description_json, description_html, description_stripped, state_id, parent_id, priority, sort_order, sequence_id, point, estimate_point_id, type_id, start_date, target_date, completed_at, archived_at, is_draft, external_source, external_id, description_binary, deleted_at) VALUES ('6b2ca529-2213-40a1-b85e-0c9e2a57ecdb', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', '[VIS-P0-I08] 种子锚点与执行器卡', '{}'::jsonb, '## 目标
提供跨六个上下文共用的可读锚点数据与手动执行器，使每张领域卡都能引用同一组真实业务值。

承载需求：无（基础设施卡）；为领域卡提供统一锚点数据。

## 验收标准
- [ ] `seed-anchors.sql` 在全新库上执行成功，无主键冲突。
- [ ] 4 个后台账号可登录：`admin`、`guard01`、`T001`、`T002`，密码均为 `abc@123`。
- [ ] 11 条预约覆盖 8 个状态；预约编号为 `AP` + 执行日 `YYYYMMDD` + `001`…`011`。
- [ ] 11 个 6 位短码 `100001`…`100011`，全局唯一。
- [ ] 22 条告知记录、3 条通行记录、3 条异常记录、3 条站内消息、1 条 200 天前审计。
- [ ] 连续执行两次 `npm run seed` 不报错（全部 INSERT 带 `ON CONFLICT DO NOTHING`）。

## 相关背景

### 必读文件
- `seed-anchors.sql` — 本卡产出的权威文件。
- `conventions.md` — 约定 8 数据库与种子、约定 9 测试与验证。
- `docs/trace/runs/v1/spac.md` §5.11 种子锚点。
- `docs/knowledge/phase-contracts/p0-contracts.md` 种子段。

### 共享内核 API（摘自 docs/knowledge/shared-kernel-api.md）
```ts
// shared/db/seed.ts
export function runSeeds(): Promise<number>; // 读取 db/seeds/*.sql 并顺序执行；本卡实现为执行 seed-anchors.sql
```

### 模块模板（摘自 docs/knowledge/module-template.md）
- 种子目录 `backend/db/seeds/`；手动执行；按外键拓扑排序。

### 种子数据来源（摘自 seed-anchors.sql）
- 角色：`admin`、`guard`、`host`、`visitor`。
- 账号：`admin`（系统管理员）、`guard01`（门卫张师傅）、`T001`（李明，教务处）、`T002`（王芳，学生处）。
- 教职工：H1 李明 `33333333-3333-4333-8333-333333333333`、H2 王芳 `44444444-4444-4444-8444-444444444444`。
- 访客类型：家长 `55555555-5555-4555-8555-555555555551`、外来人员 `55555555-5555-4555-8555-555555555552`、公务来访 `55555555-5555-4555-8555-555555555553`。
- 校门：东门 `66666666-6666-4666-8666-666666666661`、南门 `66666666-6666-4666-8666-666666666662`。
- 黑名单：赵某某 `320101198803034566`，有效期至 2027-12-31。
- 时段规则：周一至周日 07:00–18:00 可预约，`77777777-7777-4777-8777-777777777711` 至 `77777777-7777-4777-8777-777777777717`。
- 预约 P1–P11：陈晨（待审核）、刘洋（已通过）、周敏（待审核，审核人 H1）、孙浩（已到访(在校中)）、吴倩（已离校）、陈晨（已改期）、郑凯（已拒绝）、冯雪（已过期）、蒋涛（已取消）、韩梅（待审核，`black_hit=true`）、杨帆（已通过）。
- 字典：随行关系（家属/同事/朋友/其他）、证件类型（身份证/其他证件）。

## 约束

### 命名约束
- 种子 UUID 使用固定字面量，格式为合法 UUID v4。
- 所有 INSERT 显式列出列名；枚举值用中文。

### 其他约束
- [边界] 种子只放 INSERT；禁止 DDL。
- [边界] 种子手动执行，不挂到应用启动。
- [依赖] `tsx`、`pg`。
- [幂等] 每条 INSERT 带 `ON CONFLICT DO NOTHING`。

## 实施阶段
实现

## 任务

### 后端
1. 确认 `seed-anchors.sql` 位于项目根（已有文件，逐字使用；如需修正只改本文件）。
2. 复制为 `backend/db/seeds/00-anchors.sql` — 内容与根文件逐字一致；根文件中的 `CURRENT_DATE` 即执行日 D0。
3. 创建 `backend/src/shared/db/seed.ts` — `runSeeds()` 读取 `backend/db/seeds/*.sql` 按文件名排序执行，每个文件一个事务，打印「种子执行完成，共 {n} 个文件」。
4. 在 `backend/package.json` 增加 `"seed": "tsx src/shared/db/seed.ts"`。
5. 创建 `backend/src/shared/__tests__/seed.test.ts` — 断言 4 个账号、11 条预约、8 个状态、11 个短码、22 条告知。

### 用户可见文案清单（本卡必含，逐字）
| 类别 | 触发场景 | 逐字文案 | 渲染位置 |
|------|---------|---------|---------|
| 种子成功 | 执行完成 | 种子执行完成，共 {n} 个文件 | stdout |
| 种子失败 | 任一文件失败 | 种子执行失败：{文件名} | stderr |

## 验证
- [ ] `diff seed-anchors.sql backend/db/seeds/00-anchors.sql` → 无差异。
- [ ] `docker compose exec backend npm run seed` → 退出码 0。
- [ ] `docker compose exec -T db psql -U visitor -d visitor_system -c "select count(*) from users"` → `4`。
- [ ] `docker compose exec -T db psql -U visitor -d visitor_system -c "select status, count(*) from appointments group by status order by status"` → 8 行，合计 11。
- [ ] `docker compose exec -T db psql -U visitor -d visitor_system -c "select count(distinct short_code) from visit_credentials"` → `11`。
- [ ] `docker compose exec -T db psql -U visitor -d visitor_system -c "select count(*) from consent_records"` → `22`。
- [ ] 再次执行 `npm run seed` → 退出码 0，各表计数不变。

## 在开始改动之前
1. 读取 `seed-anchors.sql` 全文。
2. 读取 `spac.md` §5.11 与 `p0-contracts.md` 种子段。
3. 确认 `users.password_hash` 使用 `crypt(''abc@123'', gen_salt(''bf'', 10))`，且 `pgcrypto` 已启用。

## 完成改动之后
1. 列出创建/修改的文件。
2. 粘贴两次 seed 的输出与各表计数。
3. 确认全部验证通过。
4. 列出剩余风险（种子数据的业务可读性由各领域卡在页面验证）。
5. 写入 `docs/memory/2026-10-19/VIS-P0-I08.md`。
', '## 目标
提供跨六个上下文共用的可读锚点数据与手动执行器，使每张领域卡都能引用同一组真实业务值。

承载需求：无（基础设施卡）；为领域卡提供统一锚点数据。

## 验收标准
- [ ] `seed-anchors.sql` 在全新库上执行成功，无主键冲突。
- [ ] 4 个后台账号可登录：`admin`、`guard01`、`T001`、`T002`，密码均为 `abc@123`。
- [ ] 11 条预约覆盖 8 个状态；预约编号为 `AP` + 执行日 `YYYYMMDD` + `001`…`011`。
- [ ] 11 个 6 位短码 `100001`…`100011`，全局唯一。
- [ ] 22 条告知记录、3 条通行记录、3 条异常记录、3 条站内消息、1 条 200 天前审计。
- [ ] 连续执行两次 `npm run seed` 不报错（全部 INSERT 带 `ON CONFLICT DO NOTHING`）。

## 相关背景

### 必读文件
- `seed-anchors.sql` — 本卡产出的权威文件。
- `conventions.md` — 约定 8 数据库与种子、约定 9 测试与验证。
- `docs/trace/runs/v1/spac.md` §5.11 种子锚点。
- `docs/knowledge/phase-contracts/p0-contracts.md` 种子段。

### 共享内核 API（摘自 docs/knowledge/shared-kernel-api.md）
```ts
// shared/db/seed.ts
export function runSeeds(): Promise<number>; // 读取 db/seeds/*.sql 并顺序执行；本卡实现为执行 seed-anchors.sql
```

### 模块模板（摘自 docs/knowledge/module-template.md）
- 种子目录 `backend/db/seeds/`；手动执行；按外键拓扑排序。

### 种子数据来源（摘自 seed-anchors.sql）
- 角色：`admin`、`guard`、`host`、`visitor`。
- 账号：`admin`（系统管理员）、`guard01`（门卫张师傅）、`T001`（李明，教务处）、`T002`（王芳，学生处）。
- 教职工：H1 李明 `33333333-3333-4333-8333-333333333333`、H2 王芳 `44444444-4444-4444-8444-444444444444`。
- 访客类型：家长 `55555555-5555-4555-8555-555555555551`、外来人员 `55555555-5555-4555-8555-555555555552`、公务来访 `55555555-5555-4555-8555-555555555553`。
- 校门：东门 `66666666-6666-4666-8666-666666666661`、南门 `66666666-6666-4666-8666-666666666662`。
- 黑名单：赵某某 `320101198803034566`，有效期至 2027-12-31。
- 时段规则：周一至周日 07:00–18:00 可预约，`77777777-7777-4777-8777-777777777711` 至 `77777777-7777-4777-8777-777777777717`。
- 预约 P1–P11：陈晨（待审核）、刘洋（已通过）、周敏（待审核，审核人 H1）、孙浩（已到访(在校中)）、吴倩（已离校）、陈晨（已改期）、郑凯（已拒绝）、冯雪（已过期）、蒋涛（已取消）、韩梅（待审核，`black_hit=true`）、杨帆（已通过）。
- 字典：随行关系（家属/同事/朋友/其他）、证件类型（身份证/其他证件）。

## 约束

### 命名约束
- 种子 UUID 使用固定字面量，格式为合法 UUID v4。
- 所有 INSERT 显式列出列名；枚举值用中文。

### 其他约束
- [边界] 种子只放 INSERT；禁止 DDL。
- [边界] 种子手动执行，不挂到应用启动。
- [依赖] `tsx`、`pg`。
- [幂等] 每条 INSERT 带 `ON CONFLICT DO NOTHING`。

## 实施阶段
实现

## 任务

### 后端
1. 确认 `seed-anchors.sql` 位于项目根（已有文件，逐字使用；如需修正只改本文件）。
2. 复制为 `backend/db/seeds/00-anchors.sql` — 内容与根文件逐字一致；根文件中的 `CURRENT_DATE` 即执行日 D0。
3. 创建 `backend/src/shared/db/seed.ts` — `runSeeds()` 读取 `backend/db/seeds/*.sql` 按文件名排序执行，每个文件一个事务，打印「种子执行完成，共 {n} 个文件」。
4. 在 `backend/package.json` 增加 `"seed": "tsx src/shared/db/seed.ts"`。
5. 创建 `backend/src/shared/__tests__/seed.test.ts` — 断言 4 个账号、11 条预约、8 个状态、11 个短码、22 条告知。

### 用户可见文案清单（本卡必含，逐字）
| 类别 | 触发场景 | 逐字文案 | 渲染位置 |
|------|---------|---------|---------|
| 种子成功 | 执行完成 | 种子执行完成，共 {n} 个文件 | stdout |
| 种子失败 | 任一文件失败 | 种子执行失败：{文件名} | stderr |

## 验证
- [ ] `diff seed-anchors.sql backend/db/seeds/00-anchors.sql` → 无差异。
- [ ] `docker compose exec backend npm run seed` → 退出码 0。
- [ ] `docker compose exec -T db psql -U visitor -d visitor_system -c "select count(*) from users"` → `4`。
- [ ] `docker compose exec -T db psql -U visitor -d visitor_system -c "select status, count(*) from appointments group by status order by status"` → 8 行，合计 11。
- [ ] `docker compose exec -T db psql -U visitor -d visitor_system -c "select count(distinct short_code) from visit_credentials"` → `11`。
- [ ] `docker compose exec -T db psql -U visitor -d visitor_system -c "select count(*) from consent_records"` → `22`。
- [ ] 再次执行 `npm run seed` → 退出码 0，各表计数不变。

## 在开始改动之前
1. 读取 `seed-anchors.sql` 全文。
2. 读取 `spac.md` §5.11 与 `p0-contracts.md` 种子段。
3. 确认 `users.password_hash` 使用 `crypt(''abc@123'', gen_salt(''bf'', 10))`，且 `pgcrypto` 已启用。

## 完成改动之后
1. 列出创建/修改的文件。
2. 粘贴两次 seed 的输出与各表计数。
3. 确认全部验证通过。
4. 列出剩余风险（种子数据的业务可读性由各领域卡在页面验证）。
5. 写入 `docs/memory/2026-10-19/VIS-P0-I08.md`。
', '6fb41cb9-db51-4196-a359-19f915a20e19', NULL, 'high', 80000, 8, 5, NULL, NULL, NULL, NULL, NULL, NULL, false, NULL, NULL, NULL, NULL);
INSERT INTO issues (id, created_at, updated_at, created_by_id, updated_by_id, project_id, workspace_id, name, description_json, description_html, description_stripped, state_id, parent_id, priority, sort_order, sequence_id, point, estimate_point_id, type_id, start_date, target_date, completed_at, archived_at, is_draft, external_source, external_id, description_binary, deleted_at) VALUES ('f1a4b811-bec8-4d4d-bf28-cccf59d3528c', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', '[VIS-P0-I09] 契约冻结卡', '{}'::jsonb, '## 目标
冻结 `contracts/` 七件套与各 Phase 契约摘要，使全部卡片只消费、不改写契约。

承载需求：无（基础设施卡）；冻结全部 REQ 对应的端点与数据契约。

## 验收标准
- [ ] `contracts/openapi.yaml`、`schema.sql`、`events.yaml`、`naming.yaml`、`routes.yaml`、`symbols.yaml`、`cross-context-writes.md` 七件存在。
- [ ] `openapi.yaml` 覆盖 `spac.md` §6 全部端点，方法、路径、权限与响应 shape 逐条一致。
- [ ] `schema.sql` 与五个迁移文件的 DDL 等价。
- [ ] `symbols.yaml` 覆盖 `shared-kernel-manifest.yaml` 全部导出，并登记六个上下文门面的计划签名（取自 `p1-contracts.md`）；实际导出的逐条比对由 `VIS-P2-I03` 执行。
- [ ] `naming.yaml` 覆盖表名、列名、权限点、COPY 编号。
- [ ] `routes.yaml` 覆盖 §4 全部路由与导航。
- [ ] `events.yaml` 记录 `notification:new` 的生产与消费点。
- [ ] `cross-context-writes.md` 记录全部门面写入与只读 SQL。

## 相关背景

### 必读文件
- `docs/trace/runs/v1/spac.md` §4、§5、§6、§8.4。
- `shared-kernel-manifest.yaml`、`roles.md`、`conventions.md`。
- `docs/knowledge/phase-contracts/p0-contracts.md`、`p1-contracts.md`、`p2-contracts.md`。

### 共享内核 API（摘自 docs/knowledge/shared-kernel-api.md）
- 本卡不新增符号；`symbols.yaml` 逐条登记已有符号。

## 约束

### 命名约束
- OpenAPI 的 JSON 键一律 snake_case；路径以 `/api/v1` 为前缀。
- 事件名 `notification:new`；房间 `user:<id>`。

### 其他约束
- [边界] 本卡只写 `contracts/` 与 Phase 契约校验；不改源码。
- [契约变更请求] 任一卡发现契约缺口时，在本卡登记变更请求，禁止私改。

## 实施阶段
实现

## 任务

### 契约
1. 创建 `contracts/openapi.yaml` — OpenAPI 3.0.3，覆盖 §6 全部端点。
2. 创建 `contracts/schema.sql` — 汇总五个迁移文件 DDL。
3. 创建 `contracts/events.yaml` — `notification:new` 生产/消费/载荷。
4. 创建 `contracts/naming.yaml` — 表、列、权限点、COPY 编号。
5. 创建 `contracts/routes.yaml` — 路由、布局、角色、导航顺序。
6. 创建 `contracts/symbols.yaml` — 共享内核导出与本卡已存在的符号逐条登记；六个上下文门面登记 `p1-contracts.md` 的计划签名，字段标记 `status: planned`。
7. 创建 `contracts/cross-context-writes.md` — 门面写入矩阵与只读 SQL 清单。
8. 创建 `docs/trace/runs/v1/contract-freeze-report.md` — 逐项比对结果与差异 0 的记录。

### 用户可见文案清单（本卡必含，逐字）
| 类别 | 触发场景 | 逐字文案 | 渲染位置 |
|------|---------|---------|---------|
| 冻结完成 | 报告标题 | 契约冻结完成 | 报告标题 |

## 验证
- [ ] `ls contracts/{openapi.yaml,schema.sql,events.yaml,naming.yaml,routes.yaml,symbols.yaml,cross-context-writes.md}` → 7 个文件全部存在。
- [ ] `npx @redocly/cli lint contracts/openapi.yaml` → 0 error。
- [ ] `grep -c "^  /" contracts/openapi.yaml` → 与 §6 端点数一致。
- [ ] `grep -n "notification:new" contracts/events.yaml` → 生产点与消费点各 1 条。
- [ ] `diff <(grep -h "CREATE TABLE" backend/db/migrations/*.sql | sort) <(grep "CREATE TABLE" contracts/schema.sql | sort)` → 无差异。

## 在开始改动之前
1. 读取 `spac.md` §4/§5/§6。
2. 读取 `shared-kernel-manifest.yaml` 与 `roles.md`。
3. 确认 `backend/db/migrations/` 五个文件已存在。

## 完成改动之后
1. 列出七个契约文件与冻结报告。
2. 粘贴 lint 与 diff 输出。
3. 确认全部验证通过。
4. 列出剩余风险（OpenAPI 示例未覆盖的边界响应由集成闭环卡补充）。
5. 写入 `docs/memory/2026-10-19/VIS-P0-I09.md`。
', '## 目标
冻结 `contracts/` 七件套与各 Phase 契约摘要，使全部卡片只消费、不改写契约。

承载需求：无（基础设施卡）；冻结全部 REQ 对应的端点与数据契约。

## 验收标准
- [ ] `contracts/openapi.yaml`、`schema.sql`、`events.yaml`、`naming.yaml`、`routes.yaml`、`symbols.yaml`、`cross-context-writes.md` 七件存在。
- [ ] `openapi.yaml` 覆盖 `spac.md` §6 全部端点，方法、路径、权限与响应 shape 逐条一致。
- [ ] `schema.sql` 与五个迁移文件的 DDL 等价。
- [ ] `symbols.yaml` 覆盖 `shared-kernel-manifest.yaml` 全部导出，并登记六个上下文门面的计划签名（取自 `p1-contracts.md`）；实际导出的逐条比对由 `VIS-P2-I03` 执行。
- [ ] `naming.yaml` 覆盖表名、列名、权限点、COPY 编号。
- [ ] `routes.yaml` 覆盖 §4 全部路由与导航。
- [ ] `events.yaml` 记录 `notification:new` 的生产与消费点。
- [ ] `cross-context-writes.md` 记录全部门面写入与只读 SQL。

## 相关背景

### 必读文件
- `docs/trace/runs/v1/spac.md` §4、§5、§6、§8.4。
- `shared-kernel-manifest.yaml`、`roles.md`、`conventions.md`。
- `docs/knowledge/phase-contracts/p0-contracts.md`、`p1-contracts.md`、`p2-contracts.md`。

### 共享内核 API（摘自 docs/knowledge/shared-kernel-api.md）
- 本卡不新增符号；`symbols.yaml` 逐条登记已有符号。

## 约束

### 命名约束
- OpenAPI 的 JSON 键一律 snake_case；路径以 `/api/v1` 为前缀。
- 事件名 `notification:new`；房间 `user:<id>`。

### 其他约束
- [边界] 本卡只写 `contracts/` 与 Phase 契约校验；不改源码。
- [契约变更请求] 任一卡发现契约缺口时，在本卡登记变更请求，禁止私改。

## 实施阶段
实现

## 任务

### 契约
1. 创建 `contracts/openapi.yaml` — OpenAPI 3.0.3，覆盖 §6 全部端点。
2. 创建 `contracts/schema.sql` — 汇总五个迁移文件 DDL。
3. 创建 `contracts/events.yaml` — `notification:new` 生产/消费/载荷。
4. 创建 `contracts/naming.yaml` — 表、列、权限点、COPY 编号。
5. 创建 `contracts/routes.yaml` — 路由、布局、角色、导航顺序。
6. 创建 `contracts/symbols.yaml` — 共享内核导出与本卡已存在的符号逐条登记；六个上下文门面登记 `p1-contracts.md` 的计划签名，字段标记 `status: planned`。
7. 创建 `contracts/cross-context-writes.md` — 门面写入矩阵与只读 SQL 清单。
8. 创建 `docs/trace/runs/v1/contract-freeze-report.md` — 逐项比对结果与差异 0 的记录。

### 用户可见文案清单（本卡必含，逐字）
| 类别 | 触发场景 | 逐字文案 | 渲染位置 |
|------|---------|---------|---------|
| 冻结完成 | 报告标题 | 契约冻结完成 | 报告标题 |

## 验证
- [ ] `ls contracts/{openapi.yaml,schema.sql,events.yaml,naming.yaml,routes.yaml,symbols.yaml,cross-context-writes.md}` → 7 个文件全部存在。
- [ ] `npx @redocly/cli lint contracts/openapi.yaml` → 0 error。
- [ ] `grep -c "^  /" contracts/openapi.yaml` → 与 §6 端点数一致。
- [ ] `grep -n "notification:new" contracts/events.yaml` → 生产点与消费点各 1 条。
- [ ] `diff <(grep -h "CREATE TABLE" backend/db/migrations/*.sql | sort) <(grep "CREATE TABLE" contracts/schema.sql | sort)` → 无差异。

## 在开始改动之前
1. 读取 `spac.md` §4/§5/§6。
2. 读取 `shared-kernel-manifest.yaml` 与 `roles.md`。
3. 确认 `backend/db/migrations/` 五个文件已存在。

## 完成改动之后
1. 列出七个契约文件与冻结报告。
2. 粘贴 lint 与 diff 输出。
3. 确认全部验证通过。
4. 列出剩余风险（OpenAPI 示例未覆盖的边界响应由集成闭环卡补充）。
5. 写入 `docs/memory/2026-10-19/VIS-P0-I09.md`。
', '6fb41cb9-db51-4196-a359-19f915a20e19', NULL, 'high', 90000, 9, 5, NULL, NULL, NULL, NULL, NULL, NULL, false, NULL, NULL, NULL, NULL);
INSERT INTO issues (id, created_at, updated_at, created_by_id, updated_by_id, project_id, workspace_id, name, description_json, description_html, description_stripped, state_id, parent_id, priority, sort_order, sequence_id, point, estimate_point_id, type_id, start_date, target_date, completed_at, archived_at, is_draft, external_source, external_id, description_binary, deleted_at) VALUES ('d11aab0b-8e8c-4f5e-a656-e320405b9684', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', '[VIS-P1-I01] master 主数据全栈卡', '{}'::jsonb, '## 目标
交付访客类型、黑名单、时段规则、校门、教职工名册、系统参数与数据字典的维护界面与服务端能力，并让预约、核验、台账消费同一份主数据。

承载需求：REQ-BD-001、REQ-BD-002、REQ-BD-003、REQ-BD-004、REQ-BD-005、REQ-SM-003、REQ-SM-004；支撑 REQ-AT-003 的审核人规则主数据。

## 验收标准
- [ ] `/master` 页面五个分区可查看、新增、改名、停用、启用；删除入口返回 405 COPY-009。
- [ ] `/system/settings` 页面可修改系统参数与数据字典；保存后下一次读取立即生效。
- [ ] 黑名单支持新增、软删除、到期自动失效；删除后历史异常保留。
- [ ] 时段规则支持按星期与起止时间维护；删除即失效；禁入优先于可预约。
- [ ] 访客类型停用后退出新增下拉，但仍在台账检索筛选中。
- [ ] 13 条 TC 的逐条比对表填写完成。

## 相关背景

### 必读文件
- `conventions.md` — 约定 6 命名、约定 9 测试与验证、约定 10 前端交互与视觉、约定 12 文案。
- `docs/trace/runs/v1/spac.md` §4 路由、§4.2.10 主数据、§4.2.12 参数与字典、§5.3 主数据表、§6.4 主数据端点、§11 S-35。
- `docs/knowledge/shared-kernel-api.md` — 前端共享组件、Store 与请求封装签名。
- `docs/knowledge/phase-contracts/p1-contracts.md` §二。
- `roles.md` — adminOnly `/master/*`、`/system/*`。
- `seed-anchors.sql` — 主数据锚点。
- `output/v1.0/测试.md` 第十一、十三节；`output/v1.0/测试结果.md` 对应行。

### 共享内核 API（摘自 docs/knowledge/shared-kernel-api.md）
```ts
import { requireAuth } from ''../../../shared/middleware/requireAuth'';
import { requirePermission, requireAdmin } from ''../../../shared/middleware/requirePermission'';
import { success, paginated } from ''../../../shared/http/envelope'';
import { parsePagination } from ''../../../shared/http/pagination'';
import { asyncHandler } from ''../../../shared/http/asyncHandler'';
import { badRequest, conflict, methodNotAllowed, unprocessable } from ''../../../shared/http/errors'';
import { writeAudit } from ''../../../shared/audit/writeAudit'';
import { getConfig, setConfig } from ''../../../shared/config/configService'';
import { validateBody } from ''../../../shared/validation/validators'';
```

### 模块模板（摘自 docs/knowledge/module-template.md）
- `backend/src/modules/master/{index.ts,api/*.routes.ts,internal/*.service.ts,internal/*.repo.ts,internal/domain/rules.ts,__tests__/}`。
- `frontend/src/views/master/{MasterDataPage.vue,SystemSettingsPage.vue,routes.ts,permissions.ts}`。

### 上游契约（摘自 docs/knowledge/phase-contracts/p0-contracts.md）
- `system_config(config_key, config_value, value_type, description, updated_at)`。
- `operation_logs` 最小字段。

### 本域设计（摘自架构设计文档 §5.3、§6.4）
- 表：`hosts`、`visitor_types`、`gates`、`blacklist_entries`、`time_rules`、`reviewer_rules`、`data_dictionary`。
- 端点：`/master/visitor-types`、`/master/blacklist`、`/master/time-rules`、`/master/gates`、`/master/hosts`、`/system/params`、`/system/dictionary`。
- 门面：`getActiveVisitorTypes`、`getActiveHosts`、`getActiveGates`、`getDictionaryItems`、`getConfig`、`getConfigNumber`、`resolveReviewer`、`upsertReviewerRules`、`checkBlacklist`、`expireBlacklistEntries`。
- 软状态统一 `active`/`inactive`，界面显示「在用/停用」。
- 有效黑名单判定：`status=''有效''` 且 `expire_at >= now`。

## 约束

### 命名约束
- 权限点：`master:visitor_type:read|create|update|status`、`master:blacklist:*`、`master:time_rule:*`、`master:gate:*`、`master:host:*`、`system:param:*`、`system:dictionary:*`。
- 前端字段 camelCase（`employeeNo`、`dictType`），API 键 snake_case（`employee_no`、`dict_type`）。
- 状态值 `active`/`inactive`，展示「在用/停用」。

### 其他约束
- [边界] 只写 master 上下文与 `views/master`；预约与核验逻辑在 visit 卡。
- [边界] 跨上下文只通过 `master/index.ts` 门面导出。
- [依赖] `qrcode` 不在本卡；二维码在 access 卡。
- [校验] 名称 1–30 字；工号 1–30 字且唯一；原因 1–200 字；有效期必须晚于当前时间。

## 实施阶段
实现

## 任务

### 后端
1. 创建 `backend/src/modules/master/api/visitor-types.routes.ts` — GET 列表、POST 新增、PUT `/:id` 改名、PUT `/:id/status`、DELETE 返回 405 COPY-009。
2. 创建 `backend/src/modules/master/api/blacklist.routes.ts` — GET 分页、POST 新增、DELETE `/:id` 软删除。
3. 创建 `backend/src/modules/master/api/time-rules.routes.ts` — GET 列表、POST 新增、DELETE `/:id` 删除即失效。
4. 创建 `backend/src/modules/master/api/gates.routes.ts` — GET 列表、POST 新增、PUT `/:id`、PUT `/:id/status`、DELETE 405。
5. 创建 `backend/src/modules/master/api/hosts.routes.ts` — GET 列表、POST 新增、PUT `/:id`、PUT `/:id/status`、DELETE 405。
6. 创建 `backend/src/modules/master/api/params.routes.ts` — GET `/system/params`、PUT `/system/params/:key`。
7. 创建 `backend/src/modules/master/api/dictionary.routes.ts` — GET、POST、PUT `/:id/status`。
8. 创建 `backend/src/modules/master/internal/*.service.ts` 与 `*.repo.ts` — 七个主数据资源的读写与软状态，以及 `reviewer_rules` 审核人规则的整表替换写入；写操作在事务内调用 `writeAudit`，动作词取 `新增主数据`、`修改主数据`、`停用主数据`、`删除黑名单`、`删除时段规则`、`修改参数`、`修改字典`。
9. 创建 `backend/src/modules/master/internal/domain/rules.ts` — 时段规则判定：禁入优先；可预约闭区间；`start < end`。
10. 创建 `backend/src/modules/master/index.ts` — 导出 DTO 与 10 个门面函数；`getConfig`/`getConfigNumber` 仅转调共享内核 `configService`，不重复实现；含 `upsertReviewerRules(rules)` 供 visit 卡写审核人规则。
11. 创建 `backend/src/modules/master/__tests__/time-rules.rules.test.ts` 与 `blacklist.rules.test.ts`。
12. 创建定时任务 `blacklist-expire`（cron `10 0 * * *`）调用 `expireBlacklistEntries`，并在 `index.ts` 调用 `registerJob({ name:''blacklist-expire'', cron:''10 0 * * *'', runOnStart:false, handler })` 登记。

### 前端
13. 创建 `frontend/src/views/master/MasterDataPage.vue` — 五个分区（访客类型、黑名单、时段规则、校门、教职工名册）；每个分区完整渲染四态：加载中 `LoadingState`、加载失败 `ErrorState`（COPY-355，emit `retry` 重新取数）、空数据 `EmptyState`（COPY-272）、有数据 `a-table`。操作列固定右侧；名称列单行省略并 `a-tooltip` 全文；图标按钮带 `aria-label` 与 `a-tooltip`，可点击区不小于 32×32px；黑名单分区使用服务端分页（默认 20，上限 100）。
14. 创建 `frontend/src/views/master/SystemSettingsPage.vue` — 系统参数与数据字典两个分区；四态同 task 13；保存按钮在请求期间 `loading` 并禁用，防重复提交。
15. 创建 `frontend/src/views/master/routes.ts` — `/master`、`/system/settings`，`meta.roles: [''admin'']`。
16. 创建 `frontend/src/views/master/permissions.ts` — 权限点常量。
17. 所有写操作成功后刷新对应分区并 `message.success` Toast；停用与启用、删除统一走 `ConfirmDialog`：停用标题 COPY-381、正文 COPY-382、成功 COPY-383；启用成功 COPY-384；黑名单删除 COPY-257/COPY-258、成功 COPY-259；时段规则删除 COPY-267/COPY-268、成功 COPY-259；参数保存 COPY-292；字典新增 COPY-293；不得调用原生 `alert(` / `confirm(`。删除受限的三个分区（访客类型、校门、教职工）点击删除按钮直接 Toast COPY-009，不弹确认框。

### 用户可见文案清单（本卡必含，逐字）
| 类别 | 触发场景 | COPY | 逐字文案 | 渲染位置 |
|------|---------|------|---------|---------|
| 页面标题 | 打开主数据 | COPY-242 | 主数据 | PageHeader |
| 设置页标题 | 打开参数与字典 | COPY-289 | 参数与字典 | PageHeader |
| 设置分区标题 | 两个分区 | COPY-290 / COPY-291 | 系统参数、数据字典 | 分区标题 |
| 分区标题 | 五个分区 | — | 访客类型、黑名单、时段规则、校门与通行点、教职工名册 | 分区标题 |
| 删除受限 | 点击删除访客类型/校门/教职工 | COPY-009 | 该数据不支持删除，请使用停用功能 | Toast |
| 停用确认标题 | 点击停用 | COPY-381 | 确认停用 | ConfirmDialog title |
| 停用确认正文 | 同上 | COPY-382 | 停用后该数据不再出现在新增下拉中，历史记录保留。可再次启用。是否继续？ | ConfirmDialog content |
| 停用成功 | 停用完成 | COPY-383 | 已停用 | Toast |
| 启用成功 | 启用完成 | COPY-384 | 已启用 | Toast |
| 删除黑名单标题 | 点击删除黑名单条目 | COPY-257 | 确认删除黑名单条目 | ConfirmDialog title |
| 删除黑名单正文 | 同上 | COPY-258 | 删除后该证件号不再被拦截，历史异常记录保留。是否继续？ | ConfirmDialog content |
| 删除成功 | 黑名单/时段规则删除完成 | COPY-259 | 已删除 | Toast |
| 删除规则标题 | 点击删除时段规则 | COPY-267 | 确认删除时段规则 | ConfirmDialog title |
| 删除规则正文 | 同上 | COPY-268 | 删除后该规则立即失效，不可恢复。是否继续？ | ConfirmDialog content |
| 保存成功 | 参数/字典保存 | COPY-273 | 保存成功 | Toast |
| 参数保存成功 | 修改系统参数 | COPY-292 | 参数已保存，立即生效 | Toast |
| 字典新增成功 | 新增字典项 | COPY-293 | 字典项已新增 | Toast |
| 空态 | 任一分区无数据 | COPY-272 | 暂无数据 | EmptyState |
| 加载中... | 任一列表首次取数 | COPY-357 | 加载中... | LoadingState |
| 加载失败 | 任一列表取数失败 | COPY-355 | 数据加载失败，请点击重试 | ErrorState |
| 重试按钮 | 加载失败态 | COPY-356 | 重试 | ErrorState 按钮 |
| 必填校验 | 名称为空 | — | 请输入名称 | 字段下方 |
| 工号重复 | 新增重复工号 | — | 该工号已存在，请更换 | 字段下方 |
| 黑名单有效期 | 到期时间早于当前 | — | 有效期必须晚于当前时间 | 字段下方 |

### UI 完整性检验结论（2026-10-19）
- 检验范围：`/master` 与 `/system/settings` 共 7 个分区。
- 通过项：每分区四态；文案 COPY-255…293、381…384；停用/启用/删除统一 `ConfirmDialog`；黑名单服务端分页默认 20、上限 100；名称列省略 + tooltip；1024px 无整页横向滚动。
- 对应缺陷：U1、U2、U4。

## 验证
- [ ] `cd backend && npx vitest run src/modules/master/__tests__` → 全部通过。
- [ ] `curl -b admin.txt -X DELETE -H "X-CSRF-Token: $(curl -s -b admin.txt http://localhost:3000/api/v1/auth/csrf | jq -r .data.csrf_token)" http://localhost:3000/api/v1/master/gates/66666666-6666-4666-8666-666666666661` → 405 + COPY-009。
- [ ] `curl -b admin.txt -X PUT -H "X-CSRF-Token: $(curl -s -b admin.txt http://localhost:3000/api/v1/auth/csrf | jq -r .data.csrf_token)" -d ''{"status":"inactive"}'' http://localhost:3000/api/v1/master/visitor-types/55555555-5555-4555-8555-555555555551/status` → 200；随后 `curl -b admin.txt http://localhost:3000/api/v1/master/visitor-types | jq -r ''.data.items[] | select(.status=="active") | .name''` → 不含「家长」。
- [ ] `docker compose exec -T db psql -U visitor -d visitor_system -c "select count(*) from appointments where visitor_type_id=''55555555-5555-4555-8555-555555555551''"` → `3`，停用不改写历史预约的访客类型。
- [ ] 浏览器打开 `/master` → 五个分区渲染 seed 数据：家长、外来人员、公务来访、东门、南门、李明、王芳、赵某某、7 条时段规则。
- [ ] 打开 `/system/settings` → 修改 `entry_url` 保存后 `docker compose exec -T db psql -U visitor -d visitor_system -c "select config_value from system_config where config_key=''entry_url''"` → 新值；入口二维码读取该值的联动由 access 卡验证。
- [ ] 文案目视：停用、删除、保存三类操作逐字匹配上表。
- [ ] 断网验证：`docker compose stop backend` 后打开 `/master`，每个分区显示 COPY-355 与 COPY-356 重试按钮；恢复后端并点击重试后回到数据态。
- [ ] 空态验证：清空某一分区数据后该分区显示 COPY-272，其他分区不受影响。
- [ ] `grep -Rn "alert(\|confirm(" frontend/src/views/master` 无输出；图标按钮均含非空 `aria-label`。
- [ ] 浏览器宽度 1024px 时内容区不出现整页横向滚动条，宽表格在自身容器内横向滚动。

### 测试用例与结果比对
> 本卡独立执行时只能断言 master 侧。结论为「跨卡验收」的条目依赖 `VIS-P1-I05` 或 `VIS-P1-I04` 的消费点，由 `VIS-P2-I01` 执行；本卡只验证其数据与门面已就绪。
| TC | 测试点 | 已定预期（摘自 output/v1.0/测试.md） | 本次实际运行结果（未执行） | 比对结论 |
|----|--------|--------------------------------------|----------------------------|----------|
| TC-BD-001 | 访客类型软状态停用、历史保留分类 | 停用后新增下拉不含；台账检索仍含；历史显示原分类 | 未执行；落点：`PUT /master/visitor-types/:id/status` + `GET /appointments/form-options` 过滤 `active` + `MasterDataPage.vue` | 跨卡验收（visit 表单与台账） |
| TC-BD-002 | 黑名单两段处置、无 override | 提交软提示 `black_hit=1`；门卫硬拦；无临时放行 | 未执行；落点：`checkBlacklist` 门面 + `POST /visitor/appointments` 软提示 + `POST /gate/verify` 硬拦（visit 卡消费） | 跨卡验收（visit） |
| TC-BD-003 | 黑名单命中联动 | 通知门卫+管理员；异常记录；审计 | 未执行；落点：`publishSecurityNotification` + `POST /gate/incidents` + `writeAudit`（visit 卡消费） | 跨卡验收（visit、notify） |
| TC-BD-004 | 黑名单生命周期 | 手工删除留痕；到期自动失效不再命中 | 未执行；落点：`DELETE /master/blacklist/:id` + `blacklist-expire` 任务 + `expireBlacklistEntries` | 设计可达 |
| TC-BD-005 | 时段规则默认可配 | 07:00–18:00；缓冲 15min；上限 240min | 未执行；落点：`seed-anchors.sql` 7 条可预约规则 + `system_config` 的 `verification_buffer_minutes=15`、`max_stay_minutes=240` | 设计可达 |
| TC-BD-006 | 时段规则生效双向验收 | 新增禁入 10:00–11:00 后 10:30 提交 422；删除后放行 | 未执行；落点：`POST /master/time-rules`、`DELETE /master/time-rules/:id` + `rules.timeRuleDecision` | 部分可达（规则判定本卡可测；提交 422 跨卡验收 visit） |
| TC-BD-007 | 禁入优先 | 重叠时返回 422 | 未执行；落点：`rules.timeRuleDecision` 先判禁入再判可预约 | 设计可达 |
| TC-BD-008 | 校门归属与下拉来源 | 通行记录含 `gate_id`；下拉来自在用校门 | 未执行；落点：`POST /gate/admit` 写 `passage_records.gate_id` + `getActiveGates` + `GET /gate/form-options` | 跨卡验收（visit） |
| TC-BD-009 | 校门软状态停用不硬删 | DELETE 405；停用后历史保留 | 未执行；落点：`DELETE /master/gates/:id` 405 + `PUT /master/gates/:id/status` | 设计可达 |
| TC-BD-010 | 被访人名册作为数据来源 | 下拉来自名册；提交后 `host_id=H1` | 未执行；落点：`getActiveHosts` + `GET /appointments/form-options` + `POST /appointments` | 跨卡验收（visit） |
| TC-BD-011 | 被访人软状态停用不硬删 | DELETE 405；停用后下拉不含 | 未执行；落点：`DELETE /master/hosts/:id` 405 + `PUT /master/hosts/:id/status` + 下拉过滤 | 设计可达 |
| TC-SM-007 | 参数集中管理修改即生效 | 下一次读取即新值；二维码与留存扫描使用新值 | 未执行；落点：`PUT /system/params/:key` + `configService` 60 秒缓存失效 + `getConfigNumber(''privacy_retention_days'')` 展示层读取 | 部分可达（参数写入本卡可测；二维码与留存读取跨卡验收 access/compliance） |
| TC-SM-008 | 数据字典可维护作下拉来源 | 新项出现在下拉；停用退出新增下拉；历史检索保留 | 未执行；落点：`POST /system/dictionary` + `PUT /system/dictionary/:id/status` + `getDictionaryItems` | 设计可达 |

## 在开始改动之前
1. 读取 `spac.md` §5.3、§6.4 与 `p1-contracts.md` §二。
2. 读取 `seed-anchors.sql` 主数据段。
3. 检查 `backend/src/modules/master/` 是否已存在。

## 完成改动之后
1. 列出创建/修改的文件。
2. 粘贴单测与 curl 输出。
3. 确认 13 条 TC 比对表已填写，且「设计可达」均有落点。
4. 列出剩余风险（预约与核验消费点由 visit 卡验证）。
5. 将本卡「测试用例与结果比对」表的「本次实际运行结果」列填写为真实执行结果，写入 `docs/trace/runs/v1/test-results/VIS-P1-I01.md`：逐条 TC 给出命令、原始输出摘要、通过/失败结论；失败项附现象、根因、修复文件与回归命令。
6. 写入 `docs/memory/2026-10-19/VIS-P1-I01.md`。
', '## 目标
交付访客类型、黑名单、时段规则、校门、教职工名册、系统参数与数据字典的维护界面与服务端能力，并让预约、核验、台账消费同一份主数据。

承载需求：REQ-BD-001、REQ-BD-002、REQ-BD-003、REQ-BD-004、REQ-BD-005、REQ-SM-003、REQ-SM-004；支撑 REQ-AT-003 的审核人规则主数据。

## 验收标准
- [ ] `/master` 页面五个分区可查看、新增、改名、停用、启用；删除入口返回 405 COPY-009。
- [ ] `/system/settings` 页面可修改系统参数与数据字典；保存后下一次读取立即生效。
- [ ] 黑名单支持新增、软删除、到期自动失效；删除后历史异常保留。
- [ ] 时段规则支持按星期与起止时间维护；删除即失效；禁入优先于可预约。
- [ ] 访客类型停用后退出新增下拉，但仍在台账检索筛选中。
- [ ] 13 条 TC 的逐条比对表填写完成。

## 相关背景

### 必读文件
- `conventions.md` — 约定 6 命名、约定 9 测试与验证、约定 10 前端交互与视觉、约定 12 文案。
- `docs/trace/runs/v1/spac.md` §4 路由、§4.2.10 主数据、§4.2.12 参数与字典、§5.3 主数据表、§6.4 主数据端点、§11 S-35。
- `docs/knowledge/shared-kernel-api.md` — 前端共享组件、Store 与请求封装签名。
- `docs/knowledge/phase-contracts/p1-contracts.md` §二。
- `roles.md` — adminOnly `/master/*`、`/system/*`。
- `seed-anchors.sql` — 主数据锚点。
- `output/v1.0/测试.md` 第十一、十三节；`output/v1.0/测试结果.md` 对应行。

### 共享内核 API（摘自 docs/knowledge/shared-kernel-api.md）
```ts
import { requireAuth } from ''../../../shared/middleware/requireAuth'';
import { requirePermission, requireAdmin } from ''../../../shared/middleware/requirePermission'';
import { success, paginated } from ''../../../shared/http/envelope'';
import { parsePagination } from ''../../../shared/http/pagination'';
import { asyncHandler } from ''../../../shared/http/asyncHandler'';
import { badRequest, conflict, methodNotAllowed, unprocessable } from ''../../../shared/http/errors'';
import { writeAudit } from ''../../../shared/audit/writeAudit'';
import { getConfig, setConfig } from ''../../../shared/config/configService'';
import { validateBody } from ''../../../shared/validation/validators'';
```

### 模块模板（摘自 docs/knowledge/module-template.md）
- `backend/src/modules/master/{index.ts,api/*.routes.ts,internal/*.service.ts,internal/*.repo.ts,internal/domain/rules.ts,__tests__/}`。
- `frontend/src/views/master/{MasterDataPage.vue,SystemSettingsPage.vue,routes.ts,permissions.ts}`。

### 上游契约（摘自 docs/knowledge/phase-contracts/p0-contracts.md）
- `system_config(config_key, config_value, value_type, description, updated_at)`。
- `operation_logs` 最小字段。

### 本域设计（摘自架构设计文档 §5.3、§6.4）
- 表：`hosts`、`visitor_types`、`gates`、`blacklist_entries`、`time_rules`、`reviewer_rules`、`data_dictionary`。
- 端点：`/master/visitor-types`、`/master/blacklist`、`/master/time-rules`、`/master/gates`、`/master/hosts`、`/system/params`、`/system/dictionary`。
- 门面：`getActiveVisitorTypes`、`getActiveHosts`、`getActiveGates`、`getDictionaryItems`、`getConfig`、`getConfigNumber`、`resolveReviewer`、`upsertReviewerRules`、`checkBlacklist`、`expireBlacklistEntries`。
- 软状态统一 `active`/`inactive`，界面显示「在用/停用」。
- 有效黑名单判定：`status=''有效''` 且 `expire_at >= now`。

## 约束

### 命名约束
- 权限点：`master:visitor_type:read|create|update|status`、`master:blacklist:*`、`master:time_rule:*`、`master:gate:*`、`master:host:*`、`system:param:*`、`system:dictionary:*`。
- 前端字段 camelCase（`employeeNo`、`dictType`），API 键 snake_case（`employee_no`、`dict_type`）。
- 状态值 `active`/`inactive`，展示「在用/停用」。

### 其他约束
- [边界] 只写 master 上下文与 `views/master`；预约与核验逻辑在 visit 卡。
- [边界] 跨上下文只通过 `master/index.ts` 门面导出。
- [依赖] `qrcode` 不在本卡；二维码在 access 卡。
- [校验] 名称 1–30 字；工号 1–30 字且唯一；原因 1–200 字；有效期必须晚于当前时间。

## 实施阶段
实现

## 任务

### 后端
1. 创建 `backend/src/modules/master/api/visitor-types.routes.ts` — GET 列表、POST 新增、PUT `/:id` 改名、PUT `/:id/status`、DELETE 返回 405 COPY-009。
2. 创建 `backend/src/modules/master/api/blacklist.routes.ts` — GET 分页、POST 新增、DELETE `/:id` 软删除。
3. 创建 `backend/src/modules/master/api/time-rules.routes.ts` — GET 列表、POST 新增、DELETE `/:id` 删除即失效。
4. 创建 `backend/src/modules/master/api/gates.routes.ts` — GET 列表、POST 新增、PUT `/:id`、PUT `/:id/status`、DELETE 405。
5. 创建 `backend/src/modules/master/api/hosts.routes.ts` — GET 列表、POST 新增、PUT `/:id`、PUT `/:id/status`、DELETE 405。
6. 创建 `backend/src/modules/master/api/params.routes.ts` — GET `/system/params`、PUT `/system/params/:key`。
7. 创建 `backend/src/modules/master/api/dictionary.routes.ts` — GET、POST、PUT `/:id/status`。
8. 创建 `backend/src/modules/master/internal/*.service.ts` 与 `*.repo.ts` — 七个主数据资源的读写与软状态，以及 `reviewer_rules` 审核人规则的整表替换写入；写操作在事务内调用 `writeAudit`，动作词取 `新增主数据`、`修改主数据`、`停用主数据`、`删除黑名单`、`删除时段规则`、`修改参数`、`修改字典`。
9. 创建 `backend/src/modules/master/internal/domain/rules.ts` — 时段规则判定：禁入优先；可预约闭区间；`start < end`。
10. 创建 `backend/src/modules/master/index.ts` — 导出 DTO 与 10 个门面函数；`getConfig`/`getConfigNumber` 仅转调共享内核 `configService`，不重复实现；含 `upsertReviewerRules(rules)` 供 visit 卡写审核人规则。
11. 创建 `backend/src/modules/master/__tests__/time-rules.rules.test.ts` 与 `blacklist.rules.test.ts`。
12. 创建定时任务 `blacklist-expire`（cron `10 0 * * *`）调用 `expireBlacklistEntries`，并在 `index.ts` 调用 `registerJob({ name:''blacklist-expire'', cron:''10 0 * * *'', runOnStart:false, handler })` 登记。

### 前端
13. 创建 `frontend/src/views/master/MasterDataPage.vue` — 五个分区（访客类型、黑名单、时段规则、校门、教职工名册）；每个分区完整渲染四态：加载中 `LoadingState`、加载失败 `ErrorState`（COPY-355，emit `retry` 重新取数）、空数据 `EmptyState`（COPY-272）、有数据 `a-table`。操作列固定右侧；名称列单行省略并 `a-tooltip` 全文；图标按钮带 `aria-label` 与 `a-tooltip`，可点击区不小于 32×32px；黑名单分区使用服务端分页（默认 20，上限 100）。
14. 创建 `frontend/src/views/master/SystemSettingsPage.vue` — 系统参数与数据字典两个分区；四态同 task 13；保存按钮在请求期间 `loading` 并禁用，防重复提交。
15. 创建 `frontend/src/views/master/routes.ts` — `/master`、`/system/settings`，`meta.roles: [''admin'']`。
16. 创建 `frontend/src/views/master/permissions.ts` — 权限点常量。
17. 所有写操作成功后刷新对应分区并 `message.success` Toast；停用与启用、删除统一走 `ConfirmDialog`：停用标题 COPY-381、正文 COPY-382、成功 COPY-383；启用成功 COPY-384；黑名单删除 COPY-257/COPY-258、成功 COPY-259；时段规则删除 COPY-267/COPY-268、成功 COPY-259；参数保存 COPY-292；字典新增 COPY-293；不得调用原生 `alert(` / `confirm(`。删除受限的三个分区（访客类型、校门、教职工）点击删除按钮直接 Toast COPY-009，不弹确认框。

### 用户可见文案清单（本卡必含，逐字）
| 类别 | 触发场景 | COPY | 逐字文案 | 渲染位置 |
|------|---------|------|---------|---------|
| 页面标题 | 打开主数据 | COPY-242 | 主数据 | PageHeader |
| 设置页标题 | 打开参数与字典 | COPY-289 | 参数与字典 | PageHeader |
| 设置分区标题 | 两个分区 | COPY-290 / COPY-291 | 系统参数、数据字典 | 分区标题 |
| 分区标题 | 五个分区 | — | 访客类型、黑名单、时段规则、校门与通行点、教职工名册 | 分区标题 |
| 删除受限 | 点击删除访客类型/校门/教职工 | COPY-009 | 该数据不支持删除，请使用停用功能 | Toast |
| 停用确认标题 | 点击停用 | COPY-381 | 确认停用 | ConfirmDialog title |
| 停用确认正文 | 同上 | COPY-382 | 停用后该数据不再出现在新增下拉中，历史记录保留。可再次启用。是否继续？ | ConfirmDialog content |
| 停用成功 | 停用完成 | COPY-383 | 已停用 | Toast |
| 启用成功 | 启用完成 | COPY-384 | 已启用 | Toast |
| 删除黑名单标题 | 点击删除黑名单条目 | COPY-257 | 确认删除黑名单条目 | ConfirmDialog title |
| 删除黑名单正文 | 同上 | COPY-258 | 删除后该证件号不再被拦截，历史异常记录保留。是否继续？ | ConfirmDialog content |
| 删除成功 | 黑名单/时段规则删除完成 | COPY-259 | 已删除 | Toast |
| 删除规则标题 | 点击删除时段规则 | COPY-267 | 确认删除时段规则 | ConfirmDialog title |
| 删除规则正文 | 同上 | COPY-268 | 删除后该规则立即失效，不可恢复。是否继续？ | ConfirmDialog content |
| 保存成功 | 参数/字典保存 | COPY-273 | 保存成功 | Toast |
| 参数保存成功 | 修改系统参数 | COPY-292 | 参数已保存，立即生效 | Toast |
| 字典新增成功 | 新增字典项 | COPY-293 | 字典项已新增 | Toast |
| 空态 | 任一分区无数据 | COPY-272 | 暂无数据 | EmptyState |
| 加载中... | 任一列表首次取数 | COPY-357 | 加载中... | LoadingState |
| 加载失败 | 任一列表取数失败 | COPY-355 | 数据加载失败，请点击重试 | ErrorState |
| 重试按钮 | 加载失败态 | COPY-356 | 重试 | ErrorState 按钮 |
| 必填校验 | 名称为空 | — | 请输入名称 | 字段下方 |
| 工号重复 | 新增重复工号 | — | 该工号已存在，请更换 | 字段下方 |
| 黑名单有效期 | 到期时间早于当前 | — | 有效期必须晚于当前时间 | 字段下方 |

### UI 完整性检验结论（2026-10-19）
- 检验范围：`/master` 与 `/system/settings` 共 7 个分区。
- 通过项：每分区四态；文案 COPY-255…293、381…384；停用/启用/删除统一 `ConfirmDialog`；黑名单服务端分页默认 20、上限 100；名称列省略 + tooltip；1024px 无整页横向滚动。
- 对应缺陷：U1、U2、U4。

## 验证
- [ ] `cd backend && npx vitest run src/modules/master/__tests__` → 全部通过。
- [ ] `curl -b admin.txt -X DELETE -H "X-CSRF-Token: $(curl -s -b admin.txt http://localhost:3000/api/v1/auth/csrf | jq -r .data.csrf_token)" http://localhost:3000/api/v1/master/gates/66666666-6666-4666-8666-666666666661` → 405 + COPY-009。
- [ ] `curl -b admin.txt -X PUT -H "X-CSRF-Token: $(curl -s -b admin.txt http://localhost:3000/api/v1/auth/csrf | jq -r .data.csrf_token)" -d ''{"status":"inactive"}'' http://localhost:3000/api/v1/master/visitor-types/55555555-5555-4555-8555-555555555551/status` → 200；随后 `curl -b admin.txt http://localhost:3000/api/v1/master/visitor-types | jq -r ''.data.items[] | select(.status=="active") | .name''` → 不含「家长」。
- [ ] `docker compose exec -T db psql -U visitor -d visitor_system -c "select count(*) from appointments where visitor_type_id=''55555555-5555-4555-8555-555555555551''"` → `3`，停用不改写历史预约的访客类型。
- [ ] 浏览器打开 `/master` → 五个分区渲染 seed 数据：家长、外来人员、公务来访、东门、南门、李明、王芳、赵某某、7 条时段规则。
- [ ] 打开 `/system/settings` → 修改 `entry_url` 保存后 `docker compose exec -T db psql -U visitor -d visitor_system -c "select config_value from system_config where config_key=''entry_url''"` → 新值；入口二维码读取该值的联动由 access 卡验证。
- [ ] 文案目视：停用、删除、保存三类操作逐字匹配上表。
- [ ] 断网验证：`docker compose stop backend` 后打开 `/master`，每个分区显示 COPY-355 与 COPY-356 重试按钮；恢复后端并点击重试后回到数据态。
- [ ] 空态验证：清空某一分区数据后该分区显示 COPY-272，其他分区不受影响。
- [ ] `grep -Rn "alert(\|confirm(" frontend/src/views/master` 无输出；图标按钮均含非空 `aria-label`。
- [ ] 浏览器宽度 1024px 时内容区不出现整页横向滚动条，宽表格在自身容器内横向滚动。

### 测试用例与结果比对
> 本卡独立执行时只能断言 master 侧。结论为「跨卡验收」的条目依赖 `VIS-P1-I05` 或 `VIS-P1-I04` 的消费点，由 `VIS-P2-I01` 执行；本卡只验证其数据与门面已就绪。
| TC | 测试点 | 已定预期（摘自 output/v1.0/测试.md） | 本次实际运行结果（未执行） | 比对结论 |
|----|--------|--------------------------------------|----------------------------|----------|
| TC-BD-001 | 访客类型软状态停用、历史保留分类 | 停用后新增下拉不含；台账检索仍含；历史显示原分类 | 未执行；落点：`PUT /master/visitor-types/:id/status` + `GET /appointments/form-options` 过滤 `active` + `MasterDataPage.vue` | 跨卡验收（visit 表单与台账） |
| TC-BD-002 | 黑名单两段处置、无 override | 提交软提示 `black_hit=1`；门卫硬拦；无临时放行 | 未执行；落点：`checkBlacklist` 门面 + `POST /visitor/appointments` 软提示 + `POST /gate/verify` 硬拦（visit 卡消费） | 跨卡验收（visit） |
| TC-BD-003 | 黑名单命中联动 | 通知门卫+管理员；异常记录；审计 | 未执行；落点：`publishSecurityNotification` + `POST /gate/incidents` + `writeAudit`（visit 卡消费） | 跨卡验收（visit、notify） |
| TC-BD-004 | 黑名单生命周期 | 手工删除留痕；到期自动失效不再命中 | 未执行；落点：`DELETE /master/blacklist/:id` + `blacklist-expire` 任务 + `expireBlacklistEntries` | 设计可达 |
| TC-BD-005 | 时段规则默认可配 | 07:00–18:00；缓冲 15min；上限 240min | 未执行；落点：`seed-anchors.sql` 7 条可预约规则 + `system_config` 的 `verification_buffer_minutes=15`、`max_stay_minutes=240` | 设计可达 |
| TC-BD-006 | 时段规则生效双向验收 | 新增禁入 10:00–11:00 后 10:30 提交 422；删除后放行 | 未执行；落点：`POST /master/time-rules`、`DELETE /master/time-rules/:id` + `rules.timeRuleDecision` | 部分可达（规则判定本卡可测；提交 422 跨卡验收 visit） |
| TC-BD-007 | 禁入优先 | 重叠时返回 422 | 未执行；落点：`rules.timeRuleDecision` 先判禁入再判可预约 | 设计可达 |
| TC-BD-008 | 校门归属与下拉来源 | 通行记录含 `gate_id`；下拉来自在用校门 | 未执行；落点：`POST /gate/admit` 写 `passage_records.gate_id` + `getActiveGates` + `GET /gate/form-options` | 跨卡验收（visit） |
| TC-BD-009 | 校门软状态停用不硬删 | DELETE 405；停用后历史保留 | 未执行；落点：`DELETE /master/gates/:id` 405 + `PUT /master/gates/:id/status` | 设计可达 |
| TC-BD-010 | 被访人名册作为数据来源 | 下拉来自名册；提交后 `host_id=H1` | 未执行；落点：`getActiveHosts` + `GET /appointments/form-options` + `POST /appointments` | 跨卡验收（visit） |
| TC-BD-011 | 被访人软状态停用不硬删 | DELETE 405；停用后下拉不含 | 未执行；落点：`DELETE /master/hosts/:id` 405 + `PUT /master/hosts/:id/status` + 下拉过滤 | 设计可达 |
| TC-SM-007 | 参数集中管理修改即生效 | 下一次读取即新值；二维码与留存扫描使用新值 | 未执行；落点：`PUT /system/params/:key` + `configService` 60 秒缓存失效 + `getConfigNumber(''privacy_retention_days'')` 展示层读取 | 部分可达（参数写入本卡可测；二维码与留存读取跨卡验收 access/compliance） |
| TC-SM-008 | 数据字典可维护作下拉来源 | 新项出现在下拉；停用退出新增下拉；历史检索保留 | 未执行；落点：`POST /system/dictionary` + `PUT /system/dictionary/:id/status` + `getDictionaryItems` | 设计可达 |

## 在开始改动之前
1. 读取 `spac.md` §5.3、§6.4 与 `p1-contracts.md` §二。
2. 读取 `seed-anchors.sql` 主数据段。
3. 检查 `backend/src/modules/master/` 是否已存在。

## 完成改动之后
1. 列出创建/修改的文件。
2. 粘贴单测与 curl 输出。
3. 确认 13 条 TC 比对表已填写，且「设计可达」均有落点。
4. 列出剩余风险（预约与核验消费点由 visit 卡验证）。
5. 将本卡「测试用例与结果比对」表的「本次实际运行结果」列填写为真实执行结果，写入 `docs/trace/runs/v1/test-results/VIS-P1-I01.md`：逐条 TC 给出命令、原始输出摘要、通过/失败结论；失败项附现象、根因、修复文件与回归命令。
6. 写入 `docs/memory/2026-10-19/VIS-P1-I01.md`。
', '6fb41cb9-db51-4196-a359-19f915a20e19', NULL, 'high', 100000, 10, 13, NULL, NULL, NULL, NULL, NULL, NULL, false, NULL, NULL, NULL, NULL);
INSERT INTO issues (id, created_at, updated_at, created_by_id, updated_by_id, project_id, workspace_id, name, description_json, description_html, description_stripped, state_id, parent_id, priority, sort_order, sequence_id, point, estimate_point_id, type_id, start_date, target_date, completed_at, archived_at, is_draft, external_source, external_id, description_binary, deleted_at) VALUES ('775f4dc5-7114-4e0e-80e7-2631822f16c1', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', '[VIS-P1-I02] notify 通知全栈卡', '{}'::jsonb, '## 目标
交付站内通知、未读计数、已读持久、通知渠道配置与实时推送，覆盖 5 类流程通知与 2 类安全通知。

承载需求：REQ-NT-001、REQ-NT-002、REQ-NT-003、REQ-PT-004；支撑 REQ-GV-005 的异常提醒。

## 验收标准
- [ ] `/notifications` 页面分页展示消息，支持只看未读、单条已读、全部已读；列表具备加载中、加载失败、空、有数据四态。
- [ ] 未读数在登录后与每次通知产生后更新；刷新与重新登录后已读状态保持。
- [ ] 点击通知打开对应业务对象：admin/host 跳 `/appointments?appointmentId=<business_id>`；guard 及安全类通知跳 `/gate`。
- [ ] 渠道配置：站内固定启用；短信、企微显示「预留 · 关闭」；渠道配置区仅 admin 渲染。
- [ ] 安全类通知不受渠道开关影响。
- [ ] 6 条 TC 的逐条比对表填写完成。

## 相关背景

### 必读文件
- `conventions.md` — 约定 3 分页、约定 10 前端交互与视觉、约定 12 文案。
- `docs/trace/runs/v1/spac.md` §4.2.11 通知中心、§5.6 通知表、§6.6 通知端点、§8.4 实时事件、§11 S-37/S-38。
- `docs/knowledge/shared-kernel-api.md` — 前端共享组件、Store 与请求封装签名。
- `docs/knowledge/phase-contracts/p1-contracts.md` §三。
- `seed-anchors.sql` — 3 条站内消息。
- `output/v1.0/测试.md` 第十二节；`output/v1.0/测试结果.md` 对应行。

### 共享内核 API（摘自 docs/knowledge/shared-kernel-api.md）
```ts
export async function publishNotification(input: PublishNotificationInput): Promise<{ id: string }>;
export async function publishSecurityNotification(input: PublishNotificationInput): Promise<{ id: string }>;
export function emitNotification(userId: string, payload: { id; title; templateType; createdAt }): void;
```

### 模块模板（摘自 docs/knowledge/module-template.md）
- `backend/src/modules/notify/{index.ts,api/notifications.routes.ts,internal/notification.service.ts,internal/notification.repo.ts}`。
- `frontend/src/views/notify/{NotificationsPage.vue,routes.ts,permissions.ts}`。

### 上游契约（摘自 docs/knowledge/phase-contracts/p1-contracts.md §三）
- `notifications(id, recipient_type, recipient_id, recipient_name, recipient_phone, title, content, template_type, business_type, business_id, is_security, is_read, read_at, created_at)`。
- `notification_channels(channel, enabled, description, updated_at)`。

### 本域设计（摘自架构设计文档 §5.6、§6.6）
- 端点：`GET /notifications`、`GET /notifications/unread-count`、`PUT /notifications/:id/read`、`PUT /notifications/read-all`、`GET/PUT /system/notification-channels`。
- 模板 7 类：提交通知、审核结果、改期提议、改期确认结果、到访提醒、黑名单命中、超时未离。
- 到访提醒：`visit_start - 30min`，每条预约只发一次（`reminder_sent_at`）。
- 超时未离：`visit_end + 60min` 仍在 `已到访(在校中)`，每日只发一次。

## 约束

### 命名约束
- 权限点：`notify:notification:read|update`、`system:channel:read|update`。
- 前端 `unreadCount`、`readAt`；API `unread_count`、`read_at`。

### 其他约束
- [边界] 本卡只写 notify 上下文与 `views/notify`。
- [边界] 不新增 `/visitor/notifications`；H5 消息随预约详情 `messages[]` 返回。
- [依赖] `socket.io`。
- [幂等] 到访提醒与超时未离用唯一条件更新，避免重复发送。

## 实施阶段
实现

## 任务

### 后端
1. 创建 `backend/src/modules/notify/api/notifications.routes.ts` — 4 个后台端点。
2. 创建 `backend/src/modules/notify/api/channels.routes.ts` — `GET/PUT /system/notification-channels`。
3. 创建 `backend/src/modules/notify/internal/notification.service.ts` — `publishNotification`、`publishSecurityNotification`、`list`、`unreadCount`、`markRead`、`markAllRead`。
4. 创建 `backend/src/modules/notify/internal/notification.repo.ts` — 分页、未读、已读更新。
5. 创建 `backend/src/modules/notify/internal/domain/templates.ts` — 7 类模板的标题与正文生成函数。
6. 创建 `backend/src/modules/notify/index.ts` — 导出 `publishNotification`、`publishSecurityNotification` 与 DTO。
7. 创建定时任务 `reminder`（每分钟）：扫描 `visit_start - 30min <= now < visit_start` 且 `reminder_sent_at IS NULL` 且 `status=''已通过''` 的预约，发通知并写 `reminder_sent_at`。
8. 创建定时任务 `overdue`（每分钟）：扫描 `visit_end + 60min < now` 且 `status=''已到访(在校中)''` 的预约，当天尚无 `template_type=''超时未离''` 且 `business_id=预约 id` 的通知时，发安全通知给管理员与门卫。
9. 在 `backend/src/modules/notify/index.ts` 调用 `registerJob({ name:''reminder'', cron:''* * * * *'', runOnStart:false, handler })` 与 `registerJob({ name:''overdue'', cron:''* * * * *'', runOnStart:false, handler })`。
10. 创建 `backend/src/modules/notify/__tests__/templates.test.ts` 与 `notification.service.test.ts`。

### 前端
11. 创建 `frontend/src/views/notify/NotificationsPage.vue` — 消息列表完整渲染四态（`LoadingState` / `ErrorState` COPY-355 + COPY-356 重试 / `EmptyState` COPY-279 / 列表）；分页默认 20；「只看未读」复用 `a-checkbox`，切换时回到第 1 页；「全部标为已读」在请求期间 `loading` 并禁用，成功后 Toast COPY-278 并刷新未读数；单条「标记已读」在请求期间禁用该行按钮，防重复点击；标题列单行省略并 `a-tooltip` 全文。
12. 点击消息跳转：`business_type=''appointment''` 且当前角色为 admin/host → `/appointments?appointmentId=<business_id>`；`business_type=''appointment''` 且角色为 guard、或 `is_security=true` → `/gate`；`business_id` 为空时仅标为已读、不跳转。跳转前调用 `markRead`。
13. 页面内渲染渠道配置分区（`GET/PUT /system/notification-channels`）：仅 `authStore.role === ''admin''` 时渲染；站内固定启用且开关禁用，短信/企微状态显示 COPY-285；保存成功 Toast COPY-287。
14. 创建 `frontend/src/views/notify/routes.ts` — `/notifications`，`meta.roles: [''admin'',''guard'',''host'']`。
15. 创建 `frontend/src/views/notify/permissions.ts` — 权限点。
16. 修改 `frontend/src/layouts/AppLayout.vue` 的铃铛 — 未读数来自 `useNotificationStore`，徽标 `aria-label` 取 COPY-280；收到 `notification:new` 时 +1。

### 用户可见文案清单（本卡必含，逐字）
| 类别 | 触发场景 | COPY | 逐字文案 | 渲染位置 |
|------|---------|------|---------|---------|
| 页面标题 | 打开通知中心 | COPY-274 | 通知中心 | PageHeader |
| 未读筛选 | 复选 | COPY-275 | 只看未读 | 筛选栏 |
| 单条已读 | 按钮 | COPY-276 | 标记已读 | 行操作 |
| 全部已读 | 按钮 | COPY-277 | 全部标为已读 | 页头操作 |
| 全部已读成功 | 操作完成 | COPY-278 | 已全部标为已读 | Toast |
| 未读徽标 | 铃铛徽标 | COPY-280 | 未读消息 | 铃铛 `aria-label` |
| 空态 | 无消息 | COPY-279 | 暂无消息 | EmptyState |
| 加载中... | 首次取数 | COPY-357 | 加载中... | LoadingState |
| 加载失败 | 取数失败 | COPY-355 | 数据加载失败，请点击重试 | ErrorState |
| 重试按钮 | 加载失败态 | COPY-356 | 重试 | ErrorState 按钮 |
| 渠道标题 | 系统设置 | COPY-281 | 通知渠道 | 分区标题 |
| 站内渠道 | 渠道行 | COPY-282 | 站内消息 | 渠道名 |
| 短信渠道 | 渠道行 | COPY-283 | 短信 | 渠道名 |
| 企微渠道 | 渠道行 | COPY-284 | 企业微信 | 渠道名 |
| 预留关闭 | 短信/企微状态 | COPY-285 | 预留 · 关闭 | 状态标签 |
| 站内固定说明 | 渠道说明 | COPY-286 | 站内消息为安全类通知的固定通道，不能关闭 | 说明文字 |
| 渠道保存成功 | 保存 | COPY-287 | 通知渠道已保存 | Toast |
| 安全通知说明 | 渠道说明 | COPY-288 | 安全类通知始终发送站内消息，不受渠道开关影响 | 说明文字 |
| 提交模板标题 | 新预约 | — | 您有一条新的访客预约 | 消息标题 |
| 审核结果标题 | 通过/拒绝 | — | 您的来访申请已{通过/拒绝} | 消息标题 |
| 改期提议标题 | 提议 | — | 被访人提议调整到访时段 | 消息标题 |
| 到访提醒标题 | T-30min | — | 您的访客即将到访 | 消息标题 |
| 黑名单标题 | 命中 | — | 黑名单人员提交预约 | 消息标题 |
| 超时未离标题 | 超时 | — | 访客超时未离校 | 消息标题 |

### UI 完整性检验结论（2026-10-19）
- 检验范围：`/notifications`。
- 通过项：四态；文案 COPY-272…288；通知跳转 `?appointmentId=` 或 `/gate`；单条与批量标记已读均 `loading` 禁用；渠道分区仅 admin 且站内固定启用。
- 对应缺陷：U2、U6。

## 验证
- [ ] `cd backend && npx vitest run src/modules/notify/__tests__` → 全部通过。
- [ ] `curl -b admin.txt http://localhost:3000/api/v1/notifications/unread-count` → `data.unread_count` 为整数。
- [ ] `curl -b admin.txt -X PUT -H "X-CSRF-Token: $(curl -s -b admin.txt http://localhost:3000/api/v1/auth/csrf | jq -r .data.csrf_token)" http://localhost:3000/api/v1/notifications/read-all` → 200；再次查询未读为 0。
- [ ] 重新登录后未读数仍为 0。
- [ ] 浏览器打开 `/notifications` → admin 账号展示 seed 中收件人为 `1111…1111` 的 1 条消息；`grep -n "appointmentId=" frontend/src/views/notify/NotificationsPage.vue` → 命中跳转逻辑（落地页由 visit 卡实现，链路由集成闭环卡验证）。
- [ ] guard 登录 `/notifications` → 渠道配置分区不渲染；点击任一条 `business_type=''appointment''` 消息落地 `/gate`。
- [ ] 断网验证：`docker compose stop backend` 后打开 `/notifications` 显示 COPY-355 与 COPY-356；恢复后点击重试回到列表。
- [ ] `grep -Rn "alert(\|confirm(" frontend/src/views/notify` 无输出；`grep -n "markAllRead" frontend/src/views/notify/NotificationsPage.vue` 命中且按钮存在 `:loading` 绑定。
- [ ] 测试断言：调用 `publishNotification` 后，已连接用户的 socket 客户端在 2 秒内收到 `notification:new`，`useNotificationStore.unreadCount` 加 1。
- [ ] `grep -rn "/visitor/notifications" backend/src frontend/src` → 0 命中。

### 测试用例与结果比对
| TC | 测试点 | 已定预期（摘自 output/v1.0/测试.md） | 本次实际运行结果（未执行） | 比对结论 |
|----|--------|--------------------------------------|----------------------------|----------|
| TC-NT-001 | 提交/审核结果/改期流转通知 | 提交→审核人；通过/拒绝→访客；改期提议→访客；确认结果→审核人 | 未执行；落点：`publishNotification` + visit 卡 4 个状态迁移调用点 + `notifications` 页面 | 跨卡验收（visit 调用点） |
| TC-NT-002 | 到访提醒＝时段起前 30 分钟 | T-30min 发 1 条；T-29min 不重复 | 未执行；落点：`reminder` 任务 + `appointments.reminder_sent_at` 条件更新 | 设计可达 |
| TC-NT-003 | 异常提醒通知相关方 | 站内关闭时安全通知仍送达管理员/门卫；黑名单另写异常 | 未执行；落点：`publishSecurityNotification` 固定写站内 + `POST /gate/incidents` | 跨卡验收（visit 异常记录） |
| TC-NT-004 | 通知渠道双向验收 | 站内启用必达；短信/企微关闭无外发；安全类不受开关影响。**O-04**：「开启短信/企微后按渠道发送」与 PRD 冲突 | 未执行；落点：`PUT /system/notification-channels` 只持久化开关，无短信/企微发送器；站内固定启用 | 部分可达（剔除 O-04 孤儿断言「开启后按渠道发送」；保留「关闭态无外发」「安全类不受开关影响」） |
| TC-PT-011 | 消息红点与已读持久 | 未读红点；已读消失；刷新与重新登录保持 | 未执行；落点：`GET /notifications/unread-count` + `PUT /notifications/:id/read` + `AppLayout` 铃铛 + `useNotificationStore` | 设计可达 |
| TC-PT-012 | 消息点击进入业务对象 | 打开对应预约详情，`appointmentId` 与 `ref` 一致 | 未执行；落点：`notifications.business_id` + `NotificationsPage.vue` 跳转 `/appointments?appointmentId=<business_id>`（guard 落 `/gate`） | 跨卡验收（visit 详情页） |

## 在开始改动之前
1. 读取 `spac.md` §5.6、§6.6、§8.4。
2. 读取 `p1-contracts.md` §三 模板表。
3. 检查 `frontend/src/layouts/AppLayout.vue` 铃铛结构。

## 完成改动之后
1. 列出创建/修改的文件。
2. 粘贴单测与未读接口输出。
3. 确认 6 条 TC 比对表完成，O-04 已显式剔除。
4. 列出剩余风险（visit 卡的调用点由 visit 卡验证）。
5. 将本卡「测试用例与结果比对」表的「本次实际运行结果」列填写为真实执行结果，写入 `docs/trace/runs/v1/test-results/VIS-P1-I02.md`：逐条 TC 给出命令、原始输出摘要、通过/失败结论；失败项附现象、根因、修复文件与回归命令。
6. 写入 `docs/memory/2026-10-19/VIS-P1-I02.md`。
', '## 目标
交付站内通知、未读计数、已读持久、通知渠道配置与实时推送，覆盖 5 类流程通知与 2 类安全通知。

承载需求：REQ-NT-001、REQ-NT-002、REQ-NT-003、REQ-PT-004；支撑 REQ-GV-005 的异常提醒。

## 验收标准
- [ ] `/notifications` 页面分页展示消息，支持只看未读、单条已读、全部已读；列表具备加载中、加载失败、空、有数据四态。
- [ ] 未读数在登录后与每次通知产生后更新；刷新与重新登录后已读状态保持。
- [ ] 点击通知打开对应业务对象：admin/host 跳 `/appointments?appointmentId=<business_id>`；guard 及安全类通知跳 `/gate`。
- [ ] 渠道配置：站内固定启用；短信、企微显示「预留 · 关闭」；渠道配置区仅 admin 渲染。
- [ ] 安全类通知不受渠道开关影响。
- [ ] 6 条 TC 的逐条比对表填写完成。

## 相关背景

### 必读文件
- `conventions.md` — 约定 3 分页、约定 10 前端交互与视觉、约定 12 文案。
- `docs/trace/runs/v1/spac.md` §4.2.11 通知中心、§5.6 通知表、§6.6 通知端点、§8.4 实时事件、§11 S-37/S-38。
- `docs/knowledge/shared-kernel-api.md` — 前端共享组件、Store 与请求封装签名。
- `docs/knowledge/phase-contracts/p1-contracts.md` §三。
- `seed-anchors.sql` — 3 条站内消息。
- `output/v1.0/测试.md` 第十二节；`output/v1.0/测试结果.md` 对应行。

### 共享内核 API（摘自 docs/knowledge/shared-kernel-api.md）
```ts
export async function publishNotification(input: PublishNotificationInput): Promise<{ id: string }>;
export async function publishSecurityNotification(input: PublishNotificationInput): Promise<{ id: string }>;
export function emitNotification(userId: string, payload: { id; title; templateType; createdAt }): void;
```

### 模块模板（摘自 docs/knowledge/module-template.md）
- `backend/src/modules/notify/{index.ts,api/notifications.routes.ts,internal/notification.service.ts,internal/notification.repo.ts}`。
- `frontend/src/views/notify/{NotificationsPage.vue,routes.ts,permissions.ts}`。

### 上游契约（摘自 docs/knowledge/phase-contracts/p1-contracts.md §三）
- `notifications(id, recipient_type, recipient_id, recipient_name, recipient_phone, title, content, template_type, business_type, business_id, is_security, is_read, read_at, created_at)`。
- `notification_channels(channel, enabled, description, updated_at)`。

### 本域设计（摘自架构设计文档 §5.6、§6.6）
- 端点：`GET /notifications`、`GET /notifications/unread-count`、`PUT /notifications/:id/read`、`PUT /notifications/read-all`、`GET/PUT /system/notification-channels`。
- 模板 7 类：提交通知、审核结果、改期提议、改期确认结果、到访提醒、黑名单命中、超时未离。
- 到访提醒：`visit_start - 30min`，每条预约只发一次（`reminder_sent_at`）。
- 超时未离：`visit_end + 60min` 仍在 `已到访(在校中)`，每日只发一次。

## 约束

### 命名约束
- 权限点：`notify:notification:read|update`、`system:channel:read|update`。
- 前端 `unreadCount`、`readAt`；API `unread_count`、`read_at`。

### 其他约束
- [边界] 本卡只写 notify 上下文与 `views/notify`。
- [边界] 不新增 `/visitor/notifications`；H5 消息随预约详情 `messages[]` 返回。
- [依赖] `socket.io`。
- [幂等] 到访提醒与超时未离用唯一条件更新，避免重复发送。

## 实施阶段
实现

## 任务

### 后端
1. 创建 `backend/src/modules/notify/api/notifications.routes.ts` — 4 个后台端点。
2. 创建 `backend/src/modules/notify/api/channels.routes.ts` — `GET/PUT /system/notification-channels`。
3. 创建 `backend/src/modules/notify/internal/notification.service.ts` — `publishNotification`、`publishSecurityNotification`、`list`、`unreadCount`、`markRead`、`markAllRead`。
4. 创建 `backend/src/modules/notify/internal/notification.repo.ts` — 分页、未读、已读更新。
5. 创建 `backend/src/modules/notify/internal/domain/templates.ts` — 7 类模板的标题与正文生成函数。
6. 创建 `backend/src/modules/notify/index.ts` — 导出 `publishNotification`、`publishSecurityNotification` 与 DTO。
7. 创建定时任务 `reminder`（每分钟）：扫描 `visit_start - 30min <= now < visit_start` 且 `reminder_sent_at IS NULL` 且 `status=''已通过''` 的预约，发通知并写 `reminder_sent_at`。
8. 创建定时任务 `overdue`（每分钟）：扫描 `visit_end + 60min < now` 且 `status=''已到访(在校中)''` 的预约，当天尚无 `template_type=''超时未离''` 且 `business_id=预约 id` 的通知时，发安全通知给管理员与门卫。
9. 在 `backend/src/modules/notify/index.ts` 调用 `registerJob({ name:''reminder'', cron:''* * * * *'', runOnStart:false, handler })` 与 `registerJob({ name:''overdue'', cron:''* * * * *'', runOnStart:false, handler })`。
10. 创建 `backend/src/modules/notify/__tests__/templates.test.ts` 与 `notification.service.test.ts`。

### 前端
11. 创建 `frontend/src/views/notify/NotificationsPage.vue` — 消息列表完整渲染四态（`LoadingState` / `ErrorState` COPY-355 + COPY-356 重试 / `EmptyState` COPY-279 / 列表）；分页默认 20；「只看未读」复用 `a-checkbox`，切换时回到第 1 页；「全部标为已读」在请求期间 `loading` 并禁用，成功后 Toast COPY-278 并刷新未读数；单条「标记已读」在请求期间禁用该行按钮，防重复点击；标题列单行省略并 `a-tooltip` 全文。
12. 点击消息跳转：`business_type=''appointment''` 且当前角色为 admin/host → `/appointments?appointmentId=<business_id>`；`business_type=''appointment''` 且角色为 guard、或 `is_security=true` → `/gate`；`business_id` 为空时仅标为已读、不跳转。跳转前调用 `markRead`。
13. 页面内渲染渠道配置分区（`GET/PUT /system/notification-channels`）：仅 `authStore.role === ''admin''` 时渲染；站内固定启用且开关禁用，短信/企微状态显示 COPY-285；保存成功 Toast COPY-287。
14. 创建 `frontend/src/views/notify/routes.ts` — `/notifications`，`meta.roles: [''admin'',''guard'',''host'']`。
15. 创建 `frontend/src/views/notify/permissions.ts` — 权限点。
16. 修改 `frontend/src/layouts/AppLayout.vue` 的铃铛 — 未读数来自 `useNotificationStore`，徽标 `aria-label` 取 COPY-280；收到 `notification:new` 时 +1。

### 用户可见文案清单（本卡必含，逐字）
| 类别 | 触发场景 | COPY | 逐字文案 | 渲染位置 |
|------|---------|------|---------|---------|
| 页面标题 | 打开通知中心 | COPY-274 | 通知中心 | PageHeader |
| 未读筛选 | 复选 | COPY-275 | 只看未读 | 筛选栏 |
| 单条已读 | 按钮 | COPY-276 | 标记已读 | 行操作 |
| 全部已读 | 按钮 | COPY-277 | 全部标为已读 | 页头操作 |
| 全部已读成功 | 操作完成 | COPY-278 | 已全部标为已读 | Toast |
| 未读徽标 | 铃铛徽标 | COPY-280 | 未读消息 | 铃铛 `aria-label` |
| 空态 | 无消息 | COPY-279 | 暂无消息 | EmptyState |
| 加载中... | 首次取数 | COPY-357 | 加载中... | LoadingState |
| 加载失败 | 取数失败 | COPY-355 | 数据加载失败，请点击重试 | ErrorState |
| 重试按钮 | 加载失败态 | COPY-356 | 重试 | ErrorState 按钮 |
| 渠道标题 | 系统设置 | COPY-281 | 通知渠道 | 分区标题 |
| 站内渠道 | 渠道行 | COPY-282 | 站内消息 | 渠道名 |
| 短信渠道 | 渠道行 | COPY-283 | 短信 | 渠道名 |
| 企微渠道 | 渠道行 | COPY-284 | 企业微信 | 渠道名 |
| 预留关闭 | 短信/企微状态 | COPY-285 | 预留 · 关闭 | 状态标签 |
| 站内固定说明 | 渠道说明 | COPY-286 | 站内消息为安全类通知的固定通道，不能关闭 | 说明文字 |
| 渠道保存成功 | 保存 | COPY-287 | 通知渠道已保存 | Toast |
| 安全通知说明 | 渠道说明 | COPY-288 | 安全类通知始终发送站内消息，不受渠道开关影响 | 说明文字 |
| 提交模板标题 | 新预约 | — | 您有一条新的访客预约 | 消息标题 |
| 审核结果标题 | 通过/拒绝 | — | 您的来访申请已{通过/拒绝} | 消息标题 |
| 改期提议标题 | 提议 | — | 被访人提议调整到访时段 | 消息标题 |
| 到访提醒标题 | T-30min | — | 您的访客即将到访 | 消息标题 |
| 黑名单标题 | 命中 | — | 黑名单人员提交预约 | 消息标题 |
| 超时未离标题 | 超时 | — | 访客超时未离校 | 消息标题 |

### UI 完整性检验结论（2026-10-19）
- 检验范围：`/notifications`。
- 通过项：四态；文案 COPY-272…288；通知跳转 `?appointmentId=` 或 `/gate`；单条与批量标记已读均 `loading` 禁用；渠道分区仅 admin 且站内固定启用。
- 对应缺陷：U2、U6。

## 验证
- [ ] `cd backend && npx vitest run src/modules/notify/__tests__` → 全部通过。
- [ ] `curl -b admin.txt http://localhost:3000/api/v1/notifications/unread-count` → `data.unread_count` 为整数。
- [ ] `curl -b admin.txt -X PUT -H "X-CSRF-Token: $(curl -s -b admin.txt http://localhost:3000/api/v1/auth/csrf | jq -r .data.csrf_token)" http://localhost:3000/api/v1/notifications/read-all` → 200；再次查询未读为 0。
- [ ] 重新登录后未读数仍为 0。
- [ ] 浏览器打开 `/notifications` → admin 账号展示 seed 中收件人为 `1111…1111` 的 1 条消息；`grep -n "appointmentId=" frontend/src/views/notify/NotificationsPage.vue` → 命中跳转逻辑（落地页由 visit 卡实现，链路由集成闭环卡验证）。
- [ ] guard 登录 `/notifications` → 渠道配置分区不渲染；点击任一条 `business_type=''appointment''` 消息落地 `/gate`。
- [ ] 断网验证：`docker compose stop backend` 后打开 `/notifications` 显示 COPY-355 与 COPY-356；恢复后点击重试回到列表。
- [ ] `grep -Rn "alert(\|confirm(" frontend/src/views/notify` 无输出；`grep -n "markAllRead" frontend/src/views/notify/NotificationsPage.vue` 命中且按钮存在 `:loading` 绑定。
- [ ] 测试断言：调用 `publishNotification` 后，已连接用户的 socket 客户端在 2 秒内收到 `notification:new`，`useNotificationStore.unreadCount` 加 1。
- [ ] `grep -rn "/visitor/notifications" backend/src frontend/src` → 0 命中。

### 测试用例与结果比对
| TC | 测试点 | 已定预期（摘自 output/v1.0/测试.md） | 本次实际运行结果（未执行） | 比对结论 |
|----|--------|--------------------------------------|----------------------------|----------|
| TC-NT-001 | 提交/审核结果/改期流转通知 | 提交→审核人；通过/拒绝→访客；改期提议→访客；确认结果→审核人 | 未执行；落点：`publishNotification` + visit 卡 4 个状态迁移调用点 + `notifications` 页面 | 跨卡验收（visit 调用点） |
| TC-NT-002 | 到访提醒＝时段起前 30 分钟 | T-30min 发 1 条；T-29min 不重复 | 未执行；落点：`reminder` 任务 + `appointments.reminder_sent_at` 条件更新 | 设计可达 |
| TC-NT-003 | 异常提醒通知相关方 | 站内关闭时安全通知仍送达管理员/门卫；黑名单另写异常 | 未执行；落点：`publishSecurityNotification` 固定写站内 + `POST /gate/incidents` | 跨卡验收（visit 异常记录） |
| TC-NT-004 | 通知渠道双向验收 | 站内启用必达；短信/企微关闭无外发；安全类不受开关影响。**O-04**：「开启短信/企微后按渠道发送」与 PRD 冲突 | 未执行；落点：`PUT /system/notification-channels` 只持久化开关，无短信/企微发送器；站内固定启用 | 部分可达（剔除 O-04 孤儿断言「开启后按渠道发送」；保留「关闭态无外发」「安全类不受开关影响」） |
| TC-PT-011 | 消息红点与已读持久 | 未读红点；已读消失；刷新与重新登录保持 | 未执行；落点：`GET /notifications/unread-count` + `PUT /notifications/:id/read` + `AppLayout` 铃铛 + `useNotificationStore` | 设计可达 |
| TC-PT-012 | 消息点击进入业务对象 | 打开对应预约详情，`appointmentId` 与 `ref` 一致 | 未执行；落点：`notifications.business_id` + `NotificationsPage.vue` 跳转 `/appointments?appointmentId=<business_id>`（guard 落 `/gate`） | 跨卡验收（visit 详情页） |

## 在开始改动之前
1. 读取 `spac.md` §5.6、§6.6、§8.4。
2. 读取 `p1-contracts.md` §三 模板表。
3. 检查 `frontend/src/layouts/AppLayout.vue` 铃铛结构。

## 完成改动之后
1. 列出创建/修改的文件。
2. 粘贴单测与未读接口输出。
3. 确认 6 条 TC 比对表完成，O-04 已显式剔除。
4. 列出剩余风险（visit 卡的调用点由 visit 卡验证）。
5. 将本卡「测试用例与结果比对」表的「本次实际运行结果」列填写为真实执行结果，写入 `docs/trace/runs/v1/test-results/VIS-P1-I02.md`：逐条 TC 给出命令、原始输出摘要、通过/失败结论；失败项附现象、根因、修复文件与回归命令。
6. 写入 `docs/memory/2026-10-19/VIS-P1-I02.md`。
', '6fb41cb9-db51-4196-a359-19f915a20e19', NULL, 'high', 110000, 11, 10, NULL, NULL, NULL, NULL, NULL, NULL, false, NULL, NULL, NULL, NULL);
INSERT INTO issues (id, created_at, updated_at, created_by_id, updated_by_id, project_id, workspace_id, name, description_json, description_html, description_stripped, state_id, parent_id, priority, sort_order, sequence_id, point, estimate_point_id, type_id, start_date, target_date, completed_at, archived_at, is_draft, external_source, external_id, description_binary, deleted_at) VALUES ('0b8c0e07-3bf6-44b2-9a84-93d6f1cb081f', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', '[VIS-P1-I03] report 台账统计全栈卡', '{}'::jsonb, '## 目标
交付访客台账、在校清单、组合检索、CSV/XLSX 导出、打印与统计分析，数据范围与脱敏口径与角色一致。

承载需求：REQ-LG-001、REQ-LG-002、REQ-LG-003、REQ-LG-004、REQ-AN-001、REQ-AN-002、REQ-OR-003（读侧数据范围）。

## 验收标准
- [ ] `/ledger` 分页默认 20、上限 100、按 `visit_start` 倒序；空结果 `{items: [], total: 0}`。
- [ ] `/on-campus` 只展示最后状态为 `已到访(在校中)` 的预约。
- [ ] `/ledger` 导出 CSV 与 XLSX 均为 11 列固定顺序，文件头分别为 `EF BB BF` 与 `PK\x03\x04`；导出文件名 `访客台账_YYYYMMDD_HHmmss.{csv,xlsx}` 并携带当前筛选条件。
- [ ] `/ledger` 导出与打印入口仅 admin 渲染；guard 的到访日期固定当日且禁用。
- [ ] `/statistics` 支持日/周/月 × 访客类型；到访成立集按 `people_count` 计人次；空维度渲染 `0`。
- [ ] guard 仅见本地当日；H1/V1 访问台账返回 403；非 admin 用完整证件号检索返回 403。
- [ ] 16 条 TC 的逐条比对表填写完成。

## 相关背景

### 必读文件
- `conventions.md` — 约定 3 分页、约定 7 时间、约定 10 前端交互与视觉、约定 12 文案。
- `docs/trace/runs/v1/spac.md` §4.2.8 台账、在校清单、统计、§5.7 访问记录、§6.7 报表端点、§11 S-42。
- `docs/knowledge/shared-kernel-api.md` — 前端共享组件、Store 与请求封装签名。
- `docs/knowledge/phase-contracts/p1-contracts.md` §五。
- `output/v1.0/测试.md` 第八、九、十三节；`output/v1.0/测试结果.md` 对应行。

### 共享内核 API（摘自 docs/knowledge/shared-kernel-api.md）
```ts
import { maskIdNo } from ''../../../shared/utils/mask'';
import { parsePagination } from ''../../../shared/http/pagination'';
import { paginated, success } from ''../../../shared/http/envelope'';
import { localDayRange, formatMinute } from ''../../../shared/utils/ids'';
import { ATTENDED_STATUSES } from ''../../../shared/constants/status'';
```

### 模块模板（摘自 docs/knowledge/module-template.md）
- `backend/src/modules/report/{index.ts,api/logs.routes.ts,api/stats.routes.ts,internal/*.service.ts}`。
- `frontend/src/views/report/{LedgerPage.vue,OnCampusPage.vue,StatisticsPage.vue,routes.ts,permissions.ts}`。

### 上游契约（摘自 docs/knowledge/phase-contracts/p1-contracts.md §五）
- 只读 `appointments`、`passage_records`、`companions`、`visitor_types`、`incidents`。
- 台账列：预约编号、姓名、访客类型、手机号、证件号、被访人、到访时段、进校时刻、离校时刻、状态、事由。

### 本域设计（摘自架构设计文档 §6.7）
- `GET /logs` query：`page,page_size,name,id_no,phone,host,type,status,date_from,date_to`。
- `GET /logs/on-campus`。
- `GET /logs/export?format=csv|xlsx`。
- `GET /stats/visits?granularity=day|week|month`。
- `GET /stats/incidents`。
- 统计口径：状态 ∈ `{已通过,已到访(在校中),已离校}`；按 `visit_start` 本地日期归属；计数 = `people_count`。
- 导出零行时返回仅表头文件。

## 约束

### 命名约束
- 权限点：`report:ledger:read|export`、`report:stats:read`。
- 前端 `visitStart`、`peopleCount`；API `visit_start`、`people_count`。

### 其他约束
- [边界] 只读数据，不写 visit 表；本卡不实现门卫操作。
- [依赖] `exceljs`（生成真实 XLSX）。
- [脱敏] 所有展示、检索结果、导出、打印统一调用 `maskIdNo`；任何情况不返回完整号码。
- [性能] `visit_start`、`status`、`visitor_id_no` 索引已存在。

## 实施阶段
实现

## 任务

### 后端
1. 创建 `backend/src/modules/report/api/logs.routes.ts` — `GET /logs`、`GET /logs/on-campus`、`GET /logs/export`；`/logs` 与 `/logs/on-campus` 挂 `requirePermission(''report:ledger:read'')`，`/logs/export` 挂 `requirePermission(''report:ledger:export'')`。
2. 创建 `backend/src/modules/report/api/stats.routes.ts` — `GET /stats/visits`、`GET /stats/incidents`。
3. 创建 `backend/src/modules/report/internal/ledger.service.ts` — 组合筛选、角色数据范围、排序、分页。
4. 创建 `backend/src/modules/report/internal/export.service.ts` — CSV（BOM + 11 列）与 XLSX（exceljs + 11 列）；零行也生成表头。
5. 创建 `backend/src/modules/report/internal/stats.service.ts` — 日/周/月聚合、到访成立集、异常统计。
6. 创建 `backend/src/modules/report/index.ts` — 导出服务函数（本卡无跨上下文门面消费者）。
7. 创建 `backend/src/modules/report/__tests__/mask-export.test.ts`、`stats.rules.test.ts` 与 `ledger.rules.test.ts`；`ledger.rules.test.ts` 以注入的 `now=2026-10-12` 断言当日范围过滤。
8. 在 `backend/package.json` 增加运行依赖 `exceljs`。

### 前端
9. 创建 `frontend/src/views/report/LedgerPage.vue` — 筛选栏、表格、分页、导出下拉、打印；四态齐全（`LoadingState` / `ErrorState` COPY-355 + COPY-356 重试 / `EmptyState` COPY-206 / 表格数据态）。
10. 角色差异：`authStore.role === ''guard''` 时到访日期控件固定为当日且 `disabled`，导出下拉不渲染；admin 见完整筛选与导出下拉。查询与重置按钮在请求期间 `loading` 并禁用，防重复提交；筛选变化后分页回到第 1 页。
11. 导出：`apiClient.get(''/logs/export'', { params, responseType: ''blob'' })`，参数携带当前全部筛选条件（不再单独请求）；从 `Content-Disposition` 取文件名，缺失时前端拼 `访客台账_YYYYMMDD_HHmmss.{csv,xlsx}`；用 `URL.createObjectURL` + 临时 `a` 元素下载后 `revokeObjectURL`；按钮文案切 COPY-202 并禁用，成功 Toast COPY-203，失败读信封中的 COPY 文案。
12. 打印：页头「打印」按钮触发 `window.print()`；打印前套用 `print.css`（隐藏侧边栏、顶栏、筛选栏、操作列，保留 11 列与 `.print-only`）；按钮点击后 Toast COPY-205。
13. 创建 `frontend/src/views/report/OnCampusPage.vue` — 在校清单，展示进校时刻与已在校时长；四态同 task 9；空态 COPY-207。
14. 创建 `frontend/src/views/report/StatisticsPage.vue` — 粒度切换（日/周/月）、访客类型叠加、异常分布；图表使用原生 SVG 绘制（不引入图表库）：横轴时间、纵轴人次、按类型堆叠色块，`<title>` 提供每段数值，图例可点击隐藏/显示某类型；空维度计数显式渲染 `0`，不省略；无数据时 `EmptyState` COPY-214。页面四态同 task 9。
15. 创建 `frontend/src/views/report/routes.ts` — `/ledger`、`/on-campus`（admin/guard）、`/statistics`（admin）。
16. 创建 `frontend/src/views/report/permissions.ts`。
17. 导出与打印期间按钮进入 loading 且禁用，文案逐字取下方文案表。

### 用户可见文案清单（本卡必含，逐字）
| 类别 | 触发场景 | COPY | 逐字文案 | 渲染位置 |
|------|---------|------|---------|---------|
| 台账标题 | 打开台账 | COPY-188 | 访客台账 | PageHeader |
| 在校标题 | 打开在校清单 | COPY-189 | 在校清单 | PageHeader |
| 统计标题 | 打开统计 | COPY-190 | 统计分析 | PageHeader |
| 筛选标签 | 台账筛选 | COPY-191…196 | 访客姓名、证件号、手机号、被访人、状态、到访日期 | 筛选栏 |
| 查询/重置 | 筛选栏 | COPY-197 / COPY-198 | 查询、重置 | 按钮 |
| 导出按钮 | 页头（仅 admin） | COPY-199 | 导出 | 按钮 |
| 导出菜单 | 下拉 | COPY-200 / COPY-201 | 导出 CSV、导出 Excel | 菜单项 |
| 导出中 | 点击导出 | COPY-202 | 正在导出，请稍候... | 按钮 loading |
| 导出成功 | 完成 | COPY-203 | 导出完成 | Toast |
| 打印按钮 | 页头 | COPY-204 | 打印 | 按钮 |
| 打印中 | 点击打印 | COPY-205 | 正在准备打印... | Toast |
| 台账空态 | 无结果 | COPY-206 | 没有符合条件的访客记录 | EmptyState |
| 在校空态 | 无人在校 | COPY-207 | 当前没有在校访客 | EmptyState |
| 精确检索无权限 | 非 admin 输入完整证件号 | COPY-208 | 您无权使用完整证件号检索 | Toast |
| 统计粒度 | 切换 | COPY-209…211 | 按日、按周、按月 | 分段控件 |
| 统计标题 | 图表 | COPY-212 / COPY-213 | 来访量、异常类型分布 | 卡片标题 |
| 统计空态 | 无数据 | COPY-214 | 所选时间范围内没有数据 | EmptyState |
| 单位 | 数值 | COPY-215 | 人次 | 图表单位 |
| 在校时长列 | 表格 | COPY-161 | 已在校时长 | 列名 |
| 加载中... | 任一页面首次取数 | COPY-357 | 加载中... | LoadingState |
| 加载失败 | 任一页面取数失败 | COPY-355 | 数据加载失败，请点击重试 | ErrorState |
| 重试按钮 | 加载失败态 | COPY-356 | 重试 | ErrorState 按钮 |
| 操作列 | 表格 | — | 操作 | 列名 |

### UI 完整性检验结论（2026-10-19）
- 检验范围：`/ledger`、`/on-campus`、`/statistics`。
- 通过项：三页四态；文案 COPY-188…214；guard 到访日期固定且无导出；导出下载闭环与文件名回退；打印保留 11 列；统计原生 SVG、`<title>`、图例开关、零值显式。
- 对应缺陷：U2、U5、U10、U11、U16。

## 验证
- [ ] `cd backend && npx vitest run src/modules/report/__tests__` → 全部通过。
- [ ] `curl -b admin.txt ''http://localhost:3000/api/v1/logs?page_size=101''` → HTTP 200，`data.page_size` 为 100，`data.items` 为 seed 的 11 条（超限截断为上限，不报错）。
- [ ] `curl -b admin.txt ''http://localhost:3000/api/v1/logs?status=已取消''` → 对应子集；空条件返回 `{items: [], total: 0}`。
- [ ] `curl -b admin.txt -o l.csv ''http://localhost:3000/api/v1/logs/export?format=csv'' && xxd -l 3 l.csv` → `efbb bf`。
- [ ] `curl -b admin.txt -o l.xlsx ''http://localhost:3000/api/v1/logs/export?format=xlsx'' && xxd -l 4 l.xlsx` → `504b 0304`。
- [ ] `ledger.rules.test.ts` 以注入的 `now=2026-10-12` 断言 guard 仅返回 D0 当日数据；`curl -b guard.txt ''http://localhost:3000/api/v1/logs?date_from=$(date +%F)''` → 仅返回 D0 当日数据。
- [ ] `curl -b guard.txt ''http://localhost:3000/api/v1/logs?id_no=320101198803034566''` → 403 + COPY-208。
- [ ] 浏览器打开 `/ledger` → 展示 11 条 seed 预约；证件号均为掩码；打开 `/statistics` → 到访成立集计数与台账子集一致。
- [ ] guard 登录 `/ledger` → 到访日期显示当日且 `disabled`，导出下拉不渲染；浏览器控制台无 403 请求。
- [ ] admin 在 `/ledger` 选择「状态=已离校」后导出 CSV → 文件行数与当前筛选结果一致，文件名为 `访客台账_<14位时间>.csv`。
- [ ] 点击「打印」→ 打印预览不含侧边栏、顶栏、筛选栏与操作列，11 列完整；`grep -n "print.css" frontend/src/main.ts frontend/src/App.vue` 命中引入。
- [ ] `/statistics` 图表为 `<svg>` 元素；`grep -n "echarts\|chart.js" frontend/package.json` 无输出；无数据维度显示 `0` 而非空白。
- [ ] 断网验证：`docker compose stop backend` 后 `/ledger`、`/on-campus`、`/statistics` 均显示 COPY-355 与 COPY-356，恢复后点击重试回到数据态。
- [ ] `grep -Rn "alert(\|confirm(" frontend/src/views/report` 无输出。

### 测试用例与结果比对
| TC | 测试点 | 已定预期（摘自 output/v1.0/测试.md） | 本次实际运行结果（未执行） | 比对结论 |
|----|--------|--------------------------------------|----------------------------|----------|
| TC-LG-001 | 台账数据范围 | A1 全校；G1 当日；H1/V1 403 | 未执行；落点：`ledger.service` 角色过滤 + `requireAuth` 守卫 + `LedgerPage.vue` | 设计可达 |
| TC-LG-002 | 分页默认 20 上限 100、倒序 | 默认 20；100；101 截断；`visit_start` 倒序 | 未执行；落点：`parsePagination` + `ORDER BY visit_start DESC` | 设计可达 |
| TC-LG-003 | 空数据返回结构 | `{items: [], total: 0}`，HTTP 200 | 未执行；落点：`paginated` + `ledger.service` | 设计可达 |
| TC-LG-004 | 在校清单进校入列、离校移出 | 进校可查；离校不可查；下一次查询即反映 | 未执行；落点：`GET /logs/on-campus` + `OnCampusPage.vue` | 设计可达 |
| TC-LG-005 | 在校清单按最后状态取数 | 最后状态已离校则不在清单；进出记录保留 | 未执行；落点：`appointments.status=''已到访(在校中)''` + `passage_records` 全量保留 | 设计可达 |
| TC-LG-006 | 多条件组合检索命中 | 全部条件同时满足；停用类型仍可筛选 | 未执行；落点：`GET /logs` 组合 WHERE + `visitor_types` 不过滤停用 | 设计可达 |
| TC-LG-007 | 脱敏后仅 admin 精确命中不回显 | A1 命中但回显掩码；G1 403 + 审计 | 未执行；落点：`ledger.service` admin 精确检索 + `maskIdNo` + `writeAudit(''越权拦截'')` | 设计可达 |
| TC-LG-008 | 台账 1 万条 <2s | 10 次查询每次 <2000ms | 未执行；落点：`idx_appointments_visit_start` + 分页查询 | 设计可达（性能需集成闭环实测） |
| TC-LG-009 | 导出列固定 | 11 列固定顺序 | 未执行；落点：`export.service` 列常量 + CSV/XLSX 共用 | 设计可达 |
| TC-LG-010 | 脱敏分段掩码、导出检索同口径 | 18→前4+10*+后4；8→前1+6*+后1；5→前1+3*+后1 | 未执行；落点：`maskIdNo` 单测覆盖 + 导出/检索共用 | 设计可达 |
| TC-LG-011 | 导出命名与 CSV BOM | 文件名正则；CSV `EF BB BF`；XLSX `PK\x03\x04` | 未执行；落点：`export.service` 文件名 `访客台账_YYYYMMDD_HHmmss.{csv,xlsx}` + BOM + exceljs | 设计可达 |
| TC-LG-012 | 打印沿用导出口径 | 11 列固定；掩码逐字一致 | 未执行；落点：`print.css` + `LedgerPage.vue` 打印列定义与导出一致 | 设计可达 |
| TC-AN-001 | 按日/周/月 × 类型统计 | 返回对应粒度与类型；空维度返回 0 | 未执行；落点：`GET /stats/visits` + `date_trunc` + `StatisticsPage.vue` | 设计可达 |
| TC-AN-002 | 统计口径与台账同源 | 到访成立集；人次；按到访日；与台账子集相等 | 未执行；落点：`stats.service` 使用 `ATTENDED_STATUSES` + `SUM(people_count)` | 设计可达 |
| TC-AN-003 | 异常统计 | 4 类异常数量 + 超时未离；总数相等 | 未执行；落点：`GET /stats/incidents` + `incidents` 聚合 + 按 `visit_end + 60min < now` 且 `status=''已到访(在校中)''` 直接计算超时未离 | 设计可达 |
| TC-SM-005 | 留存 90 天到期自动脱敏（展示层） | 展示层证件号掩码；底层保留；统计仍计入。**O-02**：「隐去人像」无对应字段 | 未执行；落点：`maskIdNo` 在台账/导出/检索统一调用；无肖像字段 | 部分可达（剔除 O-02 孤儿断言「隐去人像」；保留掩码、底层保留、统计计入） |

## 在开始改动之前
1. 读取 `spac.md` §6.7 与 `p1-contracts.md` §五。
2. 读取 `seed-anchors.sql` 11 条预约，确认状态与时段。
3. 检查 `frontend/src/views/report/` 是否已存在。

## 完成改动之后
1. 列出创建/修改的文件。
2. 粘贴单测、导出文件头、403 输出。
3. 确认 16 条 TC 比对表完成，O-02 已显式剔除。
4. 列出剩余风险（1 万条性能需集成闭环造数验证）。
5. 将本卡「测试用例与结果比对」表的「本次实际运行结果」列填写为真实执行结果，写入 `docs/trace/runs/v1/test-results/VIS-P1-I03.md`：逐条 TC 给出命令、原始输出摘要、通过/失败结论；失败项附现象、根因、修复文件与回归命令。
6. 写入 `docs/memory/2026-10-19/VIS-P1-I03.md`。
', '## 目标
交付访客台账、在校清单、组合检索、CSV/XLSX 导出、打印与统计分析，数据范围与脱敏口径与角色一致。

承载需求：REQ-LG-001、REQ-LG-002、REQ-LG-003、REQ-LG-004、REQ-AN-001、REQ-AN-002、REQ-OR-003（读侧数据范围）。

## 验收标准
- [ ] `/ledger` 分页默认 20、上限 100、按 `visit_start` 倒序；空结果 `{items: [], total: 0}`。
- [ ] `/on-campus` 只展示最后状态为 `已到访(在校中)` 的预约。
- [ ] `/ledger` 导出 CSV 与 XLSX 均为 11 列固定顺序，文件头分别为 `EF BB BF` 与 `PK\x03\x04`；导出文件名 `访客台账_YYYYMMDD_HHmmss.{csv,xlsx}` 并携带当前筛选条件。
- [ ] `/ledger` 导出与打印入口仅 admin 渲染；guard 的到访日期固定当日且禁用。
- [ ] `/statistics` 支持日/周/月 × 访客类型；到访成立集按 `people_count` 计人次；空维度渲染 `0`。
- [ ] guard 仅见本地当日；H1/V1 访问台账返回 403；非 admin 用完整证件号检索返回 403。
- [ ] 16 条 TC 的逐条比对表填写完成。

## 相关背景

### 必读文件
- `conventions.md` — 约定 3 分页、约定 7 时间、约定 10 前端交互与视觉、约定 12 文案。
- `docs/trace/runs/v1/spac.md` §4.2.8 台账、在校清单、统计、§5.7 访问记录、§6.7 报表端点、§11 S-42。
- `docs/knowledge/shared-kernel-api.md` — 前端共享组件、Store 与请求封装签名。
- `docs/knowledge/phase-contracts/p1-contracts.md` §五。
- `output/v1.0/测试.md` 第八、九、十三节；`output/v1.0/测试结果.md` 对应行。

### 共享内核 API（摘自 docs/knowledge/shared-kernel-api.md）
```ts
import { maskIdNo } from ''../../../shared/utils/mask'';
import { parsePagination } from ''../../../shared/http/pagination'';
import { paginated, success } from ''../../../shared/http/envelope'';
import { localDayRange, formatMinute } from ''../../../shared/utils/ids'';
import { ATTENDED_STATUSES } from ''../../../shared/constants/status'';
```

### 模块模板（摘自 docs/knowledge/module-template.md）
- `backend/src/modules/report/{index.ts,api/logs.routes.ts,api/stats.routes.ts,internal/*.service.ts}`。
- `frontend/src/views/report/{LedgerPage.vue,OnCampusPage.vue,StatisticsPage.vue,routes.ts,permissions.ts}`。

### 上游契约（摘自 docs/knowledge/phase-contracts/p1-contracts.md §五）
- 只读 `appointments`、`passage_records`、`companions`、`visitor_types`、`incidents`。
- 台账列：预约编号、姓名、访客类型、手机号、证件号、被访人、到访时段、进校时刻、离校时刻、状态、事由。

### 本域设计（摘自架构设计文档 §6.7）
- `GET /logs` query：`page,page_size,name,id_no,phone,host,type,status,date_from,date_to`。
- `GET /logs/on-campus`。
- `GET /logs/export?format=csv|xlsx`。
- `GET /stats/visits?granularity=day|week|month`。
- `GET /stats/incidents`。
- 统计口径：状态 ∈ `{已通过,已到访(在校中),已离校}`；按 `visit_start` 本地日期归属；计数 = `people_count`。
- 导出零行时返回仅表头文件。

## 约束

### 命名约束
- 权限点：`report:ledger:read|export`、`report:stats:read`。
- 前端 `visitStart`、`peopleCount`；API `visit_start`、`people_count`。

### 其他约束
- [边界] 只读数据，不写 visit 表；本卡不实现门卫操作。
- [依赖] `exceljs`（生成真实 XLSX）。
- [脱敏] 所有展示、检索结果、导出、打印统一调用 `maskIdNo`；任何情况不返回完整号码。
- [性能] `visit_start`、`status`、`visitor_id_no` 索引已存在。

## 实施阶段
实现

## 任务

### 后端
1. 创建 `backend/src/modules/report/api/logs.routes.ts` — `GET /logs`、`GET /logs/on-campus`、`GET /logs/export`；`/logs` 与 `/logs/on-campus` 挂 `requirePermission(''report:ledger:read'')`，`/logs/export` 挂 `requirePermission(''report:ledger:export'')`。
2. 创建 `backend/src/modules/report/api/stats.routes.ts` — `GET /stats/visits`、`GET /stats/incidents`。
3. 创建 `backend/src/modules/report/internal/ledger.service.ts` — 组合筛选、角色数据范围、排序、分页。
4. 创建 `backend/src/modules/report/internal/export.service.ts` — CSV（BOM + 11 列）与 XLSX（exceljs + 11 列）；零行也生成表头。
5. 创建 `backend/src/modules/report/internal/stats.service.ts` — 日/周/月聚合、到访成立集、异常统计。
6. 创建 `backend/src/modules/report/index.ts` — 导出服务函数（本卡无跨上下文门面消费者）。
7. 创建 `backend/src/modules/report/__tests__/mask-export.test.ts`、`stats.rules.test.ts` 与 `ledger.rules.test.ts`；`ledger.rules.test.ts` 以注入的 `now=2026-10-12` 断言当日范围过滤。
8. 在 `backend/package.json` 增加运行依赖 `exceljs`。

### 前端
9. 创建 `frontend/src/views/report/LedgerPage.vue` — 筛选栏、表格、分页、导出下拉、打印；四态齐全（`LoadingState` / `ErrorState` COPY-355 + COPY-356 重试 / `EmptyState` COPY-206 / 表格数据态）。
10. 角色差异：`authStore.role === ''guard''` 时到访日期控件固定为当日且 `disabled`，导出下拉不渲染；admin 见完整筛选与导出下拉。查询与重置按钮在请求期间 `loading` 并禁用，防重复提交；筛选变化后分页回到第 1 页。
11. 导出：`apiClient.get(''/logs/export'', { params, responseType: ''blob'' })`，参数携带当前全部筛选条件（不再单独请求）；从 `Content-Disposition` 取文件名，缺失时前端拼 `访客台账_YYYYMMDD_HHmmss.{csv,xlsx}`；用 `URL.createObjectURL` + 临时 `a` 元素下载后 `revokeObjectURL`；按钮文案切 COPY-202 并禁用，成功 Toast COPY-203，失败读信封中的 COPY 文案。
12. 打印：页头「打印」按钮触发 `window.print()`；打印前套用 `print.css`（隐藏侧边栏、顶栏、筛选栏、操作列，保留 11 列与 `.print-only`）；按钮点击后 Toast COPY-205。
13. 创建 `frontend/src/views/report/OnCampusPage.vue` — 在校清单，展示进校时刻与已在校时长；四态同 task 9；空态 COPY-207。
14. 创建 `frontend/src/views/report/StatisticsPage.vue` — 粒度切换（日/周/月）、访客类型叠加、异常分布；图表使用原生 SVG 绘制（不引入图表库）：横轴时间、纵轴人次、按类型堆叠色块，`<title>` 提供每段数值，图例可点击隐藏/显示某类型；空维度计数显式渲染 `0`，不省略；无数据时 `EmptyState` COPY-214。页面四态同 task 9。
15. 创建 `frontend/src/views/report/routes.ts` — `/ledger`、`/on-campus`（admin/guard）、`/statistics`（admin）。
16. 创建 `frontend/src/views/report/permissions.ts`。
17. 导出与打印期间按钮进入 loading 且禁用，文案逐字取下方文案表。

### 用户可见文案清单（本卡必含，逐字）
| 类别 | 触发场景 | COPY | 逐字文案 | 渲染位置 |
|------|---------|------|---------|---------|
| 台账标题 | 打开台账 | COPY-188 | 访客台账 | PageHeader |
| 在校标题 | 打开在校清单 | COPY-189 | 在校清单 | PageHeader |
| 统计标题 | 打开统计 | COPY-190 | 统计分析 | PageHeader |
| 筛选标签 | 台账筛选 | COPY-191…196 | 访客姓名、证件号、手机号、被访人、状态、到访日期 | 筛选栏 |
| 查询/重置 | 筛选栏 | COPY-197 / COPY-198 | 查询、重置 | 按钮 |
| 导出按钮 | 页头（仅 admin） | COPY-199 | 导出 | 按钮 |
| 导出菜单 | 下拉 | COPY-200 / COPY-201 | 导出 CSV、导出 Excel | 菜单项 |
| 导出中 | 点击导出 | COPY-202 | 正在导出，请稍候... | 按钮 loading |
| 导出成功 | 完成 | COPY-203 | 导出完成 | Toast |
| 打印按钮 | 页头 | COPY-204 | 打印 | 按钮 |
| 打印中 | 点击打印 | COPY-205 | 正在准备打印... | Toast |
| 台账空态 | 无结果 | COPY-206 | 没有符合条件的访客记录 | EmptyState |
| 在校空态 | 无人在校 | COPY-207 | 当前没有在校访客 | EmptyState |
| 精确检索无权限 | 非 admin 输入完整证件号 | COPY-208 | 您无权使用完整证件号检索 | Toast |
| 统计粒度 | 切换 | COPY-209…211 | 按日、按周、按月 | 分段控件 |
| 统计标题 | 图表 | COPY-212 / COPY-213 | 来访量、异常类型分布 | 卡片标题 |
| 统计空态 | 无数据 | COPY-214 | 所选时间范围内没有数据 | EmptyState |
| 单位 | 数值 | COPY-215 | 人次 | 图表单位 |
| 在校时长列 | 表格 | COPY-161 | 已在校时长 | 列名 |
| 加载中... | 任一页面首次取数 | COPY-357 | 加载中... | LoadingState |
| 加载失败 | 任一页面取数失败 | COPY-355 | 数据加载失败，请点击重试 | ErrorState |
| 重试按钮 | 加载失败态 | COPY-356 | 重试 | ErrorState 按钮 |
| 操作列 | 表格 | — | 操作 | 列名 |

### UI 完整性检验结论（2026-10-19）
- 检验范围：`/ledger`、`/on-campus`、`/statistics`。
- 通过项：三页四态；文案 COPY-188…214；guard 到访日期固定且无导出；导出下载闭环与文件名回退；打印保留 11 列；统计原生 SVG、`<title>`、图例开关、零值显式。
- 对应缺陷：U2、U5、U10、U11、U16。

## 验证
- [ ] `cd backend && npx vitest run src/modules/report/__tests__` → 全部通过。
- [ ] `curl -b admin.txt ''http://localhost:3000/api/v1/logs?page_size=101''` → HTTP 200，`data.page_size` 为 100，`data.items` 为 seed 的 11 条（超限截断为上限，不报错）。
- [ ] `curl -b admin.txt ''http://localhost:3000/api/v1/logs?status=已取消''` → 对应子集；空条件返回 `{items: [], total: 0}`。
- [ ] `curl -b admin.txt -o l.csv ''http://localhost:3000/api/v1/logs/export?format=csv'' && xxd -l 3 l.csv` → `efbb bf`。
- [ ] `curl -b admin.txt -o l.xlsx ''http://localhost:3000/api/v1/logs/export?format=xlsx'' && xxd -l 4 l.xlsx` → `504b 0304`。
- [ ] `ledger.rules.test.ts` 以注入的 `now=2026-10-12` 断言 guard 仅返回 D0 当日数据；`curl -b guard.txt ''http://localhost:3000/api/v1/logs?date_from=$(date +%F)''` → 仅返回 D0 当日数据。
- [ ] `curl -b guard.txt ''http://localhost:3000/api/v1/logs?id_no=320101198803034566''` → 403 + COPY-208。
- [ ] 浏览器打开 `/ledger` → 展示 11 条 seed 预约；证件号均为掩码；打开 `/statistics` → 到访成立集计数与台账子集一致。
- [ ] guard 登录 `/ledger` → 到访日期显示当日且 `disabled`，导出下拉不渲染；浏览器控制台无 403 请求。
- [ ] admin 在 `/ledger` 选择「状态=已离校」后导出 CSV → 文件行数与当前筛选结果一致，文件名为 `访客台账_<14位时间>.csv`。
- [ ] 点击「打印」→ 打印预览不含侧边栏、顶栏、筛选栏与操作列，11 列完整；`grep -n "print.css" frontend/src/main.ts frontend/src/App.vue` 命中引入。
- [ ] `/statistics` 图表为 `<svg>` 元素；`grep -n "echarts\|chart.js" frontend/package.json` 无输出；无数据维度显示 `0` 而非空白。
- [ ] 断网验证：`docker compose stop backend` 后 `/ledger`、`/on-campus`、`/statistics` 均显示 COPY-355 与 COPY-356，恢复后点击重试回到数据态。
- [ ] `grep -Rn "alert(\|confirm(" frontend/src/views/report` 无输出。

### 测试用例与结果比对
| TC | 测试点 | 已定预期（摘自 output/v1.0/测试.md） | 本次实际运行结果（未执行） | 比对结论 |
|----|--------|--------------------------------------|----------------------------|----------|
| TC-LG-001 | 台账数据范围 | A1 全校；G1 当日；H1/V1 403 | 未执行；落点：`ledger.service` 角色过滤 + `requireAuth` 守卫 + `LedgerPage.vue` | 设计可达 |
| TC-LG-002 | 分页默认 20 上限 100、倒序 | 默认 20；100；101 截断；`visit_start` 倒序 | 未执行；落点：`parsePagination` + `ORDER BY visit_start DESC` | 设计可达 |
| TC-LG-003 | 空数据返回结构 | `{items: [], total: 0}`，HTTP 200 | 未执行；落点：`paginated` + `ledger.service` | 设计可达 |
| TC-LG-004 | 在校清单进校入列、离校移出 | 进校可查；离校不可查；下一次查询即反映 | 未执行；落点：`GET /logs/on-campus` + `OnCampusPage.vue` | 设计可达 |
| TC-LG-005 | 在校清单按最后状态取数 | 最后状态已离校则不在清单；进出记录保留 | 未执行；落点：`appointments.status=''已到访(在校中)''` + `passage_records` 全量保留 | 设计可达 |
| TC-LG-006 | 多条件组合检索命中 | 全部条件同时满足；停用类型仍可筛选 | 未执行；落点：`GET /logs` 组合 WHERE + `visitor_types` 不过滤停用 | 设计可达 |
| TC-LG-007 | 脱敏后仅 admin 精确命中不回显 | A1 命中但回显掩码；G1 403 + 审计 | 未执行；落点：`ledger.service` admin 精确检索 + `maskIdNo` + `writeAudit(''越权拦截'')` | 设计可达 |
| TC-LG-008 | 台账 1 万条 <2s | 10 次查询每次 <2000ms | 未执行；落点：`idx_appointments_visit_start` + 分页查询 | 设计可达（性能需集成闭环实测） |
| TC-LG-009 | 导出列固定 | 11 列固定顺序 | 未执行；落点：`export.service` 列常量 + CSV/XLSX 共用 | 设计可达 |
| TC-LG-010 | 脱敏分段掩码、导出检索同口径 | 18→前4+10*+后4；8→前1+6*+后1；5→前1+3*+后1 | 未执行；落点：`maskIdNo` 单测覆盖 + 导出/检索共用 | 设计可达 |
| TC-LG-011 | 导出命名与 CSV BOM | 文件名正则；CSV `EF BB BF`；XLSX `PK\x03\x04` | 未执行；落点：`export.service` 文件名 `访客台账_YYYYMMDD_HHmmss.{csv,xlsx}` + BOM + exceljs | 设计可达 |
| TC-LG-012 | 打印沿用导出口径 | 11 列固定；掩码逐字一致 | 未执行；落点：`print.css` + `LedgerPage.vue` 打印列定义与导出一致 | 设计可达 |
| TC-AN-001 | 按日/周/月 × 类型统计 | 返回对应粒度与类型；空维度返回 0 | 未执行；落点：`GET /stats/visits` + `date_trunc` + `StatisticsPage.vue` | 设计可达 |
| TC-AN-002 | 统计口径与台账同源 | 到访成立集；人次；按到访日；与台账子集相等 | 未执行；落点：`stats.service` 使用 `ATTENDED_STATUSES` + `SUM(people_count)` | 设计可达 |
| TC-AN-003 | 异常统计 | 4 类异常数量 + 超时未离；总数相等 | 未执行；落点：`GET /stats/incidents` + `incidents` 聚合 + 按 `visit_end + 60min < now` 且 `status=''已到访(在校中)''` 直接计算超时未离 | 设计可达 |
| TC-SM-005 | 留存 90 天到期自动脱敏（展示层） | 展示层证件号掩码；底层保留；统计仍计入。**O-02**：「隐去人像」无对应字段 | 未执行；落点：`maskIdNo` 在台账/导出/检索统一调用；无肖像字段 | 部分可达（剔除 O-02 孤儿断言「隐去人像」；保留掩码、底层保留、统计计入） |

## 在开始改动之前
1. 读取 `spac.md` §6.7 与 `p1-contracts.md` §五。
2. 读取 `seed-anchors.sql` 11 条预约，确认状态与时段。
3. 检查 `frontend/src/views/report/` 是否已存在。

## 完成改动之后
1. 列出创建/修改的文件。
2. 粘贴单测、导出文件头、403 输出。
3. 确认 16 条 TC 比对表完成，O-02 已显式剔除。
4. 列出剩余风险（1 万条性能需集成闭环造数验证）。
5. 将本卡「测试用例与结果比对」表的「本次实际运行结果」列填写为真实执行结果，写入 `docs/trace/runs/v1/test-results/VIS-P1-I03.md`：逐条 TC 给出命令、原始输出摘要、通过/失败结论；失败项附现象、根因、修复文件与回归命令。
6. 写入 `docs/memory/2026-10-19/VIS-P1-I03.md`。
', '6fb41cb9-db51-4196-a359-19f915a20e19', NULL, 'high', 120000, 12, 15, NULL, NULL, NULL, NULL, NULL, NULL, false, NULL, NULL, NULL, NULL);
INSERT INTO issues (id, created_at, updated_at, created_by_id, updated_by_id, project_id, workspace_id, name, description_json, description_html, description_stripped, state_id, parent_id, priority, sort_order, sequence_id, point, estimate_point_id, type_id, start_date, target_date, completed_at, archived_at, is_draft, external_source, external_id, description_binary, deleted_at) VALUES ('0e1f4737-cea2-497a-9e8d-41e84106c892', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', '[VIS-P1-I04] access 门户权限全栈卡', '{}'::jsonb, '## 目标
交付登录页、角色工作台、用户与角色管理、入口二维码，使四类身份进入正确首页且越权被服务端拦截。

承载需求：REQ-PT-001、REQ-PT-002、REQ-PT-003、REQ-PT-005、REQ-OR-001、REQ-OR-002。

## 验收标准
- [ ] `/login` 使用「账号 / 工号 + 密码」；错误、锁定、停用三类提示逐字正确；登录按钮在请求期间显示「登录中...」并禁用。
- [ ] admin/guard/host 登录后分别进入对应工作台；访客无后台入口；已登录访问 `/login` 自动跳转工作台。
- [ ] `/users` 支持新增、编辑、停用/启用、重置密码；删除返回 405；列表具备四态；新增与编辑提交期间按钮禁用。
- [ ] 工作台待办徽标与跳转正确；二维码可生成、下载（`访客入口二维码.png`）、仅打印二维码卡片、复制链接；二维码卡片仅 admin 渲染。
- [ ] 顶栏下拉提供「修改密码」与「退出登录」；修改密码成功后可重新登录。
- [ ] 14 条 TC 的逐条比对表填写完成。

## 相关背景

### 必读文件
- `conventions.md` — 约定 4 认证、约定 10 前端交互与视觉、约定 12 文案。
- `docs/trace/runs/v1/spac.md` §4.2.1 登录页、§4.2.2 工作台、§4.2.9 用户与角色、§6.2 认证与用户端点、§11 S-45/S-46。
- `docs/knowledge/shared-kernel-api.md` — 前端共享组件、Store 与请求封装签名。
- `docs/knowledge/phase-contracts/p1-contracts.md` §一。
- `roles.md` — 角色、权限矩阵、adminOnly。
- `output/v1.0/测试.md` 第三节、第十节；`output/v1.0/测试结果.md` 对应行。

### 共享内核 API（摘自 docs/knowledge/shared-kernel-api.md）
```ts
import { hashPassword, verifyPassword } from ''../../../shared/auth/password'';
import { PERMISSIONS, hasPermission } from ''../../../shared/auth/permissions'';
import { requireAuth } from ''../../../shared/middleware/requireAuth'';
import { requireAdmin } from ''../../../shared/middleware/requirePermission'';
import { loginRateLimiter } from ''../../../shared/middleware/rateLimiter'';
import { writeAudit } from ''../../../shared/audit/writeAudit'';
```

### 模块模板（摘自 docs/knowledge/module-template.md）
- `backend/src/modules/access/{index.ts,api/auth.routes.ts,api/users.routes.ts,api/roles.routes.ts,api/workbench.routes.ts,internal/*.service.ts}`。
- `frontend/src/views/access/{LoginPage.vue,WorkbenchPage.vue,UsersPage.vue,routes.ts,permissions.ts}`。

### 上游契约（摘自 docs/knowledge/phase-contracts/p0-contracts.md）
- 登录响应：`{ code: 0, message: ''登录成功'', data: { user: { id, username, display_name, role_code, host_id } } }`。
- 会话 `vs.sid`；CSRF `vs.csrf`。

### 本域设计（摘自架构设计文档 §6.2）
- 端点：`/auth/csrf`、`/auth/login`、`/auth/logout`、`/auth/me`、`/auth/password`、`/users*`、`/roles*`、`/workbench/summary`、`/system/entry-qr`。
- 工作台 KPI：待审核、待核验、异常待处理、今日预约、在校访客。
- 待核验 = 当日 `已通过` 且 `checkin_at IS NULL`。
- 二维码内容 = `system_config.entry_url`。
- 管理员不能停用自己；不能降级唯一启用中的管理员。

## 约束

### 命名约束
- 权限点：`access:user:*`、`access:role:read`、`portal:workbench:read`、`system:entry_qr:read`。
- 前端 `displayName`、`roleCode`；API `display_name`、`role_code`。

### 其他约束
- [边界] 只写 access 上下文与 `views/access`；业务页面在其他卡。
- [依赖] `qrcode`、`bcryptjs`。
- [安全] 密码只存 bcrypt 哈希；响应不返回 `password_hash`。
- [自我约束] 停用/删除当前登录账号返回 409 COPY-379；降级唯一管理员返回 409 COPY-380。

## 实施阶段
实现

## 任务

### 后端
1. 创建 `backend/src/modules/access/api/auth.routes.ts` — `GET /auth/csrf`、`POST /auth/login`、`POST /auth/logout`、`GET /auth/me`、`PUT /auth/password`。
2. 创建 `backend/src/modules/access/api/users.routes.ts` — GET、POST、PUT `/:id`、PUT `/:id/status`、PUT `/:id/password`、DELETE 405。
3. 创建 `backend/src/modules/access/api/roles.routes.ts` — GET `/roles`、GET `/roles/:code/permissions`。
4. 创建 `backend/src/modules/access/api/workbench.routes.ts` — `GET /workbench/summary`。
5. 创建 `backend/src/modules/access/api/entry-qr.routes.ts` — `GET /system/entry-qr`、`GET /system/entry-qr.png`。
6. 创建 `backend/src/modules/access/internal/auth.service.ts` — 登录、失败计数、锁定、解锁、登出、改密；登录写 `action=''登录''`、登出写 `action=''退出登录''`、改密写 `action=''修改密码''`，均经 `writeAudit` 在事务内写入。
7. 创建 `backend/src/modules/access/internal/users.service.ts` — 增改停启、重置密码（清零失败计数与锁定）、自我保护；写 `action` 依次为 `新增账号`、`停用账号`、`启用账号`、`重置密码`。
8. 创建 `backend/src/modules/access/internal/workbench.service.ts` — 按角色聚合 KPI 与待办。
9. 创建 `backend/src/modules/access/index.ts` — 导出 `CurrentUser`、`getUserById`、`getUserByHostId`、`getFirstAdminUser`。
10. 创建 `backend/src/modules/access/__tests__/login.rules.test.ts` 与 `users.rules.test.ts`。
11. 创建 `scripts/login-fixtures.sh` — 依次登录 admin、guard01、T001，分别写出 `admin.txt`、`guard.txt`、`host.txt`（curl Cookie Jar）；全部 Phase 1 卡的验证统一使用这三个文件名。

### 前端
12. 创建 `frontend/src/views/access/LoginPage.vue` — 账号/工号 + 密码表单；提交按钮在请求期间显示 COPY-021 且禁用，支持回车提交；密码框提供显示/隐藏切换按钮，`aria-label` 依次为 COPY-392/COPY-393；字段为空在字段下方提示 COPY-322/COPY-323；接口错误按 COPY-002/003/004 以 Toast 呈现；成功后 Toast COPY-022 并跳转：`route.query.redirect` 为以单个 `/` 开头的站内路径且与当前角色可见性匹配时跳该路径，否则按角色进入对应工作台；已登录访问 `/login` 直接重定向工作台。
13. 创建 `frontend/src/views/access/WorkbenchPage.vue` — 欢迎语 COPY-032、副标题 COPY-033；KPI 卡片 COPY-034…038 的可见角色与落点：待审核（admin/host）→`/reviews`、待核验（admin/guard）→`/gate`、异常待处理（admin/guard）→`/gate`、今日预约（admin/host）→`/appointments`、在校访客（admin/guard）→`/on-campus`；guard 不渲染待审核与今日预约，与 `spac.md` §4.2.2 的角色差异逐条一致。「我的待办」列表 COPY-039：每项显示业务标题、时间与状态标签，点击进入对应业务页面；无待办显示 COPY-040；整页四态齐全（加载 `LoadingState` / 失败 `ErrorState` COPY-355 + COPY-356 / 空数据 `EmptyState`）。
14. 工作台二维码卡片（仅 `authStore.role === ''admin''` 渲染）— 生成期间显示 COPY-047；失败显示 COPY-048 与重试按钮；「下载 PNG」以 blob 下载并命名 `访客入口二维码.png`；「打印」仅打印二维码卡片（其余区域加 `.no-print`）；「复制链接」调用 CopyButton 并 Toast COPY-046；入口地址标签 COPY-049。
15. 创建 `frontend/src/views/access/UsersPage.vue` — 四态齐全；列 COPY-218…223；不渲染删除按钮；新增账号弹窗 COPY-224 + 字段 COPY-225/226/227/228/229，提交期间按钮 `loading` 禁用；编辑弹窗可改姓名、部门、角色、绑定教职工；停用/启用经 ConfirmDialog（COPY-232/233），成功 Toast COPY-234/235；重置密码经 ConfirmDialog（标题 COPY-236），成功 Toast COPY-237；「角色权限」弹窗 COPY-238/239/240/241，只读不提供保存；自我保护与唯一管理员失败 Toast COPY-379/380。
16. 创建 `frontend/src/views/access/ForbiddenPage.vue` — 标题 COPY-385、正文 COPY-386、按钮 COPY-387；按钮点击跳 `/workbench`。
17. 创建 `frontend/src/views/access/ChangePasswordDialog.vue` — 修改密码弹窗（COPY-025…031）：原密码/新密码两个字段，新密码提示 COPY-028；原密码错误 COPY-030、长度不足 COPY-031 显示在字段下方；提交期间禁用；成功后 Toast COPY-029，随后调用 `logout()` 并跳 `/login`。
18. 修改 `frontend/src/layouts/AppLayout.vue` 顶栏用户下拉 — 增加「修改密码」与「退出登录」（COPY-025、COPY-391）两个菜单项；退出登录经 ConfirmDialog（COPY-023/024），确认后 `logout()` 并跳 `/login`；下拉挂载 `ChangePasswordDialog`。
19. 创建 `frontend/src/views/access/routes.ts` — `/login`（blank）、`/403`（blank）、`/workbench`、`/users`（admin）。
20. 创建 `frontend/src/views/access/permissions.ts`。

### 用户可见文案清单（本卡必含，逐字）
| 类别 | 触发场景 | COPY | 逐字文案 | 渲染位置 |
|------|---------|------|---------|---------|
| 登录页标题 | 页面 | COPY-014 | 校园访客系统 | 标题 |
| 登录页副标题 | 页面 | COPY-015 | 请使用管理员账号或教职工工号登录 | 副标题 |
| 账号标签/占位 | 表单 | COPY-016 / COPY-017 | 账号 / 工号、请输入账号或工号 | 字段 |
| 密码标签/占位 | 表单 | COPY-018 / COPY-019 | 密码、请输入密码 | 字段 |
| 密码显示切换 | 密码框图标 | COPY-392 / COPY-393 | 显示密码、隐藏密码 | 图标按钮 `aria-label` |
| 登录按钮/中 | 表单 | COPY-020 / COPY-021 | 登录、登录中... | 按钮 |
| 登录成功 | 成功 | COPY-022 | 登录成功 | Toast |
| 账号为空 | 提交 | COPY-322 | 请输入账号 | 字段下方 |
| 密码为空 | 提交 | COPY-323 | 请输入密码 | 字段下方 |
| 密码错误 | 401 | COPY-002 | 账号或密码错误，请重新输入 | Toast |
| 账号停用 | 401 | COPY-003 | 该账号已停用，请联系管理员 | Toast |
| 账号锁定 | 401 | COPY-004 | 密码错误次数过多，账号已锁定，请在 10 分钟后重试 | Toast |
| 工作台欢迎 | 工作台 | COPY-032 | 您好，{姓名} | 页头 |
| 工作台副标题 | 工作台 | COPY-033 | 今天有 {n} 条预约等待处理 | 页头 |
| KPI 名称 | 工作台 | COPY-034…038 | 待审核、待核验、异常待处理、今日预约、在校访客 | 卡片 |
| 待办标题/空 | 工作台 | COPY-039 / COPY-040 | 我的待办、暂无待办事项 | 卡片 |
| 二维码卡片 | 工作台 | COPY-041 / COPY-042 | 访客入口二维码、访客扫码后可提交来访申请 | 卡片 |
| 无权限页标题 | 访问 `/403` | COPY-385 | 无权访问 | 页面标题 |
| 无权限页正文 | 同上 | COPY-386 | 您没有访问该页面的权限 | 页面正文 |
| 返回工作台 | 同上 | COPY-387 | 返回工作台 | 按钮 |
| 二维码操作 | 卡片 | COPY-043 / COPY-044 / COPY-045 | 下载 PNG、打印、复制链接 | 按钮 |
| 二维码生成中 | 卡片加载 | COPY-047 | 正在生成二维码... | 卡片占位 |
| 复制成功 | 点击复制 | COPY-046 | 入口链接已复制 | Toast |
| 二维码失败 | 生成失败 | COPY-048 | 二维码生成失败，请重试 | Toast |
| 入口地址 | 卡片 | COPY-049 | 入口地址 | 标签 |
| 用户页标题 | 页面 | COPY-216 | 用户与角色 | PageHeader |
| 表格列 | 用户列表 | COPY-218…223 | 账号、工号、姓名、部门、角色、状态 | 列名 |
| 新增账号 | 按钮/弹窗 | COPY-217 / COPY-224 | 新增账号 | 按钮/标题 |
| 账号字段 | 表单 | COPY-225 / COPY-226 / COPY-227 / COPY-228 / COPY-229 | 账号、初始密码、初始密码至少 6 位，请告知使用人、角色、绑定教职工 | 字段 |
| 角色列值 | 表格 | COPY-388 / COPY-389 / COPY-390 | 管理员、门卫、被访教职工 | 标签 |
| 停用/启用 | 行操作 | COPY-230 / COPY-231 | 停用、启用 | 按钮 |
| 停用确认标题/正文 | 点击停用 | COPY-232 / COPY-233 | 确认停用账号 / 停用后该账号不能登录，历史记录保留。可再次启用。是否继续？ | ConfirmDialog |
| 停用/启用成功 | 完成 | COPY-234 / COPY-235 | 账号已停用、账号已启用 | Toast |
| 重置密码 | 行操作 | COPY-236 / COPY-237 | 重置密码、密码已重置，请告知使用人 | 按钮/Toast |
| 角色权限 | 弹窗 | COPY-238 / COPY-239 / COPY-240 / COPY-241 | 角色权限、管理员拥有全部权限；门卫与被访教职工的权限固定如下、权限点、数据范围 | 弹窗 |
| 修改密码 | 弹窗 | COPY-025 / COPY-026 / COPY-027 / COPY-028 | 修改密码、原密码、新密码、密码至少 6 位 | 弹窗 |
| 改密成功 | 完成 | COPY-029 | 密码修改成功，请使用新密码登录 | Toast |
| 原密码错误 | 422 | COPY-030 | 原密码不正确 | 字段下方 |
| 新密码过短 | 422 | COPY-031 | 密码长度不能少于 6 位 | 字段下方 |
| 退出登录菜单 | 顶栏下拉 | COPY-391 | 退出登录 | 菜单项 |
| 退出确认 | 点击退出 | COPY-023 / COPY-024 | 确认退出登录 / 退出后需要重新输入账号和密码才能继续使用，是否退出？ | ConfirmDialog |
| 自我保护 | 停用自己 | COPY-379 | 不能停用或删除当前登录账号 | Toast |
| 唯一管理员 | 降级唯一管理员 | COPY-380 | 系统至少保留一个启用中的管理员 | Toast |

### UI 完整性检验结论（2026-10-19）
- 检验范围：`/login`、`/workbench`、`/users`、`/403`、修改密码弹窗、`AppLayout` 顶栏。
- 通过项：三个取数页四态；KPI 按角色渲染且落点与权限一致；二维码仅 admin；用户页无删除按钮、角色权限只读；登录回车提交与密码显隐 `aria-label`；退出经 `ConfirmDialog`。
- 对应缺陷：U5、U12、U17、U18。
| 加载中... | 工作台/用户列表首次取数 | COPY-357 | 加载中... | LoadingState |
| 加载失败 | 工作台/用户列表取数失败 | COPY-355 | 数据加载失败，请点击重试 | ErrorState |
| 重试按钮 | 加载失败态 | COPY-356 | 重试 | ErrorState 按钮 |

## 验证
- [ ] `cd backend && npx vitest run src/modules/access/__tests__` → 全部通过。
- [ ] `bash scripts/login-fixtures.sh` → 生成 `admin.txt`、`guard.txt`、`host.txt` 三个 Cookie Jar。
- [ ] `curl -b admin.txt http://localhost:3000/api/v1/auth/me` → 200，`data.user.role_code=admin`；`curl -b guard.txt http://localhost:3000/api/v1/auth/me` → 200，`data.user.role_code=guard`；`curl -b host.txt http://localhost:3000/api/v1/auth/me` → 200，`data.user.role_code=host`。
- [ ] `curl -b guard.txt http://localhost:3000/api/v1/users` → 403 COPY-005，且 `docker compose exec -T db psql -U visitor -d visitor_system -c "select count(*) from operation_logs where action=''越权拦截''"` 增加 1。
- [ ] `curl -b admin.txt -X DELETE -H "X-CSRF-Token: $(curl -s -b admin.txt http://localhost:3000/api/v1/auth/csrf | jq -r .data.csrf_token)" http://localhost:3000/api/v1/users/11111111-1111-4111-8111-111111111111` → 405。
- [ ] `curl -b admin.txt -X PUT -H "X-CSRF-Token: $(curl -s -b admin.txt http://localhost:3000/api/v1/auth/csrf | jq -r .data.csrf_token)" -H ''Content-Type: application/json'' -d ''{"status":"inactive"}'' http://localhost:3000/api/v1/users/11111111-1111-4111-8111-111111111111/status` → 409 COPY-379。
- [ ] `curl -b host.txt -X POST -H "X-CSRF-Token: $(curl -s -b host.txt http://localhost:3000/api/v1/auth/csrf | jq -r .data.csrf_token)" http://localhost:3000/api/v1/auth/logout` → 200；随后 `docker compose exec -T db psql -U visitor -d visitor_system -c "select action, count(*) from operation_logs where action in (''登录'',''退出登录'') group by action order by action"` → 两行均非空，`登录` 计数 ≥ 3。
- [ ] 浏览器打开 `/login` → 使用 `T001/abc@123` 登录 → 进入教职工工作台；KPI 显示待审核 2。
- [ ] `grep -n "key: ''gate''" frontend/src/nav/navigation.ts` → 命中，且该项 `roles` 为 `[''admin'',''guard'']`、`path` 为 `/gate`（导航由 `VIS-P0-I06` 提供，本卡只断言角色可见性）。
- [ ] `/users` 停用 `T002` → 列表状态显示「停用」；启用后恢复「在用」。
- [ ] 登录页连续点击「登录」→ 按钮显示「登录中...」且禁用，仅发出 1 个 `POST /auth/login` 请求。
- [ ] 已登录状态访问 `/login` → 自动跳转对应工作台；host 访问 `/users` → 展示 COPY-385/386/387，点击按钮回 `/workbench`。
- [ ] 工作台 KPI 点击：admin 点「待审核」落 `/reviews`、点「待核验」落 `/gate`、点「在校访客」落 `/on-campus`；guard 不渲染「待审核」卡片。
- [ ] 二维码「下载 PNG」→ 文件名逐字 `访客入口二维码.png`，PNG 文件头 `\x89PNG`；「打印」预览仅含二维码卡片。
- [ ] 顶栏「修改密码」→ 输入原密码与新密码（`abc12`）→ COPY-031 显示在字段下方；改密成功后自动退出并跳 `/login`，新密码可登录。
- [ ] 断网验证：`docker compose stop backend` 后 `/workbench`、`/users` 显示 COPY-355 与 COPY-356。
- [ ] `grep -Rn "alert(\|confirm(" frontend/src/views/access frontend/src/layouts` 无输出。

### 测试用例与结果比对
| TC | 测试点 | 已定预期（摘自 output/v1.0/测试.md） | 本次实际运行结果（未执行） | 比对结论 |
|----|--------|--------------------------------------|----------------------------|----------|
| TC-PT-001 | 后台账号登录成功 | 200；`role=admin`；进入管理员工作台 | 未执行；落点：`POST /auth/login` + `LoginPage.vue` + `workbench` 路由 | 设计可达 |
| TC-PT-002 | 工号（host）登录识别身份 | 200；`role=host`；教职工工作台 | 未执行；落点：`users.username=''T001''` + `role_code=''host''` + 工作台角色分支 | 设计可达 |
| TC-PT-003 | 连续失败 5 次锁定 10 分钟 | 锁定 10 分钟；锁定期正确密码 401；自动解锁；按账号计数；成功清零 | 未执行；落点：`auth.service` 失败计数 + `locked_until` + `loginRateLimiter` | 设计可达 |
| TC-PT-004 | 密码长度 <6 拒绝 | `abc12` 422 `field=password`；`abcdef` 放行 | 未执行；落点：`PUT /auth/password` 与 `PUT /users/:id/password` 的 express-validator `.isLength({min:6})` 校验 | 设计可达 |
| TC-PT-005 | 停用账号登录 401 | 401；不建会话；记录仍存在 | 未执行；落点：`auth.service` 校验 `status=''active''` | 设计可达 |
| TC-PT-007 | 访客不占后台账号体系 | 无后台入口；直接访问后台路由 403 | 未执行；落点：`navigation.ts` 角色过滤 + `requireAuth` + `/403` | 设计可达 |
| TC-PT-008 | 角色工作台路由 | admin/guard/host 各自工作台；visitor→H5 | 未执行；落点：`workbench.service` 按角色返回 + 登录后跳转 | 设计可达 |
| TC-PT-009 | 非授权角色访问受限模块 403 | 导航不显示；接口 403；写越权审计 | 未执行；落点：`requireAdmin` + `writeAudit(''越权拦截'')` + `filterNavigation` | 设计可达 |
| TC-PT-010 | 我的待办聚合与跳转 | 待审核、待核验、异常待处理徽标；处理后递减；跳 AT/GV/GV | 未执行；落点：`GET /workbench/summary` + `WorkbenchPage.vue` | 设计可达 |
| TC-PT-013 | 生成/下载/打印入口二维码 | PNG 文件头 `\x89PNG`；解码=入口 URL；打印含同一码 | 未执行；落点：`GET /system/entry-qr` + `/system/entry-qr.png` + 浏览器打印 | 设计可达 |
| TC-PT-014 | 入口 URL 可配生效 | 修改后新二维码指向新 URL | 未执行；落点：`system_config.entry_url` + 每次生成读取最新值 | 设计可达 |
| TC-OR-001 | 账号开通/停用软状态 | 创建成功；DELETE 405；停用 `inactive` | 未执行；落点：`POST /users` + `DELETE /users/:id` 405 + `PUT /users/:id/status` | 设计可达 |
| TC-OR-002 | 停用后 401、历史留痕、可恢复 | 停用 401；历史可查；恢复后登录成功 | 未执行；落点：`auth.service` + `users` 保留 + `PUT /users/:id/status` | 设计可达 |
| TC-OR-005 | 前端 adminOnly 仅体验层且与基线一致 | 清单与 `/users*`、`/roles*`、`/master/*`、`/system/*` 一致 | 未执行；落点：`navigation.ts` + `views/*/permissions.ts` + 服务端 `requireAdmin` | 设计可达 |

## 在开始改动之前
1. 读取 `roles.md` 与 `p1-contracts.md` §一。
2. 读取 `seed-anchors.sql` 账号段，确认四个账号与密码哈希。
3. 检查 `frontend/src/views/access/` 是否已存在。

## 完成改动之后
1. 列出创建/修改的文件。
2. 粘贴单测与登录/403 输出。
3. 确认 14 条 TC 比对表完成。
4. 列出剩余风险（工作台待办依赖 visit 卡数据，由 visit 卡验证联动）。
5. 将本卡「测试用例与结果比对」表的「本次实际运行结果」列填写为真实执行结果，写入 `docs/trace/runs/v1/test-results/VIS-P1-I04.md`：逐条 TC 给出命令、原始输出摘要、通过/失败结论；失败项附现象、根因、修复文件与回归命令。
6. 写入 `docs/memory/2026-10-19/VIS-P1-I04.md`。
', '## 目标
交付登录页、角色工作台、用户与角色管理、入口二维码，使四类身份进入正确首页且越权被服务端拦截。

承载需求：REQ-PT-001、REQ-PT-002、REQ-PT-003、REQ-PT-005、REQ-OR-001、REQ-OR-002。

## 验收标准
- [ ] `/login` 使用「账号 / 工号 + 密码」；错误、锁定、停用三类提示逐字正确；登录按钮在请求期间显示「登录中...」并禁用。
- [ ] admin/guard/host 登录后分别进入对应工作台；访客无后台入口；已登录访问 `/login` 自动跳转工作台。
- [ ] `/users` 支持新增、编辑、停用/启用、重置密码；删除返回 405；列表具备四态；新增与编辑提交期间按钮禁用。
- [ ] 工作台待办徽标与跳转正确；二维码可生成、下载（`访客入口二维码.png`）、仅打印二维码卡片、复制链接；二维码卡片仅 admin 渲染。
- [ ] 顶栏下拉提供「修改密码」与「退出登录」；修改密码成功后可重新登录。
- [ ] 14 条 TC 的逐条比对表填写完成。

## 相关背景

### 必读文件
- `conventions.md` — 约定 4 认证、约定 10 前端交互与视觉、约定 12 文案。
- `docs/trace/runs/v1/spac.md` §4.2.1 登录页、§4.2.2 工作台、§4.2.9 用户与角色、§6.2 认证与用户端点、§11 S-45/S-46。
- `docs/knowledge/shared-kernel-api.md` — 前端共享组件、Store 与请求封装签名。
- `docs/knowledge/phase-contracts/p1-contracts.md` §一。
- `roles.md` — 角色、权限矩阵、adminOnly。
- `output/v1.0/测试.md` 第三节、第十节；`output/v1.0/测试结果.md` 对应行。

### 共享内核 API（摘自 docs/knowledge/shared-kernel-api.md）
```ts
import { hashPassword, verifyPassword } from ''../../../shared/auth/password'';
import { PERMISSIONS, hasPermission } from ''../../../shared/auth/permissions'';
import { requireAuth } from ''../../../shared/middleware/requireAuth'';
import { requireAdmin } from ''../../../shared/middleware/requirePermission'';
import { loginRateLimiter } from ''../../../shared/middleware/rateLimiter'';
import { writeAudit } from ''../../../shared/audit/writeAudit'';
```

### 模块模板（摘自 docs/knowledge/module-template.md）
- `backend/src/modules/access/{index.ts,api/auth.routes.ts,api/users.routes.ts,api/roles.routes.ts,api/workbench.routes.ts,internal/*.service.ts}`。
- `frontend/src/views/access/{LoginPage.vue,WorkbenchPage.vue,UsersPage.vue,routes.ts,permissions.ts}`。

### 上游契约（摘自 docs/knowledge/phase-contracts/p0-contracts.md）
- 登录响应：`{ code: 0, message: ''登录成功'', data: { user: { id, username, display_name, role_code, host_id } } }`。
- 会话 `vs.sid`；CSRF `vs.csrf`。

### 本域设计（摘自架构设计文档 §6.2）
- 端点：`/auth/csrf`、`/auth/login`、`/auth/logout`、`/auth/me`、`/auth/password`、`/users*`、`/roles*`、`/workbench/summary`、`/system/entry-qr`。
- 工作台 KPI：待审核、待核验、异常待处理、今日预约、在校访客。
- 待核验 = 当日 `已通过` 且 `checkin_at IS NULL`。
- 二维码内容 = `system_config.entry_url`。
- 管理员不能停用自己；不能降级唯一启用中的管理员。

## 约束

### 命名约束
- 权限点：`access:user:*`、`access:role:read`、`portal:workbench:read`、`system:entry_qr:read`。
- 前端 `displayName`、`roleCode`；API `display_name`、`role_code`。

### 其他约束
- [边界] 只写 access 上下文与 `views/access`；业务页面在其他卡。
- [依赖] `qrcode`、`bcryptjs`。
- [安全] 密码只存 bcrypt 哈希；响应不返回 `password_hash`。
- [自我约束] 停用/删除当前登录账号返回 409 COPY-379；降级唯一管理员返回 409 COPY-380。

## 实施阶段
实现

## 任务

### 后端
1. 创建 `backend/src/modules/access/api/auth.routes.ts` — `GET /auth/csrf`、`POST /auth/login`、`POST /auth/logout`、`GET /auth/me`、`PUT /auth/password`。
2. 创建 `backend/src/modules/access/api/users.routes.ts` — GET、POST、PUT `/:id`、PUT `/:id/status`、PUT `/:id/password`、DELETE 405。
3. 创建 `backend/src/modules/access/api/roles.routes.ts` — GET `/roles`、GET `/roles/:code/permissions`。
4. 创建 `backend/src/modules/access/api/workbench.routes.ts` — `GET /workbench/summary`。
5. 创建 `backend/src/modules/access/api/entry-qr.routes.ts` — `GET /system/entry-qr`、`GET /system/entry-qr.png`。
6. 创建 `backend/src/modules/access/internal/auth.service.ts` — 登录、失败计数、锁定、解锁、登出、改密；登录写 `action=''登录''`、登出写 `action=''退出登录''`、改密写 `action=''修改密码''`，均经 `writeAudit` 在事务内写入。
7. 创建 `backend/src/modules/access/internal/users.service.ts` — 增改停启、重置密码（清零失败计数与锁定）、自我保护；写 `action` 依次为 `新增账号`、`停用账号`、`启用账号`、`重置密码`。
8. 创建 `backend/src/modules/access/internal/workbench.service.ts` — 按角色聚合 KPI 与待办。
9. 创建 `backend/src/modules/access/index.ts` — 导出 `CurrentUser`、`getUserById`、`getUserByHostId`、`getFirstAdminUser`。
10. 创建 `backend/src/modules/access/__tests__/login.rules.test.ts` 与 `users.rules.test.ts`。
11. 创建 `scripts/login-fixtures.sh` — 依次登录 admin、guard01、T001，分别写出 `admin.txt`、`guard.txt`、`host.txt`（curl Cookie Jar）；全部 Phase 1 卡的验证统一使用这三个文件名。

### 前端
12. 创建 `frontend/src/views/access/LoginPage.vue` — 账号/工号 + 密码表单；提交按钮在请求期间显示 COPY-021 且禁用，支持回车提交；密码框提供显示/隐藏切换按钮，`aria-label` 依次为 COPY-392/COPY-393；字段为空在字段下方提示 COPY-322/COPY-323；接口错误按 COPY-002/003/004 以 Toast 呈现；成功后 Toast COPY-022 并跳转：`route.query.redirect` 为以单个 `/` 开头的站内路径且与当前角色可见性匹配时跳该路径，否则按角色进入对应工作台；已登录访问 `/login` 直接重定向工作台。
13. 创建 `frontend/src/views/access/WorkbenchPage.vue` — 欢迎语 COPY-032、副标题 COPY-033；KPI 卡片 COPY-034…038 的可见角色与落点：待审核（admin/host）→`/reviews`、待核验（admin/guard）→`/gate`、异常待处理（admin/guard）→`/gate`、今日预约（admin/host）→`/appointments`、在校访客（admin/guard）→`/on-campus`；guard 不渲染待审核与今日预约，与 `spac.md` §4.2.2 的角色差异逐条一致。「我的待办」列表 COPY-039：每项显示业务标题、时间与状态标签，点击进入对应业务页面；无待办显示 COPY-040；整页四态齐全（加载 `LoadingState` / 失败 `ErrorState` COPY-355 + COPY-356 / 空数据 `EmptyState`）。
14. 工作台二维码卡片（仅 `authStore.role === ''admin''` 渲染）— 生成期间显示 COPY-047；失败显示 COPY-048 与重试按钮；「下载 PNG」以 blob 下载并命名 `访客入口二维码.png`；「打印」仅打印二维码卡片（其余区域加 `.no-print`）；「复制链接」调用 CopyButton 并 Toast COPY-046；入口地址标签 COPY-049。
15. 创建 `frontend/src/views/access/UsersPage.vue` — 四态齐全；列 COPY-218…223；不渲染删除按钮；新增账号弹窗 COPY-224 + 字段 COPY-225/226/227/228/229，提交期间按钮 `loading` 禁用；编辑弹窗可改姓名、部门、角色、绑定教职工；停用/启用经 ConfirmDialog（COPY-232/233），成功 Toast COPY-234/235；重置密码经 ConfirmDialog（标题 COPY-236），成功 Toast COPY-237；「角色权限」弹窗 COPY-238/239/240/241，只读不提供保存；自我保护与唯一管理员失败 Toast COPY-379/380。
16. 创建 `frontend/src/views/access/ForbiddenPage.vue` — 标题 COPY-385、正文 COPY-386、按钮 COPY-387；按钮点击跳 `/workbench`。
17. 创建 `frontend/src/views/access/ChangePasswordDialog.vue` — 修改密码弹窗（COPY-025…031）：原密码/新密码两个字段，新密码提示 COPY-028；原密码错误 COPY-030、长度不足 COPY-031 显示在字段下方；提交期间禁用；成功后 Toast COPY-029，随后调用 `logout()` 并跳 `/login`。
18. 修改 `frontend/src/layouts/AppLayout.vue` 顶栏用户下拉 — 增加「修改密码」与「退出登录」（COPY-025、COPY-391）两个菜单项；退出登录经 ConfirmDialog（COPY-023/024），确认后 `logout()` 并跳 `/login`；下拉挂载 `ChangePasswordDialog`。
19. 创建 `frontend/src/views/access/routes.ts` — `/login`（blank）、`/403`（blank）、`/workbench`、`/users`（admin）。
20. 创建 `frontend/src/views/access/permissions.ts`。

### 用户可见文案清单（本卡必含，逐字）
| 类别 | 触发场景 | COPY | 逐字文案 | 渲染位置 |
|------|---------|------|---------|---------|
| 登录页标题 | 页面 | COPY-014 | 校园访客系统 | 标题 |
| 登录页副标题 | 页面 | COPY-015 | 请使用管理员账号或教职工工号登录 | 副标题 |
| 账号标签/占位 | 表单 | COPY-016 / COPY-017 | 账号 / 工号、请输入账号或工号 | 字段 |
| 密码标签/占位 | 表单 | COPY-018 / COPY-019 | 密码、请输入密码 | 字段 |
| 密码显示切换 | 密码框图标 | COPY-392 / COPY-393 | 显示密码、隐藏密码 | 图标按钮 `aria-label` |
| 登录按钮/中 | 表单 | COPY-020 / COPY-021 | 登录、登录中... | 按钮 |
| 登录成功 | 成功 | COPY-022 | 登录成功 | Toast |
| 账号为空 | 提交 | COPY-322 | 请输入账号 | 字段下方 |
| 密码为空 | 提交 | COPY-323 | 请输入密码 | 字段下方 |
| 密码错误 | 401 | COPY-002 | 账号或密码错误，请重新输入 | Toast |
| 账号停用 | 401 | COPY-003 | 该账号已停用，请联系管理员 | Toast |
| 账号锁定 | 401 | COPY-004 | 密码错误次数过多，账号已锁定，请在 10 分钟后重试 | Toast |
| 工作台欢迎 | 工作台 | COPY-032 | 您好，{姓名} | 页头 |
| 工作台副标题 | 工作台 | COPY-033 | 今天有 {n} 条预约等待处理 | 页头 |
| KPI 名称 | 工作台 | COPY-034…038 | 待审核、待核验、异常待处理、今日预约、在校访客 | 卡片 |
| 待办标题/空 | 工作台 | COPY-039 / COPY-040 | 我的待办、暂无待办事项 | 卡片 |
| 二维码卡片 | 工作台 | COPY-041 / COPY-042 | 访客入口二维码、访客扫码后可提交来访申请 | 卡片 |
| 无权限页标题 | 访问 `/403` | COPY-385 | 无权访问 | 页面标题 |
| 无权限页正文 | 同上 | COPY-386 | 您没有访问该页面的权限 | 页面正文 |
| 返回工作台 | 同上 | COPY-387 | 返回工作台 | 按钮 |
| 二维码操作 | 卡片 | COPY-043 / COPY-044 / COPY-045 | 下载 PNG、打印、复制链接 | 按钮 |
| 二维码生成中 | 卡片加载 | COPY-047 | 正在生成二维码... | 卡片占位 |
| 复制成功 | 点击复制 | COPY-046 | 入口链接已复制 | Toast |
| 二维码失败 | 生成失败 | COPY-048 | 二维码生成失败，请重试 | Toast |
| 入口地址 | 卡片 | COPY-049 | 入口地址 | 标签 |
| 用户页标题 | 页面 | COPY-216 | 用户与角色 | PageHeader |
| 表格列 | 用户列表 | COPY-218…223 | 账号、工号、姓名、部门、角色、状态 | 列名 |
| 新增账号 | 按钮/弹窗 | COPY-217 / COPY-224 | 新增账号 | 按钮/标题 |
| 账号字段 | 表单 | COPY-225 / COPY-226 / COPY-227 / COPY-228 / COPY-229 | 账号、初始密码、初始密码至少 6 位，请告知使用人、角色、绑定教职工 | 字段 |
| 角色列值 | 表格 | COPY-388 / COPY-389 / COPY-390 | 管理员、门卫、被访教职工 | 标签 |
| 停用/启用 | 行操作 | COPY-230 / COPY-231 | 停用、启用 | 按钮 |
| 停用确认标题/正文 | 点击停用 | COPY-232 / COPY-233 | 确认停用账号 / 停用后该账号不能登录，历史记录保留。可再次启用。是否继续？ | ConfirmDialog |
| 停用/启用成功 | 完成 | COPY-234 / COPY-235 | 账号已停用、账号已启用 | Toast |
| 重置密码 | 行操作 | COPY-236 / COPY-237 | 重置密码、密码已重置，请告知使用人 | 按钮/Toast |
| 角色权限 | 弹窗 | COPY-238 / COPY-239 / COPY-240 / COPY-241 | 角色权限、管理员拥有全部权限；门卫与被访教职工的权限固定如下、权限点、数据范围 | 弹窗 |
| 修改密码 | 弹窗 | COPY-025 / COPY-026 / COPY-027 / COPY-028 | 修改密码、原密码、新密码、密码至少 6 位 | 弹窗 |
| 改密成功 | 完成 | COPY-029 | 密码修改成功，请使用新密码登录 | Toast |
| 原密码错误 | 422 | COPY-030 | 原密码不正确 | 字段下方 |
| 新密码过短 | 422 | COPY-031 | 密码长度不能少于 6 位 | 字段下方 |
| 退出登录菜单 | 顶栏下拉 | COPY-391 | 退出登录 | 菜单项 |
| 退出确认 | 点击退出 | COPY-023 / COPY-024 | 确认退出登录 / 退出后需要重新输入账号和密码才能继续使用，是否退出？ | ConfirmDialog |
| 自我保护 | 停用自己 | COPY-379 | 不能停用或删除当前登录账号 | Toast |
| 唯一管理员 | 降级唯一管理员 | COPY-380 | 系统至少保留一个启用中的管理员 | Toast |

### UI 完整性检验结论（2026-10-19）
- 检验范围：`/login`、`/workbench`、`/users`、`/403`、修改密码弹窗、`AppLayout` 顶栏。
- 通过项：三个取数页四态；KPI 按角色渲染且落点与权限一致；二维码仅 admin；用户页无删除按钮、角色权限只读；登录回车提交与密码显隐 `aria-label`；退出经 `ConfirmDialog`。
- 对应缺陷：U5、U12、U17、U18。
| 加载中... | 工作台/用户列表首次取数 | COPY-357 | 加载中... | LoadingState |
| 加载失败 | 工作台/用户列表取数失败 | COPY-355 | 数据加载失败，请点击重试 | ErrorState |
| 重试按钮 | 加载失败态 | COPY-356 | 重试 | ErrorState 按钮 |

## 验证
- [ ] `cd backend && npx vitest run src/modules/access/__tests__` → 全部通过。
- [ ] `bash scripts/login-fixtures.sh` → 生成 `admin.txt`、`guard.txt`、`host.txt` 三个 Cookie Jar。
- [ ] `curl -b admin.txt http://localhost:3000/api/v1/auth/me` → 200，`data.user.role_code=admin`；`curl -b guard.txt http://localhost:3000/api/v1/auth/me` → 200，`data.user.role_code=guard`；`curl -b host.txt http://localhost:3000/api/v1/auth/me` → 200，`data.user.role_code=host`。
- [ ] `curl -b guard.txt http://localhost:3000/api/v1/users` → 403 COPY-005，且 `docker compose exec -T db psql -U visitor -d visitor_system -c "select count(*) from operation_logs where action=''越权拦截''"` 增加 1。
- [ ] `curl -b admin.txt -X DELETE -H "X-CSRF-Token: $(curl -s -b admin.txt http://localhost:3000/api/v1/auth/csrf | jq -r .data.csrf_token)" http://localhost:3000/api/v1/users/11111111-1111-4111-8111-111111111111` → 405。
- [ ] `curl -b admin.txt -X PUT -H "X-CSRF-Token: $(curl -s -b admin.txt http://localhost:3000/api/v1/auth/csrf | jq -r .data.csrf_token)" -H ''Content-Type: application/json'' -d ''{"status":"inactive"}'' http://localhost:3000/api/v1/users/11111111-1111-4111-8111-111111111111/status` → 409 COPY-379。
- [ ] `curl -b host.txt -X POST -H "X-CSRF-Token: $(curl -s -b host.txt http://localhost:3000/api/v1/auth/csrf | jq -r .data.csrf_token)" http://localhost:3000/api/v1/auth/logout` → 200；随后 `docker compose exec -T db psql -U visitor -d visitor_system -c "select action, count(*) from operation_logs where action in (''登录'',''退出登录'') group by action order by action"` → 两行均非空，`登录` 计数 ≥ 3。
- [ ] 浏览器打开 `/login` → 使用 `T001/abc@123` 登录 → 进入教职工工作台；KPI 显示待审核 2。
- [ ] `grep -n "key: ''gate''" frontend/src/nav/navigation.ts` → 命中，且该项 `roles` 为 `[''admin'',''guard'']`、`path` 为 `/gate`（导航由 `VIS-P0-I06` 提供，本卡只断言角色可见性）。
- [ ] `/users` 停用 `T002` → 列表状态显示「停用」；启用后恢复「在用」。
- [ ] 登录页连续点击「登录」→ 按钮显示「登录中...」且禁用，仅发出 1 个 `POST /auth/login` 请求。
- [ ] 已登录状态访问 `/login` → 自动跳转对应工作台；host 访问 `/users` → 展示 COPY-385/386/387，点击按钮回 `/workbench`。
- [ ] 工作台 KPI 点击：admin 点「待审核」落 `/reviews`、点「待核验」落 `/gate`、点「在校访客」落 `/on-campus`；guard 不渲染「待审核」卡片。
- [ ] 二维码「下载 PNG」→ 文件名逐字 `访客入口二维码.png`，PNG 文件头 `\x89PNG`；「打印」预览仅含二维码卡片。
- [ ] 顶栏「修改密码」→ 输入原密码与新密码（`abc12`）→ COPY-031 显示在字段下方；改密成功后自动退出并跳 `/login`，新密码可登录。
- [ ] 断网验证：`docker compose stop backend` 后 `/workbench`、`/users` 显示 COPY-355 与 COPY-356。
- [ ] `grep -Rn "alert(\|confirm(" frontend/src/views/access frontend/src/layouts` 无输出。

### 测试用例与结果比对
| TC | 测试点 | 已定预期（摘自 output/v1.0/测试.md） | 本次实际运行结果（未执行） | 比对结论 |
|----|--------|--------------------------------------|----------------------------|----------|
| TC-PT-001 | 后台账号登录成功 | 200；`role=admin`；进入管理员工作台 | 未执行；落点：`POST /auth/login` + `LoginPage.vue` + `workbench` 路由 | 设计可达 |
| TC-PT-002 | 工号（host）登录识别身份 | 200；`role=host`；教职工工作台 | 未执行；落点：`users.username=''T001''` + `role_code=''host''` + 工作台角色分支 | 设计可达 |
| TC-PT-003 | 连续失败 5 次锁定 10 分钟 | 锁定 10 分钟；锁定期正确密码 401；自动解锁；按账号计数；成功清零 | 未执行；落点：`auth.service` 失败计数 + `locked_until` + `loginRateLimiter` | 设计可达 |
| TC-PT-004 | 密码长度 <6 拒绝 | `abc12` 422 `field=password`；`abcdef` 放行 | 未执行；落点：`PUT /auth/password` 与 `PUT /users/:id/password` 的 express-validator `.isLength({min:6})` 校验 | 设计可达 |
| TC-PT-005 | 停用账号登录 401 | 401；不建会话；记录仍存在 | 未执行；落点：`auth.service` 校验 `status=''active''` | 设计可达 |
| TC-PT-007 | 访客不占后台账号体系 | 无后台入口；直接访问后台路由 403 | 未执行；落点：`navigation.ts` 角色过滤 + `requireAuth` + `/403` | 设计可达 |
| TC-PT-008 | 角色工作台路由 | admin/guard/host 各自工作台；visitor→H5 | 未执行；落点：`workbench.service` 按角色返回 + 登录后跳转 | 设计可达 |
| TC-PT-009 | 非授权角色访问受限模块 403 | 导航不显示；接口 403；写越权审计 | 未执行；落点：`requireAdmin` + `writeAudit(''越权拦截'')` + `filterNavigation` | 设计可达 |
| TC-PT-010 | 我的待办聚合与跳转 | 待审核、待核验、异常待处理徽标；处理后递减；跳 AT/GV/GV | 未执行；落点：`GET /workbench/summary` + `WorkbenchPage.vue` | 设计可达 |
| TC-PT-013 | 生成/下载/打印入口二维码 | PNG 文件头 `\x89PNG`；解码=入口 URL；打印含同一码 | 未执行；落点：`GET /system/entry-qr` + `/system/entry-qr.png` + 浏览器打印 | 设计可达 |
| TC-PT-014 | 入口 URL 可配生效 | 修改后新二维码指向新 URL | 未执行；落点：`system_config.entry_url` + 每次生成读取最新值 | 设计可达 |
| TC-OR-001 | 账号开通/停用软状态 | 创建成功；DELETE 405；停用 `inactive` | 未执行；落点：`POST /users` + `DELETE /users/:id` 405 + `PUT /users/:id/status` | 设计可达 |
| TC-OR-002 | 停用后 401、历史留痕、可恢复 | 停用 401；历史可查；恢复后登录成功 | 未执行；落点：`auth.service` + `users` 保留 + `PUT /users/:id/status` | 设计可达 |
| TC-OR-005 | 前端 adminOnly 仅体验层且与基线一致 | 清单与 `/users*`、`/roles*`、`/master/*`、`/system/*` 一致 | 未执行；落点：`navigation.ts` + `views/*/permissions.ts` + 服务端 `requireAdmin` | 设计可达 |

## 在开始改动之前
1. 读取 `roles.md` 与 `p1-contracts.md` §一。
2. 读取 `seed-anchors.sql` 账号段，确认四个账号与密码哈希。
3. 检查 `frontend/src/views/access/` 是否已存在。

## 完成改动之后
1. 列出创建/修改的文件。
2. 粘贴单测与登录/403 输出。
3. 确认 14 条 TC 比对表完成。
4. 列出剩余风险（工作台待办依赖 visit 卡数据，由 visit 卡验证联动）。
5. 将本卡「测试用例与结果比对」表的「本次实际运行结果」列填写为真实执行结果，写入 `docs/trace/runs/v1/test-results/VIS-P1-I04.md`：逐条 TC 给出命令、原始输出摘要、通过/失败结论；失败项附现象、根因、修复文件与回归命令。
6. 写入 `docs/memory/2026-10-19/VIS-P1-I04.md`。
', '6fb41cb9-db51-4196-a359-19f915a20e19', NULL, 'high', 130000, 13, 13, NULL, NULL, NULL, NULL, NULL, NULL, false, NULL, NULL, NULL, NULL);
INSERT INTO issues (id, created_at, updated_at, created_by_id, updated_by_id, project_id, workspace_id, name, description_json, description_html, description_stripped, state_id, parent_id, priority, sort_order, sequence_id, point, estimate_point_id, type_id, start_date, target_date, completed_at, archived_at, is_draft, external_source, external_id, description_binary, deleted_at) VALUES ('4d7ff842-46d7-42c7-983c-595a650671c9', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', '[VIS-P1-I05] visit 来访闭环全栈卡', '{}'::jsonb, '## 目标
交付预约、审核、门卫核验放行、现场登记、异常、访客 H5 与对象级隔离，完整贯通 8 个预约状态。

承载需求：REQ-AP-001、REQ-AP-002、REQ-AP-003、REQ-AP-004、REQ-AP-005、REQ-AT-001、REQ-AT-002、REQ-AT-003、REQ-AT-004、REQ-GV-001、REQ-GV-002、REQ-GV-003、REQ-GV-004、REQ-GV-005、REQ-GV-006、REQ-VS-001、REQ-VS-002、REQ-VS-003、REQ-VS-004、REQ-OR-003（对象级数据范围）；支撑 REQ-SM-001 的提交/审核/核验/离校审计。

## 验收标准
- [ ] 预约创建校验手机号、证件号、时段、必填、随行 ≤10、黑名单软提示、防重复、时段规则；后台代提表单与 H5 表单校验口径一致。
- [ ] 审核支持同意、拒绝（原因 2–100 字）、提议改期；改期经访客确认回 `待审核`；3 小时未确认转 `已过期`；三个动作提交期间按钮禁用。
- [ ] 门卫核验窗口 `[visit_start−15min, visit_end+15min]`；重复核销 409；离校当天再次进校不二次核销。
- [ ] 现场登记豁免未过期/已审核，仍过黑名单；两份告知默认未勾选且必勾选；短码立即置为已用。
- [ ] 异常 4 类可上报；管理员处置需说明；guard 处置按钮不渲染且接口 403。
- [ ] 黑名单核验结果只出现「拦截放行」，点击写异常且不调用放行接口。
- [ ] 访客令牌只能读本人预约；短码不能读详情；越权写审计。
- [ ] 后台四个页面均具备加载/失败/空/数据四态；H5 页面 320–480px 无横向滚动，触控目标 ≥44×44px。
- [ ] 创建预约写 `action=''新增预约''` 审计；离校登记写 `action=''离校''` 审计；两者均含操作人、时间、对象、结果、before/after。
- [ ] 54 条 TC 的逐条比对表填写完成。

## 相关背景

### 必读文件
- `conventions.md` — 约定 6 命名、约定 7 时间、约定 9 测试与验证、约定 10 前端交互与视觉、约定 12 文案、约定 13 状态机。
- `docs/trace/runs/v1/spac.md` §4.2.3 访客预约、§4.2.4 被访人审核、§4.2.5 门卫核验、§4.2.6 H5 申请、§4.2.7 H5 我的申请、§5.4/§5.5/§5.8 表、§6.3/§6.5 端点、§11 S-41/S-43/S-44/S-47。
- `docs/knowledge/shared-kernel-api.md` — 前端共享组件、Store 与请求封装签名。
- `docs/knowledge/phase-contracts/p1-contracts.md` §四。
- `roles.md` — 对象级数据范围。
- `seed-anchors.sql` — 11 条预约、短码、通行、异常、告知。
- `output/v1.0/测试.md` 第三至七、十三节；`output/v1.0/测试结果.md` 对应行。

### 共享内核 API（摘自 docs/knowledge/shared-kernel-api.md）
```ts
import { withTransaction } from ''../../../shared/db/pool'';
import { nextAppointmentNo, generateShortCode } from ''../../../shared/utils/appointmentNo'';
import { writeAudit } from ''../../../shared/audit/writeAudit'';
import { APPOINTMENT_STATUSES, OPEN_STATUSES } from ''../../../shared/constants/status'';
import { validateBody } from ''../../../shared/validation/validators'';
import { visitorTokenAuth } from ''../../../shared/middleware/visitorTokenAuth'';
import { badRequest, conflict, forbidden, notFound, unprocessable } from ''../../../shared/http/errors'';
```

### 模块模板（摘自 docs/knowledge/module-template.md）
- `backend/src/modules/visit/{index.ts,api/*.routes.ts,internal/*.service.ts,internal/domain/rules.ts,__tests__/}`。
- `frontend/src/views/visit/{AppointmentsPage.vue,ReviewsPage.vue,GatePage.vue,AppointmentForm.vue,H5ApplyPage.vue,H5MyPage.vue,routes.ts,permissions.ts}`。

### 上游契约（摘自 docs/knowledge/phase-contracts/p1-contracts.md）
- master 门面：`getActiveVisitorTypes`、`getActiveHosts`、`getActiveGates`、`getDictionaryItems`、`getConfig`、`getConfigNumber`、`resolveReviewer`、`upsertReviewerRules`、`checkBlacklist`。
- notify 门面：`publishNotification`、`publishSecurityNotification`。
- 共享表：`users`、`operation_logs`。

### 种子数据来源（摘自 seed-anchors.sql）
- P1 陈晨（待审核，10:00–11:00）、P2 刘洋（已通过）、P3 周敏（待审核，审核人 H1）、P4 孙浩（已到访(在校中)）、P5 吴倩（已离校）、P6 陈晨（已改期）、P7 郑凯（已拒绝）、P8 冯雪（已过期）、P9 蒋涛（已取消）、P10 韩梅（待审核，`black_hit=true`）、P11 杨帆（已通过）。
- 短码 `100001`–`100011`；随行 1 条（P1）；告知 22 条；通行 3 条；异常 3 条。

### 本域设计（摘自架构设计文档 §5.4、§5.5、§5.8、§6.3、§6.5）
- 8 态：待审核、已通过、已拒绝、已改期、已过期、已到访(在校中)、已离校、已取消。
- 未完结集 = `{待审核, 已改期, 已通过, 已到访(在校中)}`；终态 = `{已拒绝, 已过期, 已取消}`；到访成立集 = `{已通过, 已到访(在校中), 已离校}`。
- 防重复：同一 `visitor_id_no` 在未完结集闭区间相交即拒绝，排除自身；事务内 `pg_advisory_xact_lock` + 唯一索引。
- 改期：host 提议 → `已改期` → 访客确认 → `待审核`；访客主动改期直接 `待审核`；次数不限；`reschedule_deadline = 提议时刻 + 3h`。
- 核验窗口：`[visit_start−15min, visit_end+15min]`，端点含。
- 再次进校：`已离校` 且同一本地日期内 → `已到访(在校中)`，追加 `enter` 通行记录，不二次核销。
- 短码：`^\d{6}$` 全局唯一，随预约生成，终态后不可核验。
- 现场登记：不要求预约存在；两份告知必勾选；黑名单仍硬拦；短码生成后立即 `已使用`。

## 约束

### 命名约束
- 权限点：`visit:appointment:read|create|update`、`visit:review:read|approve|reject|reschedule`、`visit:gate:verify|admit|depart|walk_in`、`visit:incident:read|report|dispose`、`visit:visitor:read`。
- 前端 `visitStart`、`shortCode`；API `visit_start`、`short_code`。

### 其他约束
- [边界] 只写 visit 上下文与 `views/visit`；不改 master/notify 内部。
- [边界] 跨上下文只调用 master/notify 门面。
- [并发] 所有状态迁移 `SELECT ... FOR UPDATE`。
- [安全] 对象级隔离在 service 执行；越权返回 403 并写 `action=''越权拦截''` 审计。
- [告知] 每次 H5 提交与现场登记都插入独立 `consent_records`，不记忆上次勾选。

## 实施阶段
实现

## 任务

### 后端
1. 创建 `backend/src/modules/visit/api/appointments.routes.ts` — `GET /appointments/form-options`、`GET /appointments`、`POST /appointments`、`GET /appointments/:id`、`PUT /appointments/:id/reschedule`、`PUT /appointments/:id/cancel`。
2. 创建 `backend/src/modules/visit/api/reviews.routes.ts` — `GET /reviews`、`GET /reviews/:id`、`POST /reviews/:id/approve`、`POST /reviews/:id/reject`、`POST /reviews/:id/reschedule`、`GET /reviews/:id/logs`、`GET/PUT /reviews/assignment`；`GET/PUT /reviews/assignment` 必须在 `GET /reviews/:id` 之前注册，否则 `assignment` 会被 `:id` 吞掉；`PUT /reviews/assignment` 只调用 master 门面 `upsertReviewerRules` 写入，不直接写 `reviewer_rules`。
3. 创建 `backend/src/modules/visit/api/gate.routes.ts` — `GET /gate/today`、`GET /gate/form-options`、`POST /gate/verify`、`POST /gate/admit`、`POST /gate/depart`、`POST /gate/walk-in`、`GET/POST /gate/incidents`、`PUT /gate/incidents/:id/disposition`。请求体：`verify`/`admit`/`depart` 为 `{code, gate_id}`；`walk-in` 为 `{visitor_name, visitor_phone, visitor_id_no, visitor_type_id, host_id, gate_id, reason, consent:{safety:true,privacy:true}}`；`incidents` 为 `{code?, incident_type, description}`；`disposition` 为 `{status:''已处理''|''已忽略'', disposition_note}`。
4. 创建 `backend/src/modules/visit/api/visitor.routes.ts` — `GET /visitor/form-options`、`POST /visitor/appointments`（响应返回 `visitorToken` 并写 `vs.visitor` Cookie）、`GET /visitor/appointments`、`GET /visitor/appointments/:id`（含 `messages[]`）、`POST /visitor/appointments/:id/confirm-reschedule`、`PUT /visitor/appointments/:id/reschedule`、`PUT /visitor/appointments/:id/cancel`。
5. 创建 `backend/src/modules/visit/internal/domain/rules.ts` — 时段、证件、手机号、防重复、核验窗口、状态迁移、改期截止判定。
6. 创建 `backend/src/modules/visit/internal/appointment.service.ts` — 创建、改期、取消、状态历史；创建写 `action=''新增预约''` 审计，取消写 `action=''取消预约''` 审计，改期写 `action=''改期''` 审计。
7. 创建 `backend/src/modules/visit/internal/review.service.ts` — 同意、拒绝、提议改期、审核人归属查询、审核日志；同意写 `action=''审核同意''`、拒绝写 `action=''审核拒绝''`、提议改期写 `action=''改期''` 审计。
8. 创建 `backend/src/modules/visit/internal/gate.service.ts` — 核验、放行、离校、再次进校、现场登记、异常上报与处置；核验写 `action=''核验''`（`result` 取 `通过`/`失败`）、放行写 `action=''放行''`、离校写 `action=''离校''`、现场登记写 `action=''现场登记''`、异常上报写 `action=''异常上报''`、异常处置写 `action=''异常处置''` 审计。
9. 创建 `backend/src/modules/visit/internal/visitor.service.ts` — 令牌签发（32 字节 base64url，SHA-256 入库）、本人列表/详情、访客改期/取消/确认。
10. 创建 `backend/src/modules/visit/internal/consent.service.ts` — 每次提交写两条告知记录。
11. 创建 `backend/src/modules/visit/index.ts` — 导出 `getAppointmentForCompliance`、`eraseAppointmentPii`、`expireAppointments`、`confirmRescheduleTimeout`。
12. 创建定时任务 `appointment-expire`（cron `* * * * *`）— 起时刻已过且仍 `待审核/已改期` → `已过期`；`reschedule_deadline` 已过 → `已过期`；在 `index.ts` 用 `registerJob` 登记。
13. 创建 `backend/src/modules/visit/__tests__/appointment.rules.test.ts`、`review.rules.test.ts`、`gate.rules.test.ts`、`visitor.rules.test.ts`；核验窗口边界用注入 `now` 的纯函数断言，不依赖真实时钟。
14. 创建 `scripts/visitor-fixture.sh` — 用 `curl -c h5.txt` 调用 `POST /visitor/appointments` 完成一次合法提交，从响应 `data.visitorToken` 写出 `h5.token`；`h5.txt` 与 `h5.token` 供本卡与 `VIS-P1-I06` 的令牌类验证共用。

### 前端
15. 创建 `frontend/src/views/visit/AppointmentsPage.vue` — 列表 + 筛选（访客姓名 COPY-191、状态 COPY-195、到访日期 COPY-196；查询/重置 COPY-197/198）、详情抽屉、改期、取消；四态齐全（`LoadingState` / `ErrorState` COPY-355 + COPY-356 / `EmptyState` COPY-082 / 表格）。列表列固定为预约编号、访客、被访人、到访时段、状态、操作；分页默认 20；操作列固定右侧；仅 `待审核`、`已改期`、`已通过` 三类状态渲染「改期」「取消预约」，`已到访(在校中)`、`已离校` 只保留「查看详情」，终态（`已拒绝`、`已过期`、`已取消`）在详情底部显示 COPY-095。
16. 详情抽屉标题 COPY-394：读取 `route.query.appointmentId` 时自动打开对应预约，未知 id 关闭抽屉并 Toast COPY-008；抽屉内展示预约编号（附 CopyButton）、访客信息、时段、状态、随行、时间线 COPY-093/094；抽屉打开期间 `GET /appointments/:id` 独立加载态与错误态。
17. 改期弹窗 COPY-086：开始/结束时间选择器，提交期间按钮 `loading` 禁用；成功 Toast COPY-087 并刷新列表与抽屉。取消预约经 ConfirmDialog COPY-088/089，取消原因选填 COPY-091/092，成功 Toast COPY-090；终态行点击操作返回 COPY-010 Toast。
18. 创建 `frontend/src/views/visit/AppointmentForm.vue` — 后台代提表单弹窗（由 `AppointmentsPage` 的 COPY-051 打开）：字段与占位符 COPY-052…068，随行区 COPY-069…076（上限 10），校门为选填下拉（来源 `GET /gate/form-options`）；前端逐字校验见文案表；提交按钮 COPY-077/COPY-078，成功 Toast COPY-079，命中黑名单在表单顶部显示 COPY-080 提示条且不阻断提交。
19. 创建 `frontend/src/views/visit/ReviewsPage.vue` — 待审核列表 COPY-097/098、空态 COPY-099；列表列为预约编号、访客、类型、到访时段、事由、操作；四态同 task 15；行操作 COPY-100/101/102；同意经 ConfirmDialog COPY-103/104 → Toast COPY-105；拒绝弹窗 COPY-106/107/108 → Toast COPY-109；提议改期弹窗 COPY-110/111 → Toast COPY-112；三个动作提交期间按钮 `loading` 禁用，成功后该行移出列表并刷新待办计数；详情内「审核留痕」COPY-115/116/117/118，支持按预约编号筛选；「审核人配置」仅 admin 渲染（COPY-113/114），保存按钮 `loading` 禁用。
20. 创建 `frontend/src/views/visit/GatePage.vue` — 上方当日 KPI（当日预约 COPY-037、待核验 COPY-035、在校访客 COPY-038、异常待处理 COPY-036）；凭证输入 COPY-120/121、校门下拉 COPY-122/123、核验 COPY-124/125；结果卡按 COPY-129/130 与失败原因 COPY-131…134 渲染，命中时展示姓名、被访人、到访时段、校门、状态；放行 COPY-126→COPY-135、离校 COPY-136→COPY-137、再次进校 COPY-138→COPY-139。
21. 黑名单结果只渲染「拦截放行」按钮 COPY-128：点击调用 `POST /gate/incidents`（`incident_type=''黑名单命中''`）并 Toast COPY-131，绝不调用 `POST /gate/admit`；不提供任何放行覆盖入口。
22. 现场登记弹窗 COPY-140…143：两份告知勾选框默认未勾选；前端不拦截提交，服务端 422 时按 COPY-348 提示并聚焦告知区，黑名单仍硬拦；异常上报弹窗 COPY-144…149；异常列表 COPY-150/151；「处置」按钮 COPY-152 与处置弹窗 COPY-153…158 仅 admin 渲染；当日进出 COPY-159/160/161/162；页面四态同 task 15。
23. 创建 `frontend/src/views/visit/H5ApplyPage.vue` — 三步（COPY-164/165/166）：第一步表单字段与校验同后台；第二步展示 COPY-167…172 两份告知，勾选框默认未勾选；前端不拦截提交，服务端 422 时按 COPY-348 提示、自动切回第二步并聚焦告知区；第三步汇总后「提交申请」COPY-173，提交期间按钮 `loading` 禁用；成功页 COPY-174/175 与「查看我的申请」COPY-176；全页触控目标 ≥44×44px，底部按钮使用 `env(safe-area-inset-bottom)`。
24. 创建 `frontend/src/views/visit/H5MyPage.vue` — 我的申请列表 COPY-177/184；详情展示进校凭证 COPY-178/179/180（二维码 + 6 位短码）；确认改期 COPY-181/182/183 仅在 `已改期` 状态展示；改期与取消仅在 `待审核`、`已改期`、`已通过` 展示，复用 task 17 的弹窗与文案；页面底部「个人信息说明」链接 COPY-187 指向 `/h5/privacy`；消息区展示 `messages[]` 最近 5 条，超出时提供展开；四态齐全（H5 版 `LoadingState`/`ErrorState`/`EmptyState`）。
25. 创建 `frontend/src/views/visit/routes.ts` — `/appointments`、`/reviews`、`/gate`、`/h5/apply`、`/h5/my`；H5 路由标记 `meta.layout=''h5''` 且不走后台鉴权守卫。
26. 创建 `frontend/src/views/visit/permissions.ts`。
27. 所有写操作按钮在请求期间 `loading` 且禁用，防重复提交；所有失败提示读取响应信封 `message` 并以 Toast 呈现，不拼接英文或状态码。

### 用户可见文案清单（本卡必含，逐字）
| 类别 | 触发场景 | COPY | 逐字文案 | 渲染位置 |
|------|---------|------|---------|---------|
| 预约页标题 | 后台 | COPY-050 | 访客预约 | PageHeader |
| 新增预约 | 按钮 | COPY-051 | 新增预约 | 按钮 |
| 预约详情 | 抽屉 | COPY-394 | 预约详情 | 抽屉标题 |
| 表单字段 | 后台/H5 | COPY-052…068 | 访客姓名、手机号、证件号、访客类型、被访人、到访时段、来访事由、车牌号（选填）、随行人员 | 表单 |
| 表单占位 | 后台/H5 | COPY-053…068 | 请输入访客姓名、请输入 11 位手机号、请输入身份证号或其他证件号、请选择访客类型、请选择被访教职工、请选择开始时间、请选择结束时间、请简要说明来访事由（2–100 字）、请输入车牌号 | 字段 |
| 随行 | 表单 | COPY-069…076 | 添加随行人员、与主访客关系、请选择关系、移除、最多添加 10 名随行人员 | 随行区 |
| 提交 | 按钮 | COPY-077 / COPY-078 | 提交预约、正在提交... | 按钮 |
| 提交成功 | 成功 | COPY-079 | 预约已提交，请等待被访人审核 | Toast |
| 黑名单软提示 | 命中 | COPY-080 | 该证件号曾命中安全名单，本次申请已记录并将重点核验 | 提示条 |
| 我的预约 | 列表 | COPY-081 / COPY-082 / COPY-083 | 我的预约、还没有预约记录、查看详情 | 列表 |
| 改期/取消 | 操作 | COPY-084 / COPY-085 / COPY-086 / COPY-087 | 改期、取消预约、修改到访时段、改期成功 | 按钮/弹窗 |
| 取消确认 | 弹窗 | COPY-088 / COPY-089 | 确认取消预约 / 取消后该预约不能恢复，访客将收到取消通知。是否继续？ | ConfirmDialog |
| 取消原因 | 弹窗 | COPY-091 / COPY-092 | 取消原因（选填）、请说明取消原因 | 字段 |
| 取消成功 | 成功 | COPY-090 | 预约已取消 | Toast |
| 进度 | 详情 | COPY-093 / COPY-094 / COPY-095 | 预约进度、暂无进度记录、该申请已结束，如需来访请重新扫码申请 | 时间线 |
| 审核页 | 后台 | COPY-097 / COPY-098 / COPY-099 | 被访人审核、待审核预约、暂无待审核预约 | PageHeader/列表 |
| 审核操作 | 行 | COPY-100 / COPY-101 / COPY-102 | 同意、拒绝、提议改期 | 按钮 |
| 同意确认 | 弹窗 | COPY-103 / COPY-104 | 确认同意该预约 / 同意后预约进入已通过，访客将收到审核结果通知。是否继续？ | ConfirmDialog |
| 同意成功 | 成功 | COPY-105 | 已同意该预约 | Toast |
| 拒绝弹窗 | 弹窗 | COPY-106 / COPY-107 / COPY-108 | 拒绝预约、拒绝原因、请输入 2–100 字的拒绝原因 | 弹窗 |
| 拒绝成功 | 成功 | COPY-109 | 已拒绝该预约，访客将收到拒绝原因 | Toast |
| 提议改期 | 弹窗 | COPY-110 / COPY-111 | 提议新的到访时段、访客需在 3 小时内确认，逾期预约将自动过期 | 弹窗 |
| 提议成功 | 成功 | COPY-112 | 改期提议已发送，等待访客确认 | Toast |
| 审核留痕 | 详情 | COPY-115 / COPY-116 / COPY-117 / COPY-118 | 审核留痕、暂无审核记录、审核决定、说明 | 表格 |
| 审核人配置 | admin | COPY-113 / COPY-114 | 审核人配置、未配置规则时，由被访教职工本人审核 | 页面 |
| 门卫页 | 后台 | COPY-119…128 | 门卫核验放行、预约编号 / 6 位短码、请扫描二维码或输入预约编号、6 位短码、核验校门、请选择校门、核验、正在核验...、核验并放行、无预约 · 现场登记、拦截放行 | 页面 |
| 核验结果 | 结果 | COPY-129…134 | 核验通过，可以放行、核验未通过：{原因}、该访客命中安全名单，禁止放行，已记录异常、当前不在预约核验时段内、该预约已过期，不能放行、该预约尚未通过审核，不能放行 | 结果区 |
| 放行/离校 | 操作 | COPY-135…139 | 已放行，进校时刻已登记、离校登记、已登记离校、再次进校、已登记再次进校 | 按钮/Toast |
| 现场登记 | 弹窗 | COPY-140…143 | 无预约现场登记、现场登记仅限门卫协助访客完成，提交前需访客确认两份告知、登记并放行、现场登记完成，访客已放行 | 弹窗 |
| 异常上报 | 弹窗 | COPY-144…149 | 上报异常、异常类型、异常说明、请描述现场情况、提交异常、异常已上报 | 弹窗 |
| 异常列表 | 页面 | COPY-150…158 | 异常记录、暂无异常记录、处置、处置异常、处置说明、请输入处置说明、标记为已处理、标记为已忽略、异常已处置 | 列表/弹窗 |
| 当日进出 | 页面 | COPY-159 / COPY-160 / COPY-161 / COPY-162 | 今日进出、今天还没有访客进出记录、已在校时长、操作 | 表格 |
| 当日 KPI | 门卫页 | COPY-035…038 | 待核验、异常待处理、今日预约、在校访客 | KPI 卡片 |
| H5 申请 | 页面 | COPY-163…166 | 来访申请、填写信息、阅读告知、提交 | 步骤页 |
| 告知标题正文 | 页面 | COPY-167…170 | 安全告知、个人信息授权告知及两段告知正文 | 告知区 |
| 告知勾选 | 页面 | COPY-171 / COPY-172 | 我已阅读并同意《安全告知》、我已阅读并同意《个人信息授权告知》 | 勾选框 |
| 提交按钮 | 页面 | COPY-173 | 提交申请 | 按钮 |
| 提交成功 | 页面 | COPY-174 / COPY-175 / COPY-176 | 申请已提交、被访人审核通过后，您可凭本页凭证进校。、查看我的申请 | 成功页 |
| 我的申请 | H5 | COPY-177 / COPY-178 / COPY-179 / COPY-180 / COPY-184 | 我的申请、进校凭证、到校后请向门卫出示二维码或 6 位短码、短码仅用于现场核对，不能用于查询他人信息、您还没有提交过申请 | 页面 |
| 确认改期 | H5 | COPY-181 / COPY-182 / COPY-183 | 确认改期、已确认改期，等待被访人重新审核、被访人提议将到访时段调整为 {时段}，请在 {截止时间} 前确认 | 页面 |
| 隐私入口 | H5 页脚 | COPY-187 | 个人信息说明 | 链接 |
| 校验提示 | 表单 | COPY-324…343 | 姓名、手机号、证件号、类型、被访人、起止时间、事由、随行逐字提示 | 字段下方 |
| 时段校验 | 表单 | COPY-344 / COPY-345 / COPY-346 | 所选时段不在可预约时间内、所选时段属于禁止入校时段、开始时间必须晚于当前时间 | 字段下方 |
| 重复预约 | 服务端 | COPY-347 | 该证件号在所选时段已有未完成的预约 | 响应 message |
| 未勾选告知 | 服务端 | COPY-348 | 请阅读并勾选《安全告知》和《个人信息授权告知》 | 提示条 |
| 拒绝原因校验 | 服务端 | COPY-349 / COPY-350 / COPY-351 | 请填写拒绝原因、拒绝原因至少 2 个字符、拒绝原因不能超过 100 个字符 | 字段下方 |
| 处置说明校验 | 服务端 | COPY-352 | 请填写处置说明 | 字段下方 |
| 重复核销 | 服务端 | COPY-011 | 该凭证已核销，不能重复放行 | Toast |
| 状态冲突 | 服务端 | COPY-010 | 当前状态不允许该操作，请刷新后重试 | Toast |
| 越权查看 | 服务端 | COPY-006 | 您无权查看该记录 | 页面/Toast |

### UI 完整性检验结论（2026-10-19）
- 检验范围：`/appointments`、`/reviews`、`/gate`、`/h5/apply`、`/h5/my` 及代提表单。
- 通过项：六页四态；终态仅查看详情；详情深链 `?appointmentId=`；H5 三步表单 422 定位；44×44px 与安全区；黑名单只写异常不放行；审核与核验动作 `loading` 禁用。
- 对应缺陷：U6、U7、U8、U9、U15。
| 加载中... | 各页首次取数 | COPY-357 | 加载中... | LoadingState |
| 加载失败 | 各页取数失败 | COPY-355 | 数据加载失败，请点击重试 | ErrorState |
| 重试按钮 | 加载失败态 | COPY-356 | 重试 | ErrorState 按钮 |

## 验证
- [ ] `cd backend && npx vitest run src/modules/visit/__tests__` → 全部通过。
- [ ] `D1=$(date -d ''+1 day'' +%F)`；`curl -b host.txt -H ''Content-Type: application/json'' -H "X-CSRF-Token: $(curl -s -b host.txt http://localhost:3000/api/v1/auth/csrf | jq -r .data.csrf_token)" -d "{\"visitor_type_id\":\"55555555-5555-4555-8555-555555555551\",\"visitor_name\":\"林晓\",\"visitor_phone\":\"13800138000\",\"visitor_id_no\":\"110101199003071233\",\"host_id\":\"33333333-3333-4333-8333-333333333333\",\"visit_start\":\"${D1}T10:00:00+08:00\",\"visit_end\":\"${D1}T11:00:00+08:00\",\"reason\":\"业务洽谈\"}" http://localhost:3000/api/v1/appointments` → 200，`status=待审核`，返回 `appoint_no` 与 `short_code`；`docker compose exec -T db psql -U visitor -d visitor_system -c "select count(*) from operation_logs where action=''新增预约''"` 增加 1。
- [ ] 同证件号提交 `${D1}T10:30:00+08:00`–`${D1}T11:30:00+08:00` → 422，`field=visit_start`，`message` 为 COPY-347。
- [ ] `curl -b host.txt -X POST -H "X-CSRF-Token: $(curl -s -b host.txt http://localhost:3000/api/v1/auth/csrf | jq -r .data.csrf_token)" http://localhost:3000/api/v1/reviews/88888888-8888-4888-8888-888888888801/approve` → 200；P1 状态 `已通过`；`notifications` 新增 1 条；`operation_logs` 新增 `action=''审核同意''`。
- [ ] 用上一步新建预约的 `short_code` 立即调用 `POST /gate/verify`（该预约在明日窗口）→ 409 + COPY-132，`operation_logs` 新增 `action=''核验''`、`result=''失败''`。
- [ ] `WALKIN=$(curl -s -b guard.txt -X POST -H ''Content-Type: application/json'' -H "X-CSRF-Token: $(curl -s -b guard.txt http://localhost:3000/api/v1/auth/csrf | jq -r .data.csrf_token)" -d ''{"visitor_name":"赵强","visitor_phone":"13900139000","visitor_id_no":"310101199002022349","visitor_type_id":"55555555-5555-4555-8555-555555555551","host_id":"33333333-3333-4333-8333-333333333333","gate_id":"66666666-6666-4666-8666-666666666661","reason":"临时代送物品","consent":{"safety":true,"privacy":true}}'' http://localhost:3000/api/v1/gate/walk-in)` → `echo "$WALKIN" | jq -r .data.status` 为 `已到访(在校中)`；`consent_records` 新增 2 条；该预约 `visit_credentials.usage_status=''已使用''`。
- [ ] `CODE=$(echo "$WALKIN" | jq -r .data.short_code)`；`curl -b guard.txt -X POST -H ''Content-Type: application/json'' -H "X-CSRF-Token: $(curl -s -b guard.txt http://localhost:3000/api/v1/auth/csrf | jq -r .data.csrf_token)" -d "{\"code\":\"$CODE\",\"gate_id\":\"66666666-6666-4666-8666-666666666661\"}" http://localhost:3000/api/v1/gate/depart` → 200，`status=已离校`；随后同一 `$CODE` 调用 `POST /gate/admit` → 200，`status=已到访(在校中)`，`visit_credentials.usage_status` 仍为 `已使用`，`passage_records` 新增 1 条 `enter`。
- [ ] `bash scripts/visitor-fixture.sh` → 生成 `h5.txt` 与 `h5.token`；`curl -H "Authorization: Bearer $(cat h5.token)" http://localhost:3000/api/v1/visitor/appointments` → 200，只返回本人 1 条。
- [ ] `curl -b h5.txt -H ''Content-Type: application/json'' -d ''{"visitor_name":"钱多","visitor_phone":"13700137000","visitor_id_no":"110101199003071233","visitor_type_id":"55555555-5555-4555-8555-555555555551","host_id":"33333333-3333-4333-8333-333333333333","visit_start":"''${D1}''T13:00:00+08:00","visit_end":"''${D1}''T14:00:00+08:00","reason":"咨询入学","consent":{"safety":false,"privacy":false}}'' http://localhost:3000/api/v1/visitor/appointments` → 422，`field=consent`，`message` 为 COPY-348。
- [ ] 浏览器打开 `/h5/apply` → 三步流程可完成；成功后 `/h5/my` 显示二维码与 6 位短码。
- [ ] `/gate` 打开 → 当日视图出现上一步现场登记的访客；`/reviews` 以 T001 登录 → 只显示审核人解析为 T001 的待审核预约。
- [ ] 深链接 `/appointments?appointmentId=88888888-8888-4888-8888-888888888801` → 直接打开对应详情抽屉；未知 id → Toast COPY-008 且抽屉关闭。
- [ ] 黑名单访客（P10）在 `/gate` 核验 → 结果区仅出现「拦截放行」；点击后 `operation_logs` 新增 `action=''异常上报''`，`passage_records` 不新增记录。
- [ ] guard 登录 `/gate` → 异常列表无「处置」按钮；admin 登录可见并可提交处置说明。
- [ ] H5 真机或 DevTools 375×667：`/h5/apply` 三步可完成；未勾选两份告知直接提交 → 服务端 422，页面切回第二步并显示 COPY-348；`/h5/my` 无横向滚动，页脚「个人信息说明」跳 `/h5/privacy`。
- [ ] 后台四页断网验证：`docker compose stop backend` 后 `/appointments`、`/reviews`、`/gate` 均显示 COPY-355 与 COPY-356。
- [ ] `grep -Rn "alert(\|confirm(" frontend/src/views/visit` 无输出；`grep -n "gate/admit" frontend/src/views/visit/GatePage.vue` 仅出现在放行动作，不出现在拦截分支。

### 测试用例与结果比对
| TC | 测试点 | 已定预期（摘自 output/v1.0/测试.md） | 本次实际运行结果（未执行） | 比对结论 |
|----|--------|--------------------------------------|----------------------------|----------|
| TC-PT-006 | 访客免密进入 H5 | 令牌直接进「我的申请」；短码请求详情 403 + 审计 | 未执行；落点：`visitorTokenAuth` + `GET /visitor/appointments/:id` + `H5MyPage.vue` | 设计可达 |
| TC-AP-001 | 提交预约成功主流程 | `待审核`；生成编号与短码；H1 收到通知 | 未执行；落点：`POST /appointments` + `nextAppointmentNo` + `generateShortCode` + `publishNotification` | 设计可达 |
| TC-AP-002 | 手机号格式校验 | `13800138000` 放行；`1380013800`/`12345678901` 422 `field=visitor_phone` | 未执行；落点：`validators.isValidPhone` + `validateBody` | 设计可达 |
| TC-AP-003 | 证件号校验 | ①④⑤ 放行；②③⑥⑦ 422 `field=visitor_id_no` | 未执行；落点：`isValidIdCard`（GB 11643 校验位）+ `isValidOtherId`（5–20 位） | 设计可达 |
| TC-AP-004 | 到访时段规格校验 | ③④ 放行；①②⑤ 422 `field=visit_end` | 未执行；落点：`rules.validateVisitWindow`（同日晚于开始、15–240 分钟） | 设计可达 |
| TC-AP-005 | 必填缺失拦截 | `field` 依次 `host_id`、`visit_start`、`reason` | 未执行；落点：`validateBody` schema 字段顺序 | 设计可达 |
| TC-AP-006 | 随行明细 ≤10 条 | 10 条成功 `people_count=11`；11 条 422 `field=companions` | 未执行；落点：`rules.validateCompanions` + `people_count` | 设计可达 |
| TC-AP-007 | 随行证件号同规则校验 | 422 `field=companions[i].id_no` | 未执行；落点：`validateBody` 数组元素路径 + `isValidIdCard` | 设计可达 |
| TC-AP-008 | 黑名单预检覆盖随行（软提示不拦） | 创建成功；`black_hit=1`；软提示 | 未执行；落点：`checkBlacklist([主+随行])` + `black_hit` + COPY-080 | 设计可达 |
| TC-AP-009 | 时段可用且未过期校验 | 06:59 422；09:00 422；09:01 放行 | 未执行；落点：`rules.timeRuleDecision` + `visit_start > now` | 设计可达 |
| TC-AP-010 | 防重复：未完结集闭区间相交拒绝 | ①②③ 422 `field=visit_start`；④ 放行；已改期参与 | 未执行；落点：`rules.findOverlap` + `OPEN_STATUSES` + advisory lock | 设计可达 |
| TC-AP-011 | 终态后可重发 | 已拒绝/已过期/已取消/已离校均不参与防重复 | 未执行；落点：`OPEN_STATUSES` 不含四类 + 旧记录保留 | 设计可达 |
| TC-AP-012 | 禁入时段优先 | 10:30–11:30 422 `field=visit_start` | 未执行；落点：`timeRuleDecision` 先禁入后可预约 | 设计可达 |
| TC-AP-013 | 改期权限与可改边界 | 访客改期直接待审核；host/admin 提议 → 已改期；guard 403；P4/P5 409 | 未执行；落点：`PUT /appointments/:id/reschedule`、`PUT /visitor/appointments/:id/reschedule` + 状态校验 | 设计可达 |
| TC-AP-014 | 改期新时段重过校验（排除自身） | 仅与自身重叠成功；与 P2 相交 422 | 未执行；落点：`findOverlap(..., excludeId)` + 全量校验复用 | 设计可达 |
| TC-AP-015 | 取消预约成功 | `已取消`；写审计；记录保留 | 未执行；落点：`PUT /appointments/:id/cancel` + `writeAudit` + `appointment_status_history` | 设计可达 |
| TC-AP-016 | 已到访取消返回 409 | 409；状态不变 | 未执行；落点：`rules.assertTransition(''已到访(在校中)'',''已取消'')` 拒绝 | 设计可达 |
| TC-AP-017 | 预约状态 8 态跟踪与同源 | 8 态中文枚举与流转时间；与台账同源 | 未执行；落点：`appointment_status_history` + `StatusTag` + 台账共用 `status` | 设计可达 |
| TC-AT-001 | host 仅见本人相关待审核 | H1 见 P1/P3，不见 P2；按审核人归属 | 未执行；落点：`review.service` 条件 `reviewer_id=当前用户 OR admin`（被访人仅在 `resolveReviewer` 将其解析为审核人时可见） | 设计可达 |
| TC-AT-002 | admin 全校兜底 | 可见全部待审核 | 未执行；落点：`review.service` admin 分支 | 设计可达 |
| TC-AT-003 | 越权读他人预约 403＋审计 | 403 + 越权审计 | 未执行；落点：`review.service` 对象级校验 + `writeAudit(''越权拦截'')` | 设计可达 |
| TC-AT-004 | 审核同意 | `已通过`；访客收到通过通知 | 未执行；落点：`POST /reviews/:id/approve` + `publishNotification(''审核结果'')` | 设计可达 |
| TC-AT-005 | 拒绝原因必填 2–100 字 | 0/1/101 字 422 `field=reject_reason`；2/100 成功 | 未执行；落点：express-validator `.isLength({min:2,max:100})` + `unprocessable` | 设计可达 |
| TC-AT-006 | 改期＝提议改期、重过校验、次数不限、超时过期 | 无时段 422；提议→已改期；确认→待审核；3h+10min 已过期；第 3 轮成功；已改期直接同意 409 | 未执行；落点：`reschedule` + `confirm-reschedule` + `confirmRescheduleTimeout` + 状态校验 | 设计可达 |
| TC-AT-007 | 重复处理 409 | 409；原状态不变 | 未执行；落点：`assertTransition` + `SELECT FOR UPDATE` | 设计可达 |
| TC-AT-008 | 审核人默认被访教职工 | 默认审核人=被访教职工 | 未执行；落点：`resolveReviewer` 返回 `host` 对应账号 | 设计可达 |
| TC-AT-009 | 审核人配置前向不追溯（含命中优先级） | 新预约落 R1；P0 不回改；最具体优先；同具体度按声明顺序 | 未执行；落点：`resolveReviewer` 五级优先 + `declaration_order` | 设计可达 |
| TC-AT-010 | 审核写日志含四要素 | 操作人/时间/决定/原因 | 未执行；落点：`operation_logs` 过滤 `object_type=''appointment''` 且 `action in (''审核同意'',''审核拒绝'',''改期'')` | 设计可达 |
| TC-AT-011 | 按预约维度筛选日志 | 仅返回该预约日志 | 未执行；落点：`GET /reviews/:id/logs` + `object_id` 过滤 | 设计可达 |
| TC-GV-001 | 现场核验一致且在有效时段放行 | 09:45–11:15 含端点放行；09:44、11:16 拦截 | 未执行；落点：`rules.inVerifyWindow` + `POST /gate/verify` | 设计可达 |
| TC-GV-002 | 核验不一致/过期/黑名单拦截 | 均拦截并提示原因；黑名单写异常+通知+审计 | 未执行；落点：`gate.service` 分支 + COPY-131/132/133/134 + `publishSecurityNotification` | 设计可达 |
| TC-GV-003 | 有预约放行记录时刻与放行人 | `已到访(在校中)`；记录 `checkin_at`、放行人、校门 | 未执行；落点：`POST /gate/admit` + `passage_records` | 设计可达 |
| TC-GV-004 | 无预约现场登记放行 | `已到访(在校中)`；2 条告知；豁免未过期/已审核；仍过黑名单；短码立即已用 | 未执行；落点：`POST /gate/walk-in` + `consent.service` + `generateShortCode` | 设计可达 |
| TC-GV-005 | 现场登记复用 AP 采集项与校验 | 422 `field=visitor_phone`/`visitor_id_no` | 未执行；落点：`walk-in` 复用 `validateBody` 与 `rules` | 设计可达 |
| TC-GV-006 | 短码规则 6 位全局唯一 | `^\d{6}$`；100 条不重复；终态不可核验；记录保留 | 未执行；落点：`generateShortCode` + `visit_credentials.short_code UNIQUE` + 终态校验 | 设计可达 |
| TC-GV-007 | 首次核销成功、重复核销拒绝 | 首次 `已用`；在校中再次核销 409 | 未执行；落点：`visit_credentials.usage_status` + COPY-011 | 设计可达 |
| TC-GV-008 | 进校/离校登记形成在校中 | `已到访(在校中)` → `已离校`；两次时刻记录 | 未执行；落点：`POST /gate/admit`、`POST /gate/depart` + `checkin_at`/`checkout_at` | 设计可达 |
| TC-GV-009 | 当天多次进出、已离校为准终态 | 允许再次进校；凭证仍已用；新增 `enter` 记录 | 未执行；落点：`POST /gate/admit` 对当日 `已离校` 追加 `enter` 通行记录 + S-44 | 设计可达 |
| TC-GV-010 | 时刻精确到分钟 | 展示 `yyyy-MM-dd HH:mm`；审计/通知到秒 | 未执行；落点：`formatMinute` + `formatSecond` | 设计可达 |
| TC-GV-011 | 异常上报写记录并通知管理员 | 4 类均接受；`待处理`；通知管理员；黑名单另通知门卫；审计 | 未执行；落点：`POST /gate/incidents` + `INCIDENT_TYPES` + `publishNotification` + `writeAudit(''异常上报'')` | 设计可达 |
| TC-GV-012 | 异常可查（含处理状态机） | 可查；admin 处置需说明；guard 403；缺说明 422 | 未执行；落点：`GET /gate/incidents` + `PUT /gate/incidents/:id/disposition` + `requireAdmin` + `writeAudit(''异常处置'')` | 设计可达 |
| TC-GV-013 | 门口当日视图仅当日数据 | 仅本地当日预约、待核验、在校中 | 未执行；落点：`GET /gate/today` + `localDayRange` | 设计可达 |
| TC-VS-001 | 我要申请提交成功 | 复用 AP 校验；`待审核`；生成短码与编号 | 未执行；落点：`POST /visitor/appointments` 复用 `appointment.service` + `H5ApplyPage.vue` | 设计可达 |
| TC-VS-002 | 仅本人可见、越权 403 | 本人可读；读他人 403 + 审计。**O-01**：令牌过期后换发无渠道 | 未执行；落点：`visitorTokenAuth` + `GET /visitor/appointments/:id` 令牌绑定校验 | 部分可达（剔除 O-01 孤儿断言「手机号+验证码重新换取令牌」；保留本人可见与越权 403） |
| TC-VS-003 | 页内出示二维码凭证 | 二维码与 6 位短码；短码不能读详情 | 未执行；落点：`H5MyPage.vue` + 二维码由 `appointment_no` 生成 + 短码只读展示 | 设计可达 |
| TC-VS-004 | 未勾选告知不可提交 | 422 `field=consent`；两项勾选后放行 | 未执行；落点：`consent.service` 校验 + `validateBody` | 设计可达 |
| TC-VS-005 | 每次提交均需确认、留痕按预约含时间戳 | 第二次仍需勾选；每次独立记录 | 未执行；落点：每次 POST 插入 2 条 `consent_records`，不读历史 | 设计可达 |
| TC-VS-006 | 扫码直达我要申请 | URL 路径 `/h5/apply` | 未执行；落点：`shared.routes` H5 根 + `views/visit/routes.ts` | 设计可达 |
| TC-VS-007 | 移动端兼容与适配 | 三环境完成四项核心动作；320–480px 无横向滚动 | 未执行；落点：`H5Layout.vue` + viewport meta + `tokens.css` | 设计可达（需集成闭环真机验证） |
| TC-SM-004 | 授权告知留痕 + 最小必要收集 | 每条预约 2 条告知记录；采集字段 ⊆ PRD §5.1 | 未执行；落点：`consent_records` + 表单字段白名单 | 设计可达 |
| TC-OR-003 | 越权访问 403、对象级读写都落强制点 | 读写均 403 | 未执行；落点：`appointment.service`/`review.service` 对象级校验 | 设计可达 |
| TC-OR-004 | 越权写审计留痕 | 新增 `action=''越权拦截''` 审计 | 未执行；落点：`writeAudit` 于对象级拒绝分支 | 设计可达 |
| TC-OR-006 | 对象级隔离以绑定实体 id 为准 | 以 `host_id`/绑定实体 id 判定 | 未执行；落点：`GET /reviews*` 及审核动作按 `reviewer_id`；`GET /appointments/:id` 按 `host_id` 与 `users.host_id` 判定 | 设计可达 |
| TC-OR-007 | 越权写「越权拦截」审计 | user/time/object/result 齐全 | 未执行；落点：`writeAudit` 字段映射 | 设计可达 |

## 在开始改动之前
1. 读取 `conventions.md` §13 状态机与 `p1-contracts.md` §四。
2. 读取 `seed-anchors.sql` 预约、短码、告知、通行、异常段。
3. 检查 master 与 notify 门面导出是否可用。
4. 检查 `frontend/src/views/visit/` 是否已存在。

## 完成改动之后
1. 列出创建/修改的文件。
2. 粘贴四组单测与关键 curl 输出。
3. 确认 54 条 TC 比对表完成，O-01 已显式剔除。
4. 列出剩余风险（移动端兼容与 1 万条性能由集成闭环卡验证）。
5. 将本卡「测试用例与结果比对」表的「本次实际运行结果」列填写为真实执行结果，写入 `docs/trace/runs/v1/test-results/VIS-P1-I05.md`：逐条 TC 给出命令、原始输出摘要、通过/失败结论；失败项附现象、根因、修复文件与回归命令。
6. 写入 `docs/memory/2026-10-19/VIS-P1-I05.md`。
', '## 目标
交付预约、审核、门卫核验放行、现场登记、异常、访客 H5 与对象级隔离，完整贯通 8 个预约状态。

承载需求：REQ-AP-001、REQ-AP-002、REQ-AP-003、REQ-AP-004、REQ-AP-005、REQ-AT-001、REQ-AT-002、REQ-AT-003、REQ-AT-004、REQ-GV-001、REQ-GV-002、REQ-GV-003、REQ-GV-004、REQ-GV-005、REQ-GV-006、REQ-VS-001、REQ-VS-002、REQ-VS-003、REQ-VS-004、REQ-OR-003（对象级数据范围）；支撑 REQ-SM-001 的提交/审核/核验/离校审计。

## 验收标准
- [ ] 预约创建校验手机号、证件号、时段、必填、随行 ≤10、黑名单软提示、防重复、时段规则；后台代提表单与 H5 表单校验口径一致。
- [ ] 审核支持同意、拒绝（原因 2–100 字）、提议改期；改期经访客确认回 `待审核`；3 小时未确认转 `已过期`；三个动作提交期间按钮禁用。
- [ ] 门卫核验窗口 `[visit_start−15min, visit_end+15min]`；重复核销 409；离校当天再次进校不二次核销。
- [ ] 现场登记豁免未过期/已审核，仍过黑名单；两份告知默认未勾选且必勾选；短码立即置为已用。
- [ ] 异常 4 类可上报；管理员处置需说明；guard 处置按钮不渲染且接口 403。
- [ ] 黑名单核验结果只出现「拦截放行」，点击写异常且不调用放行接口。
- [ ] 访客令牌只能读本人预约；短码不能读详情；越权写审计。
- [ ] 后台四个页面均具备加载/失败/空/数据四态；H5 页面 320–480px 无横向滚动，触控目标 ≥44×44px。
- [ ] 创建预约写 `action=''新增预约''` 审计；离校登记写 `action=''离校''` 审计；两者均含操作人、时间、对象、结果、before/after。
- [ ] 54 条 TC 的逐条比对表填写完成。

## 相关背景

### 必读文件
- `conventions.md` — 约定 6 命名、约定 7 时间、约定 9 测试与验证、约定 10 前端交互与视觉、约定 12 文案、约定 13 状态机。
- `docs/trace/runs/v1/spac.md` §4.2.3 访客预约、§4.2.4 被访人审核、§4.2.5 门卫核验、§4.2.6 H5 申请、§4.2.7 H5 我的申请、§5.4/§5.5/§5.8 表、§6.3/§6.5 端点、§11 S-41/S-43/S-44/S-47。
- `docs/knowledge/shared-kernel-api.md` — 前端共享组件、Store 与请求封装签名。
- `docs/knowledge/phase-contracts/p1-contracts.md` §四。
- `roles.md` — 对象级数据范围。
- `seed-anchors.sql` — 11 条预约、短码、通行、异常、告知。
- `output/v1.0/测试.md` 第三至七、十三节；`output/v1.0/测试结果.md` 对应行。

### 共享内核 API（摘自 docs/knowledge/shared-kernel-api.md）
```ts
import { withTransaction } from ''../../../shared/db/pool'';
import { nextAppointmentNo, generateShortCode } from ''../../../shared/utils/appointmentNo'';
import { writeAudit } from ''../../../shared/audit/writeAudit'';
import { APPOINTMENT_STATUSES, OPEN_STATUSES } from ''../../../shared/constants/status'';
import { validateBody } from ''../../../shared/validation/validators'';
import { visitorTokenAuth } from ''../../../shared/middleware/visitorTokenAuth'';
import { badRequest, conflict, forbidden, notFound, unprocessable } from ''../../../shared/http/errors'';
```

### 模块模板（摘自 docs/knowledge/module-template.md）
- `backend/src/modules/visit/{index.ts,api/*.routes.ts,internal/*.service.ts,internal/domain/rules.ts,__tests__/}`。
- `frontend/src/views/visit/{AppointmentsPage.vue,ReviewsPage.vue,GatePage.vue,AppointmentForm.vue,H5ApplyPage.vue,H5MyPage.vue,routes.ts,permissions.ts}`。

### 上游契约（摘自 docs/knowledge/phase-contracts/p1-contracts.md）
- master 门面：`getActiveVisitorTypes`、`getActiveHosts`、`getActiveGates`、`getDictionaryItems`、`getConfig`、`getConfigNumber`、`resolveReviewer`、`upsertReviewerRules`、`checkBlacklist`。
- notify 门面：`publishNotification`、`publishSecurityNotification`。
- 共享表：`users`、`operation_logs`。

### 种子数据来源（摘自 seed-anchors.sql）
- P1 陈晨（待审核，10:00–11:00）、P2 刘洋（已通过）、P3 周敏（待审核，审核人 H1）、P4 孙浩（已到访(在校中)）、P5 吴倩（已离校）、P6 陈晨（已改期）、P7 郑凯（已拒绝）、P8 冯雪（已过期）、P9 蒋涛（已取消）、P10 韩梅（待审核，`black_hit=true`）、P11 杨帆（已通过）。
- 短码 `100001`–`100011`；随行 1 条（P1）；告知 22 条；通行 3 条；异常 3 条。

### 本域设计（摘自架构设计文档 §5.4、§5.5、§5.8、§6.3、§6.5）
- 8 态：待审核、已通过、已拒绝、已改期、已过期、已到访(在校中)、已离校、已取消。
- 未完结集 = `{待审核, 已改期, 已通过, 已到访(在校中)}`；终态 = `{已拒绝, 已过期, 已取消}`；到访成立集 = `{已通过, 已到访(在校中), 已离校}`。
- 防重复：同一 `visitor_id_no` 在未完结集闭区间相交即拒绝，排除自身；事务内 `pg_advisory_xact_lock` + 唯一索引。
- 改期：host 提议 → `已改期` → 访客确认 → `待审核`；访客主动改期直接 `待审核`；次数不限；`reschedule_deadline = 提议时刻 + 3h`。
- 核验窗口：`[visit_start−15min, visit_end+15min]`，端点含。
- 再次进校：`已离校` 且同一本地日期内 → `已到访(在校中)`，追加 `enter` 通行记录，不二次核销。
- 短码：`^\d{6}$` 全局唯一，随预约生成，终态后不可核验。
- 现场登记：不要求预约存在；两份告知必勾选；黑名单仍硬拦；短码生成后立即 `已使用`。

## 约束

### 命名约束
- 权限点：`visit:appointment:read|create|update`、`visit:review:read|approve|reject|reschedule`、`visit:gate:verify|admit|depart|walk_in`、`visit:incident:read|report|dispose`、`visit:visitor:read`。
- 前端 `visitStart`、`shortCode`；API `visit_start`、`short_code`。

### 其他约束
- [边界] 只写 visit 上下文与 `views/visit`；不改 master/notify 内部。
- [边界] 跨上下文只调用 master/notify 门面。
- [并发] 所有状态迁移 `SELECT ... FOR UPDATE`。
- [安全] 对象级隔离在 service 执行；越权返回 403 并写 `action=''越权拦截''` 审计。
- [告知] 每次 H5 提交与现场登记都插入独立 `consent_records`，不记忆上次勾选。

## 实施阶段
实现

## 任务

### 后端
1. 创建 `backend/src/modules/visit/api/appointments.routes.ts` — `GET /appointments/form-options`、`GET /appointments`、`POST /appointments`、`GET /appointments/:id`、`PUT /appointments/:id/reschedule`、`PUT /appointments/:id/cancel`。
2. 创建 `backend/src/modules/visit/api/reviews.routes.ts` — `GET /reviews`、`GET /reviews/:id`、`POST /reviews/:id/approve`、`POST /reviews/:id/reject`、`POST /reviews/:id/reschedule`、`GET /reviews/:id/logs`、`GET/PUT /reviews/assignment`；`GET/PUT /reviews/assignment` 必须在 `GET /reviews/:id` 之前注册，否则 `assignment` 会被 `:id` 吞掉；`PUT /reviews/assignment` 只调用 master 门面 `upsertReviewerRules` 写入，不直接写 `reviewer_rules`。
3. 创建 `backend/src/modules/visit/api/gate.routes.ts` — `GET /gate/today`、`GET /gate/form-options`、`POST /gate/verify`、`POST /gate/admit`、`POST /gate/depart`、`POST /gate/walk-in`、`GET/POST /gate/incidents`、`PUT /gate/incidents/:id/disposition`。请求体：`verify`/`admit`/`depart` 为 `{code, gate_id}`；`walk-in` 为 `{visitor_name, visitor_phone, visitor_id_no, visitor_type_id, host_id, gate_id, reason, consent:{safety:true,privacy:true}}`；`incidents` 为 `{code?, incident_type, description}`；`disposition` 为 `{status:''已处理''|''已忽略'', disposition_note}`。
4. 创建 `backend/src/modules/visit/api/visitor.routes.ts` — `GET /visitor/form-options`、`POST /visitor/appointments`（响应返回 `visitorToken` 并写 `vs.visitor` Cookie）、`GET /visitor/appointments`、`GET /visitor/appointments/:id`（含 `messages[]`）、`POST /visitor/appointments/:id/confirm-reschedule`、`PUT /visitor/appointments/:id/reschedule`、`PUT /visitor/appointments/:id/cancel`。
5. 创建 `backend/src/modules/visit/internal/domain/rules.ts` — 时段、证件、手机号、防重复、核验窗口、状态迁移、改期截止判定。
6. 创建 `backend/src/modules/visit/internal/appointment.service.ts` — 创建、改期、取消、状态历史；创建写 `action=''新增预约''` 审计，取消写 `action=''取消预约''` 审计，改期写 `action=''改期''` 审计。
7. 创建 `backend/src/modules/visit/internal/review.service.ts` — 同意、拒绝、提议改期、审核人归属查询、审核日志；同意写 `action=''审核同意''`、拒绝写 `action=''审核拒绝''`、提议改期写 `action=''改期''` 审计。
8. 创建 `backend/src/modules/visit/internal/gate.service.ts` — 核验、放行、离校、再次进校、现场登记、异常上报与处置；核验写 `action=''核验''`（`result` 取 `通过`/`失败`）、放行写 `action=''放行''`、离校写 `action=''离校''`、现场登记写 `action=''现场登记''`、异常上报写 `action=''异常上报''`、异常处置写 `action=''异常处置''` 审计。
9. 创建 `backend/src/modules/visit/internal/visitor.service.ts` — 令牌签发（32 字节 base64url，SHA-256 入库）、本人列表/详情、访客改期/取消/确认。
10. 创建 `backend/src/modules/visit/internal/consent.service.ts` — 每次提交写两条告知记录。
11. 创建 `backend/src/modules/visit/index.ts` — 导出 `getAppointmentForCompliance`、`eraseAppointmentPii`、`expireAppointments`、`confirmRescheduleTimeout`。
12. 创建定时任务 `appointment-expire`（cron `* * * * *`）— 起时刻已过且仍 `待审核/已改期` → `已过期`；`reschedule_deadline` 已过 → `已过期`；在 `index.ts` 用 `registerJob` 登记。
13. 创建 `backend/src/modules/visit/__tests__/appointment.rules.test.ts`、`review.rules.test.ts`、`gate.rules.test.ts`、`visitor.rules.test.ts`；核验窗口边界用注入 `now` 的纯函数断言，不依赖真实时钟。
14. 创建 `scripts/visitor-fixture.sh` — 用 `curl -c h5.txt` 调用 `POST /visitor/appointments` 完成一次合法提交，从响应 `data.visitorToken` 写出 `h5.token`；`h5.txt` 与 `h5.token` 供本卡与 `VIS-P1-I06` 的令牌类验证共用。

### 前端
15. 创建 `frontend/src/views/visit/AppointmentsPage.vue` — 列表 + 筛选（访客姓名 COPY-191、状态 COPY-195、到访日期 COPY-196；查询/重置 COPY-197/198）、详情抽屉、改期、取消；四态齐全（`LoadingState` / `ErrorState` COPY-355 + COPY-356 / `EmptyState` COPY-082 / 表格）。列表列固定为预约编号、访客、被访人、到访时段、状态、操作；分页默认 20；操作列固定右侧；仅 `待审核`、`已改期`、`已通过` 三类状态渲染「改期」「取消预约」，`已到访(在校中)`、`已离校` 只保留「查看详情」，终态（`已拒绝`、`已过期`、`已取消`）在详情底部显示 COPY-095。
16. 详情抽屉标题 COPY-394：读取 `route.query.appointmentId` 时自动打开对应预约，未知 id 关闭抽屉并 Toast COPY-008；抽屉内展示预约编号（附 CopyButton）、访客信息、时段、状态、随行、时间线 COPY-093/094；抽屉打开期间 `GET /appointments/:id` 独立加载态与错误态。
17. 改期弹窗 COPY-086：开始/结束时间选择器，提交期间按钮 `loading` 禁用；成功 Toast COPY-087 并刷新列表与抽屉。取消预约经 ConfirmDialog COPY-088/089，取消原因选填 COPY-091/092，成功 Toast COPY-090；终态行点击操作返回 COPY-010 Toast。
18. 创建 `frontend/src/views/visit/AppointmentForm.vue` — 后台代提表单弹窗（由 `AppointmentsPage` 的 COPY-051 打开）：字段与占位符 COPY-052…068，随行区 COPY-069…076（上限 10），校门为选填下拉（来源 `GET /gate/form-options`）；前端逐字校验见文案表；提交按钮 COPY-077/COPY-078，成功 Toast COPY-079，命中黑名单在表单顶部显示 COPY-080 提示条且不阻断提交。
19. 创建 `frontend/src/views/visit/ReviewsPage.vue` — 待审核列表 COPY-097/098、空态 COPY-099；列表列为预约编号、访客、类型、到访时段、事由、操作；四态同 task 15；行操作 COPY-100/101/102；同意经 ConfirmDialog COPY-103/104 → Toast COPY-105；拒绝弹窗 COPY-106/107/108 → Toast COPY-109；提议改期弹窗 COPY-110/111 → Toast COPY-112；三个动作提交期间按钮 `loading` 禁用，成功后该行移出列表并刷新待办计数；详情内「审核留痕」COPY-115/116/117/118，支持按预约编号筛选；「审核人配置」仅 admin 渲染（COPY-113/114），保存按钮 `loading` 禁用。
20. 创建 `frontend/src/views/visit/GatePage.vue` — 上方当日 KPI（当日预约 COPY-037、待核验 COPY-035、在校访客 COPY-038、异常待处理 COPY-036）；凭证输入 COPY-120/121、校门下拉 COPY-122/123、核验 COPY-124/125；结果卡按 COPY-129/130 与失败原因 COPY-131…134 渲染，命中时展示姓名、被访人、到访时段、校门、状态；放行 COPY-126→COPY-135、离校 COPY-136→COPY-137、再次进校 COPY-138→COPY-139。
21. 黑名单结果只渲染「拦截放行」按钮 COPY-128：点击调用 `POST /gate/incidents`（`incident_type=''黑名单命中''`）并 Toast COPY-131，绝不调用 `POST /gate/admit`；不提供任何放行覆盖入口。
22. 现场登记弹窗 COPY-140…143：两份告知勾选框默认未勾选；前端不拦截提交，服务端 422 时按 COPY-348 提示并聚焦告知区，黑名单仍硬拦；异常上报弹窗 COPY-144…149；异常列表 COPY-150/151；「处置」按钮 COPY-152 与处置弹窗 COPY-153…158 仅 admin 渲染；当日进出 COPY-159/160/161/162；页面四态同 task 15。
23. 创建 `frontend/src/views/visit/H5ApplyPage.vue` — 三步（COPY-164/165/166）：第一步表单字段与校验同后台；第二步展示 COPY-167…172 两份告知，勾选框默认未勾选；前端不拦截提交，服务端 422 时按 COPY-348 提示、自动切回第二步并聚焦告知区；第三步汇总后「提交申请」COPY-173，提交期间按钮 `loading` 禁用；成功页 COPY-174/175 与「查看我的申请」COPY-176；全页触控目标 ≥44×44px，底部按钮使用 `env(safe-area-inset-bottom)`。
24. 创建 `frontend/src/views/visit/H5MyPage.vue` — 我的申请列表 COPY-177/184；详情展示进校凭证 COPY-178/179/180（二维码 + 6 位短码）；确认改期 COPY-181/182/183 仅在 `已改期` 状态展示；改期与取消仅在 `待审核`、`已改期`、`已通过` 展示，复用 task 17 的弹窗与文案；页面底部「个人信息说明」链接 COPY-187 指向 `/h5/privacy`；消息区展示 `messages[]` 最近 5 条，超出时提供展开；四态齐全（H5 版 `LoadingState`/`ErrorState`/`EmptyState`）。
25. 创建 `frontend/src/views/visit/routes.ts` — `/appointments`、`/reviews`、`/gate`、`/h5/apply`、`/h5/my`；H5 路由标记 `meta.layout=''h5''` 且不走后台鉴权守卫。
26. 创建 `frontend/src/views/visit/permissions.ts`。
27. 所有写操作按钮在请求期间 `loading` 且禁用，防重复提交；所有失败提示读取响应信封 `message` 并以 Toast 呈现，不拼接英文或状态码。

### 用户可见文案清单（本卡必含，逐字）
| 类别 | 触发场景 | COPY | 逐字文案 | 渲染位置 |
|------|---------|------|---------|---------|
| 预约页标题 | 后台 | COPY-050 | 访客预约 | PageHeader |
| 新增预约 | 按钮 | COPY-051 | 新增预约 | 按钮 |
| 预约详情 | 抽屉 | COPY-394 | 预约详情 | 抽屉标题 |
| 表单字段 | 后台/H5 | COPY-052…068 | 访客姓名、手机号、证件号、访客类型、被访人、到访时段、来访事由、车牌号（选填）、随行人员 | 表单 |
| 表单占位 | 后台/H5 | COPY-053…068 | 请输入访客姓名、请输入 11 位手机号、请输入身份证号或其他证件号、请选择访客类型、请选择被访教职工、请选择开始时间、请选择结束时间、请简要说明来访事由（2–100 字）、请输入车牌号 | 字段 |
| 随行 | 表单 | COPY-069…076 | 添加随行人员、与主访客关系、请选择关系、移除、最多添加 10 名随行人员 | 随行区 |
| 提交 | 按钮 | COPY-077 / COPY-078 | 提交预约、正在提交... | 按钮 |
| 提交成功 | 成功 | COPY-079 | 预约已提交，请等待被访人审核 | Toast |
| 黑名单软提示 | 命中 | COPY-080 | 该证件号曾命中安全名单，本次申请已记录并将重点核验 | 提示条 |
| 我的预约 | 列表 | COPY-081 / COPY-082 / COPY-083 | 我的预约、还没有预约记录、查看详情 | 列表 |
| 改期/取消 | 操作 | COPY-084 / COPY-085 / COPY-086 / COPY-087 | 改期、取消预约、修改到访时段、改期成功 | 按钮/弹窗 |
| 取消确认 | 弹窗 | COPY-088 / COPY-089 | 确认取消预约 / 取消后该预约不能恢复，访客将收到取消通知。是否继续？ | ConfirmDialog |
| 取消原因 | 弹窗 | COPY-091 / COPY-092 | 取消原因（选填）、请说明取消原因 | 字段 |
| 取消成功 | 成功 | COPY-090 | 预约已取消 | Toast |
| 进度 | 详情 | COPY-093 / COPY-094 / COPY-095 | 预约进度、暂无进度记录、该申请已结束，如需来访请重新扫码申请 | 时间线 |
| 审核页 | 后台 | COPY-097 / COPY-098 / COPY-099 | 被访人审核、待审核预约、暂无待审核预约 | PageHeader/列表 |
| 审核操作 | 行 | COPY-100 / COPY-101 / COPY-102 | 同意、拒绝、提议改期 | 按钮 |
| 同意确认 | 弹窗 | COPY-103 / COPY-104 | 确认同意该预约 / 同意后预约进入已通过，访客将收到审核结果通知。是否继续？ | ConfirmDialog |
| 同意成功 | 成功 | COPY-105 | 已同意该预约 | Toast |
| 拒绝弹窗 | 弹窗 | COPY-106 / COPY-107 / COPY-108 | 拒绝预约、拒绝原因、请输入 2–100 字的拒绝原因 | 弹窗 |
| 拒绝成功 | 成功 | COPY-109 | 已拒绝该预约，访客将收到拒绝原因 | Toast |
| 提议改期 | 弹窗 | COPY-110 / COPY-111 | 提议新的到访时段、访客需在 3 小时内确认，逾期预约将自动过期 | 弹窗 |
| 提议成功 | 成功 | COPY-112 | 改期提议已发送，等待访客确认 | Toast |
| 审核留痕 | 详情 | COPY-115 / COPY-116 / COPY-117 / COPY-118 | 审核留痕、暂无审核记录、审核决定、说明 | 表格 |
| 审核人配置 | admin | COPY-113 / COPY-114 | 审核人配置、未配置规则时，由被访教职工本人审核 | 页面 |
| 门卫页 | 后台 | COPY-119…128 | 门卫核验放行、预约编号 / 6 位短码、请扫描二维码或输入预约编号、6 位短码、核验校门、请选择校门、核验、正在核验...、核验并放行、无预约 · 现场登记、拦截放行 | 页面 |
| 核验结果 | 结果 | COPY-129…134 | 核验通过，可以放行、核验未通过：{原因}、该访客命中安全名单，禁止放行，已记录异常、当前不在预约核验时段内、该预约已过期，不能放行、该预约尚未通过审核，不能放行 | 结果区 |
| 放行/离校 | 操作 | COPY-135…139 | 已放行，进校时刻已登记、离校登记、已登记离校、再次进校、已登记再次进校 | 按钮/Toast |
| 现场登记 | 弹窗 | COPY-140…143 | 无预约现场登记、现场登记仅限门卫协助访客完成，提交前需访客确认两份告知、登记并放行、现场登记完成，访客已放行 | 弹窗 |
| 异常上报 | 弹窗 | COPY-144…149 | 上报异常、异常类型、异常说明、请描述现场情况、提交异常、异常已上报 | 弹窗 |
| 异常列表 | 页面 | COPY-150…158 | 异常记录、暂无异常记录、处置、处置异常、处置说明、请输入处置说明、标记为已处理、标记为已忽略、异常已处置 | 列表/弹窗 |
| 当日进出 | 页面 | COPY-159 / COPY-160 / COPY-161 / COPY-162 | 今日进出、今天还没有访客进出记录、已在校时长、操作 | 表格 |
| 当日 KPI | 门卫页 | COPY-035…038 | 待核验、异常待处理、今日预约、在校访客 | KPI 卡片 |
| H5 申请 | 页面 | COPY-163…166 | 来访申请、填写信息、阅读告知、提交 | 步骤页 |
| 告知标题正文 | 页面 | COPY-167…170 | 安全告知、个人信息授权告知及两段告知正文 | 告知区 |
| 告知勾选 | 页面 | COPY-171 / COPY-172 | 我已阅读并同意《安全告知》、我已阅读并同意《个人信息授权告知》 | 勾选框 |
| 提交按钮 | 页面 | COPY-173 | 提交申请 | 按钮 |
| 提交成功 | 页面 | COPY-174 / COPY-175 / COPY-176 | 申请已提交、被访人审核通过后，您可凭本页凭证进校。、查看我的申请 | 成功页 |
| 我的申请 | H5 | COPY-177 / COPY-178 / COPY-179 / COPY-180 / COPY-184 | 我的申请、进校凭证、到校后请向门卫出示二维码或 6 位短码、短码仅用于现场核对，不能用于查询他人信息、您还没有提交过申请 | 页面 |
| 确认改期 | H5 | COPY-181 / COPY-182 / COPY-183 | 确认改期、已确认改期，等待被访人重新审核、被访人提议将到访时段调整为 {时段}，请在 {截止时间} 前确认 | 页面 |
| 隐私入口 | H5 页脚 | COPY-187 | 个人信息说明 | 链接 |
| 校验提示 | 表单 | COPY-324…343 | 姓名、手机号、证件号、类型、被访人、起止时间、事由、随行逐字提示 | 字段下方 |
| 时段校验 | 表单 | COPY-344 / COPY-345 / COPY-346 | 所选时段不在可预约时间内、所选时段属于禁止入校时段、开始时间必须晚于当前时间 | 字段下方 |
| 重复预约 | 服务端 | COPY-347 | 该证件号在所选时段已有未完成的预约 | 响应 message |
| 未勾选告知 | 服务端 | COPY-348 | 请阅读并勾选《安全告知》和《个人信息授权告知》 | 提示条 |
| 拒绝原因校验 | 服务端 | COPY-349 / COPY-350 / COPY-351 | 请填写拒绝原因、拒绝原因至少 2 个字符、拒绝原因不能超过 100 个字符 | 字段下方 |
| 处置说明校验 | 服务端 | COPY-352 | 请填写处置说明 | 字段下方 |
| 重复核销 | 服务端 | COPY-011 | 该凭证已核销，不能重复放行 | Toast |
| 状态冲突 | 服务端 | COPY-010 | 当前状态不允许该操作，请刷新后重试 | Toast |
| 越权查看 | 服务端 | COPY-006 | 您无权查看该记录 | 页面/Toast |

### UI 完整性检验结论（2026-10-19）
- 检验范围：`/appointments`、`/reviews`、`/gate`、`/h5/apply`、`/h5/my` 及代提表单。
- 通过项：六页四态；终态仅查看详情；详情深链 `?appointmentId=`；H5 三步表单 422 定位；44×44px 与安全区；黑名单只写异常不放行；审核与核验动作 `loading` 禁用。
- 对应缺陷：U6、U7、U8、U9、U15。
| 加载中... | 各页首次取数 | COPY-357 | 加载中... | LoadingState |
| 加载失败 | 各页取数失败 | COPY-355 | 数据加载失败，请点击重试 | ErrorState |
| 重试按钮 | 加载失败态 | COPY-356 | 重试 | ErrorState 按钮 |

## 验证
- [ ] `cd backend && npx vitest run src/modules/visit/__tests__` → 全部通过。
- [ ] `D1=$(date -d ''+1 day'' +%F)`；`curl -b host.txt -H ''Content-Type: application/json'' -H "X-CSRF-Token: $(curl -s -b host.txt http://localhost:3000/api/v1/auth/csrf | jq -r .data.csrf_token)" -d "{\"visitor_type_id\":\"55555555-5555-4555-8555-555555555551\",\"visitor_name\":\"林晓\",\"visitor_phone\":\"13800138000\",\"visitor_id_no\":\"110101199003071233\",\"host_id\":\"33333333-3333-4333-8333-333333333333\",\"visit_start\":\"${D1}T10:00:00+08:00\",\"visit_end\":\"${D1}T11:00:00+08:00\",\"reason\":\"业务洽谈\"}" http://localhost:3000/api/v1/appointments` → 200，`status=待审核`，返回 `appoint_no` 与 `short_code`；`docker compose exec -T db psql -U visitor -d visitor_system -c "select count(*) from operation_logs where action=''新增预约''"` 增加 1。
- [ ] 同证件号提交 `${D1}T10:30:00+08:00`–`${D1}T11:30:00+08:00` → 422，`field=visit_start`，`message` 为 COPY-347。
- [ ] `curl -b host.txt -X POST -H "X-CSRF-Token: $(curl -s -b host.txt http://localhost:3000/api/v1/auth/csrf | jq -r .data.csrf_token)" http://localhost:3000/api/v1/reviews/88888888-8888-4888-8888-888888888801/approve` → 200；P1 状态 `已通过`；`notifications` 新增 1 条；`operation_logs` 新增 `action=''审核同意''`。
- [ ] 用上一步新建预约的 `short_code` 立即调用 `POST /gate/verify`（该预约在明日窗口）→ 409 + COPY-132，`operation_logs` 新增 `action=''核验''`、`result=''失败''`。
- [ ] `WALKIN=$(curl -s -b guard.txt -X POST -H ''Content-Type: application/json'' -H "X-CSRF-Token: $(curl -s -b guard.txt http://localhost:3000/api/v1/auth/csrf | jq -r .data.csrf_token)" -d ''{"visitor_name":"赵强","visitor_phone":"13900139000","visitor_id_no":"310101199002022349","visitor_type_id":"55555555-5555-4555-8555-555555555551","host_id":"33333333-3333-4333-8333-333333333333","gate_id":"66666666-6666-4666-8666-666666666661","reason":"临时代送物品","consent":{"safety":true,"privacy":true}}'' http://localhost:3000/api/v1/gate/walk-in)` → `echo "$WALKIN" | jq -r .data.status` 为 `已到访(在校中)`；`consent_records` 新增 2 条；该预约 `visit_credentials.usage_status=''已使用''`。
- [ ] `CODE=$(echo "$WALKIN" | jq -r .data.short_code)`；`curl -b guard.txt -X POST -H ''Content-Type: application/json'' -H "X-CSRF-Token: $(curl -s -b guard.txt http://localhost:3000/api/v1/auth/csrf | jq -r .data.csrf_token)" -d "{\"code\":\"$CODE\",\"gate_id\":\"66666666-6666-4666-8666-666666666661\"}" http://localhost:3000/api/v1/gate/depart` → 200，`status=已离校`；随后同一 `$CODE` 调用 `POST /gate/admit` → 200，`status=已到访(在校中)`，`visit_credentials.usage_status` 仍为 `已使用`，`passage_records` 新增 1 条 `enter`。
- [ ] `bash scripts/visitor-fixture.sh` → 生成 `h5.txt` 与 `h5.token`；`curl -H "Authorization: Bearer $(cat h5.token)" http://localhost:3000/api/v1/visitor/appointments` → 200，只返回本人 1 条。
- [ ] `curl -b h5.txt -H ''Content-Type: application/json'' -d ''{"visitor_name":"钱多","visitor_phone":"13700137000","visitor_id_no":"110101199003071233","visitor_type_id":"55555555-5555-4555-8555-555555555551","host_id":"33333333-3333-4333-8333-333333333333","visit_start":"''${D1}''T13:00:00+08:00","visit_end":"''${D1}''T14:00:00+08:00","reason":"咨询入学","consent":{"safety":false,"privacy":false}}'' http://localhost:3000/api/v1/visitor/appointments` → 422，`field=consent`，`message` 为 COPY-348。
- [ ] 浏览器打开 `/h5/apply` → 三步流程可完成；成功后 `/h5/my` 显示二维码与 6 位短码。
- [ ] `/gate` 打开 → 当日视图出现上一步现场登记的访客；`/reviews` 以 T001 登录 → 只显示审核人解析为 T001 的待审核预约。
- [ ] 深链接 `/appointments?appointmentId=88888888-8888-4888-8888-888888888801` → 直接打开对应详情抽屉；未知 id → Toast COPY-008 且抽屉关闭。
- [ ] 黑名单访客（P10）在 `/gate` 核验 → 结果区仅出现「拦截放行」；点击后 `operation_logs` 新增 `action=''异常上报''`，`passage_records` 不新增记录。
- [ ] guard 登录 `/gate` → 异常列表无「处置」按钮；admin 登录可见并可提交处置说明。
- [ ] H5 真机或 DevTools 375×667：`/h5/apply` 三步可完成；未勾选两份告知直接提交 → 服务端 422，页面切回第二步并显示 COPY-348；`/h5/my` 无横向滚动，页脚「个人信息说明」跳 `/h5/privacy`。
- [ ] 后台四页断网验证：`docker compose stop backend` 后 `/appointments`、`/reviews`、`/gate` 均显示 COPY-355 与 COPY-356。
- [ ] `grep -Rn "alert(\|confirm(" frontend/src/views/visit` 无输出；`grep -n "gate/admit" frontend/src/views/visit/GatePage.vue` 仅出现在放行动作，不出现在拦截分支。

### 测试用例与结果比对
| TC | 测试点 | 已定预期（摘自 output/v1.0/测试.md） | 本次实际运行结果（未执行） | 比对结论 |
|----|--------|--------------------------------------|----------------------------|----------|
| TC-PT-006 | 访客免密进入 H5 | 令牌直接进「我的申请」；短码请求详情 403 + 审计 | 未执行；落点：`visitorTokenAuth` + `GET /visitor/appointments/:id` + `H5MyPage.vue` | 设计可达 |
| TC-AP-001 | 提交预约成功主流程 | `待审核`；生成编号与短码；H1 收到通知 | 未执行；落点：`POST /appointments` + `nextAppointmentNo` + `generateShortCode` + `publishNotification` | 设计可达 |
| TC-AP-002 | 手机号格式校验 | `13800138000` 放行；`1380013800`/`12345678901` 422 `field=visitor_phone` | 未执行；落点：`validators.isValidPhone` + `validateBody` | 设计可达 |
| TC-AP-003 | 证件号校验 | ①④⑤ 放行；②③⑥⑦ 422 `field=visitor_id_no` | 未执行；落点：`isValidIdCard`（GB 11643 校验位）+ `isValidOtherId`（5–20 位） | 设计可达 |
| TC-AP-004 | 到访时段规格校验 | ③④ 放行；①②⑤ 422 `field=visit_end` | 未执行；落点：`rules.validateVisitWindow`（同日晚于开始、15–240 分钟） | 设计可达 |
| TC-AP-005 | 必填缺失拦截 | `field` 依次 `host_id`、`visit_start`、`reason` | 未执行；落点：`validateBody` schema 字段顺序 | 设计可达 |
| TC-AP-006 | 随行明细 ≤10 条 | 10 条成功 `people_count=11`；11 条 422 `field=companions` | 未执行；落点：`rules.validateCompanions` + `people_count` | 设计可达 |
| TC-AP-007 | 随行证件号同规则校验 | 422 `field=companions[i].id_no` | 未执行；落点：`validateBody` 数组元素路径 + `isValidIdCard` | 设计可达 |
| TC-AP-008 | 黑名单预检覆盖随行（软提示不拦） | 创建成功；`black_hit=1`；软提示 | 未执行；落点：`checkBlacklist([主+随行])` + `black_hit` + COPY-080 | 设计可达 |
| TC-AP-009 | 时段可用且未过期校验 | 06:59 422；09:00 422；09:01 放行 | 未执行；落点：`rules.timeRuleDecision` + `visit_start > now` | 设计可达 |
| TC-AP-010 | 防重复：未完结集闭区间相交拒绝 | ①②③ 422 `field=visit_start`；④ 放行；已改期参与 | 未执行；落点：`rules.findOverlap` + `OPEN_STATUSES` + advisory lock | 设计可达 |
| TC-AP-011 | 终态后可重发 | 已拒绝/已过期/已取消/已离校均不参与防重复 | 未执行；落点：`OPEN_STATUSES` 不含四类 + 旧记录保留 | 设计可达 |
| TC-AP-012 | 禁入时段优先 | 10:30–11:30 422 `field=visit_start` | 未执行；落点：`timeRuleDecision` 先禁入后可预约 | 设计可达 |
| TC-AP-013 | 改期权限与可改边界 | 访客改期直接待审核；host/admin 提议 → 已改期；guard 403；P4/P5 409 | 未执行；落点：`PUT /appointments/:id/reschedule`、`PUT /visitor/appointments/:id/reschedule` + 状态校验 | 设计可达 |
| TC-AP-014 | 改期新时段重过校验（排除自身） | 仅与自身重叠成功；与 P2 相交 422 | 未执行；落点：`findOverlap(..., excludeId)` + 全量校验复用 | 设计可达 |
| TC-AP-015 | 取消预约成功 | `已取消`；写审计；记录保留 | 未执行；落点：`PUT /appointments/:id/cancel` + `writeAudit` + `appointment_status_history` | 设计可达 |
| TC-AP-016 | 已到访取消返回 409 | 409；状态不变 | 未执行；落点：`rules.assertTransition(''已到访(在校中)'',''已取消'')` 拒绝 | 设计可达 |
| TC-AP-017 | 预约状态 8 态跟踪与同源 | 8 态中文枚举与流转时间；与台账同源 | 未执行；落点：`appointment_status_history` + `StatusTag` + 台账共用 `status` | 设计可达 |
| TC-AT-001 | host 仅见本人相关待审核 | H1 见 P1/P3，不见 P2；按审核人归属 | 未执行；落点：`review.service` 条件 `reviewer_id=当前用户 OR admin`（被访人仅在 `resolveReviewer` 将其解析为审核人时可见） | 设计可达 |
| TC-AT-002 | admin 全校兜底 | 可见全部待审核 | 未执行；落点：`review.service` admin 分支 | 设计可达 |
| TC-AT-003 | 越权读他人预约 403＋审计 | 403 + 越权审计 | 未执行；落点：`review.service` 对象级校验 + `writeAudit(''越权拦截'')` | 设计可达 |
| TC-AT-004 | 审核同意 | `已通过`；访客收到通过通知 | 未执行；落点：`POST /reviews/:id/approve` + `publishNotification(''审核结果'')` | 设计可达 |
| TC-AT-005 | 拒绝原因必填 2–100 字 | 0/1/101 字 422 `field=reject_reason`；2/100 成功 | 未执行；落点：express-validator `.isLength({min:2,max:100})` + `unprocessable` | 设计可达 |
| TC-AT-006 | 改期＝提议改期、重过校验、次数不限、超时过期 | 无时段 422；提议→已改期；确认→待审核；3h+10min 已过期；第 3 轮成功；已改期直接同意 409 | 未执行；落点：`reschedule` + `confirm-reschedule` + `confirmRescheduleTimeout` + 状态校验 | 设计可达 |
| TC-AT-007 | 重复处理 409 | 409；原状态不变 | 未执行；落点：`assertTransition` + `SELECT FOR UPDATE` | 设计可达 |
| TC-AT-008 | 审核人默认被访教职工 | 默认审核人=被访教职工 | 未执行；落点：`resolveReviewer` 返回 `host` 对应账号 | 设计可达 |
| TC-AT-009 | 审核人配置前向不追溯（含命中优先级） | 新预约落 R1；P0 不回改；最具体优先；同具体度按声明顺序 | 未执行；落点：`resolveReviewer` 五级优先 + `declaration_order` | 设计可达 |
| TC-AT-010 | 审核写日志含四要素 | 操作人/时间/决定/原因 | 未执行；落点：`operation_logs` 过滤 `object_type=''appointment''` 且 `action in (''审核同意'',''审核拒绝'',''改期'')` | 设计可达 |
| TC-AT-011 | 按预约维度筛选日志 | 仅返回该预约日志 | 未执行；落点：`GET /reviews/:id/logs` + `object_id` 过滤 | 设计可达 |
| TC-GV-001 | 现场核验一致且在有效时段放行 | 09:45–11:15 含端点放行；09:44、11:16 拦截 | 未执行；落点：`rules.inVerifyWindow` + `POST /gate/verify` | 设计可达 |
| TC-GV-002 | 核验不一致/过期/黑名单拦截 | 均拦截并提示原因；黑名单写异常+通知+审计 | 未执行；落点：`gate.service` 分支 + COPY-131/132/133/134 + `publishSecurityNotification` | 设计可达 |
| TC-GV-003 | 有预约放行记录时刻与放行人 | `已到访(在校中)`；记录 `checkin_at`、放行人、校门 | 未执行；落点：`POST /gate/admit` + `passage_records` | 设计可达 |
| TC-GV-004 | 无预约现场登记放行 | `已到访(在校中)`；2 条告知；豁免未过期/已审核；仍过黑名单；短码立即已用 | 未执行；落点：`POST /gate/walk-in` + `consent.service` + `generateShortCode` | 设计可达 |
| TC-GV-005 | 现场登记复用 AP 采集项与校验 | 422 `field=visitor_phone`/`visitor_id_no` | 未执行；落点：`walk-in` 复用 `validateBody` 与 `rules` | 设计可达 |
| TC-GV-006 | 短码规则 6 位全局唯一 | `^\d{6}$`；100 条不重复；终态不可核验；记录保留 | 未执行；落点：`generateShortCode` + `visit_credentials.short_code UNIQUE` + 终态校验 | 设计可达 |
| TC-GV-007 | 首次核销成功、重复核销拒绝 | 首次 `已用`；在校中再次核销 409 | 未执行；落点：`visit_credentials.usage_status` + COPY-011 | 设计可达 |
| TC-GV-008 | 进校/离校登记形成在校中 | `已到访(在校中)` → `已离校`；两次时刻记录 | 未执行；落点：`POST /gate/admit`、`POST /gate/depart` + `checkin_at`/`checkout_at` | 设计可达 |
| TC-GV-009 | 当天多次进出、已离校为准终态 | 允许再次进校；凭证仍已用；新增 `enter` 记录 | 未执行；落点：`POST /gate/admit` 对当日 `已离校` 追加 `enter` 通行记录 + S-44 | 设计可达 |
| TC-GV-010 | 时刻精确到分钟 | 展示 `yyyy-MM-dd HH:mm`；审计/通知到秒 | 未执行；落点：`formatMinute` + `formatSecond` | 设计可达 |
| TC-GV-011 | 异常上报写记录并通知管理员 | 4 类均接受；`待处理`；通知管理员；黑名单另通知门卫；审计 | 未执行；落点：`POST /gate/incidents` + `INCIDENT_TYPES` + `publishNotification` + `writeAudit(''异常上报'')` | 设计可达 |
| TC-GV-012 | 异常可查（含处理状态机） | 可查；admin 处置需说明；guard 403；缺说明 422 | 未执行；落点：`GET /gate/incidents` + `PUT /gate/incidents/:id/disposition` + `requireAdmin` + `writeAudit(''异常处置'')` | 设计可达 |
| TC-GV-013 | 门口当日视图仅当日数据 | 仅本地当日预约、待核验、在校中 | 未执行；落点：`GET /gate/today` + `localDayRange` | 设计可达 |
| TC-VS-001 | 我要申请提交成功 | 复用 AP 校验；`待审核`；生成短码与编号 | 未执行；落点：`POST /visitor/appointments` 复用 `appointment.service` + `H5ApplyPage.vue` | 设计可达 |
| TC-VS-002 | 仅本人可见、越权 403 | 本人可读；读他人 403 + 审计。**O-01**：令牌过期后换发无渠道 | 未执行；落点：`visitorTokenAuth` + `GET /visitor/appointments/:id` 令牌绑定校验 | 部分可达（剔除 O-01 孤儿断言「手机号+验证码重新换取令牌」；保留本人可见与越权 403） |
| TC-VS-003 | 页内出示二维码凭证 | 二维码与 6 位短码；短码不能读详情 | 未执行；落点：`H5MyPage.vue` + 二维码由 `appointment_no` 生成 + 短码只读展示 | 设计可达 |
| TC-VS-004 | 未勾选告知不可提交 | 422 `field=consent`；两项勾选后放行 | 未执行；落点：`consent.service` 校验 + `validateBody` | 设计可达 |
| TC-VS-005 | 每次提交均需确认、留痕按预约含时间戳 | 第二次仍需勾选；每次独立记录 | 未执行；落点：每次 POST 插入 2 条 `consent_records`，不读历史 | 设计可达 |
| TC-VS-006 | 扫码直达我要申请 | URL 路径 `/h5/apply` | 未执行；落点：`shared.routes` H5 根 + `views/visit/routes.ts` | 设计可达 |
| TC-VS-007 | 移动端兼容与适配 | 三环境完成四项核心动作；320–480px 无横向滚动 | 未执行；落点：`H5Layout.vue` + viewport meta + `tokens.css` | 设计可达（需集成闭环真机验证） |
| TC-SM-004 | 授权告知留痕 + 最小必要收集 | 每条预约 2 条告知记录；采集字段 ⊆ PRD §5.1 | 未执行；落点：`consent_records` + 表单字段白名单 | 设计可达 |
| TC-OR-003 | 越权访问 403、对象级读写都落强制点 | 读写均 403 | 未执行；落点：`appointment.service`/`review.service` 对象级校验 | 设计可达 |
| TC-OR-004 | 越权写审计留痕 | 新增 `action=''越权拦截''` 审计 | 未执行；落点：`writeAudit` 于对象级拒绝分支 | 设计可达 |
| TC-OR-006 | 对象级隔离以绑定实体 id 为准 | 以 `host_id`/绑定实体 id 判定 | 未执行；落点：`GET /reviews*` 及审核动作按 `reviewer_id`；`GET /appointments/:id` 按 `host_id` 与 `users.host_id` 判定 | 设计可达 |
| TC-OR-007 | 越权写「越权拦截」审计 | user/time/object/result 齐全 | 未执行；落点：`writeAudit` 字段映射 | 设计可达 |

## 在开始改动之前
1. 读取 `conventions.md` §13 状态机与 `p1-contracts.md` §四。
2. 读取 `seed-anchors.sql` 预约、短码、告知、通行、异常段。
3. 检查 master 与 notify 门面导出是否可用。
4. 检查 `frontend/src/views/visit/` 是否已存在。

## 完成改动之后
1. 列出创建/修改的文件。
2. 粘贴四组单测与关键 curl 输出。
3. 确认 54 条 TC 比对表完成，O-01 已显式剔除。
4. 列出剩余风险（移动端兼容与 1 万条性能由集成闭环卡验证）。
5. 将本卡「测试用例与结果比对」表的「本次实际运行结果」列填写为真实执行结果，写入 `docs/trace/runs/v1/test-results/VIS-P1-I05.md`：逐条 TC 给出命令、原始输出摘要、通过/失败结论；失败项附现象、根因、修复文件与回归命令。
6. 写入 `docs/memory/2026-10-19/VIS-P1-I05.md`。
', '6fb41cb9-db51-4196-a359-19f915a20e19', NULL, 'urgent', 140000, 14, 21, NULL, NULL, NULL, NULL, NULL, NULL, false, NULL, NULL, NULL, NULL);
INSERT INTO issues (id, created_at, updated_at, created_by_id, updated_by_id, project_id, workspace_id, name, description_json, description_html, description_stripped, state_id, parent_id, priority, sort_order, sequence_id, point, estimate_point_id, type_id, start_date, target_date, completed_at, archived_at, is_draft, external_source, external_id, description_binary, deleted_at) VALUES ('eaea3ff3-4b13-4e26-be0f-3998ce8df732', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', '[VIS-P1-I06] compliance 审计隐私全栈卡', '{}'::jsonb, '## 目标
交付操作日志查询、审计留存策略、个人信息留存、人工清除、本人副本与隐私案件记录，保证七类敏感操作可追溯。

承载需求：REQ-SM-001、REQ-SM-002。

## 验收标准
- [ ] `/system/audit` 支持按操作人、时间范围、对象、动作四维查询；最小字段齐全；列表具备四态。
- [ ] 操作日志的改动前/改动后以左右并排 JSON 展示，差异字段高亮，长值可展开。
- [ ] 审计保留 365 天；不提供提前删除。
- [ ] `/system/privacy` 支持修改留存期限、按预约编号人工清除、查看隐私案件；三个分区均具备四态。
- [ ] 人工清除后主记录 `visitor_name`/`visitor_phone`/`visitor_id_no` 为 NULL；审计 before/after 明文保留。
- [ ] `/h5/privacy` 返回本人信息副本，证件号掩码；不提供「更正」入口；令牌失效时给出 COPY-007 与重新扫码入口。
- [ ] 4 条 TC 的逐条比对表填写完成。

## 相关背景

### 必读文件
- `conventions.md` — 约定 10 前端交互与视觉、约定 11 审计、约定 12 文案。
- `docs/trace/runs/v1/spac.md` §4.2.12 参数与字典、操作日志、信息保护、§6.8 合规模块端点、§11 S-46、§5.9/§5.10。
- `docs/knowledge/shared-kernel-api.md` — 前端共享组件、Store 与请求封装签名。
- `docs/knowledge/phase-contracts/p1-contracts.md` §六。
- `roles.md` — adminOnly `/audit-logs*`、`/privacy/*`。
- `output/v1.0/测试.md` 第十三节；`output/v1.0/测试结果.md` 对应行。
- `output/v1.0/孤儿测试用例.md` — O-02、O-03。

### 共享内核 API（摘自 docs/knowledge/shared-kernel-api.md）
```ts
import { writeAudit } from ''../../../shared/audit/writeAudit'';
import { getConfigNumber, setConfig } from ''../../../shared/config/configService'';
import { getAppointmentForCompliance, eraseAppointmentPii } from ''../../visit'';
import { maskIdNo } from ''../../../shared/utils/mask'';
```

### 模块模板（摘自 docs/knowledge/module-template.md）
- `backend/src/modules/compliance/{index.ts,api/audit.routes.ts,api/privacy.routes.ts,internal/*.service.ts}`。
- `frontend/src/views/compliance/{AuditLogsPage.vue,PrivacyPage.vue,H5PrivacyPage.vue,routes.ts,permissions.ts}`。

### 上游契约（摘自 docs/knowledge/phase-contracts/p1-contracts.md §六）
- `operation_logs(id, user_id, user_name, occurred_at, object_type, object_id, action, result, before_value, after_value, ip, note)`。
- `privacy_cases(id, appointment_id, case_type, subject_name, description, status, handled_by, handled_at, created_at)`。
- visit 门面：`getAppointmentForCompliance`、`eraseAppointmentPii`。

### 本域设计（摘自架构设计文档 §6.8）
- 端点：`GET /audit-logs`、`GET/PUT /privacy/retention`、`POST /privacy/appointments/:id/erase`、`GET /privacy/cases`、`GET /visitor/privacy/copy`。
- 七类敏感操作的 `action` 取值（`conventions.md` 约定 11）：审核 `审核同意`/`审核拒绝`、放行 `放行`、失败核验 `核验`（`result=''失败''`）、取消 `取消预约`、异常 `异常上报`/`异常处置`、越权 `越权拦截`、提交与离校 `新增预约`/`离校`。
- 留存：个人信息 90 天；审计 365 天；到期展示层掩码，不物理删除。
- 人工清除：物理置空主记录 PII；写 `privacy_cases` 与审计；审计明文保留。
- 信息副本：姓名、手机号、证件号（掩码）、预约列表；不提供更正接口。

## 约束

### 命名约束
- 权限点：`system:audit:read`、`system:privacy:read|update`、`visit:privacy:read`。
- 前端 `objectType`、`occurredAt`；API `object_type`、`occurred_at`。

### 其他约束
- [边界] 只写 compliance 上下文与 `views/compliance`；清除调用 visit 门面，不直接写 `appointments`。
- [边界] 不新增更正端点。
- [依赖] 无新增第三方依赖。
- [审计] 审计查询本身不写审计；`operation_logs` 只由业务动作写入，避免读操作放大日志量。

## 实施阶段
实现

## 任务

### 后端
1. 创建 `backend/src/modules/compliance/api/audit.routes.ts` — `GET /audit-logs` 四维查询与分页。
2. 创建 `backend/src/modules/compliance/api/privacy.routes.ts` — `GET/PUT /privacy/retention`、`POST /privacy/appointments/:id/erase`、`GET /privacy/cases`。
3. 创建 `backend/src/modules/compliance/api/visitor-privacy.routes.ts` — `GET /visitor/privacy/copy`，使用 `visitorTokenAuth`。
4. 创建 `backend/src/modules/compliance/internal/audit.service.ts` — 查询与字段映射。
5. 创建 `backend/src/modules/compliance/internal/privacy.service.ts` — 留存配置、人工清除、案件记录、副本组装；人工清除写 `action=''人工清除''`、改留存写 `action=''修改留存配置''` 审计。
6. 创建 `backend/src/modules/compliance/index.ts` — 导出服务函数。
7. 创建定时任务 `audit-cleanup`（每日 03:10）— 删除 `occurred_at < now - 365 days` 的审计；用 `registerJob({name:''audit-cleanup'', cron:''10 3 * * *'', handler})` 注册，由 `startJobs()` 统一启动。
8. 创建 `backend/src/modules/compliance/__tests__/privacy.service.test.ts` 与 `audit.rules.test.ts`。

### 前端
9. 创建 `frontend/src/views/compliance/AuditLogsPage.vue` — 四维筛选（COPY-295…298）、表格（列 COPY-300…306）、分页默认 20；四态齐全（`LoadingState` / `ErrorState` COPY-355 + COPY-356 / `EmptyState` COPY-299 / 表格）；筛选变化后回到第 1 页，查询按钮请求期间 `loading` 禁用。
10. 操作日志的「改动前/改动后」以左右并排 JSON 视图渲染：键按字母序对齐，差异字段整行高亮（新增/修改/删除分别用不同底色），长值折叠为前 3 行并可展开；空值显示 `—`；不得把原始 JSON 字符串直接塞进单元格。
11. 创建 `frontend/src/views/compliance/PrivacyPage.vue` — 三个分区均具备四态：留存期限（COPY-308/309，输入正整数，非法时字段下方 COPY-353，保存成功 Toast COPY-310）；人工清除（COPY-311…315，预约编号与清除原因均必填，点击「确认清除」弹 ConfirmDialog COPY-316/317，成功后 Toast COPY-318 并清空表单、刷新案件列表）；隐私处理记录（COPY-319/320，表格展示对象、类型、说明、状态、处置人、时间）。
12. 创建 `frontend/src/views/compliance/H5PrivacyPage.vue` — 标题 COPY-187；正文 COPY-395；「获取我的信息副本」COPY-185，生成期间按钮显示 COPY-186 并禁用；副本以只读卡片展示姓名、手机号、掩码证件号与预约列表；令牌失效（403）时展示 COPY-007 与按钮 COPY-396 跳 `/h5/apply`；页面四态齐全，触控目标 ≥44×44px。
13. 创建 `frontend/src/views/compliance/routes.ts` — `/system/audit`、`/system/privacy`（admin）、`/h5/privacy`（h5，不走后台鉴权守卫）。
14. 创建 `frontend/src/views/compliance/permissions.ts`。

### 用户可见文案清单（本卡必含，逐字）
| 类别 | 触发场景 | COPY | 逐字文案 | 渲染位置 |
|------|---------|------|---------|---------|
| 日志标题 | 页面 | COPY-294 | 操作日志 | PageHeader |
| 筛选标签 | 页面 | COPY-295…298 | 操作人、动作、对象、时间范围 | 筛选栏 |
| 表格列 | 页面 | COPY-300…306 | 时间、操作人、对象、动作、结果、改动前、改动后 | 表头 |
| 日志空态 | 无结果 | COPY-299 | 没有符合条件的操作记录 | EmptyState |
| 信息保护标题 | 页面 | COPY-307 | 信息保护 | PageHeader |
| 留存标签 | 表单 | COPY-308 | 个人信息留存期限（天） | 字段 |
| 留存说明 | 说明 | COPY-309 | 超过留存期限的记录在界面与导出中显示脱敏信息，原始数据按制度保留用于安全追溯 | 说明文字 |
| 留存保存成功 | 保存 | COPY-310 | 留存期限已保存 | Toast |
| 留存非法 | 非正整数 | COPY-353 | 留存期限必须是大于 0 的整数 | 字段下方 |
| 人工清除标题 | 分区 | COPY-311 | 人工清除个人信息 | 分区标题 |
| 人工清除说明 | 说明 | COPY-312 | 输入预约编号后，该预约的姓名、手机号、证件号将从主记录中物理清除，操作日志保留 | 说明文字 |
| 人工清除字段 | 表单 | COPY-313 / COPY-314 / COPY-315 | 预约编号、清除原因、确认清除 | 字段/按钮 |
| 人工清除确认 | 弹窗 | COPY-316 / COPY-317 | 确认清除个人信息 / 清除后主记录中的姓名、手机号、证件号不可恢复，操作日志中的记录保留。是否继续？ | ConfirmDialog |
| 清除成功 | 完成 | COPY-318 | 个人信息已清除 | Toast |
| 案件标题/空态 | 页面 | COPY-319 / COPY-320 | 隐私处理记录、暂无处理记录 | 分区 |
| 隐私页标题 | H5 | COPY-187 | 个人信息说明 | PageHeader |
| 隐私正文 | H5 | COPY-395 | 系统收集您的姓名、手机号、证件号及随行人员信息，仅用于本次来访登记与校园安全管理，并按留存期限处理；超过留存期限后，界面与导出中的证件号显示为脱敏信息。 | 正文 |
| 副本入口 | H5 | COPY-185 | 获取我的信息副本 | 按钮 |
| 副本生成中 | H5 | COPY-186 | 正在生成信息副本... | 按钮 loading |
| 令牌失效 | H5 403 | COPY-007 / COPY-396 | 该申请链接已失效，请重新扫码申请 / 重新扫码申请 | 提示与按钮 |

### UI 完整性检验结论（2026-10-19）
- 检验范围：`/system/audit`、`/system/privacy`、`/h5/privacy` 共 5 个分区。
- 通过项：分区四态；日志四维筛选与并排 JSON 差异高亮；留存/清除/案件规则与确认框；H5 403 重签按钮；44×44px。
- 对应缺陷：U2、U9、U12、U14。
| 加载中... | 各页首次取数 | COPY-357 | 加载中... | LoadingState |
| 加载失败 | 各页取数失败 | COPY-355 | 数据加载失败，请点击重试 | ErrorState |
| 重试按钮 | 加载失败态 | COPY-356 | 重试 | ErrorState 按钮 |

## 验证
- [ ] `cd backend && npx vitest run src/modules/compliance/__tests__` → 全部通过。
- [ ] 先自造一条审核日志：`bash scripts/login-fixtures.sh`；`curl -b host.txt -X POST -H "X-CSRF-Token: $(curl -s -b host.txt http://localhost:3000/api/v1/auth/csrf | jq -r .data.csrf_token)" http://localhost:3000/api/v1/reviews/88888888-8888-4888-8888-888888888801/approve` → 200；再 `curl -b admin.txt "http://localhost:3000/api/v1/audit-logs?action=%E5%AE%A1%E6%A0%B8%E5%90%8C%E6%84%8F&date_from=$(date +%F)"` → 返回该条日志，字段含 `before_value`/`after_value`。
- [ ] `curl -b guard.txt http://localhost:3000/api/v1/audit-logs` → 403。
- [ ] `curl -b admin.txt -X PUT -H "X-CSRF-Token: $(curl -s -b admin.txt http://localhost:3000/api/v1/auth/csrf | jq -r .data.csrf_token)" -H ''Content-Type: application/json'' -d ''{"retention_days":90}'' http://localhost:3000/api/v1/privacy/retention` → 200；`GET` 返回 90；`operation_logs` 新增 `action=''修改留存配置''`。
- [ ] `curl -b admin.txt -X POST -H "X-CSRF-Token: $(curl -s -b admin.txt http://localhost:3000/api/v1/auth/csrf | jq -r .data.csrf_token)" -H ''Content-Type: application/json'' -d ''{"reason":"本人申请"}'' http://localhost:3000/api/v1/privacy/appointments/88888888-8888-4888-8888-888888888805/erase` → 200；`docker compose exec -T db psql -U visitor -d visitor_system -c "select visitor_name, visitor_phone, visitor_id_no from appointments where id=''88888888-8888-4888-8888-888888888805''"` → 三列为空；`operation_logs` 新增 `action=''人工清除''` 且 `before_value` 保留明文。
- [ ] `bash scripts/visitor-fixture.sh`（由 `VIS-P1-I05` 提供）→ 生成 `h5.txt` 与 `h5.token`；`curl -H "Authorization: Bearer $(cat h5.token)" http://localhost:3000/api/v1/visitor/privacy/copy` → 200，证件号为掩码。
- [ ] `grep -rn "更正" backend/src frontend/src` → 0 命中。
- [ ] `/system/audit` 选中一条含 `before_value`/`after_value` 的日志 → 抽屉内左右并排展示 JSON，差异键高亮，长值可展开。
- [ ] `/system/privacy` 留存期限输入 `0` → 字段下方 COPY-353；输入 `90` 保存 → Toast COPY-310。
- [ ] H5 令牌失效场景：清除 `h5.token` 后访问 `/h5/privacy` → 显示 COPY-007 与 COPY-396，点击按钮落 `/h5/apply`。
- [ ] 断网验证：`docker compose stop backend` 后 `/system/audit`、`/system/privacy` 显示 COPY-355 与 COPY-356。
- [ ] `grep -Rn "alert(\|confirm(" frontend/src/views/compliance` 无输出。

### 测试用例与结果比对
| TC | 测试点 | 已定预期（摘自 output/v1.0/测试.md） | 本次实际运行结果（未执行） | 比对结论 |
|----|--------|--------------------------------------|----------------------------|----------|
| TC-SM-001 | 敏感操作写日志 | 审核/放行/失败核验/取消/异常/越权拦截各新增一条，含谁/什么/何时/结果 | 未执行；落点：`writeAudit` 在 visit 各 service 的调用点，`action` 取 `审核同意`/`审核拒绝`/`放行`/`核验`(失败)/`取消预约`/`异常上报`/`异常处置`/`越权拦截`，另含 `新增预约`/`离校`；`/system/audit` 展示 | 设计可达 |
| TC-SM-002 | 日志最小字段与查询维度（含明文例外） | 7 个最小字段；四维可查；before/after PII 明文保留 | 未执行；落点：`operation_logs` 表 + `GET /audit-logs` 四维筛选 + 明文 JSONB | 设计可达 |
| TC-SM-003 | 日志留存 ≥180 天 | 留存 ≥180；180 天前仍可查；不提前删除 | 未执行；落点：`system_config.audit_retention_days=365` + `audit-cleanup` 任务 | 设计可达 |
| TC-SM-006 | 人工清除＝物理删除、本人索取更正 | PII 物理删除且不可检索；审计明文保留；本人副本掩码。**O-03**：更正流程无确定接口 | 未执行；落点：`eraseAppointmentPii` + `privacy_cases` + `GET /visitor/privacy/copy`；不提供更正端点 | 部分可达（剔除 O-03 孤儿断言「更正流程」；保留清除、审计保留、副本三项） |

## 在开始改动之前
1. 读取 `spac.md` §6.8 与 `p1-contracts.md` §六。
2. 读取 `output/v1.0/孤儿测试用例.md` 中 O-02/O-03。
3. 检查 visit 门面 `eraseAppointmentPii` 是否可用。

## 完成改动之后
1. 列出创建/修改的文件。
2. 粘贴单测、审计查询、清除后 SQL 结果。
3. 确认 4 条 TC 比对表完成，O-03 已显式剔除。
4. 列出剩余风险（审计清理任务的时间边界由集成闭环卡验证）。
5. 将本卡「测试用例与结果比对」表的「本次实际运行结果」列填写为真实执行结果，写入 `docs/trace/runs/v1/test-results/VIS-P1-I06.md`：逐条 TC 给出命令、原始输出摘要、通过/失败结论；失败项附现象、根因、修复文件与回归命令。
6. 写入 `docs/memory/2026-10-19/VIS-P1-I06.md`。
', '## 目标
交付操作日志查询、审计留存策略、个人信息留存、人工清除、本人副本与隐私案件记录，保证七类敏感操作可追溯。

承载需求：REQ-SM-001、REQ-SM-002。

## 验收标准
- [ ] `/system/audit` 支持按操作人、时间范围、对象、动作四维查询；最小字段齐全；列表具备四态。
- [ ] 操作日志的改动前/改动后以左右并排 JSON 展示，差异字段高亮，长值可展开。
- [ ] 审计保留 365 天；不提供提前删除。
- [ ] `/system/privacy` 支持修改留存期限、按预约编号人工清除、查看隐私案件；三个分区均具备四态。
- [ ] 人工清除后主记录 `visitor_name`/`visitor_phone`/`visitor_id_no` 为 NULL；审计 before/after 明文保留。
- [ ] `/h5/privacy` 返回本人信息副本，证件号掩码；不提供「更正」入口；令牌失效时给出 COPY-007 与重新扫码入口。
- [ ] 4 条 TC 的逐条比对表填写完成。

## 相关背景

### 必读文件
- `conventions.md` — 约定 10 前端交互与视觉、约定 11 审计、约定 12 文案。
- `docs/trace/runs/v1/spac.md` §4.2.12 参数与字典、操作日志、信息保护、§6.8 合规模块端点、§11 S-46、§5.9/§5.10。
- `docs/knowledge/shared-kernel-api.md` — 前端共享组件、Store 与请求封装签名。
- `docs/knowledge/phase-contracts/p1-contracts.md` §六。
- `roles.md` — adminOnly `/audit-logs*`、`/privacy/*`。
- `output/v1.0/测试.md` 第十三节；`output/v1.0/测试结果.md` 对应行。
- `output/v1.0/孤儿测试用例.md` — O-02、O-03。

### 共享内核 API（摘自 docs/knowledge/shared-kernel-api.md）
```ts
import { writeAudit } from ''../../../shared/audit/writeAudit'';
import { getConfigNumber, setConfig } from ''../../../shared/config/configService'';
import { getAppointmentForCompliance, eraseAppointmentPii } from ''../../visit'';
import { maskIdNo } from ''../../../shared/utils/mask'';
```

### 模块模板（摘自 docs/knowledge/module-template.md）
- `backend/src/modules/compliance/{index.ts,api/audit.routes.ts,api/privacy.routes.ts,internal/*.service.ts}`。
- `frontend/src/views/compliance/{AuditLogsPage.vue,PrivacyPage.vue,H5PrivacyPage.vue,routes.ts,permissions.ts}`。

### 上游契约（摘自 docs/knowledge/phase-contracts/p1-contracts.md §六）
- `operation_logs(id, user_id, user_name, occurred_at, object_type, object_id, action, result, before_value, after_value, ip, note)`。
- `privacy_cases(id, appointment_id, case_type, subject_name, description, status, handled_by, handled_at, created_at)`。
- visit 门面：`getAppointmentForCompliance`、`eraseAppointmentPii`。

### 本域设计（摘自架构设计文档 §6.8）
- 端点：`GET /audit-logs`、`GET/PUT /privacy/retention`、`POST /privacy/appointments/:id/erase`、`GET /privacy/cases`、`GET /visitor/privacy/copy`。
- 七类敏感操作的 `action` 取值（`conventions.md` 约定 11）：审核 `审核同意`/`审核拒绝`、放行 `放行`、失败核验 `核验`（`result=''失败''`）、取消 `取消预约`、异常 `异常上报`/`异常处置`、越权 `越权拦截`、提交与离校 `新增预约`/`离校`。
- 留存：个人信息 90 天；审计 365 天；到期展示层掩码，不物理删除。
- 人工清除：物理置空主记录 PII；写 `privacy_cases` 与审计；审计明文保留。
- 信息副本：姓名、手机号、证件号（掩码）、预约列表；不提供更正接口。

## 约束

### 命名约束
- 权限点：`system:audit:read`、`system:privacy:read|update`、`visit:privacy:read`。
- 前端 `objectType`、`occurredAt`；API `object_type`、`occurred_at`。

### 其他约束
- [边界] 只写 compliance 上下文与 `views/compliance`；清除调用 visit 门面，不直接写 `appointments`。
- [边界] 不新增更正端点。
- [依赖] 无新增第三方依赖。
- [审计] 审计查询本身不写审计；`operation_logs` 只由业务动作写入，避免读操作放大日志量。

## 实施阶段
实现

## 任务

### 后端
1. 创建 `backend/src/modules/compliance/api/audit.routes.ts` — `GET /audit-logs` 四维查询与分页。
2. 创建 `backend/src/modules/compliance/api/privacy.routes.ts` — `GET/PUT /privacy/retention`、`POST /privacy/appointments/:id/erase`、`GET /privacy/cases`。
3. 创建 `backend/src/modules/compliance/api/visitor-privacy.routes.ts` — `GET /visitor/privacy/copy`，使用 `visitorTokenAuth`。
4. 创建 `backend/src/modules/compliance/internal/audit.service.ts` — 查询与字段映射。
5. 创建 `backend/src/modules/compliance/internal/privacy.service.ts` — 留存配置、人工清除、案件记录、副本组装；人工清除写 `action=''人工清除''`、改留存写 `action=''修改留存配置''` 审计。
6. 创建 `backend/src/modules/compliance/index.ts` — 导出服务函数。
7. 创建定时任务 `audit-cleanup`（每日 03:10）— 删除 `occurred_at < now - 365 days` 的审计；用 `registerJob({name:''audit-cleanup'', cron:''10 3 * * *'', handler})` 注册，由 `startJobs()` 统一启动。
8. 创建 `backend/src/modules/compliance/__tests__/privacy.service.test.ts` 与 `audit.rules.test.ts`。

### 前端
9. 创建 `frontend/src/views/compliance/AuditLogsPage.vue` — 四维筛选（COPY-295…298）、表格（列 COPY-300…306）、分页默认 20；四态齐全（`LoadingState` / `ErrorState` COPY-355 + COPY-356 / `EmptyState` COPY-299 / 表格）；筛选变化后回到第 1 页，查询按钮请求期间 `loading` 禁用。
10. 操作日志的「改动前/改动后」以左右并排 JSON 视图渲染：键按字母序对齐，差异字段整行高亮（新增/修改/删除分别用不同底色），长值折叠为前 3 行并可展开；空值显示 `—`；不得把原始 JSON 字符串直接塞进单元格。
11. 创建 `frontend/src/views/compliance/PrivacyPage.vue` — 三个分区均具备四态：留存期限（COPY-308/309，输入正整数，非法时字段下方 COPY-353，保存成功 Toast COPY-310）；人工清除（COPY-311…315，预约编号与清除原因均必填，点击「确认清除」弹 ConfirmDialog COPY-316/317，成功后 Toast COPY-318 并清空表单、刷新案件列表）；隐私处理记录（COPY-319/320，表格展示对象、类型、说明、状态、处置人、时间）。
12. 创建 `frontend/src/views/compliance/H5PrivacyPage.vue` — 标题 COPY-187；正文 COPY-395；「获取我的信息副本」COPY-185，生成期间按钮显示 COPY-186 并禁用；副本以只读卡片展示姓名、手机号、掩码证件号与预约列表；令牌失效（403）时展示 COPY-007 与按钮 COPY-396 跳 `/h5/apply`；页面四态齐全，触控目标 ≥44×44px。
13. 创建 `frontend/src/views/compliance/routes.ts` — `/system/audit`、`/system/privacy`（admin）、`/h5/privacy`（h5，不走后台鉴权守卫）。
14. 创建 `frontend/src/views/compliance/permissions.ts`。

### 用户可见文案清单（本卡必含，逐字）
| 类别 | 触发场景 | COPY | 逐字文案 | 渲染位置 |
|------|---------|------|---------|---------|
| 日志标题 | 页面 | COPY-294 | 操作日志 | PageHeader |
| 筛选标签 | 页面 | COPY-295…298 | 操作人、动作、对象、时间范围 | 筛选栏 |
| 表格列 | 页面 | COPY-300…306 | 时间、操作人、对象、动作、结果、改动前、改动后 | 表头 |
| 日志空态 | 无结果 | COPY-299 | 没有符合条件的操作记录 | EmptyState |
| 信息保护标题 | 页面 | COPY-307 | 信息保护 | PageHeader |
| 留存标签 | 表单 | COPY-308 | 个人信息留存期限（天） | 字段 |
| 留存说明 | 说明 | COPY-309 | 超过留存期限的记录在界面与导出中显示脱敏信息，原始数据按制度保留用于安全追溯 | 说明文字 |
| 留存保存成功 | 保存 | COPY-310 | 留存期限已保存 | Toast |
| 留存非法 | 非正整数 | COPY-353 | 留存期限必须是大于 0 的整数 | 字段下方 |
| 人工清除标题 | 分区 | COPY-311 | 人工清除个人信息 | 分区标题 |
| 人工清除说明 | 说明 | COPY-312 | 输入预约编号后，该预约的姓名、手机号、证件号将从主记录中物理清除，操作日志保留 | 说明文字 |
| 人工清除字段 | 表单 | COPY-313 / COPY-314 / COPY-315 | 预约编号、清除原因、确认清除 | 字段/按钮 |
| 人工清除确认 | 弹窗 | COPY-316 / COPY-317 | 确认清除个人信息 / 清除后主记录中的姓名、手机号、证件号不可恢复，操作日志中的记录保留。是否继续？ | ConfirmDialog |
| 清除成功 | 完成 | COPY-318 | 个人信息已清除 | Toast |
| 案件标题/空态 | 页面 | COPY-319 / COPY-320 | 隐私处理记录、暂无处理记录 | 分区 |
| 隐私页标题 | H5 | COPY-187 | 个人信息说明 | PageHeader |
| 隐私正文 | H5 | COPY-395 | 系统收集您的姓名、手机号、证件号及随行人员信息，仅用于本次来访登记与校园安全管理，并按留存期限处理；超过留存期限后，界面与导出中的证件号显示为脱敏信息。 | 正文 |
| 副本入口 | H5 | COPY-185 | 获取我的信息副本 | 按钮 |
| 副本生成中 | H5 | COPY-186 | 正在生成信息副本... | 按钮 loading |
| 令牌失效 | H5 403 | COPY-007 / COPY-396 | 该申请链接已失效，请重新扫码申请 / 重新扫码申请 | 提示与按钮 |

### UI 完整性检验结论（2026-10-19）
- 检验范围：`/system/audit`、`/system/privacy`、`/h5/privacy` 共 5 个分区。
- 通过项：分区四态；日志四维筛选与并排 JSON 差异高亮；留存/清除/案件规则与确认框；H5 403 重签按钮；44×44px。
- 对应缺陷：U2、U9、U12、U14。
| 加载中... | 各页首次取数 | COPY-357 | 加载中... | LoadingState |
| 加载失败 | 各页取数失败 | COPY-355 | 数据加载失败，请点击重试 | ErrorState |
| 重试按钮 | 加载失败态 | COPY-356 | 重试 | ErrorState 按钮 |

## 验证
- [ ] `cd backend && npx vitest run src/modules/compliance/__tests__` → 全部通过。
- [ ] 先自造一条审核日志：`bash scripts/login-fixtures.sh`；`curl -b host.txt -X POST -H "X-CSRF-Token: $(curl -s -b host.txt http://localhost:3000/api/v1/auth/csrf | jq -r .data.csrf_token)" http://localhost:3000/api/v1/reviews/88888888-8888-4888-8888-888888888801/approve` → 200；再 `curl -b admin.txt "http://localhost:3000/api/v1/audit-logs?action=%E5%AE%A1%E6%A0%B8%E5%90%8C%E6%84%8F&date_from=$(date +%F)"` → 返回该条日志，字段含 `before_value`/`after_value`。
- [ ] `curl -b guard.txt http://localhost:3000/api/v1/audit-logs` → 403。
- [ ] `curl -b admin.txt -X PUT -H "X-CSRF-Token: $(curl -s -b admin.txt http://localhost:3000/api/v1/auth/csrf | jq -r .data.csrf_token)" -H ''Content-Type: application/json'' -d ''{"retention_days":90}'' http://localhost:3000/api/v1/privacy/retention` → 200；`GET` 返回 90；`operation_logs` 新增 `action=''修改留存配置''`。
- [ ] `curl -b admin.txt -X POST -H "X-CSRF-Token: $(curl -s -b admin.txt http://localhost:3000/api/v1/auth/csrf | jq -r .data.csrf_token)" -H ''Content-Type: application/json'' -d ''{"reason":"本人申请"}'' http://localhost:3000/api/v1/privacy/appointments/88888888-8888-4888-8888-888888888805/erase` → 200；`docker compose exec -T db psql -U visitor -d visitor_system -c "select visitor_name, visitor_phone, visitor_id_no from appointments where id=''88888888-8888-4888-8888-888888888805''"` → 三列为空；`operation_logs` 新增 `action=''人工清除''` 且 `before_value` 保留明文。
- [ ] `bash scripts/visitor-fixture.sh`（由 `VIS-P1-I05` 提供）→ 生成 `h5.txt` 与 `h5.token`；`curl -H "Authorization: Bearer $(cat h5.token)" http://localhost:3000/api/v1/visitor/privacy/copy` → 200，证件号为掩码。
- [ ] `grep -rn "更正" backend/src frontend/src` → 0 命中。
- [ ] `/system/audit` 选中一条含 `before_value`/`after_value` 的日志 → 抽屉内左右并排展示 JSON，差异键高亮，长值可展开。
- [ ] `/system/privacy` 留存期限输入 `0` → 字段下方 COPY-353；输入 `90` 保存 → Toast COPY-310。
- [ ] H5 令牌失效场景：清除 `h5.token` 后访问 `/h5/privacy` → 显示 COPY-007 与 COPY-396，点击按钮落 `/h5/apply`。
- [ ] 断网验证：`docker compose stop backend` 后 `/system/audit`、`/system/privacy` 显示 COPY-355 与 COPY-356。
- [ ] `grep -Rn "alert(\|confirm(" frontend/src/views/compliance` 无输出。

### 测试用例与结果比对
| TC | 测试点 | 已定预期（摘自 output/v1.0/测试.md） | 本次实际运行结果（未执行） | 比对结论 |
|----|--------|--------------------------------------|----------------------------|----------|
| TC-SM-001 | 敏感操作写日志 | 审核/放行/失败核验/取消/异常/越权拦截各新增一条，含谁/什么/何时/结果 | 未执行；落点：`writeAudit` 在 visit 各 service 的调用点，`action` 取 `审核同意`/`审核拒绝`/`放行`/`核验`(失败)/`取消预约`/`异常上报`/`异常处置`/`越权拦截`，另含 `新增预约`/`离校`；`/system/audit` 展示 | 设计可达 |
| TC-SM-002 | 日志最小字段与查询维度（含明文例外） | 7 个最小字段；四维可查；before/after PII 明文保留 | 未执行；落点：`operation_logs` 表 + `GET /audit-logs` 四维筛选 + 明文 JSONB | 设计可达 |
| TC-SM-003 | 日志留存 ≥180 天 | 留存 ≥180；180 天前仍可查；不提前删除 | 未执行；落点：`system_config.audit_retention_days=365` + `audit-cleanup` 任务 | 设计可达 |
| TC-SM-006 | 人工清除＝物理删除、本人索取更正 | PII 物理删除且不可检索；审计明文保留；本人副本掩码。**O-03**：更正流程无确定接口 | 未执行；落点：`eraseAppointmentPii` + `privacy_cases` + `GET /visitor/privacy/copy`；不提供更正端点 | 部分可达（剔除 O-03 孤儿断言「更正流程」；保留清除、审计保留、副本三项） |

## 在开始改动之前
1. 读取 `spac.md` §6.8 与 `p1-contracts.md` §六。
2. 读取 `output/v1.0/孤儿测试用例.md` 中 O-02/O-03。
3. 检查 visit 门面 `eraseAppointmentPii` 是否可用。

## 完成改动之后
1. 列出创建/修改的文件。
2. 粘贴单测、审计查询、清除后 SQL 结果。
3. 确认 4 条 TC 比对表完成，O-03 已显式剔除。
4. 列出剩余风险（审计清理任务的时间边界由集成闭环卡验证）。
5. 将本卡「测试用例与结果比对」表的「本次实际运行结果」列填写为真实执行结果，写入 `docs/trace/runs/v1/test-results/VIS-P1-I06.md`：逐条 TC 给出命令、原始输出摘要、通过/失败结论；失败项附现象、根因、修复文件与回归命令。
6. 写入 `docs/memory/2026-10-19/VIS-P1-I06.md`。
', '6fb41cb9-db51-4196-a359-19f915a20e19', NULL, 'high', 150000, 15, 10, NULL, NULL, NULL, NULL, NULL, NULL, false, NULL, NULL, NULL, NULL);
INSERT INTO issues (id, created_at, updated_at, created_by_id, updated_by_id, project_id, workspace_id, name, description_json, description_html, description_stripped, state_id, parent_id, priority, sort_order, sequence_id, point, estimate_point_id, type_id, start_date, target_date, completed_at, archived_at, is_draft, external_source, external_id, description_binary, deleted_at) VALUES ('0a42f431-9bd6-4e96-87e0-817c85a1a7af', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', '[VIS-P2-I01] 集成闭环卡', '{}'::jsonb, '## 目标
按三阶段完成全系统集成验证：扫描验证、可运行性验证、缺陷自愈，并产出 `docs/trace/runs/v1/integration-report.md`。

承载需求：无（收口卡）；验证上述 45 条 REQ 的集成结果。

## 验收标准
- [ ] 阶段一：后端 typecheck、前端 build、两端单测、路由发现、健康检查全部通过。
- [ ] 阶段二：10 条端到端链路全部通过。
- [ ] 阶段二补充：18 条路由的 UI 质量闸门六项全部通过，结果写入 `integration-report.md`。
- [ ] 阶段三：每个失败项记录现象、复现命令、根因、修复文件、回归命令。
- [ ] `integration-report.md` 含三阶段命令与原始输出摘要。
- [ ] `docs/trace/runs/v1/test-results/summary.md` 汇总 107 条 TC：卡片编号、TC 编号、结论、结果文件路径；结论只取「通过 / 部分可达 / 未通过」。
- [ ] 修复后重跑阶段一与阶段二全部通过。

## 相关背景

### 必读文件
- `docs/knowledge/phase-contracts/p2-contracts.md` §一。
- `docs/trace/runs/v1/spac.md` §9.3 关键场景验收。
- `docs/trace/runs/v1/issues.yaml` 全部 Phase 1 卡。
- `docs/trace/runs/v1/ui-completeness-audit.md` — 六维检验方法与 U1–U20 缺陷清单。
- `output/v1.0/测试.md` 全部 107 条。

### 共享内核 API（摘自 docs/knowledge/shared-kernel-api.md）
- 本卡不新增符号；只消费。

## 约束

### 命名约束
- 报告路径固定 `docs/trace/runs/v1/integration-report.md`。

### 其他约束
- [边界] 允许修复任意卡片的缺陷，但必须记录修复文件与回归命令。
- [边界] 不得把失败项登记为「已知偏差」后结束。
- [环境] 需数据库的用例在 `docker compose` 启动后执行。

## 实施阶段
测试

## 任务

### 阶段一：扫描验证
1. 执行 `cd backend && npm run typecheck`。
2. 执行 `cd frontend && npm run build`。
3. 执行 `cd backend && npx vitest run`。
4. 执行 `cd frontend && npx vitest run`。
5. 请求一个需要鉴权的领域端点确认路由被发现：`curl -b admin.txt http://localhost:3000/api/v1/audit-logs` → 200 且 `code=0`；未登录同端点 → 401。
6. 执行 `curl -s http://localhost:3000/api/v1/health` → `code=0`。

### 阶段二：可运行性验证
7. 登录 → 工作台。
8. H5 提交 → 审核通过。
9. 核验 → 放行 → 离校。
10. 现场登记。
11. 改期闭环。
12. 黑名单软提示与硬拦。
13. 导出 CSV/XLSX 文件头。
14. 隐私清除。
15. 统计与台账一致。
16. 实时消息徽标。

### 阶段二补充：UI 质量闸门
17. 逐条打开 `spac.md` §4.1 的全部 18 条后台与 H5 路由，按下列六项检查并记录：
    - 四态：`docker compose stop backend` 后页面显示 COPY-355 与 COPY-356，点击重试恢复；空数据页面显示对应 `EmptyState`；首次取数显示 `LoadingState`。
    - 文案：页面不出现英文框架默认文案、裸错误码、HTTP 状态码；所有提示与按钮逐字匹配 `conventions.md` §12.2。
    - 交互：不存在原生 `alert(` / `confirm(`；所有写操作按钮请求期间 `loading` 且禁用。
    - 角色：以 admin、guard、host 三账号分别登录，导航与页内操作按钮与服务端权限一致，不可见操作不渲染。
    - 响应式：后台 1024px、H5 375×667 与 320×568 宽度下无横向滚动；H5 触控目标 ≥44×44px。
    - 可访问性：图标按钮 `aria-label` 非空；表格操作列固定右侧；超长文本单行省略并提供 `a-tooltip`。
18. 逐页检查结果写入 `docs/trace/runs/v1/integration-report.md` 的「UI 质量闸门」小节，任一不合格项按阶段三流程修复并回归。

### 阶段三：缺陷自愈
19. 逐项记录并修复，重跑阶段一、阶段二与 UI 质量闸门。
20. 汇总六张卡的 `test-results/VIS-P1-I0{1..6}.md`，产出 `docs/trace/runs/v1/test-results/summary.md`：107 行，逐行给出卡片、TC、结论、结果文件锚点。
21. 产出 `docs/trace/runs/v1/integration-report.md`。

### 用户可见文案清单（本卡必含，逐字）
| 类别 | 触发场景 | 逐字文案 | 渲染位置 |
|------|---------|---------|---------|
| 报告标题 | 报告 | 集成闭环报告 | 标题 |
| 阶段通过 | 每阶段结束 | 阶段通过：{阶段名} | 报告正文 |
| 阶段失败 | 有失败项 | 阶段失败：{检查项} | 报告正文 |

### UI 完整性检验结论（2026-10-19）
- 检验范围：18 条路由的浏览器实测闸门。
- 通过项：六维检查（四态、文案、交互、角色、响应式、可访问性）已写入阶段二任务 17–18；结果写入 `integration-report.md`「UI 质量闸门」小节。
- 对应缺陷：U19。

## 验证
- [ ] 阶段一六项检查全部退出码 0。
- [ ] 阶段二十条链路逐条有 `curl` 或浏览器观察记录。
- [ ] UI 质量闸门：`docker compose stop backend` 后逐页确认 COPY-355/COPY-356；`grep -rn "alert(\|confirm(\|Modal.confirm" frontend/src --include=''*.vue'' --include=''*.ts''` → 0 命中；三种角色逐页核对不可见操作未渲染；320px 宽无横向滚动。
- [ ] `grep -c "阶段失败" docs/trace/runs/v1/integration-report.md` → `0`。
- [ ] 重跑阶段一与阶段二全部通过。

## 在开始改动之前
1. 读取 `p2-contracts.md` §一。
2. 确认 `docker compose ps` 三服务 healthy。
3. 确认 seed 已执行；执行 `bash scripts/login-fixtures.sh` 生成 `admin.txt`、`guard.txt`、`host.txt`，执行 `bash scripts/visitor-fixture.sh` 生成 `h5.token`。

## 完成改动之后
1. 列出修复的文件与回归命令。
2. 粘贴三阶段结果。
3. 确认全部验证通过。
4. 列出剩余风险（性能与兼容项需单独记录实测数据）。
5. 写入 `docs/memory/2026-10-19/VIS-P2-I01.md`。
', '## 目标
按三阶段完成全系统集成验证：扫描验证、可运行性验证、缺陷自愈，并产出 `docs/trace/runs/v1/integration-report.md`。

承载需求：无（收口卡）；验证上述 45 条 REQ 的集成结果。

## 验收标准
- [ ] 阶段一：后端 typecheck、前端 build、两端单测、路由发现、健康检查全部通过。
- [ ] 阶段二：10 条端到端链路全部通过。
- [ ] 阶段二补充：18 条路由的 UI 质量闸门六项全部通过，结果写入 `integration-report.md`。
- [ ] 阶段三：每个失败项记录现象、复现命令、根因、修复文件、回归命令。
- [ ] `integration-report.md` 含三阶段命令与原始输出摘要。
- [ ] `docs/trace/runs/v1/test-results/summary.md` 汇总 107 条 TC：卡片编号、TC 编号、结论、结果文件路径；结论只取「通过 / 部分可达 / 未通过」。
- [ ] 修复后重跑阶段一与阶段二全部通过。

## 相关背景

### 必读文件
- `docs/knowledge/phase-contracts/p2-contracts.md` §一。
- `docs/trace/runs/v1/spac.md` §9.3 关键场景验收。
- `docs/trace/runs/v1/issues.yaml` 全部 Phase 1 卡。
- `docs/trace/runs/v1/ui-completeness-audit.md` — 六维检验方法与 U1–U20 缺陷清单。
- `output/v1.0/测试.md` 全部 107 条。

### 共享内核 API（摘自 docs/knowledge/shared-kernel-api.md）
- 本卡不新增符号；只消费。

## 约束

### 命名约束
- 报告路径固定 `docs/trace/runs/v1/integration-report.md`。

### 其他约束
- [边界] 允许修复任意卡片的缺陷，但必须记录修复文件与回归命令。
- [边界] 不得把失败项登记为「已知偏差」后结束。
- [环境] 需数据库的用例在 `docker compose` 启动后执行。

## 实施阶段
测试

## 任务

### 阶段一：扫描验证
1. 执行 `cd backend && npm run typecheck`。
2. 执行 `cd frontend && npm run build`。
3. 执行 `cd backend && npx vitest run`。
4. 执行 `cd frontend && npx vitest run`。
5. 请求一个需要鉴权的领域端点确认路由被发现：`curl -b admin.txt http://localhost:3000/api/v1/audit-logs` → 200 且 `code=0`；未登录同端点 → 401。
6. 执行 `curl -s http://localhost:3000/api/v1/health` → `code=0`。

### 阶段二：可运行性验证
7. 登录 → 工作台。
8. H5 提交 → 审核通过。
9. 核验 → 放行 → 离校。
10. 现场登记。
11. 改期闭环。
12. 黑名单软提示与硬拦。
13. 导出 CSV/XLSX 文件头。
14. 隐私清除。
15. 统计与台账一致。
16. 实时消息徽标。

### 阶段二补充：UI 质量闸门
17. 逐条打开 `spac.md` §4.1 的全部 18 条后台与 H5 路由，按下列六项检查并记录：
    - 四态：`docker compose stop backend` 后页面显示 COPY-355 与 COPY-356，点击重试恢复；空数据页面显示对应 `EmptyState`；首次取数显示 `LoadingState`。
    - 文案：页面不出现英文框架默认文案、裸错误码、HTTP 状态码；所有提示与按钮逐字匹配 `conventions.md` §12.2。
    - 交互：不存在原生 `alert(` / `confirm(`；所有写操作按钮请求期间 `loading` 且禁用。
    - 角色：以 admin、guard、host 三账号分别登录，导航与页内操作按钮与服务端权限一致，不可见操作不渲染。
    - 响应式：后台 1024px、H5 375×667 与 320×568 宽度下无横向滚动；H5 触控目标 ≥44×44px。
    - 可访问性：图标按钮 `aria-label` 非空；表格操作列固定右侧；超长文本单行省略并提供 `a-tooltip`。
18. 逐页检查结果写入 `docs/trace/runs/v1/integration-report.md` 的「UI 质量闸门」小节，任一不合格项按阶段三流程修复并回归。

### 阶段三：缺陷自愈
19. 逐项记录并修复，重跑阶段一、阶段二与 UI 质量闸门。
20. 汇总六张卡的 `test-results/VIS-P1-I0{1..6}.md`，产出 `docs/trace/runs/v1/test-results/summary.md`：107 行，逐行给出卡片、TC、结论、结果文件锚点。
21. 产出 `docs/trace/runs/v1/integration-report.md`。

### 用户可见文案清单（本卡必含，逐字）
| 类别 | 触发场景 | 逐字文案 | 渲染位置 |
|------|---------|---------|---------|
| 报告标题 | 报告 | 集成闭环报告 | 标题 |
| 阶段通过 | 每阶段结束 | 阶段通过：{阶段名} | 报告正文 |
| 阶段失败 | 有失败项 | 阶段失败：{检查项} | 报告正文 |

### UI 完整性检验结论（2026-10-19）
- 检验范围：18 条路由的浏览器实测闸门。
- 通过项：六维检查（四态、文案、交互、角色、响应式、可访问性）已写入阶段二任务 17–18；结果写入 `integration-report.md`「UI 质量闸门」小节。
- 对应缺陷：U19。

## 验证
- [ ] 阶段一六项检查全部退出码 0。
- [ ] 阶段二十条链路逐条有 `curl` 或浏览器观察记录。
- [ ] UI 质量闸门：`docker compose stop backend` 后逐页确认 COPY-355/COPY-356；`grep -rn "alert(\|confirm(\|Modal.confirm" frontend/src --include=''*.vue'' --include=''*.ts''` → 0 命中；三种角色逐页核对不可见操作未渲染；320px 宽无横向滚动。
- [ ] `grep -c "阶段失败" docs/trace/runs/v1/integration-report.md` → `0`。
- [ ] 重跑阶段一与阶段二全部通过。

## 在开始改动之前
1. 读取 `p2-contracts.md` §一。
2. 确认 `docker compose ps` 三服务 healthy。
3. 确认 seed 已执行；执行 `bash scripts/login-fixtures.sh` 生成 `admin.txt`、`guard.txt`、`host.txt`，执行 `bash scripts/visitor-fixture.sh` 生成 `h5.token`。

## 完成改动之后
1. 列出修复的文件与回归命令。
2. 粘贴三阶段结果。
3. 确认全部验证通过。
4. 列出剩余风险（性能与兼容项需单独记录实测数据）。
5. 写入 `docs/memory/2026-10-19/VIS-P2-I01.md`。
', '6fb41cb9-db51-4196-a359-19f915a20e19', NULL, 'high', 160000, 16, 8, NULL, NULL, NULL, NULL, NULL, NULL, false, NULL, NULL, NULL, NULL);
INSERT INTO issues (id, created_at, updated_at, created_by_id, updated_by_id, project_id, workspace_id, name, description_json, description_html, description_stripped, state_id, parent_id, priority, sort_order, sequence_id, point, estimate_point_id, type_id, start_date, target_date, completed_at, archived_at, is_draft, external_source, external_id, description_binary, deleted_at) VALUES ('2f123ef6-a1d4-48a8-8966-c5cca7b18a0c', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', '[VIS-P2-I02] 封版归档卡', '{}'::jsonb, '## 目标
完成 10 项封版检查，产出 `FREEZE`、git tag `v1.0.0-freeze` 与最终 README。

承载需求：无（收口卡）。

## 验收标准
- [ ] 10 项检查全部通过并在 `FREEZE` 中记录。
- [ ] `contracts/` 七件套存在。
- [ ] 每个 adminOnly 端点用 guard 请求返回 403。
- [ ] 迁移与种子各连续执行两次无冲突。
- [ ] `test-results/summary.md` 存在且 107 行全部有结论，无「未执行」。
- [ ] `FREEZE` 记录基线 commit、日期、检查结果。
- [ ] tag `v1.0.0-freeze` 存在。

## 相关背景

### 必读文件
- `docs/knowledge/phase-contracts/p2-contracts.md` §二。
- `README.md`。
- `docs/trace/runs/v1/integration-report.md`。

## 约束

### 命名约束
- `FREEZE` 路径固定 `docs/trace/runs/v1/FREEZE`。
- tag 固定 `v1.0.0-freeze`。

### 其他约束
- [边界] 本卡只做检查与归档，不改业务代码。
- [边界] 任一检查失败 → 回对应卡修复后重跑。

## 实施阶段
审查

## 任务
1. 执行 10 项检查：设计文件齐全、契约七件套、卡片全部关闭、端点逐条可达、权限点逐条生效、迁移幂等、种子幂等、测试绿、README 可用、无伪占位。
2. 创建 `docs/trace/runs/v1/FREEZE` — 记录基线 commit、日期、10 项结果。
3. 更新 `README.md` — 最终启动指南与测试账号。
4. 创建 git tag `v1.0.0-freeze`。

### 用户可见文案清单（本卡必含，逐字）
| 类别 | 触发场景 | 逐字文案 | 渲染位置 |
|------|---------|---------|---------|
| 封版标题 | FREEZE | V1.0 封版记录 | 标题 |
| 检查通过 | 每项 | 通过：{检查项} | 正文 |
| 检查失败 | 任一项 | 未通过：{检查项} | 正文 |

## 验证
- [ ] `ls docs/trace/runs/v1/FREEZE` → 存在。
- [ ] `git tag -l v1.0.0-freeze` → 输出 tag。
- [ ] `grep -c "未通过" docs/trace/runs/v1/FREEZE` → `0`。
- [ ] 按 README 从零启动成功，4 个测试账号可登录。

## 在开始改动之前
1. 读取 `p2-contracts.md` §二。
2. 确认集成闭环卡已完成。

## 完成改动之后
1. 列出 FREEZE 与 tag。
2. 粘贴 10 项检查结果。
3. 确认全部通过。
4. 列出剩余风险（下一轮增量前需状态刷新）。
5. 写入 `docs/memory/2026-10-19/VIS-P2-I02.md`。
', '## 目标
完成 10 项封版检查，产出 `FREEZE`、git tag `v1.0.0-freeze` 与最终 README。

承载需求：无（收口卡）。

## 验收标准
- [ ] 10 项检查全部通过并在 `FREEZE` 中记录。
- [ ] `contracts/` 七件套存在。
- [ ] 每个 adminOnly 端点用 guard 请求返回 403。
- [ ] 迁移与种子各连续执行两次无冲突。
- [ ] `test-results/summary.md` 存在且 107 行全部有结论，无「未执行」。
- [ ] `FREEZE` 记录基线 commit、日期、检查结果。
- [ ] tag `v1.0.0-freeze` 存在。

## 相关背景

### 必读文件
- `docs/knowledge/phase-contracts/p2-contracts.md` §二。
- `README.md`。
- `docs/trace/runs/v1/integration-report.md`。

## 约束

### 命名约束
- `FREEZE` 路径固定 `docs/trace/runs/v1/FREEZE`。
- tag 固定 `v1.0.0-freeze`。

### 其他约束
- [边界] 本卡只做检查与归档，不改业务代码。
- [边界] 任一检查失败 → 回对应卡修复后重跑。

## 实施阶段
审查

## 任务
1. 执行 10 项检查：设计文件齐全、契约七件套、卡片全部关闭、端点逐条可达、权限点逐条生效、迁移幂等、种子幂等、测试绿、README 可用、无伪占位。
2. 创建 `docs/trace/runs/v1/FREEZE` — 记录基线 commit、日期、10 项结果。
3. 更新 `README.md` — 最终启动指南与测试账号。
4. 创建 git tag `v1.0.0-freeze`。

### 用户可见文案清单（本卡必含，逐字）
| 类别 | 触发场景 | 逐字文案 | 渲染位置 |
|------|---------|---------|---------|
| 封版标题 | FREEZE | V1.0 封版记录 | 标题 |
| 检查通过 | 每项 | 通过：{检查项} | 正文 |
| 检查失败 | 任一项 | 未通过：{检查项} | 正文 |

## 验证
- [ ] `ls docs/trace/runs/v1/FREEZE` → 存在。
- [ ] `git tag -l v1.0.0-freeze` → 输出 tag。
- [ ] `grep -c "未通过" docs/trace/runs/v1/FREEZE` → `0`。
- [ ] 按 README 从零启动成功，4 个测试账号可登录。

## 在开始改动之前
1. 读取 `p2-contracts.md` §二。
2. 确认集成闭环卡已完成。

## 完成改动之后
1. 列出 FREEZE 与 tag。
2. 粘贴 10 项检查结果。
3. 确认全部通过。
4. 列出剩余风险（下一轮增量前需状态刷新）。
5. 写入 `docs/memory/2026-10-19/VIS-P2-I02.md`。
', '6fb41cb9-db51-4196-a359-19f915a20e19', NULL, 'high', 170000, 17, 5, NULL, NULL, NULL, NULL, NULL, NULL, false, NULL, NULL, NULL, NULL);
INSERT INTO issues (id, created_at, updated_at, created_by_id, updated_by_id, project_id, workspace_id, name, description_json, description_html, description_stripped, state_id, parent_id, priority, sort_order, sequence_id, point, estimate_point_id, type_id, start_date, target_date, completed_at, archived_at, is_draft, external_source, external_id, description_binary, deleted_at) VALUES ('72ee7324-4187-4f8b-ad75-5c74c49dc36d', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', '[VIS-P2-I03] 状态刷新卡', '{}'::jsonb, '## 目标
从实际代码反写 `contracts/` 七件套，完成 8 项一致性检查，产出 `state-refresh-report.md`。

承载需求：无（收口卡）。

## 验收标准
- [ ] `openapi.yaml` 与实际端点逐条一致。
- [ ] `events.yaml` 与实际事件一致。
- [ ] `schema.sql` 与实际迁移一致。
- [ ] `symbols.yaml` 与 `shared-kernel-manifest.yaml` 及实际导出一致。
- [ ] `routes.yaml` 与实际路由、导航一致。
- [ ] `naming.yaml` 与实际命名一致。
- [ ] `cross-context-writes.md` 与实际调用一致。
- [ ] 涌现约定已回写 `conventions.md`。
- [ ] `state-refresh-report.md` 记录 8 项检查、差异、修正。

## 相关背景

### 必读文件
- `docs/knowledge/phase-contracts/p2-contracts.md` §三。
- `contracts/` 七件套。
- `backend/src/modules/*/api/*.routes.ts`、`backend/db/migrations/*.sql`、`frontend/src/nav/navigation.ts`。

## 约束

### 命名约束
- 刷新后的契约 JSON 键仍为 snake_case。

### 其他约束
- [边界] 只写 `contracts/`、`conventions.md` 与报告，不改业务代码。
- [边界] 发现代码与设计不一致时，以代码为事实回写契约，并在报告记录。

## 实施阶段
审查

## 任务
1. 从 `*.routes.ts` 反写 `contracts/openapi.yaml`。
2. 从迁移反写 `contracts/schema.sql`。
3. 从通知生产/消费点反写 `contracts/events.yaml`。
4. 从实际表列与权限点反写 `contracts/naming.yaml`。
5. 从 `navigation.ts` 与实际路由反写 `contracts/routes.yaml`。
6. 从实际导出反写 `contracts/symbols.yaml`。
7. 从门面调用与只读 SQL 反写 `contracts/cross-context-writes.md`。
8. 将涌现约定追加到 `conventions.md`。
9. 创建 `docs/trace/runs/v1/state-refresh-report.md`。

### 用户可见文案清单（本卡必含，逐字）
| 类别 | 触发场景 | 逐字文案 | 渲染位置 |
|------|---------|---------|---------|
| 报告标题 | 报告 | 状态刷新报告 | 标题 |
| 检查通过 | 每项 | 通过：{检查项} | 正文 |
| 差异记录 | 有差异 | 差异：{文件} {说明} | 正文 |

## 验证
- [ ] `grep -c "^  /" contracts/openapi.yaml` 与路由文件端点数一致。
- [ ] `diff` 迁移 DDL 与 `contracts/schema.sql` 无差异。
- [ ] `grep -n "notification:new" contracts/events.yaml` 存在。
- [ ] `grep -c "通过：" docs/trace/runs/v1/state-refresh-report.md` → `8`。
- [ ] `git status --porcelain | grep -vE ''^(..) (contracts/|conventions\.md|docs/trace/runs/v1/state-refresh-report\.md)''` → 0 行。

## 在开始改动之前
1. 读取 `p2-contracts.md` §三。
2. 确认封版归档卡已完成。

## 完成改动之后
1. 列出刷新后的七个契约文件与报告。
2. 粘贴 8 项检查结果。
3. 确认全部通过。
4. 列出剩余风险（下一轮增量以本契约集为基线）。
5. 写入 `docs/memory/2026-10-19/VIS-P2-I03.md`。
', '## 目标
从实际代码反写 `contracts/` 七件套，完成 8 项一致性检查，产出 `state-refresh-report.md`。

承载需求：无（收口卡）。

## 验收标准
- [ ] `openapi.yaml` 与实际端点逐条一致。
- [ ] `events.yaml` 与实际事件一致。
- [ ] `schema.sql` 与实际迁移一致。
- [ ] `symbols.yaml` 与 `shared-kernel-manifest.yaml` 及实际导出一致。
- [ ] `routes.yaml` 与实际路由、导航一致。
- [ ] `naming.yaml` 与实际命名一致。
- [ ] `cross-context-writes.md` 与实际调用一致。
- [ ] 涌现约定已回写 `conventions.md`。
- [ ] `state-refresh-report.md` 记录 8 项检查、差异、修正。

## 相关背景

### 必读文件
- `docs/knowledge/phase-contracts/p2-contracts.md` §三。
- `contracts/` 七件套。
- `backend/src/modules/*/api/*.routes.ts`、`backend/db/migrations/*.sql`、`frontend/src/nav/navigation.ts`。

## 约束

### 命名约束
- 刷新后的契约 JSON 键仍为 snake_case。

### 其他约束
- [边界] 只写 `contracts/`、`conventions.md` 与报告，不改业务代码。
- [边界] 发现代码与设计不一致时，以代码为事实回写契约，并在报告记录。

## 实施阶段
审查

## 任务
1. 从 `*.routes.ts` 反写 `contracts/openapi.yaml`。
2. 从迁移反写 `contracts/schema.sql`。
3. 从通知生产/消费点反写 `contracts/events.yaml`。
4. 从实际表列与权限点反写 `contracts/naming.yaml`。
5. 从 `navigation.ts` 与实际路由反写 `contracts/routes.yaml`。
6. 从实际导出反写 `contracts/symbols.yaml`。
7. 从门面调用与只读 SQL 反写 `contracts/cross-context-writes.md`。
8. 将涌现约定追加到 `conventions.md`。
9. 创建 `docs/trace/runs/v1/state-refresh-report.md`。

### 用户可见文案清单（本卡必含，逐字）
| 类别 | 触发场景 | 逐字文案 | 渲染位置 |
|------|---------|---------|---------|
| 报告标题 | 报告 | 状态刷新报告 | 标题 |
| 检查通过 | 每项 | 通过：{检查项} | 正文 |
| 差异记录 | 有差异 | 差异：{文件} {说明} | 正文 |

## 验证
- [ ] `grep -c "^  /" contracts/openapi.yaml` 与路由文件端点数一致。
- [ ] `diff` 迁移 DDL 与 `contracts/schema.sql` 无差异。
- [ ] `grep -n "notification:new" contracts/events.yaml` 存在。
- [ ] `grep -c "通过：" docs/trace/runs/v1/state-refresh-report.md` → `8`。
- [ ] `git status --porcelain | grep -vE ''^(..) (contracts/|conventions\.md|docs/trace/runs/v1/state-refresh-report\.md)''` → 0 行。

## 在开始改动之前
1. 读取 `p2-contracts.md` §三。
2. 确认封版归档卡已完成。

## 完成改动之后
1. 列出刷新后的七个契约文件与报告。
2. 粘贴 8 项检查结果。
3. 确认全部通过。
4. 列出剩余风险（下一轮增量以本契约集为基线）。
5. 写入 `docs/memory/2026-10-19/VIS-P2-I03.md`。
', '6fb41cb9-db51-4196-a359-19f915a20e19', NULL, 'medium', 180000, 18, 5, NULL, NULL, NULL, NULL, NULL, NULL, false, NULL, NULL, NULL, NULL);

-- ============ issue_sequences (18) ============
INSERT INTO issue_sequences (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, sequence, project_id, workspace_id, deleted, deleted_at) VALUES ('0e3682d9-f738-4dee-b1a5-110c2ca364fa', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '7bd3ad51-7dbc-47c2-93de-08eaa2ebc8eb', 1, '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', false, NULL);
INSERT INTO issue_sequences (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, sequence, project_id, workspace_id, deleted, deleted_at) VALUES ('273b06e4-2d72-4c92-a59c-691743a52895', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '2b04c45b-1ebd-489a-bfee-3685ee181656', 2, '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', false, NULL);
INSERT INTO issue_sequences (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, sequence, project_id, workspace_id, deleted, deleted_at) VALUES ('4cfb26b6-8a7c-4228-b82b-516b670a596b', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '33cb93ab-b049-49f7-89a4-e424d31c1de9', 3, '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', false, NULL);
INSERT INTO issue_sequences (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, sequence, project_id, workspace_id, deleted, deleted_at) VALUES ('d00d273d-21b5-45a5-90c7-6feaa647119f', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '337f0cc4-12cc-4936-906c-d4037ecb5a70', 4, '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', false, NULL);
INSERT INTO issue_sequences (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, sequence, project_id, workspace_id, deleted, deleted_at) VALUES ('0424d599-110e-48aa-b757-c0330e6a21a6', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '9324bf50-22d1-46cf-be45-76c9ceb28fb5', 5, '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', false, NULL);
INSERT INTO issue_sequences (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, sequence, project_id, workspace_id, deleted, deleted_at) VALUES ('44dfd100-512f-4ded-8ae7-27f79e69868f', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', 'c8ad6233-7a8f-41c3-b2d9-ba2858513520', 6, '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', false, NULL);
INSERT INTO issue_sequences (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, sequence, project_id, workspace_id, deleted, deleted_at) VALUES ('f467ad2a-25d7-4c9e-acf5-c3676fd29560', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', 'b6b838b4-5b81-4098-90e3-fe8c6bf2415c', 7, '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', false, NULL);
INSERT INTO issue_sequences (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, sequence, project_id, workspace_id, deleted, deleted_at) VALUES ('bd823f15-ba85-4fda-8494-f381ae7521a7', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '6b2ca529-2213-40a1-b85e-0c9e2a57ecdb', 8, '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', false, NULL);
INSERT INTO issue_sequences (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, sequence, project_id, workspace_id, deleted, deleted_at) VALUES ('64ca565b-efdc-41a5-9a17-60e9fbe1c6a8', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', 'f1a4b811-bec8-4d4d-bf28-cccf59d3528c', 9, '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', false, NULL);
INSERT INTO issue_sequences (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, sequence, project_id, workspace_id, deleted, deleted_at) VALUES ('f02efb8d-cc61-4144-8a2e-b3ded6c07158', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', 'd11aab0b-8e8c-4f5e-a656-e320405b9684', 10, '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', false, NULL);
INSERT INTO issue_sequences (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, sequence, project_id, workspace_id, deleted, deleted_at) VALUES ('08b01754-93a1-4de5-a083-3c780e8e238a', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '775f4dc5-7114-4e0e-80e7-2631822f16c1', 11, '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', false, NULL);
INSERT INTO issue_sequences (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, sequence, project_id, workspace_id, deleted, deleted_at) VALUES ('22e44745-be47-41c0-a5d7-dea48518768b', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '0b8c0e07-3bf6-44b2-9a84-93d6f1cb081f', 12, '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', false, NULL);
INSERT INTO issue_sequences (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, sequence, project_id, workspace_id, deleted, deleted_at) VALUES ('b8720317-980f-4d00-8c0b-7304fa62b63d', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '0e1f4737-cea2-497a-9e8d-41e84106c892', 13, '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', false, NULL);
INSERT INTO issue_sequences (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, sequence, project_id, workspace_id, deleted, deleted_at) VALUES ('42542cd1-764b-4e9f-8cb4-e2dce6ba6900', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '4d7ff842-46d7-42c7-983c-595a650671c9', 14, '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', false, NULL);
INSERT INTO issue_sequences (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, sequence, project_id, workspace_id, deleted, deleted_at) VALUES ('1f374d1e-1a2b-4fad-b4e2-26de94712071', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', 'eaea3ff3-4b13-4e26-be0f-3998ce8df732', 15, '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', false, NULL);
INSERT INTO issue_sequences (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, sequence, project_id, workspace_id, deleted, deleted_at) VALUES ('3d9bbec4-341c-4267-aaac-7e4a1e5cd355', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '0a42f431-9bd6-4e96-87e0-817c85a1a7af', 16, '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', false, NULL);
INSERT INTO issue_sequences (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, sequence, project_id, workspace_id, deleted, deleted_at) VALUES ('d92f221e-6e76-4eb9-b9d2-7f74ccd3986b', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '2f123ef6-a1d4-48a8-8966-c5cca7b18a0c', 17, '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', false, NULL);
INSERT INTO issue_sequences (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, sequence, project_id, workspace_id, deleted, deleted_at) VALUES ('e3a5d7e7-bf1e-459c-b4a8-6086f55d6afc', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '72ee7324-4187-4f8b-ad75-5c74c49dc36d', 18, '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', false, NULL);

-- ============ issue_blockers + issue_relations (42) ============
INSERT INTO issue_blockers (id, created_at, updated_at, created_by_id, updated_by_id, block_id, blocked_by_id, project_id, workspace_id, deleted_at) VALUES ('f3b2507c-5748-4c35-831f-731f0ff5b5ae', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '2b04c45b-1ebd-489a-bfee-3685ee181656', '7bd3ad51-7dbc-47c2-93de-08eaa2ebc8eb', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_relations (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, related_issue_id, relation_type, project_id, workspace_id) VALUES ('7d514671-af18-438f-b7d0-13ce3236f3ff', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '2b04c45b-1ebd-489a-bfee-3685ee181656', '7bd3ad51-7dbc-47c2-93de-08eaa2ebc8eb', 'blocked_by', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9');
INSERT INTO issue_blockers (id, created_at, updated_at, created_by_id, updated_by_id, block_id, blocked_by_id, project_id, workspace_id, deleted_at) VALUES ('ce290d0d-0d6e-4e65-b928-d71d2adf5e36', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '33cb93ab-b049-49f7-89a4-e424d31c1de9', '2b04c45b-1ebd-489a-bfee-3685ee181656', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_relations (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, related_issue_id, relation_type, project_id, workspace_id) VALUES ('3cd27c0e-9996-4219-aa7d-ac073a4fe0eb', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '33cb93ab-b049-49f7-89a4-e424d31c1de9', '2b04c45b-1ebd-489a-bfee-3685ee181656', 'blocked_by', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9');
INSERT INTO issue_blockers (id, created_at, updated_at, created_by_id, updated_by_id, block_id, blocked_by_id, project_id, workspace_id, deleted_at) VALUES ('138e3985-a416-4304-a448-5e28da7415e2', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '337f0cc4-12cc-4936-906c-d4037ecb5a70', '2b04c45b-1ebd-489a-bfee-3685ee181656', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_relations (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, related_issue_id, relation_type, project_id, workspace_id) VALUES ('0f7711a1-aa14-432d-8442-dfad222f1a98', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '337f0cc4-12cc-4936-906c-d4037ecb5a70', '2b04c45b-1ebd-489a-bfee-3685ee181656', 'blocked_by', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9');
INSERT INTO issue_blockers (id, created_at, updated_at, created_by_id, updated_by_id, block_id, blocked_by_id, project_id, workspace_id, deleted_at) VALUES ('5c226eb1-8124-4c03-b57d-5bea1b0eb882', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '337f0cc4-12cc-4936-906c-d4037ecb5a70', '33cb93ab-b049-49f7-89a4-e424d31c1de9', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_relations (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, related_issue_id, relation_type, project_id, workspace_id) VALUES ('39567674-898e-4a2f-8dab-cda70406e04b', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '337f0cc4-12cc-4936-906c-d4037ecb5a70', '33cb93ab-b049-49f7-89a4-e424d31c1de9', 'blocked_by', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9');
INSERT INTO issue_blockers (id, created_at, updated_at, created_by_id, updated_by_id, block_id, blocked_by_id, project_id, workspace_id, deleted_at) VALUES ('3fd09f45-89fc-43f8-b7df-a906221e243b', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '9324bf50-22d1-46cf-be45-76c9ceb28fb5', '7bd3ad51-7dbc-47c2-93de-08eaa2ebc8eb', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_relations (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, related_issue_id, relation_type, project_id, workspace_id) VALUES ('45e70059-495f-4388-94d1-324525d55216', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '9324bf50-22d1-46cf-be45-76c9ceb28fb5', '7bd3ad51-7dbc-47c2-93de-08eaa2ebc8eb', 'blocked_by', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9');
INSERT INTO issue_blockers (id, created_at, updated_at, created_by_id, updated_by_id, block_id, blocked_by_id, project_id, workspace_id, deleted_at) VALUES ('7e06b7b9-c81c-4aa6-b810-0f2b1407c965', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', 'c8ad6233-7a8f-41c3-b2d9-ba2858513520', '9324bf50-22d1-46cf-be45-76c9ceb28fb5', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_relations (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, related_issue_id, relation_type, project_id, workspace_id) VALUES ('791fdc47-8f70-4e7b-846b-871602f42619', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', 'c8ad6233-7a8f-41c3-b2d9-ba2858513520', '9324bf50-22d1-46cf-be45-76c9ceb28fb5', 'blocked_by', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9');
INSERT INTO issue_blockers (id, created_at, updated_at, created_by_id, updated_by_id, block_id, blocked_by_id, project_id, workspace_id, deleted_at) VALUES ('49eef7ff-6f99-42ac-a738-518980018c41', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', 'b6b838b4-5b81-4098-90e3-fe8c6bf2415c', '7bd3ad51-7dbc-47c2-93de-08eaa2ebc8eb', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_relations (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, related_issue_id, relation_type, project_id, workspace_id) VALUES ('ab7d857e-6082-433c-a0d5-105f16257d65', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', 'b6b838b4-5b81-4098-90e3-fe8c6bf2415c', '7bd3ad51-7dbc-47c2-93de-08eaa2ebc8eb', 'blocked_by', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9');
INSERT INTO issue_blockers (id, created_at, updated_at, created_by_id, updated_by_id, block_id, blocked_by_id, project_id, workspace_id, deleted_at) VALUES ('eba5ea33-917b-4ca9-b278-81042f2dc5f8', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', 'b6b838b4-5b81-4098-90e3-fe8c6bf2415c', '2b04c45b-1ebd-489a-bfee-3685ee181656', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_relations (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, related_issue_id, relation_type, project_id, workspace_id) VALUES ('8549aaad-2c54-4509-b82f-88fed766099a', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', 'b6b838b4-5b81-4098-90e3-fe8c6bf2415c', '2b04c45b-1ebd-489a-bfee-3685ee181656', 'blocked_by', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9');
INSERT INTO issue_blockers (id, created_at, updated_at, created_by_id, updated_by_id, block_id, blocked_by_id, project_id, workspace_id, deleted_at) VALUES ('7d121010-eee8-4f18-acca-0873afdc8e0c', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', 'b6b838b4-5b81-4098-90e3-fe8c6bf2415c', '33cb93ab-b049-49f7-89a4-e424d31c1de9', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_relations (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, related_issue_id, relation_type, project_id, workspace_id) VALUES ('78dff284-6b3f-493d-aca5-53b0c1c5995c', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', 'b6b838b4-5b81-4098-90e3-fe8c6bf2415c', '33cb93ab-b049-49f7-89a4-e424d31c1de9', 'blocked_by', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9');
INSERT INTO issue_blockers (id, created_at, updated_at, created_by_id, updated_by_id, block_id, blocked_by_id, project_id, workspace_id, deleted_at) VALUES ('bdcd6008-0de5-4bea-89a5-c73a1765e9d7', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', 'b6b838b4-5b81-4098-90e3-fe8c6bf2415c', '337f0cc4-12cc-4936-906c-d4037ecb5a70', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_relations (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, related_issue_id, relation_type, project_id, workspace_id) VALUES ('cdee4b04-3a66-4171-b310-8c9d6971c27e', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', 'b6b838b4-5b81-4098-90e3-fe8c6bf2415c', '337f0cc4-12cc-4936-906c-d4037ecb5a70', 'blocked_by', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9');
INSERT INTO issue_blockers (id, created_at, updated_at, created_by_id, updated_by_id, block_id, blocked_by_id, project_id, workspace_id, deleted_at) VALUES ('6be688a8-7c75-45b2-b5e2-6263c782ef92', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', 'b6b838b4-5b81-4098-90e3-fe8c6bf2415c', '9324bf50-22d1-46cf-be45-76c9ceb28fb5', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_relations (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, related_issue_id, relation_type, project_id, workspace_id) VALUES ('a3a6406f-b5a5-4d2b-a3a0-933b802403da', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', 'b6b838b4-5b81-4098-90e3-fe8c6bf2415c', '9324bf50-22d1-46cf-be45-76c9ceb28fb5', 'blocked_by', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9');
INSERT INTO issue_blockers (id, created_at, updated_at, created_by_id, updated_by_id, block_id, blocked_by_id, project_id, workspace_id, deleted_at) VALUES ('10ca2b8c-3a8d-4571-a0dc-ebcfda46de66', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', 'b6b838b4-5b81-4098-90e3-fe8c6bf2415c', 'c8ad6233-7a8f-41c3-b2d9-ba2858513520', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_relations (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, related_issue_id, relation_type, project_id, workspace_id) VALUES ('b4d6035c-4474-4967-bd44-52c20626ed83', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', 'b6b838b4-5b81-4098-90e3-fe8c6bf2415c', 'c8ad6233-7a8f-41c3-b2d9-ba2858513520', 'blocked_by', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9');
INSERT INTO issue_blockers (id, created_at, updated_at, created_by_id, updated_by_id, block_id, blocked_by_id, project_id, workspace_id, deleted_at) VALUES ('47999381-3db0-4ac9-a4bd-872ba6e8598b', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '6b2ca529-2213-40a1-b85e-0c9e2a57ecdb', '2b04c45b-1ebd-489a-bfee-3685ee181656', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_relations (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, related_issue_id, relation_type, project_id, workspace_id) VALUES ('198d5454-56be-4dd2-9a1c-23230bea64ed', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '6b2ca529-2213-40a1-b85e-0c9e2a57ecdb', '2b04c45b-1ebd-489a-bfee-3685ee181656', 'blocked_by', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9');
INSERT INTO issue_blockers (id, created_at, updated_at, created_by_id, updated_by_id, block_id, blocked_by_id, project_id, workspace_id, deleted_at) VALUES ('4170471e-57ad-4db9-95f5-0107c0cf9fc0', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '6b2ca529-2213-40a1-b85e-0c9e2a57ecdb', '33cb93ab-b049-49f7-89a4-e424d31c1de9', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_relations (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, related_issue_id, relation_type, project_id, workspace_id) VALUES ('999c4dc6-e057-4335-8c63-d6a289ecfc68', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '6b2ca529-2213-40a1-b85e-0c9e2a57ecdb', '33cb93ab-b049-49f7-89a4-e424d31c1de9', 'blocked_by', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9');
INSERT INTO issue_blockers (id, created_at, updated_at, created_by_id, updated_by_id, block_id, blocked_by_id, project_id, workspace_id, deleted_at) VALUES ('e8da9118-31ea-4130-8cc8-78a5a69498df', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', 'f1a4b811-bec8-4d4d-bf28-cccf59d3528c', '7bd3ad51-7dbc-47c2-93de-08eaa2ebc8eb', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_relations (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, related_issue_id, relation_type, project_id, workspace_id) VALUES ('56d4f2cd-5c82-4c86-a382-d0247235ed3f', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', 'f1a4b811-bec8-4d4d-bf28-cccf59d3528c', '7bd3ad51-7dbc-47c2-93de-08eaa2ebc8eb', 'blocked_by', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9');
INSERT INTO issue_blockers (id, created_at, updated_at, created_by_id, updated_by_id, block_id, blocked_by_id, project_id, workspace_id, deleted_at) VALUES ('0765370a-e697-47b7-adae-806bc0f13745', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', 'f1a4b811-bec8-4d4d-bf28-cccf59d3528c', '2b04c45b-1ebd-489a-bfee-3685ee181656', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_relations (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, related_issue_id, relation_type, project_id, workspace_id) VALUES ('56be896c-960f-495f-a341-5744557658ef', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', 'f1a4b811-bec8-4d4d-bf28-cccf59d3528c', '2b04c45b-1ebd-489a-bfee-3685ee181656', 'blocked_by', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9');
INSERT INTO issue_blockers (id, created_at, updated_at, created_by_id, updated_by_id, block_id, blocked_by_id, project_id, workspace_id, deleted_at) VALUES ('836c240c-71a0-41b6-bcf9-e9d6483ac84e', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', 'f1a4b811-bec8-4d4d-bf28-cccf59d3528c', '33cb93ab-b049-49f7-89a4-e424d31c1de9', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_relations (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, related_issue_id, relation_type, project_id, workspace_id) VALUES ('f5708441-d689-457e-ac80-130c1cadc78d', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', 'f1a4b811-bec8-4d4d-bf28-cccf59d3528c', '33cb93ab-b049-49f7-89a4-e424d31c1de9', 'blocked_by', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9');
INSERT INTO issue_blockers (id, created_at, updated_at, created_by_id, updated_by_id, block_id, blocked_by_id, project_id, workspace_id, deleted_at) VALUES ('f527d2fd-6a22-4624-9138-0d5ca26c5a43', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', 'f1a4b811-bec8-4d4d-bf28-cccf59d3528c', '337f0cc4-12cc-4936-906c-d4037ecb5a70', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_relations (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, related_issue_id, relation_type, project_id, workspace_id) VALUES ('0b513a85-6847-4754-8bd2-e870ac6e2da5', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', 'f1a4b811-bec8-4d4d-bf28-cccf59d3528c', '337f0cc4-12cc-4936-906c-d4037ecb5a70', 'blocked_by', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9');
INSERT INTO issue_blockers (id, created_at, updated_at, created_by_id, updated_by_id, block_id, blocked_by_id, project_id, workspace_id, deleted_at) VALUES ('b9710dc4-c997-43cc-846e-91fbb82c730f', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', 'f1a4b811-bec8-4d4d-bf28-cccf59d3528c', '9324bf50-22d1-46cf-be45-76c9ceb28fb5', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_relations (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, related_issue_id, relation_type, project_id, workspace_id) VALUES ('3ed78d99-b7d7-481e-a0f4-29e317f9e68a', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', 'f1a4b811-bec8-4d4d-bf28-cccf59d3528c', '9324bf50-22d1-46cf-be45-76c9ceb28fb5', 'blocked_by', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9');
INSERT INTO issue_blockers (id, created_at, updated_at, created_by_id, updated_by_id, block_id, blocked_by_id, project_id, workspace_id, deleted_at) VALUES ('2e59c8e9-95c9-4eab-b500-afafefd4494b', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', 'f1a4b811-bec8-4d4d-bf28-cccf59d3528c', 'c8ad6233-7a8f-41c3-b2d9-ba2858513520', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_relations (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, related_issue_id, relation_type, project_id, workspace_id) VALUES ('3a019bfe-0da3-4213-ab6f-878fb0ac767a', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', 'f1a4b811-bec8-4d4d-bf28-cccf59d3528c', 'c8ad6233-7a8f-41c3-b2d9-ba2858513520', 'blocked_by', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9');
INSERT INTO issue_blockers (id, created_at, updated_at, created_by_id, updated_by_id, block_id, blocked_by_id, project_id, workspace_id, deleted_at) VALUES ('4788d908-5a5c-4a5b-b0bd-3b9f66fe424d', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', 'd11aab0b-8e8c-4f5e-a656-e320405b9684', 'b6b838b4-5b81-4098-90e3-fe8c6bf2415c', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_relations (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, related_issue_id, relation_type, project_id, workspace_id) VALUES ('fdd79f4b-180a-43d9-972a-e3ea08701233', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', 'd11aab0b-8e8c-4f5e-a656-e320405b9684', 'b6b838b4-5b81-4098-90e3-fe8c6bf2415c', 'blocked_by', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9');
INSERT INTO issue_blockers (id, created_at, updated_at, created_by_id, updated_by_id, block_id, blocked_by_id, project_id, workspace_id, deleted_at) VALUES ('64f966ea-8e70-4c26-991b-5bd4a89868ca', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', 'd11aab0b-8e8c-4f5e-a656-e320405b9684', '0e1f4737-cea2-497a-9e8d-41e84106c892', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_relations (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, related_issue_id, relation_type, project_id, workspace_id) VALUES ('201e814e-aa24-4d84-9a37-439051630afb', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', 'd11aab0b-8e8c-4f5e-a656-e320405b9684', '0e1f4737-cea2-497a-9e8d-41e84106c892', 'blocked_by', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9');
INSERT INTO issue_blockers (id, created_at, updated_at, created_by_id, updated_by_id, block_id, blocked_by_id, project_id, workspace_id, deleted_at) VALUES ('356292f9-a45a-47fc-ba3f-e614ac1913f9', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '775f4dc5-7114-4e0e-80e7-2631822f16c1', 'b6b838b4-5b81-4098-90e3-fe8c6bf2415c', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_relations (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, related_issue_id, relation_type, project_id, workspace_id) VALUES ('9efb7c82-9663-4fde-a590-8287b1efe500', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '775f4dc5-7114-4e0e-80e7-2631822f16c1', 'b6b838b4-5b81-4098-90e3-fe8c6bf2415c', 'blocked_by', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9');
INSERT INTO issue_blockers (id, created_at, updated_at, created_by_id, updated_by_id, block_id, blocked_by_id, project_id, workspace_id, deleted_at) VALUES ('ef4d8d67-e7e3-428b-a0de-a3d04ea7d020', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '775f4dc5-7114-4e0e-80e7-2631822f16c1', '0e1f4737-cea2-497a-9e8d-41e84106c892', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_relations (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, related_issue_id, relation_type, project_id, workspace_id) VALUES ('f954b5ae-91f7-44f7-a46c-4fd6d393473e', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '775f4dc5-7114-4e0e-80e7-2631822f16c1', '0e1f4737-cea2-497a-9e8d-41e84106c892', 'blocked_by', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9');
INSERT INTO issue_blockers (id, created_at, updated_at, created_by_id, updated_by_id, block_id, blocked_by_id, project_id, workspace_id, deleted_at) VALUES ('4270f1f5-bdc4-4de1-a11b-39623427b2ed', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '0b8c0e07-3bf6-44b2-9a84-93d6f1cb081f', 'b6b838b4-5b81-4098-90e3-fe8c6bf2415c', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_relations (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, related_issue_id, relation_type, project_id, workspace_id) VALUES ('8567d6fe-1d12-49bf-ad8a-871ca74111cd', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '0b8c0e07-3bf6-44b2-9a84-93d6f1cb081f', 'b6b838b4-5b81-4098-90e3-fe8c6bf2415c', 'blocked_by', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9');
INSERT INTO issue_blockers (id, created_at, updated_at, created_by_id, updated_by_id, block_id, blocked_by_id, project_id, workspace_id, deleted_at) VALUES ('3d0f2c7e-d082-472f-a53c-51830eda5b85', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '0b8c0e07-3bf6-44b2-9a84-93d6f1cb081f', '0e1f4737-cea2-497a-9e8d-41e84106c892', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_relations (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, related_issue_id, relation_type, project_id, workspace_id) VALUES ('dff2b7ce-dfd3-4649-b529-830affdf84b3', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '0b8c0e07-3bf6-44b2-9a84-93d6f1cb081f', '0e1f4737-cea2-497a-9e8d-41e84106c892', 'blocked_by', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9');
INSERT INTO issue_blockers (id, created_at, updated_at, created_by_id, updated_by_id, block_id, blocked_by_id, project_id, workspace_id, deleted_at) VALUES ('56d8e915-9e3a-4b8c-a828-4c27b47a229b', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '0e1f4737-cea2-497a-9e8d-41e84106c892', 'b6b838b4-5b81-4098-90e3-fe8c6bf2415c', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_relations (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, related_issue_id, relation_type, project_id, workspace_id) VALUES ('c478e915-8a9c-4975-a8fc-79f7c171d5c7', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '0e1f4737-cea2-497a-9e8d-41e84106c892', 'b6b838b4-5b81-4098-90e3-fe8c6bf2415c', 'blocked_by', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9');
INSERT INTO issue_blockers (id, created_at, updated_at, created_by_id, updated_by_id, block_id, blocked_by_id, project_id, workspace_id, deleted_at) VALUES ('7e7188af-169e-468b-a819-b5806f51288f', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '0e1f4737-cea2-497a-9e8d-41e84106c892', '6b2ca529-2213-40a1-b85e-0c9e2a57ecdb', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_relations (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, related_issue_id, relation_type, project_id, workspace_id) VALUES ('7b416842-6a25-4997-b8e3-f2650bf16318', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '0e1f4737-cea2-497a-9e8d-41e84106c892', '6b2ca529-2213-40a1-b85e-0c9e2a57ecdb', 'blocked_by', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9');
INSERT INTO issue_blockers (id, created_at, updated_at, created_by_id, updated_by_id, block_id, blocked_by_id, project_id, workspace_id, deleted_at) VALUES ('219c91a1-8145-49e2-8da6-0a81d97c4284', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '0e1f4737-cea2-497a-9e8d-41e84106c892', 'f1a4b811-bec8-4d4d-bf28-cccf59d3528c', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_relations (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, related_issue_id, relation_type, project_id, workspace_id) VALUES ('3ea9a733-3b65-4a84-9ddd-00394d363973', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '0e1f4737-cea2-497a-9e8d-41e84106c892', 'f1a4b811-bec8-4d4d-bf28-cccf59d3528c', 'blocked_by', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9');
INSERT INTO issue_blockers (id, created_at, updated_at, created_by_id, updated_by_id, block_id, blocked_by_id, project_id, workspace_id, deleted_at) VALUES ('de75a8ec-76da-47b4-af29-a70971b870f9', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '4d7ff842-46d7-42c7-983c-595a650671c9', 'b6b838b4-5b81-4098-90e3-fe8c6bf2415c', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_relations (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, related_issue_id, relation_type, project_id, workspace_id) VALUES ('2aea595a-6c18-4d85-8e74-52a70f0798e4', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '4d7ff842-46d7-42c7-983c-595a650671c9', 'b6b838b4-5b81-4098-90e3-fe8c6bf2415c', 'blocked_by', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9');
INSERT INTO issue_blockers (id, created_at, updated_at, created_by_id, updated_by_id, block_id, blocked_by_id, project_id, workspace_id, deleted_at) VALUES ('9e01d2dc-a1c0-4485-848f-af298a9077e0', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '4d7ff842-46d7-42c7-983c-595a650671c9', 'd11aab0b-8e8c-4f5e-a656-e320405b9684', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_relations (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, related_issue_id, relation_type, project_id, workspace_id) VALUES ('e03b47d7-1d45-45d7-9557-e72f795152c9', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '4d7ff842-46d7-42c7-983c-595a650671c9', 'd11aab0b-8e8c-4f5e-a656-e320405b9684', 'blocked_by', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9');
INSERT INTO issue_blockers (id, created_at, updated_at, created_by_id, updated_by_id, block_id, blocked_by_id, project_id, workspace_id, deleted_at) VALUES ('6c416dbc-d561-4f33-86b6-3e3244e3cbd1', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '4d7ff842-46d7-42c7-983c-595a650671c9', '775f4dc5-7114-4e0e-80e7-2631822f16c1', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_relations (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, related_issue_id, relation_type, project_id, workspace_id) VALUES ('d7de9ba8-da07-4817-a593-14233a6248d5', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '4d7ff842-46d7-42c7-983c-595a650671c9', '775f4dc5-7114-4e0e-80e7-2631822f16c1', 'blocked_by', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9');
INSERT INTO issue_blockers (id, created_at, updated_at, created_by_id, updated_by_id, block_id, blocked_by_id, project_id, workspace_id, deleted_at) VALUES ('a0fddf37-3468-402a-b7cb-2d89ec548114', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '4d7ff842-46d7-42c7-983c-595a650671c9', '0e1f4737-cea2-497a-9e8d-41e84106c892', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_relations (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, related_issue_id, relation_type, project_id, workspace_id) VALUES ('39ae2d83-9636-44ab-aabd-cce7d4814ace', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '4d7ff842-46d7-42c7-983c-595a650671c9', '0e1f4737-cea2-497a-9e8d-41e84106c892', 'blocked_by', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9');
INSERT INTO issue_blockers (id, created_at, updated_at, created_by_id, updated_by_id, block_id, blocked_by_id, project_id, workspace_id, deleted_at) VALUES ('443ff359-909d-458a-83ef-4bd465d7f365', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', 'eaea3ff3-4b13-4e26-be0f-3998ce8df732', '4d7ff842-46d7-42c7-983c-595a650671c9', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_relations (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, related_issue_id, relation_type, project_id, workspace_id) VALUES ('e47a7bc2-12b9-4a5e-b1da-79cc96319941', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', 'eaea3ff3-4b13-4e26-be0f-3998ce8df732', '4d7ff842-46d7-42c7-983c-595a650671c9', 'blocked_by', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9');
INSERT INTO issue_blockers (id, created_at, updated_at, created_by_id, updated_by_id, block_id, blocked_by_id, project_id, workspace_id, deleted_at) VALUES ('4cde0ce9-2c6a-4b61-a7af-e64d22db608c', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '0a42f431-9bd6-4e96-87e0-817c85a1a7af', 'd11aab0b-8e8c-4f5e-a656-e320405b9684', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_relations (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, related_issue_id, relation_type, project_id, workspace_id) VALUES ('44d9b48b-ee6f-496e-ae00-5df2414e5003', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '0a42f431-9bd6-4e96-87e0-817c85a1a7af', 'd11aab0b-8e8c-4f5e-a656-e320405b9684', 'blocked_by', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9');
INSERT INTO issue_blockers (id, created_at, updated_at, created_by_id, updated_by_id, block_id, blocked_by_id, project_id, workspace_id, deleted_at) VALUES ('7de4976f-025e-4cdf-a76e-1c3d4b384d4a', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '0a42f431-9bd6-4e96-87e0-817c85a1a7af', '775f4dc5-7114-4e0e-80e7-2631822f16c1', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_relations (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, related_issue_id, relation_type, project_id, workspace_id) VALUES ('f84ecb44-dd69-4d1c-a0eb-089535ebe665', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '0a42f431-9bd6-4e96-87e0-817c85a1a7af', '775f4dc5-7114-4e0e-80e7-2631822f16c1', 'blocked_by', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9');
INSERT INTO issue_blockers (id, created_at, updated_at, created_by_id, updated_by_id, block_id, blocked_by_id, project_id, workspace_id, deleted_at) VALUES ('c6ccc077-e8f4-4be7-b254-539b52fc02e6', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '0a42f431-9bd6-4e96-87e0-817c85a1a7af', '0b8c0e07-3bf6-44b2-9a84-93d6f1cb081f', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_relations (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, related_issue_id, relation_type, project_id, workspace_id) VALUES ('7d637b63-bce8-464b-959b-14175840f09f', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '0a42f431-9bd6-4e96-87e0-817c85a1a7af', '0b8c0e07-3bf6-44b2-9a84-93d6f1cb081f', 'blocked_by', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9');
INSERT INTO issue_blockers (id, created_at, updated_at, created_by_id, updated_by_id, block_id, blocked_by_id, project_id, workspace_id, deleted_at) VALUES ('91779e40-2038-4b6f-998b-e12c90959162', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '0a42f431-9bd6-4e96-87e0-817c85a1a7af', '0e1f4737-cea2-497a-9e8d-41e84106c892', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_relations (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, related_issue_id, relation_type, project_id, workspace_id) VALUES ('c7e40791-95f0-4b24-8bec-87b85e512726', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '0a42f431-9bd6-4e96-87e0-817c85a1a7af', '0e1f4737-cea2-497a-9e8d-41e84106c892', 'blocked_by', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9');
INSERT INTO issue_blockers (id, created_at, updated_at, created_by_id, updated_by_id, block_id, blocked_by_id, project_id, workspace_id, deleted_at) VALUES ('aa093a82-ae38-44f3-9f63-d0969be4cbf8', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '0a42f431-9bd6-4e96-87e0-817c85a1a7af', '4d7ff842-46d7-42c7-983c-595a650671c9', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_relations (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, related_issue_id, relation_type, project_id, workspace_id) VALUES ('9291b0ce-697a-43dd-8972-0f09880dd1dc', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '0a42f431-9bd6-4e96-87e0-817c85a1a7af', '4d7ff842-46d7-42c7-983c-595a650671c9', 'blocked_by', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9');
INSERT INTO issue_blockers (id, created_at, updated_at, created_by_id, updated_by_id, block_id, blocked_by_id, project_id, workspace_id, deleted_at) VALUES ('21efcc61-a95d-4bdc-82e5-2dba9b7d0ea3', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '0a42f431-9bd6-4e96-87e0-817c85a1a7af', 'eaea3ff3-4b13-4e26-be0f-3998ce8df732', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_relations (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, related_issue_id, relation_type, project_id, workspace_id) VALUES ('4c5e96c5-c7a6-4a92-b636-35eef337b46a', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '0a42f431-9bd6-4e96-87e0-817c85a1a7af', 'eaea3ff3-4b13-4e26-be0f-3998ce8df732', 'blocked_by', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9');
INSERT INTO issue_blockers (id, created_at, updated_at, created_by_id, updated_by_id, block_id, blocked_by_id, project_id, workspace_id, deleted_at) VALUES ('b1b591c9-344f-433f-a681-e5f2e917ed6b', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '2f123ef6-a1d4-48a8-8966-c5cca7b18a0c', '0a42f431-9bd6-4e96-87e0-817c85a1a7af', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_relations (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, related_issue_id, relation_type, project_id, workspace_id) VALUES ('49187cab-e01c-4ee4-8209-227a4d9e3045', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '2f123ef6-a1d4-48a8-8966-c5cca7b18a0c', '0a42f431-9bd6-4e96-87e0-817c85a1a7af', 'blocked_by', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9');
INSERT INTO issue_blockers (id, created_at, updated_at, created_by_id, updated_by_id, block_id, blocked_by_id, project_id, workspace_id, deleted_at) VALUES ('2fbe719b-6db0-4121-a37e-2c8378042d00', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '72ee7324-4187-4f8b-ad75-5c74c49dc36d', '2f123ef6-a1d4-48a8-8966-c5cca7b18a0c', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_relations (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, related_issue_id, relation_type, project_id, workspace_id) VALUES ('b476c3b1-12b7-463c-8368-fec955fab4a0', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '72ee7324-4187-4f8b-ad75-5c74c49dc36d', '2f123ef6-a1d4-48a8-8966-c5cca7b18a0c', 'blocked_by', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9');

-- ============ labels (23) ============
INSERT INTO labels (id, created_at, updated_at, created_by_id, updated_by_id, project_id, workspace_id, name, description, color, sort_order, parent_id, external_id, external_source, deleted_at) VALUES ('9d255286-0baa-4301-8092-f9ee29b80123', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', 'access', '', '#FF6900', 10000, NULL, NULL, NULL, NULL);
INSERT INTO labels (id, created_at, updated_at, created_by_id, updated_by_id, project_id, workspace_id, name, description, color, sort_order, parent_id, external_id, external_source, deleted_at) VALUES ('9c709e54-3b8d-4cb9-8025-8085e3d80155', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', 'assembly', '', '#FCB900', 20000, NULL, NULL, NULL, NULL);
INSERT INTO labels (id, created_at, updated_at, created_by_id, updated_by_id, project_id, workspace_id, name, description, color, sort_order, parent_id, external_id, external_source, deleted_at) VALUES ('9e252997-d8b9-4e78-84c2-6b4dd54ad709', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', 'auth', '', '#7BDCB5', 30000, NULL, NULL, NULL, NULL);
INSERT INTO labels (id, created_at, updated_at, created_by_id, updated_by_id, project_id, workspace_id, name, description, color, sort_order, parent_id, external_id, external_source, deleted_at) VALUES ('be0e0bbb-5bf4-46ed-8a4e-f6e90e731e8f', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', 'backend', '', '#00D084', 40000, NULL, NULL, NULL, NULL);
INSERT INTO labels (id, created_at, updated_at, created_by_id, updated_by_id, project_id, workspace_id, name, description, color, sort_order, parent_id, external_id, external_source, deleted_at) VALUES ('3a3bb1a9-10c1-4e5d-acd1-30ac8e8d55b5', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', 'compliance', '', '#8ED1FC', 50000, NULL, NULL, NULL, NULL);
INSERT INTO labels (id, created_at, updated_at, created_by_id, updated_by_id, project_id, workspace_id, name, description, color, sort_order, parent_id, external_id, external_source, deleted_at) VALUES ('07c1ed1f-42ec-4912-90bd-0898fe490425', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', 'contracts', '', '#0693E3', 60000, NULL, NULL, NULL, NULL);
INSERT INTO labels (id, created_at, updated_at, created_by_id, updated_by_id, project_id, workspace_id, name, description, color, sort_order, parent_id, external_id, external_source, deleted_at) VALUES ('58789a52-287d-4984-8eae-db22e6226014', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', 'core', '', '#ABB8C3', 70000, NULL, NULL, NULL, NULL);
INSERT INTO labels (id, created_at, updated_at, created_by_id, updated_by_id, project_id, workspace_id, name, description, color, sort_order, parent_id, external_id, external_source, deleted_at) VALUES ('66bf43fe-9b0e-4413-b5e9-f4e05cd64e41', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', 'database', '', '#EB144C', 80000, NULL, NULL, NULL, NULL);
INSERT INTO labels (id, created_at, updated_at, created_by_id, updated_by_id, project_id, workspace_id, name, description, color, sort_order, parent_id, external_id, external_source, deleted_at) VALUES ('752fbb08-d84e-417f-b697-9977f76cf5ae', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', 'docker', '', '#F78DA7', 90000, NULL, NULL, NULL, NULL);
INSERT INTO labels (id, created_at, updated_at, created_by_id, updated_by_id, project_id, workspace_id, name, description, color, sort_order, parent_id, external_id, external_source, deleted_at) VALUES ('bf843281-e9f3-4ba0-b29d-ce2bda88dec3', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', 'freeze', '', '#9900EF', 100000, NULL, NULL, NULL, NULL);
INSERT INTO labels (id, created_at, updated_at, created_by_id, updated_by_id, project_id, workspace_id, name, description, color, sort_order, parent_id, external_id, external_source, deleted_at) VALUES ('5fe21d8c-2864-4d66-ab39-5de2a153e0bb', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', 'frontend', '', '#FF7A00', 110000, NULL, NULL, NULL, NULL);
INSERT INTO labels (id, created_at, updated_at, created_by_id, updated_by_id, project_id, workspace_id, name, description, color, sort_order, parent_id, external_id, external_source, deleted_at) VALUES ('da43cfab-3923-43d5-91fe-a9404ff3681b', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', 'fullstack', '', '#FFB800', 120000, NULL, NULL, NULL, NULL);
INSERT INTO labels (id, created_at, updated_at, created_by_id, updated_by_id, project_id, workspace_id, name, description, color, sort_order, parent_id, external_id, external_source, deleted_at) VALUES ('d05a1dcf-b3d6-4969-a9e4-6f62f3d0ba0c', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', 'infrastructure', '', '#6BCB77', 130000, NULL, NULL, NULL, NULL);
INSERT INTO labels (id, created_at, updated_at, created_by_id, updated_by_id, project_id, workspace_id, name, description, color, sort_order, parent_id, external_id, external_source, deleted_at) VALUES ('b0cd4589-7d5e-4b19-80b5-7fa5ab925a93', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', 'integration', '', '#4D96FF', 140000, NULL, NULL, NULL, NULL);
INSERT INTO labels (id, created_at, updated_at, created_by_id, updated_by_id, project_id, workspace_id, name, description, color, sort_order, parent_id, external_id, external_source, deleted_at) VALUES ('da2b8c37-a1ba-48d7-91bd-0466e37104f3', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', 'master', '', '#9B5DE5', 150000, NULL, NULL, NULL, NULL);
INSERT INTO labels (id, created_at, updated_at, created_by_id, updated_by_id, project_id, workspace_id, name, description, color, sort_order, parent_id, external_id, external_source, deleted_at) VALUES ('b2d14041-7ab7-4ffd-a4be-1752b6da3197', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', 'notify', '', '#F15BB5', 160000, NULL, NULL, NULL, NULL);
INSERT INTO labels (id, created_at, updated_at, created_by_id, updated_by_id, project_id, workspace_id, name, description, color, sort_order, parent_id, external_id, external_source, deleted_at) VALUES ('fec1e646-a923-45d7-8cff-8e690012470e', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', 'release', '', '#00BBF9', 170000, NULL, NULL, NULL, NULL);
INSERT INTO labels (id, created_at, updated_at, created_by_id, updated_by_id, project_id, workspace_id, name, description, color, sort_order, parent_id, external_id, external_source, deleted_at) VALUES ('4054a1b8-2956-4718-9528-9be55fa97203', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', 'report', '', '#00F5D4', 180000, NULL, NULL, NULL, NULL);
INSERT INTO labels (id, created_at, updated_at, created_by_id, updated_by_id, project_id, workspace_id, name, description, color, sort_order, parent_id, external_id, external_source, deleted_at) VALUES ('5a739e56-6587-4961-9c2c-16972a4eb49b', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', 'routing', '', '#FEE440', 190000, NULL, NULL, NULL, NULL);
INSERT INTO labels (id, created_at, updated_at, created_by_id, updated_by_id, project_id, workspace_id, name, description, color, sort_order, parent_id, external_id, external_source, deleted_at) VALUES ('37545d12-a148-4769-9b5b-88f0154628ff', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', 'seed', '', '#FF006E', 200000, NULL, NULL, NULL, NULL);
INSERT INTO labels (id, created_at, updated_at, created_by_id, updated_by_id, project_id, workspace_id, name, description, color, sort_order, parent_id, external_id, external_source, deleted_at) VALUES ('fa14a457-a4b5-4af4-9a83-d7dbde7cfb36', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', 'shared-kernel', '', '#8338EC', 210000, NULL, NULL, NULL, NULL);
INSERT INTO labels (id, created_at, updated_at, created_by_id, updated_by_id, project_id, workspace_id, name, description, color, sort_order, parent_id, external_id, external_source, deleted_at) VALUES ('bd8bce8b-d6cf-4f1b-b075-f7dc5349ab06', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', 'verification', '', '#3A86FF', 220000, NULL, NULL, NULL, NULL);
INSERT INTO labels (id, created_at, updated_at, created_by_id, updated_by_id, project_id, workspace_id, name, description, color, sort_order, parent_id, external_id, external_source, deleted_at) VALUES ('803b1cf7-64e3-42bc-bb4f-0cfda5f2bb01', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', 'visit', '', '#FB5607', 230000, NULL, NULL, NULL, NULL);

-- ============ issue_labels (45) ============
INSERT INTO issue_labels (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, label_id, project_id, workspace_id, deleted_at) VALUES ('933b73fb-de47-4878-bf5f-e74330614ed4', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '7bd3ad51-7dbc-47c2-93de-08eaa2ebc8eb', 'd05a1dcf-b3d6-4969-a9e4-6f62f3d0ba0c', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_labels (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, label_id, project_id, workspace_id, deleted_at) VALUES ('ae461f24-53ac-4ad9-ab88-9cc8f6b3234a', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '7bd3ad51-7dbc-47c2-93de-08eaa2ebc8eb', 'be0e0bbb-5bf4-46ed-8a4e-f6e90e731e8f', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_labels (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, label_id, project_id, workspace_id, deleted_at) VALUES ('9645ee7f-0110-4d90-bc40-44e2c2d559c4', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '7bd3ad51-7dbc-47c2-93de-08eaa2ebc8eb', '5fe21d8c-2864-4d66-ab39-5de2a153e0bb', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_labels (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, label_id, project_id, workspace_id, deleted_at) VALUES ('44cc4b85-9ccc-4557-86fe-63812152a0c9', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '7bd3ad51-7dbc-47c2-93de-08eaa2ebc8eb', '752fbb08-d84e-417f-b697-9977f76cf5ae', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_labels (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, label_id, project_id, workspace_id, deleted_at) VALUES ('5c47f9ae-a3e4-409f-b558-197104a054fc', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '2b04c45b-1ebd-489a-bfee-3685ee181656', 'd05a1dcf-b3d6-4969-a9e4-6f62f3d0ba0c', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_labels (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, label_id, project_id, workspace_id, deleted_at) VALUES ('0d9d8fd1-f75f-4c9f-8e66-5893ab27e926', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '2b04c45b-1ebd-489a-bfee-3685ee181656', '66bf43fe-9b0e-4413-b5e9-f4e05cd64e41', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_labels (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, label_id, project_id, workspace_id, deleted_at) VALUES ('df2f5411-c6ce-4ef9-869d-f7594582b85a', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '33cb93ab-b049-49f7-89a4-e424d31c1de9', 'd05a1dcf-b3d6-4969-a9e4-6f62f3d0ba0c', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_labels (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, label_id, project_id, workspace_id, deleted_at) VALUES ('3d6a2033-c283-403d-b2e2-3550bfeab8fd', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '33cb93ab-b049-49f7-89a4-e424d31c1de9', 'be0e0bbb-5bf4-46ed-8a4e-f6e90e731e8f', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_labels (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, label_id, project_id, workspace_id, deleted_at) VALUES ('dd40137e-7b56-4eb9-b247-684f1f244c8f', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '33cb93ab-b049-49f7-89a4-e424d31c1de9', 'fa14a457-a4b5-4af4-9a83-d7dbde7cfb36', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_labels (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, label_id, project_id, workspace_id, deleted_at) VALUES ('6cc58a98-95af-410f-969a-7331bc866226', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '337f0cc4-12cc-4936-906c-d4037ecb5a70', 'd05a1dcf-b3d6-4969-a9e4-6f62f3d0ba0c', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_labels (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, label_id, project_id, workspace_id, deleted_at) VALUES ('e3ff6050-3070-4437-9690-160632e224cc', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '337f0cc4-12cc-4936-906c-d4037ecb5a70', 'be0e0bbb-5bf4-46ed-8a4e-f6e90e731e8f', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_labels (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, label_id, project_id, workspace_id, deleted_at) VALUES ('63303ef9-25f4-40d6-9029-f75c7f42f4b3', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '337f0cc4-12cc-4936-906c-d4037ecb5a70', '9e252997-d8b9-4e78-84c2-6b4dd54ad709', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_labels (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, label_id, project_id, workspace_id, deleted_at) VALUES ('e8248545-e25f-462b-ae26-1346bb899d93', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '9324bf50-22d1-46cf-be45-76c9ceb28fb5', 'd05a1dcf-b3d6-4969-a9e4-6f62f3d0ba0c', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_labels (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, label_id, project_id, workspace_id, deleted_at) VALUES ('3501da95-c876-4e30-8435-19bb11ed2ca3', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '9324bf50-22d1-46cf-be45-76c9ceb28fb5', '5fe21d8c-2864-4d66-ab39-5de2a153e0bb', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_labels (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, label_id, project_id, workspace_id, deleted_at) VALUES ('f1a6281e-37db-4226-a5b5-d7a9b7d07fd2', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', 'c8ad6233-7a8f-41c3-b2d9-ba2858513520', 'd05a1dcf-b3d6-4969-a9e4-6f62f3d0ba0c', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_labels (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, label_id, project_id, workspace_id, deleted_at) VALUES ('b0e2c3cf-2589-4e1b-bf31-8307744361a4', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', 'c8ad6233-7a8f-41c3-b2d9-ba2858513520', '5fe21d8c-2864-4d66-ab39-5de2a153e0bb', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_labels (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, label_id, project_id, workspace_id, deleted_at) VALUES ('513be831-129c-48db-b74e-dafcbbb791f4', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', 'c8ad6233-7a8f-41c3-b2d9-ba2858513520', '5a739e56-6587-4961-9c2c-16972a4eb49b', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_labels (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, label_id, project_id, workspace_id, deleted_at) VALUES ('1710fa84-a2d5-48fb-bd86-d2a4b218e583', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', 'b6b838b4-5b81-4098-90e3-fe8c6bf2415c', 'd05a1dcf-b3d6-4969-a9e4-6f62f3d0ba0c', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_labels (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, label_id, project_id, workspace_id, deleted_at) VALUES ('f1404d07-2859-491c-997a-1210064743de', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', 'b6b838b4-5b81-4098-90e3-fe8c6bf2415c', 'be0e0bbb-5bf4-46ed-8a4e-f6e90e731e8f', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_labels (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, label_id, project_id, workspace_id, deleted_at) VALUES ('91d16dc3-1af2-4208-8e3a-8811ee4859e2', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', 'b6b838b4-5b81-4098-90e3-fe8c6bf2415c', '9c709e54-3b8d-4cb9-8025-8085e3d80155', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_labels (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, label_id, project_id, workspace_id, deleted_at) VALUES ('9eb12303-e98a-4d61-9e34-a9afdd7085d3', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '6b2ca529-2213-40a1-b85e-0c9e2a57ecdb', 'd05a1dcf-b3d6-4969-a9e4-6f62f3d0ba0c', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_labels (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, label_id, project_id, workspace_id, deleted_at) VALUES ('82d8fd05-4f9a-4023-aa7a-bd1b404e5624', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '6b2ca529-2213-40a1-b85e-0c9e2a57ecdb', '66bf43fe-9b0e-4413-b5e9-f4e05cd64e41', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_labels (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, label_id, project_id, workspace_id, deleted_at) VALUES ('89ae902f-e7a2-4d24-a628-1c724afee052', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '6b2ca529-2213-40a1-b85e-0c9e2a57ecdb', '37545d12-a148-4769-9b5b-88f0154628ff', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_labels (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, label_id, project_id, workspace_id, deleted_at) VALUES ('32110847-c057-43d2-8bc3-bbc92d3bd378', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', 'f1a4b811-bec8-4d4d-bf28-cccf59d3528c', 'd05a1dcf-b3d6-4969-a9e4-6f62f3d0ba0c', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_labels (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, label_id, project_id, workspace_id, deleted_at) VALUES ('8f95fe70-4456-4c04-83c6-255a5d7beb65', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', 'f1a4b811-bec8-4d4d-bf28-cccf59d3528c', '07c1ed1f-42ec-4912-90bd-0898fe490425', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_labels (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, label_id, project_id, workspace_id, deleted_at) VALUES ('094b0fd6-cb96-4660-acf8-8326f13515ff', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', 'd11aab0b-8e8c-4f5e-a656-e320405b9684', 'da43cfab-3923-43d5-91fe-a9404ff3681b', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_labels (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, label_id, project_id, workspace_id, deleted_at) VALUES ('1e403a68-e90c-4801-a9db-70faf098de2f', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', 'd11aab0b-8e8c-4f5e-a656-e320405b9684', 'da2b8c37-a1ba-48d7-91bd-0466e37104f3', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_labels (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, label_id, project_id, workspace_id, deleted_at) VALUES ('a314f4b7-c3fb-4022-bbab-ef0767d33063', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '775f4dc5-7114-4e0e-80e7-2631822f16c1', 'da43cfab-3923-43d5-91fe-a9404ff3681b', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_labels (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, label_id, project_id, workspace_id, deleted_at) VALUES ('eee27b5f-5595-4ab5-b1be-f3562e39580a', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '775f4dc5-7114-4e0e-80e7-2631822f16c1', 'b2d14041-7ab7-4ffd-a4be-1752b6da3197', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_labels (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, label_id, project_id, workspace_id, deleted_at) VALUES ('50aed436-6564-4684-89ee-7691ec054e5e', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '0b8c0e07-3bf6-44b2-9a84-93d6f1cb081f', 'da43cfab-3923-43d5-91fe-a9404ff3681b', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_labels (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, label_id, project_id, workspace_id, deleted_at) VALUES ('1e7b21c5-67db-4f68-81f2-f94046e79959', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '0b8c0e07-3bf6-44b2-9a84-93d6f1cb081f', '4054a1b8-2956-4718-9528-9be55fa97203', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_labels (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, label_id, project_id, workspace_id, deleted_at) VALUES ('3635e237-5b6d-47db-9ad6-de59017a7fb5', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '0e1f4737-cea2-497a-9e8d-41e84106c892', 'da43cfab-3923-43d5-91fe-a9404ff3681b', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_labels (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, label_id, project_id, workspace_id, deleted_at) VALUES ('ae602773-8cbc-401d-953c-854e04fe6e20', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '0e1f4737-cea2-497a-9e8d-41e84106c892', '9d255286-0baa-4301-8092-f9ee29b80123', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_labels (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, label_id, project_id, workspace_id, deleted_at) VALUES ('2b343a66-947e-4768-809a-0e53b3cea0d8', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '0e1f4737-cea2-497a-9e8d-41e84106c892', '9e252997-d8b9-4e78-84c2-6b4dd54ad709', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_labels (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, label_id, project_id, workspace_id, deleted_at) VALUES ('dfc4f34f-2028-4ace-b7eb-ee2e08b74d1d', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '4d7ff842-46d7-42c7-983c-595a650671c9', 'da43cfab-3923-43d5-91fe-a9404ff3681b', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_labels (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, label_id, project_id, workspace_id, deleted_at) VALUES ('b5fd1339-dbe4-417b-aef5-6f0c913f6ead', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '4d7ff842-46d7-42c7-983c-595a650671c9', '803b1cf7-64e3-42bc-bb4f-0cfda5f2bb01', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_labels (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, label_id, project_id, workspace_id, deleted_at) VALUES ('1a5b60bc-7ad6-4757-9a21-3c040281e58e', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '4d7ff842-46d7-42c7-983c-595a650671c9', '58789a52-287d-4984-8eae-db22e6226014', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_labels (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, label_id, project_id, workspace_id, deleted_at) VALUES ('2fabe7da-5179-422f-9066-57db044e9a1c', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', 'eaea3ff3-4b13-4e26-be0f-3998ce8df732', 'da43cfab-3923-43d5-91fe-a9404ff3681b', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_labels (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, label_id, project_id, workspace_id, deleted_at) VALUES ('476c4b76-2e26-4441-add2-b724584846a6', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', 'eaea3ff3-4b13-4e26-be0f-3998ce8df732', '3a3bb1a9-10c1-4e5d-acd1-30ac8e8d55b5', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_labels (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, label_id, project_id, workspace_id, deleted_at) VALUES ('a095a9a5-3684-49d4-bed5-a82b4ae5b613', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '0a42f431-9bd6-4e96-87e0-817c85a1a7af', 'b0cd4589-7d5e-4b19-80b5-7fa5ab925a93', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_labels (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, label_id, project_id, workspace_id, deleted_at) VALUES ('f01e6641-0a7c-46e2-b4c4-0fe1634e6d86', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '0a42f431-9bd6-4e96-87e0-817c85a1a7af', 'bd8bce8b-d6cf-4f1b-b075-f7dc5349ab06', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_labels (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, label_id, project_id, workspace_id, deleted_at) VALUES ('94ba9501-f79a-4d2a-9d61-e7bec9bfe2ed', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '2f123ef6-a1d4-48a8-8966-c5cca7b18a0c', 'fec1e646-a923-45d7-8cff-8e690012470e', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_labels (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, label_id, project_id, workspace_id, deleted_at) VALUES ('8f73a19e-248f-4ecf-a7e0-d8484c3ae6a9', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '2f123ef6-a1d4-48a8-8966-c5cca7b18a0c', 'bf843281-e9f3-4ba0-b29d-ce2bda88dec3', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_labels (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, label_id, project_id, workspace_id, deleted_at) VALUES ('5b90f8ef-16da-4f8a-a645-077083e8e06b', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '72ee7324-4187-4f8b-ad75-5c74c49dc36d', 'fec1e646-a923-45d7-8cff-8e690012470e', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);
INSERT INTO issue_labels (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, label_id, project_id, workspace_id, deleted_at) VALUES ('de2665bb-87d3-4caf-b613-78b97f27dabb', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '72ee7324-4187-4f8b-ad75-5c74c49dc36d', '07c1ed1f-42ec-4912-90bd-0898fe490425', '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', NULL);

-- ============ issue_activities (18) ============
INSERT INTO issue_activities (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, verb, field, old_value, new_value, comment, attachments, old_identifier, new_identifier, epoch, project_id, workspace_id, actor_id, issue_comment_id, deleted_at) VALUES ('607f386f-6c1d-4a94-abe4-192e976e7af9', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '7bd3ad51-7dbc-47c2-93de-08eaa2ebc8eb', 'created', NULL, NULL, NULL, '', '{}', NULL, NULL, EXTRACT(EPOCH FROM NOW()), '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', '11fb2311-d19b-4f7f-9e28-21c2afce823c', NULL, NULL);
INSERT INTO issue_activities (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, verb, field, old_value, new_value, comment, attachments, old_identifier, new_identifier, epoch, project_id, workspace_id, actor_id, issue_comment_id, deleted_at) VALUES ('c16935b1-d120-4fcd-8d8b-0f49ce678c47', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '2b04c45b-1ebd-489a-bfee-3685ee181656', 'created', NULL, NULL, NULL, '', '{}', NULL, NULL, EXTRACT(EPOCH FROM NOW()), '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', '11fb2311-d19b-4f7f-9e28-21c2afce823c', NULL, NULL);
INSERT INTO issue_activities (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, verb, field, old_value, new_value, comment, attachments, old_identifier, new_identifier, epoch, project_id, workspace_id, actor_id, issue_comment_id, deleted_at) VALUES ('19b79e70-29ea-415b-a2e3-88c4f0544ebc', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '33cb93ab-b049-49f7-89a4-e424d31c1de9', 'created', NULL, NULL, NULL, '', '{}', NULL, NULL, EXTRACT(EPOCH FROM NOW()), '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', '11fb2311-d19b-4f7f-9e28-21c2afce823c', NULL, NULL);
INSERT INTO issue_activities (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, verb, field, old_value, new_value, comment, attachments, old_identifier, new_identifier, epoch, project_id, workspace_id, actor_id, issue_comment_id, deleted_at) VALUES ('b38e89d4-44e7-4259-8785-aa8de6f49bc1', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '337f0cc4-12cc-4936-906c-d4037ecb5a70', 'created', NULL, NULL, NULL, '', '{}', NULL, NULL, EXTRACT(EPOCH FROM NOW()), '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', '11fb2311-d19b-4f7f-9e28-21c2afce823c', NULL, NULL);
INSERT INTO issue_activities (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, verb, field, old_value, new_value, comment, attachments, old_identifier, new_identifier, epoch, project_id, workspace_id, actor_id, issue_comment_id, deleted_at) VALUES ('9fb7b5ac-5c61-487e-8132-d1782db6ee28', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '9324bf50-22d1-46cf-be45-76c9ceb28fb5', 'created', NULL, NULL, NULL, '', '{}', NULL, NULL, EXTRACT(EPOCH FROM NOW()), '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', '11fb2311-d19b-4f7f-9e28-21c2afce823c', NULL, NULL);
INSERT INTO issue_activities (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, verb, field, old_value, new_value, comment, attachments, old_identifier, new_identifier, epoch, project_id, workspace_id, actor_id, issue_comment_id, deleted_at) VALUES ('f8a8e6b7-5c4a-4461-b793-bc37c5efddb8', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', 'c8ad6233-7a8f-41c3-b2d9-ba2858513520', 'created', NULL, NULL, NULL, '', '{}', NULL, NULL, EXTRACT(EPOCH FROM NOW()), '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', '11fb2311-d19b-4f7f-9e28-21c2afce823c', NULL, NULL);
INSERT INTO issue_activities (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, verb, field, old_value, new_value, comment, attachments, old_identifier, new_identifier, epoch, project_id, workspace_id, actor_id, issue_comment_id, deleted_at) VALUES ('c0a4a27a-09dc-4870-b97c-d63ff0527e9c', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', 'b6b838b4-5b81-4098-90e3-fe8c6bf2415c', 'created', NULL, NULL, NULL, '', '{}', NULL, NULL, EXTRACT(EPOCH FROM NOW()), '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', '11fb2311-d19b-4f7f-9e28-21c2afce823c', NULL, NULL);
INSERT INTO issue_activities (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, verb, field, old_value, new_value, comment, attachments, old_identifier, new_identifier, epoch, project_id, workspace_id, actor_id, issue_comment_id, deleted_at) VALUES ('fa95736f-ef72-4845-ba0f-cc4689b7d867', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '6b2ca529-2213-40a1-b85e-0c9e2a57ecdb', 'created', NULL, NULL, NULL, '', '{}', NULL, NULL, EXTRACT(EPOCH FROM NOW()), '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', '11fb2311-d19b-4f7f-9e28-21c2afce823c', NULL, NULL);
INSERT INTO issue_activities (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, verb, field, old_value, new_value, comment, attachments, old_identifier, new_identifier, epoch, project_id, workspace_id, actor_id, issue_comment_id, deleted_at) VALUES ('dd272099-4eab-4820-a381-92dcdf4a641b', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', 'f1a4b811-bec8-4d4d-bf28-cccf59d3528c', 'created', NULL, NULL, NULL, '', '{}', NULL, NULL, EXTRACT(EPOCH FROM NOW()), '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', '11fb2311-d19b-4f7f-9e28-21c2afce823c', NULL, NULL);
INSERT INTO issue_activities (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, verb, field, old_value, new_value, comment, attachments, old_identifier, new_identifier, epoch, project_id, workspace_id, actor_id, issue_comment_id, deleted_at) VALUES ('e8ed743c-8207-49f6-94df-3c140a27365e', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', 'd11aab0b-8e8c-4f5e-a656-e320405b9684', 'created', NULL, NULL, NULL, '', '{}', NULL, NULL, EXTRACT(EPOCH FROM NOW()), '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', '11fb2311-d19b-4f7f-9e28-21c2afce823c', NULL, NULL);
INSERT INTO issue_activities (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, verb, field, old_value, new_value, comment, attachments, old_identifier, new_identifier, epoch, project_id, workspace_id, actor_id, issue_comment_id, deleted_at) VALUES ('8aba18f0-aa46-4fb0-8b53-1e9d3bec29ad', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '775f4dc5-7114-4e0e-80e7-2631822f16c1', 'created', NULL, NULL, NULL, '', '{}', NULL, NULL, EXTRACT(EPOCH FROM NOW()), '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', '11fb2311-d19b-4f7f-9e28-21c2afce823c', NULL, NULL);
INSERT INTO issue_activities (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, verb, field, old_value, new_value, comment, attachments, old_identifier, new_identifier, epoch, project_id, workspace_id, actor_id, issue_comment_id, deleted_at) VALUES ('964701e0-0531-4bed-9be8-d835f8ffe7d1', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '0b8c0e07-3bf6-44b2-9a84-93d6f1cb081f', 'created', NULL, NULL, NULL, '', '{}', NULL, NULL, EXTRACT(EPOCH FROM NOW()), '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', '11fb2311-d19b-4f7f-9e28-21c2afce823c', NULL, NULL);
INSERT INTO issue_activities (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, verb, field, old_value, new_value, comment, attachments, old_identifier, new_identifier, epoch, project_id, workspace_id, actor_id, issue_comment_id, deleted_at) VALUES ('ca00da1f-0c5a-43e6-b820-c32627e259f4', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '0e1f4737-cea2-497a-9e8d-41e84106c892', 'created', NULL, NULL, NULL, '', '{}', NULL, NULL, EXTRACT(EPOCH FROM NOW()), '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', '11fb2311-d19b-4f7f-9e28-21c2afce823c', NULL, NULL);
INSERT INTO issue_activities (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, verb, field, old_value, new_value, comment, attachments, old_identifier, new_identifier, epoch, project_id, workspace_id, actor_id, issue_comment_id, deleted_at) VALUES ('46bd2de6-32d1-4e43-a1cf-be22980aa8b0', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '4d7ff842-46d7-42c7-983c-595a650671c9', 'created', NULL, NULL, NULL, '', '{}', NULL, NULL, EXTRACT(EPOCH FROM NOW()), '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', '11fb2311-d19b-4f7f-9e28-21c2afce823c', NULL, NULL);
INSERT INTO issue_activities (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, verb, field, old_value, new_value, comment, attachments, old_identifier, new_identifier, epoch, project_id, workspace_id, actor_id, issue_comment_id, deleted_at) VALUES ('299adc16-4061-4fa7-aca0-ac1c8d25ca15', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', 'eaea3ff3-4b13-4e26-be0f-3998ce8df732', 'created', NULL, NULL, NULL, '', '{}', NULL, NULL, EXTRACT(EPOCH FROM NOW()), '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', '11fb2311-d19b-4f7f-9e28-21c2afce823c', NULL, NULL);
INSERT INTO issue_activities (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, verb, field, old_value, new_value, comment, attachments, old_identifier, new_identifier, epoch, project_id, workspace_id, actor_id, issue_comment_id, deleted_at) VALUES ('8d8a5144-d78c-4181-931b-641105d52100', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '0a42f431-9bd6-4e96-87e0-817c85a1a7af', 'created', NULL, NULL, NULL, '', '{}', NULL, NULL, EXTRACT(EPOCH FROM NOW()), '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', '11fb2311-d19b-4f7f-9e28-21c2afce823c', NULL, NULL);
INSERT INTO issue_activities (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, verb, field, old_value, new_value, comment, attachments, old_identifier, new_identifier, epoch, project_id, workspace_id, actor_id, issue_comment_id, deleted_at) VALUES ('8a22365c-a44f-475a-a688-d3491e66582b', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '2f123ef6-a1d4-48a8-8966-c5cca7b18a0c', 'created', NULL, NULL, NULL, '', '{}', NULL, NULL, EXTRACT(EPOCH FROM NOW()), '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', '11fb2311-d19b-4f7f-9e28-21c2afce823c', NULL, NULL);
INSERT INTO issue_activities (id, created_at, updated_at, created_by_id, updated_by_id, issue_id, verb, field, old_value, new_value, comment, attachments, old_identifier, new_identifier, epoch, project_id, workspace_id, actor_id, issue_comment_id, deleted_at) VALUES ('39414f22-54c4-4fb7-be4d-90716702c278', NOW(), NOW(), '11fb2311-d19b-4f7f-9e28-21c2afce823c', '11fb2311-d19b-4f7f-9e28-21c2afce823c', '72ee7324-4187-4f8b-ad75-5c74c49dc36d', 'created', NULL, NULL, NULL, '', '{}', NULL, NULL, EXTRACT(EPOCH FROM NOW()), '2924e784-2228-4087-bec1-43a04de1df6f', '6c6a5a06-9043-425a-b19e-0003cd181fe9', '11fb2311-d19b-4f7f-9e28-21c2afce823c', NULL, NULL);

COMMIT;
