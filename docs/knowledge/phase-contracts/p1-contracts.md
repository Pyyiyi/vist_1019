# Phase 1 契约摘要（p1-contracts）

> 六个上下文的表与端点摘要。完整字段以 `spac.md` §5/§6 为准。
> 跨上下文调用只允许使用各上下文 `index.ts` 门面导出的符号。

---

## 一、access 上下文

### 表

使用 Phase 0 共享表：`users`、`roles`、`permissions`、`role_permissions`、`auth_types`、`sessions`。

### 端点

| 方法 | 路径 | 权限 | 响应要点 |
|------|------|------|----------|
| GET | `/auth/csrf` | 公开 | `{csrf_token}` |
| POST | `/auth/login` | 公开 | `{user}` + `vs.sid` |
| POST | `/auth/logout` | 已登录 | `{logged_out:true}` |
| GET | `/auth/me` | 已登录 | `{user}` |
| PUT | `/auth/password` | 已登录 | `{changed:true}` |
| GET | `/users` | admin | 分页 `{items,total,page,page_size}` |
| POST | `/users` | admin | 新用户 |
| PUT | `/users/:id` | admin | 更新后的用户 |
| PUT | `/users/:id/status` | admin | `{id,status}` |
| PUT | `/users/:id/password` | admin | `{reset:true}` |
| DELETE | `/users/:id` | admin | 405 COPY-009 |
| GET | `/roles` | admin | 角色列表 |
| GET | `/roles/:code/permissions` | admin | `{role,permissions[]}` |
| GET | `/workbench/summary` | 后台角色 | `{role,todo,kpi,unread_count}` |
| GET | `/system/entry-qr` | admin | `{entry_url,qr_data_url}` |
| GET | `/system/entry-qr.png` | admin | `image/png` |

### 门面

```ts
export type CurrentUser = { id: string; username: string; displayName: string; roleCode: 'admin'|'guard'|'host'; hostId: string | null };
export async function getUserById(id: string): Promise<CurrentUser | null>;
export async function getUserByHostId(hostId: string): Promise<CurrentUser | null>;
export async function getFirstAdminUser(): Promise<CurrentUser | null>;
```

---

## 二、master 上下文

### 表

`hosts`、`visitor_types`、`gates`、`blacklist_entries`、`time_rules`、`reviewer_rules`、`data_dictionary`、`system_config`。

### 端点

| 方法 | 路径 | 权限 | 说明 |
|------|------|------|------|
| GET/POST | `/master/visitor-types` | admin | 列表 / 新增 |
| PUT | `/master/visitor-types/:id` | admin | 改名 |
| PUT | `/master/visitor-types/:id/status` | admin | 停用/启用 |
| DELETE | `/master/visitor-types/:id` | admin | 405 |
| GET/POST | `/master/blacklist` | admin | 分页 / 新增 |
| DELETE | `/master/blacklist/:id` | admin | 软删除 |
| GET/POST | `/master/time-rules` | admin | 列表 / 新增 |
| DELETE | `/master/time-rules/:id` | admin | 删除即失效 |
| GET/POST | `/master/gates` | admin | 列表 / 新增 |
| PUT | `/master/gates/:id` | admin | 改名 |
| PUT | `/master/gates/:id/status` | admin | 停用/启用 |
| DELETE | `/master/gates/:id` | admin | 405 |
| GET/POST | `/master/hosts` | admin | 列表 / 新增 |
| PUT | `/master/hosts/:id` | admin | 更新 |
| PUT | `/master/hosts/:id/status` | admin | 停用/启用 |
| DELETE | `/master/hosts/:id` | admin | 405 |
| GET | `/system/params` | admin | 参数列表 |
| PUT | `/system/params/:key` | admin | 更新 |
| GET | `/system/dictionary` | admin | 字典列表 |
| POST | `/system/dictionary` | admin | 新增 |
| PUT | `/system/dictionary/:id/status` | admin | 停用/启用 |

### 门面

```ts
export type VisitorTypeDto = { id: string; name: string; status: 'active' | 'inactive' };
export type HostDto = { id: string; name: string; employeeNo: string; department: string; status: 'active' | 'inactive' };
export type GateDto = { id: string; name: string; status: 'active' | 'inactive' };
export type DictionaryItemDto = { id: string; dictType: string; dictKey: string; dictLabel: string };
export type ReviewerRuleDto = { id: string; visitorTypeId: string | null; gateId: string | null; startTime: string | null; endTime: string | null; reviewerKind: 'host' | 'admin' | 'designated'; reviewerUserId: string | null; declarationOrder: number; status: 'active' | 'inactive' };

export async function getActiveVisitorTypes(): Promise<VisitorTypeDto[]>;
export async function getActiveHosts(): Promise<HostDto[]>;
export async function getActiveGates(): Promise<GateDto[]>;
export async function getDictionaryItems(dictType: string): Promise<DictionaryItemDto[]>;
export async function getConfig(key: string): Promise<string>;
export async function getConfigNumber(key: string): Promise<number>;
export async function resolveReviewer(input: {
  visitorTypeId: string;
  expectedGateId: string | null;
  visitStart: string;
  hostId: string;
}): Promise<string | null>;
export async function upsertReviewerRules(rules: Omit<ReviewerRuleDto, 'id'>[]): Promise<ReviewerRuleDto[]>;
export async function checkBlacklist(idNos: string[]): Promise<{ hit: boolean; matchedIdNos: string[] }>;
export async function expireBlacklistEntries(now: Date): Promise<number>;
```

### 审核人解析顺序

1. 访客类型 + 校门 + 时段（`expected_gate_id` 非空且时段覆盖 `visit_start`）
2. 访客类型 + 校门（`expected_gate_id` 非空）
3. 访客类型 + 时段
4. 访客类型
5. 全局规则
6. 默认：被访人绑定的 host 账号

同层多条规则取 `declaration_order` 最小者。规则可指定 `host`、`admin`、`designated`。解析结果写入 `appointments.reviewer_id`；规则只对之后创建的预约生效。

---

## 三、notify 上下文

### 表

`notifications`、`notification_channels`。

### 端点

| 方法 | 路径 | 权限 | 说明 |
|------|------|------|------|
| GET | `/notifications` | 后台角色 | 分页，`unreadOnly` |
| GET | `/notifications/unread-count` | 后台角色 | `{unread_count}` |
| PUT | `/notifications/:id/read` | 后台角色 | 仅本人 |
| PUT | `/notifications/read-all` | 后台角色 | `{updated}` |
| GET | `/system/notification-channels` | admin | 渠道列表 |
| PUT | `/system/notification-channels` | admin | `{sms,wecom}` |

### 门面

```ts
export type PublishNotificationInput = {
  recipientType: 'user' | 'visitor';
  recipientId: string;
  recipientName: string;
  recipientPhone?: string | null;
  templateType: '提交通知' | '审核结果' | '改期提议' | '改期确认结果' | '到访提醒' | '黑名单命中' | '超时未离';
  title: string;
  content: string;
  businessType: string;
  businessId: string | null;
  isSecurity: boolean;
};
export async function publishNotification(input: PublishNotificationInput): Promise<{ id: string }>;
export async function publishSecurityNotification(input: PublishNotificationInput): Promise<{ id: string }>;
```

### 模板

| 模板 | 标题 | 正文要点 |
|------|------|----------|
| 提交通知 | 您有一条新的访客预约 | 访客 {姓名} 预约 {时段} 来访，请及时审核 |
| 审核结果 | 您的来访申请已{通过/拒绝} | 时段、被访人；拒绝时附原因 |
| 改期提议 | 被访人提议调整到访时段 | 新时段与 3 小时确认期限 |
| 改期确认结果 | 访客已确认改期 | 预约回到待审核 |
| 到访提醒 | 您的访客即将到访 | 访客、时段、校门 |
| 黑名单命中 | 黑名单人员提交预约 | 脱敏证件号、时段 |
| 超时未离 | 访客超时未离校 | 访客、进校时刻、已在校时长 |

---

## 四、visit 上下文

### 表

`appointments`、`companions`、`visit_credentials`、`passage_records`、`consent_records`、`incidents`、`appointment_status_history`、`visitor_tokens`。

### 端点

| 方法 | 路径 | 权限 | 说明 |
|------|------|------|------|
| GET | `/appointments/form-options` | admin/host | `{visitorTypes,hosts,gates,relations}` |
| GET | `/appointments` | admin/host | 分页预约 |
| POST | `/appointments` | admin/host | 代提 |
| GET | `/appointments/:id` | admin/host | 详情 + 历史 + 随行 |
| PUT | `/appointments/:id/reschedule` | admin/host | 改期 |
| PUT | `/appointments/:id/cancel` | admin/host | 取消 |
| GET | `/reviews` | admin/host | 分页待审核 |
| GET | `/reviews/:id` | admin/host | 详情 |
| POST | `/reviews/:id/approve` | admin/host | 同意 |
| POST | `/reviews/:id/reject` | admin/host | 拒绝 |
| POST | `/reviews/:id/reschedule` | admin/host | 提议改期 |
| GET | `/reviews/:id/logs` | admin/host | 审核留痕 |
| GET | `/reviews/assignment` | admin | 审核人规则 |
| PUT | `/reviews/assignment` | admin | 保存规则 |
| GET | `/gate/today` | admin/guard | 当日视图 |
| GET | `/gate/form-options` | admin/guard | 校门、异常类型、关系 |
| POST | `/gate/verify` | admin/guard | 核验 |
| POST | `/gate/admit` | admin/guard | 放行 |
| POST | `/gate/depart` | admin/guard | 离校 |
| POST | `/gate/walk-in` | admin/guard | 现场登记 |
| POST | `/gate/incidents` | admin/guard | 上报异常 |
| GET | `/gate/incidents` | admin/guard | 异常列表 |
| PUT | `/gate/incidents/:id/disposition` | admin | 处置 |
| GET | `/visitor/form-options` | 公开 | H5 表单选项 |
| POST | `/visitor/appointments` | 公开 | H5 提交 |
| GET | `/visitor/appointments` | 令牌 | 本人列表 |
| GET | `/visitor/appointments/:id` | 令牌 | 本人详情（含 `messages[]`，消息随详情返回） |
| POST | `/visitor/appointments/:id/confirm-reschedule` | 令牌 | 确认改期 |
| PUT | `/visitor/appointments/:id/reschedule` | 令牌 | 访客改期 |
| PUT | `/visitor/appointments/:id/cancel` | 令牌 | 访客取消 |

### 门面

```ts
export type AppointmentSummaryDto = {
  id: string;
  appointNo: string;
  visitorName: string | null;
  status: string;
  visitStart: string;
  visitEnd: string;
  hostId: string;
  reviewerId: string | null;
};
export async function getAppointmentForCompliance(id: string): Promise<AppointmentSummaryDto | null>;
export async function eraseAppointmentPii(id: string, actorId: string, reason: string): Promise<boolean>;
export async function expireAppointments(now: Date): Promise<number>;
export async function confirmRescheduleTimeout(now: Date): Promise<number>;
```

### 核心规则

- 状态迁移按 `conventions.md` §13.2；同状态重复操作 409。
- 防重复：主访客 `visitor_id_no`；未完结集闭区间相交；排除自身；事务内 advisory lock + 唯一索引兜底。
- 核验窗口：`[visit_start - 15min, visit_end + 15min]`。
- 黑名单：提交软提示；门卫硬拦；无 override。
- 现场登记：豁免未过期/已审核；仍过黑名单；短码立即已使用。
- 再次进校：已离校当天可回在校中，不二次核销。

---

## 五、report 上下文

### 表

无自有表；只读 `appointments`、`passage_records`、`companions`、`visitor_types`、`incidents`。

### 端点

| 方法 | 路径 | 权限 | 说明 |
|------|------|------|------|
| GET | `/logs` | admin/guard | 台账分页 |
| GET | `/logs/on-campus` | admin/guard | 在校清单 |
| GET | `/logs/export` | admin | `format=csv|xlsx` |
| GET | `/stats/visits` | admin | `granularity=day|week|month` |
| GET | `/stats/incidents` | admin | 四类异常 + 超时未离 |

### 口径

- 台账按 `visit_start DESC`。
- 证件号掩码统一 `maskIdNo`。
- 导出 11 列：预约编号、姓名、访客类型、手机号、证件号、被访人、到访时段、进校时刻、离校时刻、状态、事由。
- 统计：到访成立集；`people_count` 计人次；按本地日期归属；空维度返回 0。
- guard 只能看本地当日；非 admin 完整证件号检索 403。

---

## 六、compliance 上下文

### 表

`operation_logs`（Phase 0 共享表）、`privacy_cases`。

### 端点

| 方法 | 路径 | 权限 | 说明 |
|------|------|------|------|
| GET | `/audit-logs` | admin | 分页审计 |
| GET | `/privacy/retention` | admin | `{retentionDays,auditRetentionDays}` |
| PUT | `/privacy/retention` | admin | 更新 |
| POST | `/privacy/appointments/:id/erase` | admin | 人工清除 |
| GET | `/privacy/cases` | admin | 案件分页 |
| GET | `/visitor/privacy/copy` | 令牌 | 本人副本 |

### 规则

- 审计保留 365 天，不提供提前删除。
- 人工清除调用 visit 门面；主记录 PII 置 NULL；审计明文保留。
- 本人副本证件号掩码；“更正”不提供。
