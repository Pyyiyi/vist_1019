# VIS-P0-I08 · 种子锚点与执行器卡

- 执行日期：2026-10-19
- 卡片：VIS-P0-I08（Plane `6b2ca529-2213-40a1-b85e-0c9e2a57ecdb`）
- 结果：完成；种子 SQL 副本、手动执行器、数据库测试、生产容器执行路径与幂等验证均通过。

## 交付文件

- `backend/db/seeds/00-anchors.sql`（逐字复制根 `seed-anchors.sql`）
- `backend/src/shared/db/seed.ts`（`runSeeds(): Promise<number>`，按文件名排序、每个文件一个事务）
- `backend/src/shared/__tests__/seed.test.ts`（账号、预约、状态、短码、告知与幂等断言）
- `backend/package.json`、`backend/package-lock.json`（新增 `seed` 脚本；`tsx` 调整为运行时依赖）
- `backend/Dockerfile`（运行时镜像复制 `src`，使 `docker compose exec backend npm run seed` 可用）
- `docs/memory/2026-10-19/VIS-P0-I08.md`

## 验证证据

验证使用独立 Compose 项目与全新命名卷（PostgreSQL 15、临时宿主端口 `55590`），构建生产镜像后执行迁移与两次种子。标准宿主机端口当时已被其他进程占用，因此验证栈使用隔离端口，不触碰其他工作区数据。

### 迁移与两次种子

```text
backend-1 | 数据库迁移完成，已应用 5 个文件
backend-1 | visitor-system-backend listening on port 3000

> visitor-system-backend@1.0.0 seed
> tsx src/shared/db/seed.ts
种子执行完成，共 1 个文件
seed1_exit=0

> visitor-system-backend@1.0.0 seed
> tsx src/shared/db/seed.ts
种子执行完成，共 1 个文件
seed2_exit=0
```

### 指定计数

```text
 count
-------
     4
(users)

     status     | count
----------------+-------
 已到访(在校中) |     1
 已取消         |     1
 已拒绝         |     1
 已改期         |     1
 已离校         |     1
 已过期         |     1
 已通过         |     2
 待审核         |     3
(8 rows)

 count
-------
    11
(distinct short codes)

 count
-------
    22
(consent records)
```

附属锚点计数：`passage_records=3`、`incidents=3`、`notifications=3`、200 天前审计 `=1`；重复短码分组计数为 `0`。

### 账号与预约编号

```text
 username | password_ok
----------+-------------
 T001     | t
 T002     | t
 admin    | t
 guard01  | t

 AP20261019001
 AP20261019002
 AP20261019003
 AP20261019004
 AP20261019005
 AP20261019006
 AP20261019007
 AP20261019008
 AP20261019009
 AP20261019010
 AP20261019011
```

### 失败文案与回滚边界

在容器内临时加入 `99-failure-proof.sql` 后执行种子：

```text
failure_exit=1
stderr: 种子执行失败：99-failure-proof.sql
```

失败后 `users=4`、`appointments=11`、`visit_credentials=11`、`consent_records=22` 保持不变；临时文件随即删除。

### 静态、测试与运行时闸门

- `diff seed-anchors.sql backend/db/seeds/00-anchors.sql`：退出码 0，无差异。
- `npm run typecheck`：退出码 0。
- `npx vitest run src/shared/__tests__/seed.test.ts`：5 条测试通过。
- `npm test`：8 个文件、52 条测试全部通过（合并最新 origin/main 后复跑）。
- `npm run build`：退出码 0。
- `GET /api/v1/health`：HTTP 200，`{"code":0,"message":"操作成功","data":{"status":"ok"}}`。
- 前端 `npm run build`：通过；前端 `npm test`：5 个文件、35 条测试通过。
- `origin/main` 合并结果 clean；合并后再次构建生产镜像、执行两次 seed 并确认计数，最终 `users=4`、`appointments=11`、`statuses=8`、`short_codes=11`、`consents=22`。
- 验证结束后已删除临时 Compose 容器、网络、卷与临时数据库容器。

## 环境约束

- 工作区默认 `.env` 不存在且标准宿主端口被其他进程占用；验证使用临时 `.env`、隔离 Compose 项目、全新命名卷和显式 `DATABASE_URL`，验证后已清理。
- backend 与 frontend 均未配置 `lint` 脚本；使用 `typecheck`、测试与 `build` 作为静态/构建闸门。

## 剩余风险

- 种子数据的业务可读性由各领域卡在页面验证；本卡只保证锚点值、数量、状态覆盖与幂等执行。
- 预约编号的每日序号依赖执行日 D0；跨日重复执行时以执行日重新计算，领域卡不得缓存示例日期。
