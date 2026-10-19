# 状态刷新报告

- 日期：2026-10-20（Asia/Shanghai）
- 卡片：`VIS-P2-I03` / `72ee7324-4187-4f8b-ad75-5c74c49dc36d`
- 基线：`origin/main` @ `c8332e7`
- 范围：`contracts/` 七件套、`conventions.md`、本报告
- 原则：以实际代码为事实；早期设计与代码不一致时刷新契约并在本报告登记；不修改业务代码

## 八项检查

### 1. OpenAPI 与实际端点

通过：openapi.yaml 与实际端点逐条一致

- 直接从 23 个 `*.routes.ts` 提取到 89 个方法操作、72 个唯一路径；`openapi.yaml` 的方法与路径集合差异均为 0。
- 每个操作的 `x-access`、`x-authentication`、`x-allowed-roles` 与 `x-required-permission` 按实际中间件刷新。
- `requireAdmin` 不再登记虚构权限点；门卫核验/放行/离校、事故上报/处置、工作台、隐私与主数据接口按实际请求体、响应体修正。
- 验证：`grep -c "^  /" contracts/openapi.yaml` → `72`，与实际唯一路由数一致；OpenAPI 方法操作数 → `89`。

差异：contracts/openapi.yaml 权限声明与门卫、工作台、隐私请求/响应 schema 与路由及服务 DTO 不一致

修正：按实际中间件重写权限元数据，补齐 `todos`、门卫 KPI 键、门卫表单选项、核验/放行/离校/现场登记、事故处置、隐私案件与通知渠道请求字段

### 2. 事件生产与消费

通过：events.yaml 与实际事件一致

- 生产点覆盖 `publishNotification`、`publishSecurityNotification` 与 `runOverdueJob`，均落到 `emitNotification`。
- 消费点覆盖 `AppLayout`、通知 store、通知中心页面与 `frontend/src/realtime/socket.ts`。
- 明确只有 `recipient_type=user` 且实际插入成功的通知发送事件；重复通知不发送事件。
- 验证：`grep -n "notification:new" contracts/events.yaml` 存在匹配。

差异：contracts/events.yaml 将 /ws 误记为 Socket.IO namespace，并声明了代码中不存在的 H5 30 秒轮询

修正：改为 `path: /ws`、默认命名空间 `/`，记录 H5 无 WebSocket 且无定时轮询，并补充运行时载荷键与契约 snake_case 键的差异

### 3. Schema 与迁移

通过：schema.sql 与实际迁移一致

- 实际迁移为 `001-shared.sql` 至 `006-notify-idempotency.sql`，共 6 个文件、26 张业务表。
- `contracts/schema.sql` 按文件名顺序逐字拼接全部迁移，包含 `006` 的超时未离每日唯一索引。
- 验证：`diff -u <(cat backend/db/migrations/*.sql) contracts/schema.sql` 输出 0 行。

差异：contracts/schema.sql 原先只拼接 001–005，缺少 006-notify-idempotency.sql

修正：以 6 个迁移文件逐字重建 schema.sql；在 naming.yaml 登记 `uq_notifications_overdue_daily`

### 4. 符号与 manifest

通过：symbols.yaml 与 shared-kernel-manifest.yaml 及实际导出一致

- manifest 登记 57 个文件、95 个导出；实际为 57 个文件、134 个导出。
- manifest 的 95 个导出全部存在于实际源码，缺失数为 0；实际多出 39 个未声明导出，分布在 14 个文件。
- 6 个上下文门面共 91 个实际导出，全部从 `index.ts` 复核并标记为 `actual`。
- 验证：每个 manifest 导出与实际导出集合逐文件比对；`missing_from_actual` 为空。

差异：contracts/symbols.yaml 仅登记 manifest 的 95 个导出，遗漏 14 个文件中的 39 个实际导出，且六个门面仍为 planned

修正：按实际导出重建 symbols.yaml，保留 manifest 对比结果、门面实际导出与 assembly 信息

### 5. 路由与导航

通过：routes.yaml 与实际路由、导航一致

- 视图路由实际有 19 条记录、18 个唯一路径；导航 11 个一级项与 `navigation.ts` 完全一致。
- `/403` 实际为 `blank` 且无角色限制；H5 路由实际无后台角色并绕过认证守卫；`/h5/apply` 标题为“来访申请”。
- 通知中心不再声明不存在的 30 秒轮询兜底；`/h5/privacy` 的两个来源定义已显式登记。
- 验证：路由记录、layer、layout、title、roles 与实际对象比对；导航对象忽略新增 `order` 字段后完全相等。

差异：contracts/routes.yaml 未记录 /h5/privacy 重复定义，/403 与 H5 角色/layout、/h5/apply 标题和 /notifications 轮询字段与代码不一致

修正：按实际 route meta 与共享路由重写路由项，新增 duplicate_paths 与 router 守卫信息，移除虚构轮询字段

### 6. 命名与权限点

通过：naming.yaml 与实际表列与权限点一致

- 26 张表的名称、列顺序与迁移 DDL 逐表一致，差异为 0。
- 权限来源分三层登记：种子 33 个、运行时白名单 50 个、路由检查 47 个；去重后 59 个。
- 明确登记 3 个仅在路由出现、未进入运行时白名单的权限码，以及种子/运行时/路由三者的未使用集合。
- 验证：DDL 解析列集合与 contract 比较差异 0；006 唯一索引与权限来源集合均存在。

差异：contracts/naming.yaml 的 permissions 仅登记 roles.md 的 33 个种子权限，未反映运行时白名单和路由实际检查，且缺少 006 唯一索引

修正：重建权限条目为实际三层并集，增加 permission_inventory、permission_drift、unique_indexes 与逐权限使用端点

### 7. 跨上下文调用

通过：cross-context-writes.md 与实际门面调用及只读 SQL 一致

- 门面写入 4 项：visit→notify 两项、visit→master 一项、compliance→visit 一项。
- 直接跨上下文写入 3 项：access→master.hosts、notify→visit.appointments、compliance→master.system_config；已作为债务登记。
- 门面读取与实际 import 逐条核对；report 实际只直读 appointments、visitor_types、hosts、incidents，已移除不存在的 passage_records/companions 声明。
- 验证：SQL 扫描覆盖 FROM/JOIN/INSERT/UPDATE/DELETE；facade import 扫描覆盖所有模块 `index.ts` 调用。

差异：contracts/cross-context-writes.md 声称 notify 不直读 visit，但实际存在 3 条跨上下文 SQL 写入和多条直接读取

修正：改写为门面写入、直接写入债务、门面读取、只读 SQL 四段式矩阵，并标注禁止扩展项

### 8. 涌现约定回写

通过：涌现约定已回写 conventions.md

- 新增“约定 16 · 状态刷新涌现约定（VIS-P2-I03）”，覆盖契约事实源、权限三层、HTTP/事件命名、前端路由、实时通知幂等与跨上下文债务。
- 约定与本次七件套保持一致，并明确后续新增权限点、迁移、事件载荷与跨上下文调用的更新责任。
- 验证：`rg -n "约定 16|权限点三层事实|实时通知与幂等|跨上下文调用" conventions.md` 存在匹配。

差异：conventions.md 未记录实际权限分层、H5 无轮询、事件运行时键名与跨上下文债务

修正：追加约定 16，共 6 个小节，明确代码优先与后续收敛规则

## 验证汇总

| 检查 | 结果 |
|------|------|
| OpenAPI 路径计数 | `72`，与唯一路由数一致 |
| OpenAPI 方法操作 | `89`，与路由文件操作数一致 |
| 迁移 DDL diff | `0` 行 |
| `notification:new` | 存在 |
| 八项通过记录 | `8` 条 |
| 契约 JSON 键 | snake_case |
| 允许变更范围 | `contracts/`、`conventions.md`、本报告 |

## 剩余风险

- 运行时权限白名单、种子权限与路由检查仍有 3 个路由权限码缺口；下一轮应统一到单一权限源。
- `/h5/privacy` 在 compliance 与 visit 两处重复定义，运行期最终命中的组件取决于路由装载顺序，下一轮应删除其中一个定义。
- 3 条直接跨上下文 SQL 写入尚未门面化；本轮按“以代码为事实”记录为债务，未修改业务代码。
- Socket.IO 载荷仍使用 `templateType`/`createdAt`；契约已登记 snake_case 规范化键并保留运行时差异。
