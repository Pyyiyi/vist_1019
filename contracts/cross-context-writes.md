# 跨上下文写入与只读 SQL

> 权威来源：`conventions.md` 约定 1.4/1.5、`docs/trace/runs/v1/spac.md` §6.9、`docs/knowledge/phase-contracts/p1-contracts.md`。
> 跨上下文写入只能调用目标上下文 `index.ts` 门面；跨上下文读取只允许只读 SQL 或目标门面提供的只读函数。

## 门面写入矩阵

| 生产上下文 | 目标门面 | 方法 | 目标表 | 触发点 | 事务与审计 |
|------------|----------|------|--------|--------|------------|
| visit | notify | `publishNotification(input)` | `notifications` | 预约提交、审核通过/拒绝、改期提议、改期确认、到访提醒等普通通知 | 目标门面完成写入；写入成功后发送 `notification:new`；失败按调用方事务策略处理 |
| visit | notify | `publishSecurityNotification(input)` | `notifications`（`is_security=true`） | 黑名单命中、超时未离等安全类通知 | 安全类始终走站内渠道并发送 `notification:new` |
| visit | master | `upsertReviewerRules(rules)` | `reviewer_rules` | `PUT /api/v1/reviews/assignment` 保存审核人规则 | 目标门面在自身事务内写入并写审计；只影响之后创建的预约 |
| compliance | visit | `eraseAppointmentPii(id, actorId, reason)` | `appointments` | `POST /api/v1/privacy/appointments/:id/erase` | 目标门面置空主记录 PII；调用方写入 `privacy_cases`；审计 before/after 明文保留 |

除上表外，不允许跨上下文直接 `INSERT`、`UPDATE`、`DELETE` 其他上下文表。`writeAudit()` 写入共享表 `operation_logs`，属于共享内核调用，不计为跨上下文门面写入。

## 门面读取

| 消费上下文 | 目标上下文 | 只读门面 | 用途 |
|------------|------------|----------|------|
| visit | access | `getUserById`、`getUserByHostId`、`getFirstAdminUser` | 解析当前用户、host 绑定账号与默认管理员审核人 |
| visit | master | `getActiveVisitorTypes`、`getActiveHosts`、`getActiveGates`、`getDictionaryItems`、`getConfig`、`getConfigNumber`、`resolveReviewer`、`checkBlacklist` | 表单选项、配置读取、审核人解析、黑名单检查 |
| master | access | `getUserById` | 校验审核规则中的 `designated` 用户引用 |
| compliance | visit | `getAppointmentForCompliance` | 获取隐私案件与本人副本所需的预约摘要 |

## 只读 SQL 清单

### access

| 表 | 归属上下文 | 用途 | 约束 |
|----|------------|------|------|
| `hosts` | master | 登录时按 `employee_no` 解析 host 与绑定账号 | 仅 `SELECT`；不写 `hosts` |

### report

| 表 | 归属上下文 | 用途 | 约束 |
|----|------------|------|------|
| `appointments` | visit | 台账、在校清单、到访统计口径 | 仅 `SELECT`；按对象范围与本地日期过滤 |
| `passage_records` | visit | 进校/离校时刻与再次进校 | 仅 `SELECT` |
| `companions` | visit | 台账人数与导出明细 | 仅 `SELECT` |
| `visitor_types` | master | 台账与统计的访客类型维度 | 仅 `SELECT` |
| `incidents` | visit | 异常统计与超时未离计数 | 仅 `SELECT` |

### compliance

| 表 | 归属上下文 | 用途 | 约束 |
|----|------------|------|------|
| `appointments` | visit | 本人副本与人工清除定位预约 | 优先经 `getAppointmentForCompliance`；补充查询必须只读 |
| `companions` | visit | 本人副本随行人员 | 仅 `SELECT`；证件号掩码输出 |
| `consent_records` | visit | 本人副本告知记录 | 仅 `SELECT` |
| `passage_records` | visit | 本人副本通行记录 | 仅 `SELECT` |

### 其他上下文

- `master` 不直接读取其他上下文业务表；配置、字典与审核人用户引用分别使用 `system_config`/`data_dictionary` 自身表及 access 门面。
- `notify` 不直接读取 visit 表；通知调用方在 `PublishNotificationInput` 中提供标题、正文与业务标识。
- `visit` 不直接读取 master 业务表；全部经 master 门面。

## 禁止项

1. 禁止跨上下文外键；跨上下文引用只使用软引用列与索引。
2. 禁止导入其他上下文的 `internal/`、`.service`、`.repo` 或 `domain`。
3. 禁止在只读 SQL 中出现 `INSERT`、`UPDATE`、`DELETE`、DDL 或 `SELECT ... FOR UPDATE`。
4. 禁止以姓名、工号、手机号字符串替代绑定实体 id 做对象范围判定。
5. 新增跨上下文写入必须先登记到本文件并更新目标 `index.ts` 门面；禁止私改契约。
