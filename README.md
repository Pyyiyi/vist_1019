# 校园访客系统 V1.0

> 校园来访预约、审核、门卫核验、台账与安全管理的全栈系统。
> 功能唯一真相：`input/v1.0/PRD/14-V1.0需求文档PRD.md`；架构：`docs/trace/runs/v1/spac.md`。

---

## 一、快速启动

```bash
cp .env.example .env
docker compose up -d --build
docker compose ps
```

就绪判据：

```bash
curl -s http://localhost:3000/api/v1/health
# {"code":0,"message":"操作成功","data":{"status":"ok"}}
```

`docker compose ps` 中 `db`、`backend`、`frontend` 均为 `healthy`。

访问：

| 入口 | 地址 |
|------|------|
| 后台 | `http://localhost:8080` |
| 访客 H5 | `http://localhost:8080/h5/apply` |
| 后端 API | `http://localhost:3000/api/v1` |

首次启动后执行迁移与种子：

```bash
docker compose exec backend npm run migrate
docker compose exec backend npm run seed
```

迁移在应用启动时自动执行；上述 `migrate` 用于手动复核。种子必须手动执行。

默认端口 `3000/8080/55432` 被并行环境占用时，按第十节覆盖 `HOST_*` 变量后再启动。

---

## 二、测试账号

| 角色 | 账号/工号 | 密码 | 显示名 | 可见范围 |
|------|-----------|------|--------|----------|
| 管理员 | `admin` | `abc@123` | 系统管理员 | 全校、全部模块 |
| 门卫 | `guard01` | `abc@123` | 门卫张师傅 | 当日门口、当日台账 |
| 被访教职工 | `T001` | `abc@123` | 李明（教务处） | 本人相关预约与审核 |
| 被访教职工 | `T002` | `abc@123` | 王芳（学生处） | 本人相关预约与审核 |

访客不登录后台。访客通过 H5 提交后获得绑定令牌，可查看本人申请。

---

## 三、技术栈

| 层 | 选型 |
|----|------|
| 前端 | Vue 3 + Vue Router 4 + Pinia + Ant Design Vue 4 + Vite |
| 后端 | Node.js 20 + Express 4 + TypeScript（ES2022） |
| 数据库 | PostgreSQL 15 |
| 会话 | express-session + connect-pg-simple |
| 实时 | socket.io（后台消息红点） |
| 测试 | vitest + supertest + @vue/test-utils |
| 部署 | Docker Compose + nginx |

---

## 四、目录

```
backend/                 后端服务
  src/modules/           六个限界上下文
  src/shared/            共享内核
  db/migrations/         DDL 迁移
  db/seeds/              种子数据
frontend/                前端应用
  src/views/             六个上下文的页面
  src/nav/               唯一导航写入点
deploy/nginx.conf        SPA 回退与 /api 代理
docs/
  trace/runs/v1/         spac / issues / agent_plane
  knowledge/             共享内核、模块模板、Phase 契约、配置契约
  memory/                每卡执行记忆与轮次总结
contracts/               契约七件套
```

---

## 五、常用命令

### 后端

```bash
cd backend
npm run dev          # tsx watch src/main.ts
npm run build        # tsc -p tsconfig.json
npm run typecheck    # tsc --noEmit
npm run migrate      # tsx src/shared/db/migrate.ts
npm run seed         # tsx src/shared/db/seed.ts
npx vitest run
```

### 前端

```bash
cd frontend
npm run dev          # vite，端口 8080
npm run build        # vue-tsc --noEmit && vite build
npx vitest run
```

### 单测过滤

```bash
cd backend
npx vitest run src/modules/visit/__tests__/appointment.rules.test.ts
npx vitest run src/modules/master/__tests__/blacklist.rules.test.ts
```

---

## 六、环境变量

唯一权威：`docs/knowledge/config-contract.md`。默认值：

| 变量 | 默认 |
|------|------|
| `HOST_DB_PORT` | `55432` |
| `HOST_BACKEND_PORT` | `3000` |
| `HOST_FRONTEND_PORT` | `8080` |
| `DATABASE_URL` | `postgres://visitor:visitor@db:5432/visitor_system` |
| `COOKIE_SECURE` | `false` |
| `ENABLE_JOBS` | `true` |
| `TZ` | `Asia/Shanghai` |

---

## 七、种子数据

`seed-anchors.sql` 提供跨域锚点：

- 4 个后台账号、2 名教职工。
- 3 类访客类型、2 个校门、1 条有效黑名单、周一至周日 07:00–18:00 可预约规则、2 类字典。
- 11 条预约，覆盖 8 个状态；1 条待处理黑名单异常、1 条已处理信息不符、1 条已忽略强行闯入。
- 11 个 6 位短码（`100001`–`100011`）。
- 22 条告知记录、3 条通行记录、3 条站内消息、1 条 200 天前审计。

---

## 八、开发约定

- 全部跨卡约定见 `conventions.md`；用户可见文案逐字取自其 `COPY-###` 表。
- 模块边界、import 三档、16 步中间件序见 `conventions.md` 约定 1/2。
- 新增路由靠 `modules/<ctx>/api/*.routes.ts` 命名落位，不手工注册。
- 新增页面靠 `views/<ctx>/routes.ts` 自动发现；导航只在 `nav/navigation.ts` 写入。
- 迁移只放 DDL；种子只放 INSERT 且手动执行。
- 不使用倾向性模糊词与模糊时间词。

---

## 九、文档索引

| 文档 | 用途 |
|------|------|
| `docs/trace/runs/v1/spac.md` | 架构唯一真相 |
| `docs/trace/runs/v1/issues.yaml` | 可执行卡片 |
| `docs/trace/runs/v1/agent_plane.md` | 拆解总览与校验 |
| `conventions.md` | 跨卡约定与文案权威 |
| `roles.md` | 角色、权限点、数据范围 |
| `scenes.md` | 场景链路分析 |
| `schema-shared.sql` | 共享表 DDL |
| `seed-anchors.sql` | 跨域种子锚点 |
| `shared-kernel-manifest.yaml` | import 路径与导出符号权威 |
| `docs/knowledge/config-contract.md` | 环境变量唯一真相 |
| `docs/knowledge/module-template.md` | 模块模板 |
| `docs/knowledge/shared-kernel-api.md` | 共享内核签名 |
| `docs/knowledge/phase-contracts/` | 各 Phase 契约 |

---

## 十、封版信息（V1.0）

| 项目 | 值 |
|------|----|
| 基线 commit | `d02d1f52bc4a43d2b4accbb557709f750bb99ee5`（`origin/main`，VIS-P2-I01 集成闭环卡） |
| 封版 tag | `v1.0.0-freeze` |
| 封版日期 | 2026-10-20（Asia/Shanghai） |
| 封版记录 | `docs/trace/runs/v1/FREEZE` |
| 契约快照 | `contracts/` 七件套：`openapi.yaml`、`schema.sql`、`events.yaml`、`naming.yaml`、`routes.yaml`、`symbols.yaml`、`cross-context-writes.md` |

封版验证摘要：10 项检查全部通过；后端 122 条、前端 45 条单测通过；89 个端点操作逐条可达；49 个 adminOnly 端点以门卫会话请求均返回 403；迁移与种子连续执行两次无冲突。

若默认端口 `3000/8080/55432` 被占用，在 `.env` 中覆盖 `HOST_BACKEND_PORT`、`HOST_FRONTEND_PORT`、`HOST_DB_PORT` 后再执行 `docker compose up -d --build`；容器内端口保持 `3000/80/5432`。
