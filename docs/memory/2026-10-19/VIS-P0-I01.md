# VIS-P0-I01 · 项目脚手架与运行时闭环

- 执行日期：2026-10-19
- 卡片：VIS-P0-I01（Plane `7bd3ad51-7dbc-47c2-93de-08eaa2ebc8eb`）
- 结果：完成（工程骨架、健康检查、Docker Compose 运行闭环）

## 交付文件

### 后端

- `backend/package.json`、`backend/package-lock.json`
- `backend/tsconfig.json`
- `backend/src/main.ts`、`backend/src/app.ts`、`backend/src/config.ts`
- `backend/src/__tests__/health.test.ts`
- `backend/.env.example`、`backend/Dockerfile`、`backend/.dockerignore`
- `backend/src/modules/.gitkeep` 与 `access` / `visit` / `master` / `notify` / `report` / `compliance` 六个上下文占位
- `backend/db/migrations/.gitkeep`、`backend/db/seeds/.gitkeep`

### 前端

- `frontend/package.json`、`frontend/package-lock.json`
- `frontend/tsconfig.json`、`frontend/vite.config.ts`
- `frontend/index.html`、`frontend/public/favicon.svg`
- `frontend/src/main.ts`、`frontend/src/App.vue`、`frontend/src/env.d.ts`
- `frontend/src/__tests__/App.test.ts`
- `frontend/Dockerfile`、`frontend/.dockerignore`
- `frontend/src/views/.gitkeep`、`frontend/src/api/.gitkeep`

### 部署与根目录

- `deploy/nginx.conf`
- `docker-compose.yml`、`.dockerignore`、`.env.example`、`.gitignore`、`.npmrc`
- `docs/memory/MEMORY.md`、`docs/memory/2026-10-19/VIS-P0-I01.md`

## 验证证据

| 命令 | 结果 |
|------|------|
| `cd backend && npm ci && npm run typecheck && npm run build` | 退出码 0；生成 `backend/dist/main.js` |
| `cd backend && npm test` | 1 test passed（health 信封逐字断言） |
| `cd frontend && npm ci && npm run build` | 退出码 0；生成 `frontend/dist/index.html` |
| `cd frontend && npm test` | 1 test passed（标题 `校园访客系统`） |
| `docker compose up -d --build` | `db` / `backend` / `frontend` 三服务 `healthy` |
| `curl -s http://localhost:<backend>/api/v1/health` | `{"code":0,"message":"操作成功","data":{"status":"ok"}}` |
| 通过 nginx 访问 `/api/v1/health` | 同一信封 |
| `curl -s -o /dev/null -w '%{http_code}' http://localhost:<frontend>/h5/apply` | `200`（SPA 回退） |
| 首页 `<title>` 与静态资源 | `校园访客系统`；JS 资源 `200` |
| `grep -n 'lang="zh-CN"' frontend/index.html` | 1 行命中 |
| `grep -n 'viewport-fit=cover' frontend/index.html` | 1 行命中 |
| `grep -rn docker-entrypoint-initdb.d docker-compose.yml` | 0 命中 |
| `docker compose down` 后 `docker volume inspect visitor_pgdata` | 卷仍存在 |
| `node ./node_modules/vite/bin/vite.js` 与 `tsx watch src/main.ts` | 均正常启动；Vite 页面/`main.ts`/`App.vue` 返回 200 |
| Headless Chromium 截图 | 页面居中渲染「校园访客系统」 |

## 环境约束

本机为多项目共享宿主：默认端口 `3000` 被 Plane 前端 dev server 占用，`55432` 被其他项目的宿主 Postgres 占用。
因此运行时验证使用覆盖值 `HOST_BACKEND_PORT=13010`、`HOST_DB_PORT=55440`，容器内端口仍固定为 3000/5432/80；
`.env.example` 保持契约要求的默认值 `55432/3000/8080`。

## 剩余风险

- 健康检查当前直接手写信封，尚未接入共享内核 `responseEnvelope`；由 Hub 集成补全卡覆盖。
- `backend/src/app.ts` 仅挂载 `express.json()` 与健康检查，其余 15 步中间件/路由装配由后续共享内核与 Hub 集成卡完成。
- 本卡未创建任何业务表或业务页面，符合边界约束。
- `config.ts` 启动即校验全部必填变量；本地直接 `tsx` 运行时需先导出 `.env`（Docker 通过 `env_file` 注入）。
