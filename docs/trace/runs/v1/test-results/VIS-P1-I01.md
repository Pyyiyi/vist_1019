# VIS-P1-I01 master 主数据全栈卡 · 测试结果

- 执行日期：2026-10-19
- 工作区：`/root/code/symphony-workspaces/project-two/d11aab0b-8e8c-4f5e-a656-e320405b9684`
- 基线：`origin/main@a0e5ec7` + 本卡工作树
- 后端运行：`http://127.0.0.1:3300/api/v1`
- 前端运行：`http://localhost:5361`
- 数据库：隔离 PostgreSQL 15，`127.0.0.1:55442/visitor_system`

系统环境的 `3000` 端口由 Plane Web 占用，因此后端使用 `3300`；`login-fixtures.sh` 通过 `BASE_URL` 覆盖默认地址。业务逻辑、Cookie、CSRF、路由和数据库实现均未改变。

## 基线复现

改造前登录 admin 后请求新增端点：

```text
GET /api/v1/master/visitor-types -> 404 {"code":40401,"message":"要查看的记录不存在或已被删除"}
GET /api/v1/system/params    -> 404 {"code":40401,"message":"要查看的记录不存在或已被删除"}
```

改造后同一接口返回 200 与 seed 数据。

## 自动测试与构建

```text
$ cd backend && npx vitest run src/modules/master/__tests__
Test Files  2 passed (2)
Tests       8 passed (8)

$ cd backend && npm run typecheck
$ cd backend && npm run build
$ cd frontend && npm run typecheck
$ cd frontend && npm run build
全部通过

全量后端回归（临时将 vitest 测试库指向隔离端口，执行后已还原）：
Test Files  15 passed (15)
Tests       89 passed (89)
```

前端浏览器自动化通过 Playwright 执行，覆盖登录、五分区渲染、停用/启用确认、COPY-009、参数保存 loading、两页离线态、单分区空态、aria-label 与 1024px 宽度检查。

## 13 条 TC 逐条比对

| TC | 测试点 | 命令/证据 | 本次实际运行结果（原始输出摘要） | 比对结论 |
|----|--------|-----------|----------------------------------|----------|
| TC-BD-001 | 访客类型软状态停用、历史保留分类 | `PUT /master/visitor-types/:id/status`；`GET /master/visitor-types`；`select count(*) from appointments ...` | 停用返回 `HTTP 200`、`status=inactive`；活动列表只剩“外来人员、公务来访”；停用前后历史预约数均为 `4`。工单示例写 `3`，但当前 `origin/main` seed 与两侧查询均为 `4`，停用未改写历史 | 主数据侧通过；下拉与台账展示由 visit 卡联验 |
| TC-BD-002 | 黑名单两段处置、无 override | `checkBlacklist(['320101198803034566'])` | `{"hit":true,"matchedIdNos":["320101198803034566"]}`；门面只返回命中结果，没有临时放行入口 | 门面通过；预约软提示与门卫硬拦由 visit 卡验收 |
| TC-BD-003 | 黑名单命中联动 | 黑名单新增/删除审计；`operation_logs` 聚合 | 新增动作落 `新增主数据`，删除动作落 `删除黑名单`；主数据侧具备审计事务 | 主数据审计通过；通知、异常记录与门卫处置由 visit/notify 卡验收 |
| TC-BD-004 | 黑名单生命周期 | `POST /master/blacklist`、`DELETE /master/blacklist/:id`、`expireBlacklistEntries(now)`、psql 状态查询 | 删除后 `已删除|true`；到期任务返回 `expiredCount=1`，台账状态变为 `已过期`；seed 黑名单仍可命中 | 通过（master 侧） |
| TC-BD-005 | 时段规则默认可配 | seed SQL + `system_config` 查询 | `可预约|7`；`max_stay_minutes=240`；`verification_buffer_minutes=15` | 通过 |
| TC-BD-006 | 时段规则生效双向验收 | `POST /master/time-rules` 新增 10:00–11:00 禁入；运行 `time-rules.rules.test.ts`；`DELETE /master/time-rules/:id` | 新增 `HTTP 200`；规则测试 5/5 通过，10:30 命中禁入；删除 `HTTP 200`，数据库同 id 计数为 `0` | 规则判定与删除通过；提交预约返回 422 由 visit 卡联验 |
| TC-BD-007 | 禁入优先 | `npx vitest run src/modules/master/__tests__/time-rules.rules.test.ts` | 重叠时返回 `{allowed:false,reason:'deny',matchedRuleId:'deny'}`；端点相接也按重叠处理 | 通过 |
| TC-BD-008 | 校门归属与下拉来源 | `getActiveGates()`；`GET /master/gates` | 活动校门为 `["东门","南门"]` | 门面通过；`passage_records.gate_id` 写入由 visit 卡验收 |
| TC-BD-009 | 校门软状态停用不硬删 | `DELETE /master/gates/:id`；`PUT /master/gates/:id/status`；活动列表查询 | DELETE 返回 `HTTP 405`、`该数据不支持删除，请使用停用功能`；停用东门后活动列表只剩 `["南门"]`，随后恢复 | 通过 |
| TC-BD-010 | 被访人名册作为数据来源 | `getActiveHosts()`；`resolveReviewer(...)` | 活动名册为 `T002 王芳、T001 李明`；无审核规则时默认解析到被访人绑定的 host 账号 `44444444-4444-4444-8444-444444444445` | 门面通过；预约表单 `host_id` 写入由 visit 卡验收 |
| TC-BD-011 | 被访人软状态停用不硬删 | `DELETE /master/hosts/:id`；`PUT /master/hosts/:id/status`；活动列表查询 | DELETE 返回 `HTTP 405` COPY-009；停用 T001 后活动列表不含 T001；恢复后返回；重复工号返回 409 `该工号已存在，请更换` 且 `field=employee_no`，浏览器断言错误显示在工号字段下方 | 通过 |
| TC-SM-007 | 参数集中管理修改即生效 | `PUT /system/params/entry_url`；立即 `GET /system/params`；psql `system_config` | PUT 返回 `参数已保存，立即生效`；下一次 GET 与数据库均读到 `http://localhost/h5/apply-tc`；验证后恢复原值 | 主数据侧通过；二维码与留存展示由 access/compliance 卡验收 |
| TC-SM-008 | 数据字典可维护作下拉来源 | `POST /system/dictionary`；`PUT /system/dictionary/:id/status`；`getDictionaryItems(type)` / 列表查询 | 新增返回 200；停用后活动字典数量 `0`，`include_inactive=true` 可见 `tc_verify|inactive` | 通过 |

## 验收命令原始输出

```text
DELETE /master/gates/66666666-6666-4666-8666-666666666661
{"code":40501,"message":"该数据不支持删除，请使用停用功能","data":null}
HTTP:405

PUT /master/visitor-types/55555555-5555-4555-8555-555555555551/status
{"code":0,"message":"操作成功","data":{"id":"55555555-5555-4555-8555-555555555551","status":"inactive"}}
HTTP:200

GET /master/visitor-types (active)
外来人员
公务来访

seed render:
visitor-types ["家长","外来人员","公务来访"]
gates         ["东门","南门"]
hosts         ["王芳","李明"]
time-rules    7 条 07:00–18:00
blacklist     ["赵某某"]
entry_url     http://localhost/h5/apply

page size cap:
{"page":1,"page_size":100,"total":1}

native dialog grep:
(no output)
```

## UI 走查与截图

Playwright 断言结果：

```text
sectionTitles = ["访客类型","黑名单","时段规则","校门与通行点","教职工名册"]
停用确认标题/正文逐字通过；停用/启用 Toast 为“已停用/已启用”
受限删除 Toast 为“该数据不支持删除，请使用停用功能”
参数保存期间存在 `.ant-btn-loading:disabled`，成功 Toast 为“参数已保存，立即生效”
/master 断网：5 个 ErrorState + 5 个“重试”按钮；恢复后逐区回到数据态
/system/settings 断网：2 个 ErrorState + 2 个“重试”按钮
单分区空态：仅访客类型显示 1 个“暂无数据”，其他分区保持数据
1024px: scrollWidth=1024, clientWidth=1024, bodyScrollWidth=1024
所有当前渲染图标按钮的 aria-label 非空
教职工重复工号：弹窗字段下方显示“该工号已存在，请更换”
```

截图：

- `docs/trace/runs/v1/screenshots/VIS-P1-I01-master.png`
- `docs/trace/runs/v1/screenshots/VIS-P1-I01-settings.png`
- `docs/trace/runs/v1/screenshots/VIS-P1-I01-master-offline.png`
- `docs/trace/runs/v1/screenshots/VIS-P1-I01-settings-offline.png`

## 发现并修复的问题

### 1. 1024px 整页横向滚动

- 现象：浏览器宽度 1024px 时 `scrollWidth=1256`。
- 根因：`AppLayout` 的 shell/content 仍强制 `--layout-content-min-width: 1024px`，叠加 232px 侧栏。
- 修复文件：`frontend/src/layouts/AppLayout.vue`。
- 回归：Playwright 复测 `scrollWidth=1024`，宽表格在 `.ant-table` 容器内滚动。

### 2. 权限常量总数断言

- 现象：新增 master/system 细粒度权限点后认证测试仍断言旧数量。
- 根因：6 个旧 `*:manage` 权限被 23 个细粒度权限替换，期望值应为 50。
- 修复文件：`backend/src/shared/__tests__/auth.test.ts`。
- 回归：全量后端 `13 files / 77 tests` 通过。

## 剩余风险

- 预约表单、提交 422、门卫硬拦、通行记录与台账展示均由 `VIS-P1-I04` / `VIS-P1-I05` 消费，本卡只验证门面、数据与 master 页面。
- 工单验收示例写“家长历史预约为 3”，当前 `origin/main` seed 及数据库实际均为 4。此差异来自共享 seed，不应在 master 卡内改写，需在跨卡集成验收时按共享种子裁决。
