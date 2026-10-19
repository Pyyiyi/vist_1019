# 校园访客系统 V1.0 · 角色与权限（roles）

> 权威依据：`input/v1.0/PRD/14-V1.0需求文档PRD.md` §4；`docs/trace/runs/v1/spac.md` §3。
> 权限点格式：`context:resource:action`。访客不进入后台账号体系。

---

## 一、角色总表

| 角色码 | 显示名 | 登录标识 | 登录方式 | 默认落地页 | 数据范围 |
|--------|--------|----------|----------|-----------|----------|
| `admin` | 管理员 | 账号 | 账号 + 密码 | `/workbench` | 全校 |
| `guard` | 门卫 | 账号 | 账号 + 密码 | `/workbench` | 本地当日、现场 |
| `host` | 被访教职工 | 工号 | 工号 + 密码 | `/workbench` | 本人相关 |
| `visitor` | 访客 | 令牌 | 不可枚举令牌 | `/h5/my` | 令牌绑定预约 |

---

## 二、权限点清单（33 项）

| # | 权限点 | 名称 | admin | guard | host | visitor |
|---|--------|------|:-----:|:-----:|:----:|:-------:|
| 1 | `pt:workbench:read` | 查看工作台 | ✓ | ✓ | ✓ | — |
| 2 | `pt:qr:manage` | 管理入口二维码 | ✓ | — | — | — |
| 3 | `visit:appointment:create` | 代提预约 | ✓ | — | ✓ | — |
| 4 | `visit:appointment:read` | 查看预约 | ✓ | — | ✓ | — |
| 5 | `visit:appointment:update` | 改期预约 | ✓ | — | ✓ | — |
| 6 | `visit:appointment:cancel` | 取消预约 | ✓ | — | ✓ | — |
| 7 | `visit:review:read` | 查看审核 | ✓ | — | ✓ | — |
| 8 | `visit:review:decide` | 审核决定 | ✓ | — | ✓ | — |
| 9 | `visit:review:reschedule` | 提议改期 | ✓ | — | ✓ | — |
| 10 | `visit:gate:today:read` | 查看当日门口 | ✓ | ✓ | — | — |
| 11 | `visit:gate:verify` | 现场核验 | ✓ | ✓ | — | — |
| 12 | `visit:gate:admit` | 放行登记 | ✓ | ✓ | — | — |
| 13 | `visit:gate:depart` | 离校登记 | ✓ | ✓ | — | — |
| 14 | `visit:gate:walkin` | 现场登记 | ✓ | ✓ | — | — |
| 15 | `visit:gate:incident:report` | 上报异常 | ✓ | ✓ | — | — |
| 16 | `visit:gate:incident:dispose` | 处置异常 | ✓ | — | — | — |
| 17 | `report:ledger:read` | 查看台账 | ✓ | ✓ | — | — |
| 18 | `report:ledger:export` | 导出台账 | ✓ | — | — | — |
| 19 | `report:stats:read` | 查看统计 | ✓ | — | — | — |
| 20 | `access:user:manage` | 管理账号 | ✓ | — | — | — |
| 21 | `access:role:read` | 查看角色权限 | ✓ | — | — | — |
| 22 | `master:visitor-type:manage` | 管理访客类型 | ✓ | — | — | — |
| 23 | `master:blacklist:manage` | 管理黑名单 | ✓ | — | — | — |
| 24 | `master:time-rule:manage` | 管理时段规则 | ✓ | — | — | — |
| 25 | `master:gate:manage` | 管理校门 | ✓ | — | — | — |
| 26 | `master:host:manage` | 管理教职工名册 | ✓ | — | — | — |
| 27 | `master:reviewer-rule:manage` | 管理审核人配置 | ✓ | — | — | — |
| 28 | `notify:notification:read` | 查看站内消息 | ✓ | ✓ | ✓ | — |
| 29 | `notify:channel:manage` | 配置通知渠道 | ✓ | — | — | — |
| 30 | `system:param:manage` | 管理系统参数 | ✓ | — | — | — |
| 31 | `system:dictionary:manage` | 管理数据字典 | ✓ | — | — | — |
| 32 | `compliance:audit:read` | 查看操作日志 | ✓ | — | — | — |
| 33 | `compliance:privacy:manage` | 管理个人信息 | ✓ | — | — | — |

访客端不校验权限点，只校验令牌绑定关系。

---

## 三、对象级数据范围

### 3.1 admin

- 全部预约、审核、台账、统计、主数据、账号、日志、隐私。
- 唯一可处置异常、导出、配置渠道、管理主数据的角色。
- 精确证件号检索回显掩码，不回显完整号码。

### 3.2 guard

| 允许 | 边界 |
|------|------|
| 查看当日本地预约与进出 | `visit_start` 落在服务端本地当日 |
| 核验、放行、离校、再次进校 | 仅对 `已通过`、`已到访(在校中)`、`已离校` |
| 无预约现场登记 | 必须完成两份告知确认 |
| 上报异常 | 不能处置异常 |
| 查看台账 | 仅本地当日，证件号掩码 |

禁止：审核、改期、取消、导出、统计、主数据、账号、日志、隐私。

### 3.3 host

| 允许 | 边界 |
|------|------|
| 查看预约详情 | `host_id = 本人 host_id` 或 `reviewer_id = 本人用户 id` 或 `created_by = 本人用户 id` |
| 代提预约 | 被访人只能选择本人 |
| 审核 | `reviewer_id = 本人用户 id` |
| 改期、取消 | 本人相关且状态为 `待审核` / `已通过` / `已改期` |
| 查看审核留痕 | 本人审核的预约 |

禁止：台账、在校清单、统计、主数据、账号、系统管理、异常处置。

判定以绑定实体 id 为准，不以姓名、工号、手机号字符串匹配。

### 3.4 visitor

| 允许 | 边界 |
|------|------|
| 查看本人预约 | 令牌绑定的 `appointment_id` |
| 发起改期 | 状态为 `待审核` / `已通过` / `已改期` |
| 确认改期 | 状态为 `已改期` |
| 取消 | 状态为 `待审核` / `已通过` / `已改期` |
| 查看本人消息 | 令牌绑定预约的通知 |
| 获取本人信息副本 | 令牌绑定预约 |

禁止：查看他人预约、后台页面、主数据、统计。以 6 位短码调用详情返回 403。

---

## 四、adminOnly 端点

以下前缀只允许 `admin`。非 admin 访问返回 403 并写“越权拦截”审计：

- `/api/v1/users*`
- `/api/v1/roles*`
- `/api/v1/master/*`
- `/api/v1/system/*`
- `/api/v1/audit-logs*`
- `/api/v1/privacy/*`

例外：`/api/v1/system/entry-qr` 与 `/api/v1/system/entry-qr.png` 属于工作台二维码，权限点为 `pt:qr:manage`，只授予 admin。

---

## 五、会话与令牌

| 项 | 后台会话 | 访客令牌 |
|----|----------|----------|
| 载体 | `vs.sid` Cookie | `Authorization: Bearer` 或 `vs.visitor` Cookie |
| 存储 | `sessions` 表 | `visitor_tokens.token_hash`（SHA-256） |
| 有效期 | 8 小时 | 至绑定预约进入终态 |
| CSRF | 所有写请求需要 | 不校验 CSRF，令牌本身即凭证 |
| 失败响应 | 401 COPY-001 | 403 COPY-007 |
| 换发 | 重新登录 | 不提供 |

---

## 六、种子账号

| 角色 | 账号/工号 | 密码 | 显示名 | 绑定 |
|------|-----------|------|--------|------|
| admin | `admin` | `abc@123` | 系统管理员 | — |
| guard | `guard01` | `abc@123` | 门卫张师傅 | — |
| host | `T001` | `abc@123` | 李明 | 教务处 |
| host | `T002` | `abc@123` | 王芳 | 学生处 |

首次登录不强制改密。密码修改与管理员重置都要求 ≥6 位。

---

## 七、越权审计

任何 403 必须写一条 `operation_logs`：

| 字段 | 值 |
|------|-----|
| `action` | `越权拦截` |
| `result` | `拒绝` |
| `object_type` | 资源类型，如 `appointment`、`user`、`audit_log` |
| `object_id` | 目标 id；无目标时为 NULL |
| `user_id` / `user_name` | 当前登录用户 |
| `occurred_at` | 服务端当前时间 |
| `before_value` / `after_value` | 请求方法与路径摘要 |
| `note` | 缺失权限点或对象范围说明 |
