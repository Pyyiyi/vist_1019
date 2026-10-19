# VIS-P0-I09 契约冻结卡

## 结果

- 完成 `contracts/` 七件套冻结。
- 冻结报告：`docs/trace/runs/v1/contract-freeze-report.md`。
- 基线：`origin/main` @ `ba0cb65`。
- 分支：`feature/f1a4b811-bec8-4d4d-bf28-cccf59d3528c`。

## 产物

- `contracts/openapi.yaml`：OpenAPI 3.0.3，89 个方法操作 / 72 个唯一路径。
- `contracts/schema.sql`：五个迁移 DDL 的逐字汇总，26 张表。
- `contracts/events.yaml`：`notification:new` 生产点、消费点、房间和载荷。
- `contracts/naming.yaml`：26 张表列名、33 个权限点、407 个 COPY 编号。
- `contracts/routes.yaml`：18 个路由、2 个兜底、11 个一级导航项。
- `contracts/symbols.yaml`：95 个共享内核导出，6 个上下文门面，27 个 planned 门面导出。
- `contracts/cross-context-writes.md`：4 类门面写入与只读 SQL 清单。

## 验证

- `npx @redocly/cli lint contracts/openapi.yaml`：0 error、0 warning。
- OpenAPI 方法/路径/权限集合与 `spac.md` §6 差异：0。
- `schema.sql` 与五个迁移的 `CREATE TABLE` 集合差异：0；完整文件内容 5/5 匹配。
- `symbols.yaml` 与 `shared-kernel-manifest.yaml` 的路径/名称/kind 集合差异：0。
- 路由集合与 `spac.md` §4 差异：0。
- `notification:new` 在生产点、消费点各出现 1 次。
- `backend` 与 `frontend` 均在 `npm ci` 后通过 `npm run build`。

## 决策

- `includeInactive` 查询参数按 snake_case 约束冻结为 `include_inactive`。
- OpenAPI 路径项使用标准 OpenAPI 参数语法 `{id}`，另以 `x-contract-endpoint-index` 保留逐方法登记；该索引同时满足 89 个操作的机械计数。
- report/compliance 无门面导出，但仍在 `symbols.yaml` 中登记为空门面。

## 剩余风险

- OpenAPI 边界响应示例留给后续集成闭环卡补齐。
- 实际门面导出比对由 `VIS-P2-I03` 执行。
- 契约变更必须先登记请求，禁止在各实现卡内私改。
