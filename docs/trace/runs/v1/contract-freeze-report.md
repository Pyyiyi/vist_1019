# 契约冻结完成

- 日期：2026-10-19
- 卡片：`VIS-P0-I09` / `f1a4b811-bec8-4d4d-bf28-cccf59d3528c`
- 基线：`origin/main` @ `ba0cb65`
- 状态：已冻结；全部卡片只消费，不改写。契约缺口必须在本卡登记变更请求。

## 冻结产物

| 文件 | 内容 | 数量 |
|------|------|------|
| `contracts/openapi.yaml` | OpenAPI 3.0.3；`spac.md` §6 全部端点 | 89 个方法操作；72 个唯一路径 |
| `contracts/schema.sql` | `001-shared.sql` 至 `005-compliance.sql` 的逐字汇总 | 5 个迁移；26 张表 |
| `contracts/events.yaml` | `notification:new` 生产、消费、房间与载荷 | 1 个生产点；1 个消费点 |
| `contracts/naming.yaml` | 表名、列名、权限点、COPY 编号 | 26 张表；33 个权限点；407 个 COPY |
| `contracts/routes.yaml` | `spac.md` §4 路由、布局、角色、导航顺序 | 18 个路由；2 个兜底；11 个一级导航 |
| `contracts/symbols.yaml` | 共享内核导出与六个上下文门面计划签名 | 57 个文件；95 个导出；6 个门面；27 个 planned 导出 |
| `contracts/cross-context-writes.md` | 门面写入矩阵与只读 SQL 清单 | 4 类门面写入 |

## 逐项比对

### OpenAPI

- 从 `docs/trace/runs/v1/spac.md` §6 提取 89 条 `方法 + 路径 + 权限列`。
- OpenAPI 路径项规范化 `:id` 为 `{id}` 后，方法、路径与 `x-access` 的集合差异为 **0**。
- 每个操作登记 `x-access`、`x-authentication`、`x-allowed-roles`；需要权限点的操作另登记 `x-required-permission`。
- 所有成功响应使用统一信封 `{code,message,data}`；分页、详情、变更、二进制端点分别登记响应 shape。
- 统一错误响应覆盖 401、403、404、405、409、422、429；字段错误通过 `ErrorEnvelope.field` 返回。
- `includeInactive` 按命名约束冻结为查询参数 `include_inactive`；响应 JSON 键全部为 snake_case。
- 二进制端点 `/system/entry-qr.png` 与 `/logs/export` 冻结为文件流，不套信封；失败仍返回 JSON 信封。

### Schema

- `contracts/schema.sql` 按文件名顺序拼接五个迁移文件，保留 `BEGIN`/`COMMIT`、DDL、索引与注释。
- 五个迁移文件内容逐字包含于汇总文件：**5/5**。
- `CREATE TABLE` 集合差异为 **0**；表数量 **26**。

### Symbols

- `shared-kernel-manifest.yaml` 登记 57 个文件、95 个导出；`symbols.yaml` 逐文件逐导出登记，路径/名称/kind 集合差异为 **0**。
- 六个上下文门面均登记：`access`、`master`、`notify`、`visit`、`report`、`compliance`。
- `access`、`master`、`notify`、`visit` 的计划签名取自 `p1-contracts.md`，共 27 个导出，全部标记 `status: planned`。
- `report` 与 `compliance` 按 `p1-contracts.md` 登记为空门面导出，并保留用途说明。
- 实际源码导出的逐条比对留给 `VIS-P2-I03`。

### Naming

- 26 张表的名称与 DDL 列顺序逐表登记。
- 33 个权限点从 `roles.md` 生成，包含 admin/guard/host/visitor 授权矩阵。
- 407 个 COPY 编号从 `conventions.md` §12.2 生成，包含编号、场景与逐字文案。
- 软引用、预约编号、短码、事件名、房间与 API 前缀均登记。

### Routes

- §4 的 18 个路由集合差异为 **0**。
- 登记每个路由的页面、布局、可见角色、消费端点、REQ 与关键角色差异。
- 登记两个兜底路由：`/:pathMatch(.*)*`、`/h5/:pathMatch(.*)*`。
- 导航顺序、层级、标题、路径、角色与图标取自唯一写入点 `frontend/src/nav/navigation.ts`。

### Events

- 生产点：`notify.publishNotification` / `publishSecurityNotification` 写入成功后调用 `emitNotification`。
- 消费点：`AppLayout` 未读徽标与通知中心列表。
- 房间：`user:<recipient_id>`；H5 不建立 WebSocket，使用加载与 30 秒轮询兜底。
- 载荷：`{id,title,templateType,createdAt}`。

### Cross-context writes

- 门面写入仅允许：
  - `visit → notify.publishNotification`
  - `visit → notify.publishSecurityNotification`
  - `visit → master.upsertReviewerRules`
  - `compliance → visit.eraseAppointmentPii`
- 只读 SQL 清单覆盖 access、report、compliance 的跨上下文读取，并明确禁止写他人表。

## 验证输出

### 七件套存在

```text
$ ls contracts/{openapi.yaml,schema.sql,events.yaml,naming.yaml,routes.yaml,symbols.yaml,cross-context-writes.md}
contracts/openapi.yaml
contracts/schema.sql
contracts/events.yaml
contracts/naming.yaml
contracts/routes.yaml
contracts/symbols.yaml
contracts/cross-context-writes.md
```

### OpenAPI lint

```text
$ npx @redocly/cli lint contracts/openapi.yaml
No configurations were provided -- using built in recommended configuration by default.

validating contracts/openapi.yaml...
contracts/openapi.yaml: validated in 232ms

Woohoo! Your API description is valid. 🎉
```

结果：**0 error，0 warning**。

### 端点数量

```text
$ grep -c "^  /" contracts/openapi.yaml
89
```

`spac.md` §6 方法操作总数为 **89**；OpenAPI 路径项为 **72**，差异来自同一路径承载多个方法。`x-contract-endpoint-index` 以一行一个操作登记全部 89 条。

### 事件点

```text
$ grep -n "notification:new" contracts/events.yaml
16:  - event: notification:new
27:  - event: notification:new
```

生产点与消费点各 1 条。

### DDL 差异

```text
$ diff <(grep -h "CREATE TABLE" backend/db/migrations/*.sql | sort) <(grep "CREATE TABLE" contracts/schema.sql | sort)
$ echo $?
0
```

无差异输出。


### Repository build gates

```text
$ cd backend && npm ci && npm run build
> visitor-system-backend@1.0.0 build
> tsc -p tsconfig.json

$ cd frontend && npm ci && npm run build
> visitor-system-frontend@1.0.0 build
> vue-tsc --noEmit && vite build
✓ built in 19.35s
```

结果：两个构建均退出码 0。

## 契约变更请求

无。

## 剩余风险

- OpenAPI 已冻结端点、请求字段、成功响应 shape 与主要错误；示例未覆盖全部边界响应。边界响应样例由后续集成闭环卡补齐，不回改本卡契约。
- 门面实际导出与计划签名的逐条比对由 `VIS-P2-I03` 执行。
- 若运行期发现 §6 未登记的响应字段或错误场景，必须先在本卡登记变更请求，禁止私改契约。
