# VIS-P0-I02 · 数据库 DDL 与迁移执行器

- 执行日期：2026-10-19
- 卡片：VIS-P0-I02（Plane `2b04c45b-1ebd-489a-bfee-3685ee181656`）
- 结果：完成；26 张业务表、5 个迁移文件、启动迁移执行器、连接池、重复执行保护与 Docker 运行时打包均已验证。

## 交付文件

### 迁移文件

- `backend/db/migrations/001-shared.sql`
- `backend/db/migrations/002-master.sql`
- `backend/db/migrations/003-visit.sql`
- `backend/db/migrations/004-notify.sql`
- `backend/db/migrations/005-compliance.sql`

### 执行器与接线

- `backend/src/shared/db/pool.ts`
- `backend/src/shared/db/migrate.ts`
- `backend/src/main.ts`
- `backend/package.json`
- `backend/Dockerfile`（将 `db/migrations` 复制进运行时镜像）

## 验证证据

验证使用专用栈的 PostgreSQL 宿主端口 `55440`。执行前清空 `public` schema，确保首次迁移从空库开始；业务表均为空，未丢失业务数据。

### 首次迁移

```text
> visitor-system-backend@1.0.0 migrate
> tsx src/shared/db/migrate.ts

数据库迁移完成，已应用 5 个文件
first_migrate_exit=0
```

`_migrations` 内容：

```text
      filename      
--------------------
 001-shared.sql
 002-master.sql
 003-visit.sql
 004-notify.sql
 005-compliance.sql
(5 rows)

 migration_count 
-----------------
               5
```

### 第二次迁移

```text
> visitor-system-backend@1.0.0 migrate
> tsx src/shared/db/migrate.ts

数据库迁移完成，已应用 0 个文件
second_migrate_exit=0

 migration_count 
-----------------
               5
```

### 数据库结构

- `\dt` 返回 27 张表：`_migrations` + 8 张共享表 + 7 张 master 表 + 8 张 visit 表 + 2 张 notify 表 + 1 张 compliance 表。
- `\d appointments` 显示 `chk_appointments_status`，包含 `待审核`、`已通过`、`已拒绝`、`已改期`、`已过期`、`已到访(在校中)`、`已离校`、`已取消` 8 个中文状态。
- 全库共 33 条 CHECK 约束；枚举列均带 CHECK。
- 全库共 10 条外键，仅存在于 shared 上下文内部或 visit 上下文内部；跨上下文引用列均未建外键。
- `grep -n "INSERT" backend/db/migrations/*.sql` 无命中，`grep_insert_exit=1`。

### 失败与回滚

临时加入 `006-failure-proof.sql` 后执行迁移，结果为：

```text
failure_migrate_exit=1
stderr: 数据库迁移失败：006-failure-proof.sql
```

失败后 `_migrations` 仍为 5，临时表 `migration_failure_probe` 不存在，证明文件事务已完整回滚。临时文件随后删除。

### 静态与运行时闸门

| 命令 | 实际结果 |
|------|----------|
| `cd backend && npm run typecheck` | 退出码 0 |
| `cd backend && npm run build` | 退出码 0 |
| `cd backend && npm test` | 1 test passed |
| `cd frontend && npm run build` | 构建通过 |
| `cd frontend && npm test` | 1 test passed |
| 启动 `node dist/main.js` | stdout `数据库迁移完成，已应用 0 个文件`，监听 `13011`；`GET /api/v1/health` 返回 `{"code":0,"message":"操作成功","data":{"status":"ok"}}` |
| `docker compose build backend && docker compose up -d --no-deps backend` | 镜像构建、容器启动及健康检查通过 |
| `docker compose exec -T backend sh -c 'ls -1 db/migrations'` | 运行时镜像含 `001-shared.sql` 至 `005-compliance.sql` |
| Compose 后端日志 | `数据库迁移完成，已应用 0 个文件`；`visitor-system-backend listening on port 3000` |

## 环境约束

- backend/frontend 的 `package.json` 均未配置 `lint` 脚本；使用 typecheck、build 与测试作为静态/构建闸门。
- 宿主机执行 `npm run migrate` 需显式提供可访问的 `DATABASE_URL`；本卡验证使用 `postgres://visitor:visitor@127.0.0.1:55440/visitor_system`。
- 宿主机运行后端使用 `PORT=13011`，避免占用 Compose 后端端口；Compose 验证使用项目 `.env` 中的 `13010`。

## 剩余风险

- 领域表索引仅验证存在性、列顺序与查询定义；真实数据量下的执行计划与性能由集成闭环卡验证。
- 当前只实现连接池与迁移器；业务 Repository、种子执行器与定时任务不在本卡范围。
- 首次启动迁移会延长应用就绪时间；多实例并发启动下的 DDL 锁策略留待部署模型明确后复核。
