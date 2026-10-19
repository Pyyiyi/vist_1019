# 跨上下文写入与只读 SQL

> 权威来源：实际 `backend/src/modules/*/index.ts` 门面导入、`backend/src/modules/*/internal/**/*.ts` 的 SQL 与 `backend/db/migrations/*.sql`。
> 本文件以代码为事实记录；直接跨上下文 SQL 写入列为现存债务，下一轮不得继续扩展。

## 门面写入矩阵

| 生产上下文 | 目标门面 | 方法 | 目标表 | 实际触发点 | 事务与审计 |
|------------|----------|------|--------|------------|------------|
| visit | notify | `publishNotification(input)` | `notifications` | 预约提交、审核结果、改期、到访提醒等普通通知 | notify 直接写入并在实际插入后发送 `notification:new`；失败由调用方 `safeNotify` 隔离 |
| visit | notify | `publishSecurityNotification(input)` | `notifications`（`is_security=true`） | 黑名单命中、超时未离等安全类通知 | notify 直接写入并在实际插入后发送 `notification:new` |
| visit | master | `upsertReviewerRules(rules)` | `reviewer_rules` | `PUT /api/v1/reviews/assignment` 保存审核人规则 | master 在自身事务内全量替换并写审计 |
| compliance | visit | `eraseAppointmentPii(id, actorId, reason)` | `appointments`、`companions` | `POST /api/v1/privacy/appointments/:id/erase` | visit 在自身事务内清空主记录与随行人员 PII 并写审计；compliance 随后写入 `privacy_cases` |

## 现存直接跨上下文写入（债务）

| 生产上下文 | 目标上下文 | 实际语句 | 触发点 | 风险 |
|------------|------------|----------|--------|------|
| access | master | `UPDATE hosts SET department = ...` | `users.service.ts` 新增/修改 host 账号时同步部门 | 绕过 master 门面，host 审计与归属边界不完整 |
| notify | visit | `UPDATE appointments SET reminder_sent_at = now()` | `runReminderJob` 抢占到访提醒 | 绕过 visit 门面，直接修改 visit 表 |
| compliance | master | `UPDATE system_config SET config_value = ...` | `PUT /api/v1/privacy/retention` | 绕过 master 门面，需保留系统参数审计 |

除上表与门面写入矩阵外，不允许新增跨上下文 `INSERT`、`UPDATE`、`DELETE` 或 DDL。上述三项必须在后续增量中收敛为门面调用。

## 门面读取矩阵

| 消费上下文 | 目标上下文 | 实际门面导出 | 用途 |
|------------|------------|--------------|------|
| visit | access | `getUserById`、`getFirstAdminUser` | 黑名单安全通知接收人与默认管理员审核人 |
| visit | master | `getActiveVisitorTypes`、`getActiveHosts`、`getActiveGates`、`getDictionaryItems`、`getConfigNumber`、`getTimeRules`、`resolveReviewer`、`timeRuleDecision` | 表单选项、参数、时段规则、审核人解析 |
| visit | notify | `listNotificationsForVisitor`、`renderTemplate` | H5 本人通知列表与模板渲染 |
| master | access | `getUserByHostId`、`getFirstAdminUser` | 审核规则解析 host/admin 接收人 |
| compliance | visit | `getAppointmentForCompliance` | 隐私案件与本人副本所需预约摘要 |

## 直接只读 SQL 矩阵

### access

| 表 | 归属上下文 | 实际用途 | 约束 |
|----|------------|----------|------|
| `appointments` | visit | 工作台待审核、待核验、今日预约、在校数量与待办 | 仅 `SELECT` |
| `incidents` | visit | 工作台待处理异常数量与待办 | 仅 `SELECT` |
| `notifications` | notify | 工作台未读数 | 仅 `SELECT` |
| `hosts` | master | 登录与账号绑定校验；host 部门同步 | 读取为 `SELECT`；部门同步见直接写入债务 |
| `system_config` | master | 登录锁定参数与入口二维码 URL | 仅 `SELECT` |

### visit

| 表 | 归属上下文 | 实际用途 | 约束 |
|----|------------|----------|------|
| `users` | access | 黑名单命中时选择 admin/guard 安全通知接收人 | 仅 `SELECT`；其余用户解析使用 access 门面 |
| `operation_logs` | shared | 审计历史与审核日志 | 共享内核表，不属于跨上下文门面写入 |

### notify

| 表 | 归属上下文 | 实际用途 | 约束 |
|----|------------|----------|------|
| `appointments` | visit | 到访提醒候选、超时未离候选、提醒抢占 | 读取为 `SELECT`；`reminder_sent_at` 更新见直接写入债务 |
| `users` | access | 选择 admin/guard 安全通知接收人 | 仅 `SELECT` |
| `gates` | master | 到访提醒模板中的校门名称 | 仅 `SELECT` |

### report

| 表 | 归属上下文 | 实际用途 | 约束 |
|----|------------|----------|------|
| `appointments` | visit | 台账、在校清单、到访统计 | 仅 `SELECT` |
| `visitor_types` | master | 台账与统计的访客类型维度 | 仅 `SELECT` |
| `hosts` | master | 台账中的被访人姓名 | 仅 `SELECT` |
| `incidents` | visit | 异常统计与超时未离计数 | 仅 `SELECT` |

### compliance

| 表 | 归属上下文 | 实际用途 | 约束 |
|----|------------|----------|------|
| `appointments` | visit | 本人副本、隐私案件定位与人工清除 | 读取为 `SELECT`；清除经 visit 门面 |
| `companions` | visit | 本人副本随行人员与案件展示 | 仅 `SELECT` |
| `consent_records` | visit | 本人副本告知记录 | 仅 `SELECT` |
| `passage_records` | visit | 本人副本通行记录 | 仅 `SELECT` |
| `users` | access | 隐私案件处理人姓名 | 仅 `SELECT` |
| `system_config` | master | 隐私与审计留存期限 | 读取为 `SELECT`；更新见直接写入债务 |
| `operation_logs` | shared | 审计查询与过期清理 | 共享内核表 |

### master

`master` 的业务读写均落在自身表；审核人用户引用经 access 门面，系统参数读写落在自身 `system_config`。

## 边界规则

1. 新跨上下文写入必须调用目标上下文 `index.ts` 门面并登记到本文件。
2. 新代码不得扩大“现存直接跨上下文写入（债务）”表；发现调用点应改为门面。
3. 跨上下文读取只允许 `SELECT` 或目标门面提供的只读函数；禁止 `INSERT`、`UPDATE`、`DELETE`、DDL 与 `SELECT ... FOR UPDATE`。
4. 禁止跨上下文外键；跨上下文引用使用软引用列与索引。
5. 禁止导入其他上下文的 `internal/`、`.service`、`.repo` 或 `domain`。
6. 对象范围判定必须使用绑定实体 id，不得以姓名、工号或手机号字符串代替。
