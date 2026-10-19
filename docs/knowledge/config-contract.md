# 环境配置契约（config-contract）

> 本文件是环境变量的唯一真相。`.env.example`、`docker-compose.yml`、`backend/src/shared/config/*` 与全部卡片必须逐字一致。
> 每个变量给出唯一确定值；不配置开发/生产分支。

---

## 一、必填变量

| 变量 | 唯一值 | 消费方 | 说明 |
|------|--------|--------|------|
| `NODE_ENV` | `production` | 后端 | 固定值；本地亦使用该值，避免分支 |
| `PORT` | `3000` | 后端 | 容器内监听端口 |
| `DATABASE_URL` | `postgres://visitor:visitor@db:5432/visitor_system` | 后端 | compose 网络内连接串 |
| `DB_POOL_MAX` | `10` | 后端 | 连接池上限 |
| `SESSION_SECRET` | `visitor-session-secret-2026` | 后端 | 会话签名；`.env` 可覆盖，取值长度 ≥32 |
| `COOKIE_SECRET` | `visitor-cookie-secret-2026` | 后端 | Cookie 解析签名 |
| `COOKIE_SECURE` | `false` | 后端 | 本地 http 必须为 false；https 部署改为 true |
| `SESSION_TTL_HOURS` | `8` | 后端 | 会话有效期 |
| `CORS_ORIGIN` | `http://localhost:8080` | 后端 | 前端来源；Vite 开发时为 `http://localhost:5173` |
| `TZ` | `Asia/Shanghai` | 后端 / db | 本地时区 |
| `ENABLE_JOBS` | `true` | 后端 | 定时任务开关；单元测试设 false |
| `LOG_LEVEL` | `info` | 后端 | `debug` / `info` / `warn` / `error` |

## 二、宿主机端口映射

| 变量 | 唯一值 | 容器内端口 | 说明 |
|------|--------|------------|------|
| `HOST_DB_PORT` | `55432` | 5432 | PostgreSQL |
| `HOST_BACKEND_PORT` | `3000` | 3000 | Express |
| `HOST_FRONTEND_PORT` | `8080` | 80 | nginx |

## 三、数据库容器

| 变量 | 唯一值 | 说明 |
|------|--------|------|
| `POSTGRES_DB` | `visitor_system` | 数据库名 |
| `POSTGRES_USER` | `visitor` | 数据库用户 |
| `POSTGRES_PASSWORD` | `visitor` | 数据库密码 |
| `PGDATA` | `/var/lib/postgresql/data/pgdata` | 数据目录 |
| `TZ` | `Asia/Shanghai` | 容器时区 |

数据库卷：`visitor_pgdata` → `/var/lib/postgresql/data`。

## 四、前端构建变量

| 变量 | 唯一值 | 说明 |
|------|--------|------|
| `VITE_API_BASE` | `/api/v1` | apiClient baseURL |
| `VITE_WS_PATH` | `/ws` | socket.io 路径 |
| `VITE_APP_TITLE` | `校园访客系统` | 页面标题 |

Vite 开发服务器：端口 `5173`，代理 `/api` 与 `/ws` 到 `http://localhost:3000`，并补请求头 `X-Forwarded-Proto: https`。

## 五、业务参数

业务参数存于 `system_config` 表，不通过环境变量注入。初值与读取方式见 `spac.md` §5.7；读取统一走 `getConfig` / `getConfigNumber`。

| key | 初值 |
|-----|------|
| `entry_url` | `http://localhost/h5/apply` |
| `privacy_retention_days` | `90` |
| `audit_retention_days` | `365` |
| `verification_buffer_minutes` | `15` |
| `max_stay_minutes` | `240` |
| `min_stay_minutes` | `15` |
| `reschedule_confirm_timeout_hours` | `3` |
| `arrival_reminder_minutes` | `30` |
| `login_max_failures` | `5` |
| `login_lock_minutes` | `10` |
| `password_min_length` | `6` |
| `max_companions` | `10` |
| `ledger_page_size_default` | `20` |
| `ledger_page_size_max` | `100` |
| `booking_default_start` | `07:00` |
| `booking_default_end` | `18:00` |

## 六、启动校验

`config.ts` 在进程启动时校验：

1. 必填变量全部存在；缺失时打印变量名并 `process.exit(1)`。
2. `PORT`、`HOST_*_PORT`、`DB_POOL_MAX`、`SESSION_TTL_HOURS` 为正整数。
3. `SESSION_SECRET`、`COOKIE_SECRET` 长度 ≥32。
4. `COOKIE_SECURE`、`ENABLE_JOBS` 为 `true`/`false`。
5. `TZ` 固定为 `Asia/Shanghai`。

## 七、`.env.example`

```dotenv
NODE_ENV=production
PORT=3000
DATABASE_URL=postgres://visitor:visitor@db:5432/visitor_system
DB_POOL_MAX=10
SESSION_SECRET=visitor-session-secret-2026
COOKIE_SECRET=visitor-cookie-secret-2026
COOKIE_SECURE=false
SESSION_TTL_HOURS=8
CORS_ORIGIN=http://localhost:8080
TZ=Asia/Shanghai
ENABLE_JOBS=true
LOG_LEVEL=info

HOST_DB_PORT=55432
HOST_BACKEND_PORT=3000
HOST_FRONTEND_PORT=8080

POSTGRES_DB=visitor_system
POSTGRES_USER=visitor
POSTGRES_PASSWORD=visitor
PGDATA=/var/lib/postgresql/data/pgdata

VITE_API_BASE=/api/v1
VITE_WS_PATH=/ws
VITE_APP_TITLE=校园访客系统
```
