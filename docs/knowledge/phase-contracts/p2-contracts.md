# Phase 2 契约摘要（p2-contracts）

> Phase 2 是集成与封版阶段。本文件规定集成闭环、封版归档、状态刷新三张卡的验收接口。
> 不新增业务端点，不修改 Phase 0/1 的冻结契约。

---

## 一、集成闭环契约

### 1.1 阶段一：扫描验证

| 检查 | 命令 | 通过判据 |
|------|------|----------|
| 后端类型 | `cd backend && npm run typecheck` | 退出码 0 |
| 前端类型与构建 | `cd frontend && npm run build` | 退出码 0，产物 `frontend/dist/index.html` |
| 后端单测 | `cd backend && npx vitest run` | 全部通过；需数据库用例在 compose 启动后执行 |
| 前端单测 | `cd frontend && npx vitest run` | 全部通过 |
| 路由发现 | 启动后请求任一领域端点 | 非 404 |
| 健康检查 | `curl -s http://localhost:3000/api/v1/health` | `code=0` |

### 1.2 阶段二：可运行性验证

| 链路 | 步骤 | 通过判据 |
|------|------|----------|
| 登录 → 工作台 | `admin` 登录 | 200；`role=admin`；工作台 KPI 渲染 |
| H5 提交 → 审核通过 | 提交新预约 → host 审核 | 新预约 `待审核` → `已通过`；通知两条 |
| 核验 → 放行 → 离校 | 门卫核验短码 → 放行 → 离校 | 状态 `已到访(在校中)` → `已离校`；台账可见 |
| 现场登记 | 门卫现场登记 | 状态直接 `已到访(在校中)`；凭证已使用 |
| 改期闭环 | 提议 → 访客确认 → 审核 | `已改期` → `待审核` → `已通过` |
| 黑名单 | 提交 P10 同类预约 → 门卫核验 | 提交软提示；核验硬拦；异常记录 |
| 导出 | 台账导出 CSV / XLSX | 文件头分别为 `EF BB BF` / `PK\x03\x04` |
| 隐私清除 | 人工清除一条预约 | 主记录 PII 为 NULL；审计明文保留 |
| 统计 | 打开统计页 | 到访成立集计数与台账一致 |
| 实时消息 | 新通知产生 | 后台铃铛徽标即时 +1 |

### 1.3 阶段三：缺陷自愈

- 每个失败项记录：现象、复现命令、根因、修复文件、回归命令。
- 修复后重跑阶段一与阶段二。
- 产出 `docs/trace/runs/v1/integration-report.md`，含每阶段命令与原始输出摘要。

---

## 二、封版归档契约

### 2.1 十项检查

| # | 检查 | 判据 |
|---|------|------|
| 1 | 设计文件齐全 | `spac.md`、`README.md`、`conventions.md`、`schema-shared.sql`、`seed-anchors.sql`、`shared-kernel-manifest.yaml`、`roles.md`、`scenes.md`、`docs/knowledge/*` 全部存在 |
| 2 | 契约七件套 | `contracts/openapi.yaml`、`schema.sql`、`events.yaml`、`naming.yaml`、`routes.yaml`、`symbols.yaml`、`cross-context-writes.md` 全部存在 |
| 3 | 卡片全部关闭 | `issues.yaml` 中每个 id 有对应实现或明确结论 |
| 4 | 端点逐条可达 | `openapi.yaml` 中每个路径用 curl 或测试请求一次，非 404/500 |
| 5 | 权限点逐条生效 | 每个 adminOnly 端点用 guard 请求返回 403 |
| 6 | 迁移幂等 | 连续执行两次 `npm run migrate`，第二次应用 0 个文件 |
| 7 | 种子幂等 | 连续执行两次 `npm run seed`，无主键冲突 |
| 8 | 测试绿 | 后端与前端单测全部通过；需数据库用例在 compose 下通过 |
| 9 | README 可用 | 按 README 从零启动成功；测试账号可登录 |
| 10 | 无伪占位 | 全库 grep 无 `TODO`、`FIXME`、`<ID>`、`test1`、`foo`、`lorem` 作为业务数据 |

### 2.2 封版产物

- `docs/trace/runs/v1/FREEZE`：记录基线 commit、日期、10 项检查结果。
- git tag：`v1.0.0-freeze`。
- `README.md` 更新为最终启动指南。

---

## 三、状态刷新契约

### 3.1 从代码反写

| 文件 | 来源 |
|------|------|
| `contracts/openapi.yaml` | 各 `*.routes.ts` 的实际方法、路径、请求、响应、权限 |
| `contracts/schema.sql` | `backend/db/migrations/*.sql` 的实际 DDL |
| `contracts/events.yaml` | `notification:new` 的生产与消费点 |
| `contracts/naming.yaml` | 实际表名、列名、权限点、文案编号 |
| `contracts/routes.yaml` | `frontend/src/nav/navigation.ts` 与实际路由 |
| `contracts/symbols.yaml` | 各上下文 `index.ts` 与共享内核的实际导出 |
| `contracts/cross-context-writes.md` | 实际门面调用与只读 SQL |

### 3.2 八项检查

1. `openapi.yaml` 与实际端点逐条一致。
2. `events.yaml` 与实际事件一致。
3. `schema.sql` 与实际迁移一致。
4. `symbols.yaml` 与 `shared-kernel-manifest.yaml` 及实际导出一致。
5. `routes.yaml` 与实际路由、导航一致。
6. `naming.yaml` 与实际命名一致。
7. `cross-context-writes.md` 与实际调用一致。
8. 涌现约定已回写 `conventions.md`。

### 3.3 产物

- `docs/trace/runs/v1/state-refresh-report.md`：记录 8 项检查、差异、修正。
- 刷新后的 `contracts/` 七件套。

---

## 四、Phase 2 完成判据

- [ ] `integration-report.md` 三阶段齐全，全部失败项已修复并回归通过。
- [ ] `FREEZE` 存在，10 项检查全部通过。
- [ ] tag `v1.0.0-freeze` 存在。
- [ ] `contracts/` 七件套与实际代码一致。
- [ ] `state-refresh-report.md` 8 项检查全部通过。
