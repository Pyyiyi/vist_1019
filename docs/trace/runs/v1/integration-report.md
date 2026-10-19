# 集成闭环报告

- 执行日期：2026-10-20
- 工作区：`/root/code/symphony-workspaces/project-two/0a42f431-9bd6-4e96-87e0-817c85a1a7af`
- 代码基线：`origin/main@ca40e90` + 本卡修复
- 运行环境：`docker compose` 三服务健康；本机端口 `3000/55432` 被并行工作区占用，本卡使用后端 `13030`、前端 `18081`、数据库 `55452`，容器内仍为 `3000/80/5432`
- 种子：`docker compose exec backend npm run seed`
- 登录夹具：`bash scripts/login-fixtures.sh`、`bash scripts/visitor-fixture.sh`
- 结论：扫描验证、可运行性验证、UI 质量闸门、缺陷自愈全部通过。

## 总览

| 检查块 | 结果 | 摘要 |
|---|---|---|
| 阶段一：扫描验证 | 阶段通过：扫描验证 | 后端类型、前端构建、两端单测、鉴权路由、健康检查全部通过 |
| 阶段二：可运行性验证 | 阶段通过：可运行性验证 | 10/10 条端到端链路通过 |
| 阶段二补充：UI 质量闸门 | 阶段通过：UI 质量闸门 | 18/18 条路由按六维检查通过，适用状态均有浏览器实测证据 |
| 阶段三：缺陷自愈 | 阶段通过：缺陷自愈 | 8 个缺陷完成现象、复现、根因、修复文件、回归记录，修复后全量复跑通过 |

## 阶段一：扫描验证

### 命令与原始输出摘要

```text
$ cd backend && npm run typecheck
exit=0

$ cd frontend && npm run build
exit=0
（仅 Vite 动态导入与 500 kB chunk 警告，无构建错误）

$ cd backend && npx vitest run
Test Files  24 passed (24)
Tests       122 passed (122)

$ cd frontend && npx vitest run
Test Files  7 passed (7)
Tests       45 passed (45)

$ curl -b admin.txt http://localhost:13030/api/v1/audit-logs
audit_auth_http=200 audit_auth_code=0

$ curl http://localhost:13030/api/v1/audit-logs
audit_unauth_http=401

$ curl -s http://localhost:13030/api/v1/health
{"code":0,"message":"操作成功","data":{"status":"ok"}}
```

后端数据库测试使用同一 compose 集群内新建的 `visitor_system_test`，执行迁移后将 `vitest.setup.ts` 临时指向测试库，测试结束立即还原；未改写业务实现。

阶段通过：扫描验证

## 阶段二：可运行性验证

### 命令与原始输出摘要

以下命令均以 `BASE=http://localhost:13030/api/v1` 执行，CSRF 取自对应 Netscape cookie jar。

| 链路 | 关键命令与结果 | 结论 |
|---|---|---|
| 7. 登录 → 工作台 | `curl -b admin.txt /auth/me`；`GET /workbench/summary` → `role=admin`，KPI、待办与未读数均渲染 | 通过 |
| 8. H5 提交 → 审核通过 | `POST /visitor/appointments` → `AP20261020009`、`待审核`；host `POST /reviews/:id/approve` → `已通过`；`notifications=2`；访客详情 `messages` 返回审核结果，正文为 `到访时段 2026-10-21 13:00–14:00，被访人 李明` | 通过 |
| 9. 核验 → 放行 → 离校 | `POST /gate/verify` → `allowed=true`；`POST /gate/admit` → `已到访(在校中)`；`POST /gate/depart` → `已离校`；台账含进校/离校时刻 | 通过 |
| 10. 现场登记 | `POST /gate/walk-in` → `AP20261020010`、`已到访(在校中)`、凭证 `已使用`、告知记录 `2` 条 | 通过 |
| 11. 改期闭环 | host 提议 → 访客确认 → host 审核；状态序列 `待审核 → 已改期 → 待审核 → 已通过`，预约号 `AP20261020011` | 通过 |
| 12. 黑名单软提示与硬拦 | H5 提交命中黑名单 → `black_hit=true`；门卫核验 → `allowed=false, reason=blacklist`；强行放行 → HTTP `409`；异常上报成功 | 通过 |
| 13. CSV / XLSX 文件头 | CSV `efbbbf`；XLSX `504b0304`；下载名匹配 `访客台账_YYYYMMDD_HHmmss.{csv,xlsx}` | 通过 |
| 14. 隐私清除 | 清除前 `赵某某|13400134000|320101198803034566`；清除后 `NULL|NULL|NULL`；审计 `before_value` 保留完整明文 | 通过 |
| 15. 统计与台账一致 | `2026-10-20` 到访成立集：统计 `7`，台账按 `已通过/已到访(在校中)/已离校` 汇总 `7` | 通过 |
| 16. 实时消息徽标 | socket.io 收到 `notification:new` 黑名单事件；管理员未读数 `8 → 9` | 通过 |

最终执行摘要：

```text
{"chain":"verify->admit->depart","appoint_no":"AP20261020009","item":{"status":"已离校","checkin_at":"2026-10-19T16:37:43.976Z","checkout_at":"2026-10-19T16:37:44.006Z"}}
{"chain":"walk-in","appoint_no":"AP20261020010","status":"已到访(在校中)","credential_status":"已使用","consents":2}
{"chain":"reschedule","appoint_no":"AP20261020011","status":"已通过","history":["待审核","已改期","待审核","已通过"]}
{"chain":"blacklist","black_hit":true,"verify_mode":"blocked","admit_http":409}
{"chain":"realtime","unread_before":8,"unread_after":9}
{"chain":"export","csv_header":"efbbbf","xlsx_header":"504b0304"}
{"chain":"privacy","before":"赵某某|13400134000|320101198803034566","after":"NULL|NULL|NULL","audit_plaintext":true}
{"chain":"stats-ledger","stats_attended":7,"ledger_attended":7}
ALL_10_CHAINS_PASS
```

阶段通过：可运行性验证

## UI 质量闸门

### 18 条路由六项检查结果

说明：数据页的“四态”包含首次加载 `LoadingState/COPY-357`、空数据 `EmptyState`、后端停止后的 `COPY-355 + COPY-356` 与重试恢复；静态页对不适用的状态明确记为不适用。

| 路由 | 四态 | 文案 | 交互 | 角色 | 响应式 | 可访问性 | 结果 |
|---|---|---|---|---|---|---|---|
| `/login` | 不适用（表单页；提交中状态实测） | 通过 | 通过（登录中禁用） | 未登录 | 通过（1024） | 通过 | 通过 |
| `/workbench` | 通过 | 通过 | 通过 | admin/guard/host | 通过（1024） | 通过 | 通过 |
| `/appointments` | 通过 | 通过 | 通过 | admin/host | 通过（1024） | 通过 | 通过 |
| `/reviews` | 通过 | 通过 | 通过 | admin/host | 通过（1024） | 通过 | 通过 |
| `/gate` | 通过 | 通过 | 通过 | admin/guard | 通过（1024） | 通过（含固定操作列与异常说明 tooltip） | 通过 |
| `/h5/apply` | 加载/错误/重试通过；空态不适用（表单） | 通过 | 通过 | visitor | 通过（375×667、320×568） | 通过（全部触控目标 ≥44×44） | 通过 |
| `/h5/my` | 通过 | 通过 | 通过 | visitor | 通过（375×667、320×568） | 通过 | 通过 |
| `/ledger` | 通过 | 通过 | 通过（导出加载禁用） | admin/guard；guard 日期固定且禁用 | 通过（1024） | 通过（固定操作列、事由 tooltip） | 通过 |
| `/on-campus` | 通过 | 通过 | 通过 | admin/guard | 通过（1024） | 通过 | 通过 |
| `/statistics` | 通过 | 通过 | 通过 | admin | 通过（1024） | 通过 | 通过 |
| `/users` | 通过 | 通过 | 通过 | admin | 通过（1024） | 通过 | 通过 |
| `/master` | 通过（五个分区） | 通过 | 通过 | admin | 通过（1024） | 通过 | 通过 |
| `/notifications` | 通过 | 通过 | 通过 | admin/guard/host；渠道配置仅 admin | 通过（1024） | 通过 | 通过 |
| `/system/settings` | 通过（两个分区） | 通过 | 通过 | admin | 通过（1024） | 通过 | 通过 |
| `/system/audit` | 通过 | 通过 | 通过 | admin | 通过（1024） | 通过（固定列与 tooltip 已覆盖文本列） | 通过 |
| `/system/privacy` | 通过 | 通过 | 通过 | admin | 通过（1024） | 通过 | 通过 |
| `/h5/privacy` | 点击取数显示 Loading；错误/重试通过；空态不适用 | 通过 | 通过（生成副本禁用） | visitor | 通过（375×667、320×568） | 通过 | 通过 |
| `/403` | 不适用（静态页） | 通过（仅“无权访问/您没有访问该页面的权限/返回工作台”） | 通过 | 全部 | 通过（1024） | 通过 | 通过 |

### 机械证据

```text
首次加载：13/13 后台数据路由与 /h5/apply、/h5/my 出现“加载中...”
/h5/privacy：点击“获取我的信息副本”后出现“加载中...”与“正在生成信息副本...”
空数据：13/13 数据路由出现 EmptyState（最小 1 个、主数据与设置页多个分区）
后端停止：13/13 后台路由、3/3 H5 路由均出现 COPY-355 + COPY-356；启动后逐分区点击“重试”，剩余错误态均为 0
文案扫描：18/18 路由无框架英文、无裸错误码/HTTP 状态码、无 null/undefined/NaN
原生弹窗：grep -rn "alert(\|confirm(\|Modal.confirm" frontend/src --include='*.vue' --include='*.ts' → 0 命中
交互样本：登录按钮“登录中...” disabled=true；导出按钮 loading=true、disabled=true
角色导航：admin 14 项、guard 5 项、host 4 项；越权直达 /appointments|/users|/gate|/statistics 均落 /403
操作可见性：admin 显示异常“处置”与通知渠道；guard/host 不渲染；guard 台账无导出且日期控件 disabled
响应式：后台 1024px 横向溢出 0；H5 375×667 与 320×568 横向溢出 0，触控目标小于 44×44 的数量 0
可访问性：分页图标按钮缺失 aria-label 0；无名图标按钮 0；操作列未固定 0；长文本未单行省略 0；异常说明与台账事由 hover tooltip 均出现完整文本
```

阶段通过：UI 质量闸门

## 阶段三：缺陷自愈

### 缺陷记录

| 编号 | 现象 | 复现命令 | 根因 | 修复文件 | 回归命令 |
|---|---|---|---|---|---|
| D1 | 审核通过后数据库有访客通知，但 H5 详情 `messages=[]` | `TOKEN=$(cat h5.token); curl -H "Authorization: Bearer $TOKEN" "$BASE/visitor/appointments/<id>" | jq '.data.messages'`；数据库同预约通知数为 2 | 通知列表仓储把 `recipient_type` 固定为 `user`，访客通知按预约 ID 存储却被用户条件过滤 | `backend/src/modules/notify/internal/notification.repo.ts`、`notification.service.ts`、`notify/index.ts`、`visit/internal/visitor.service.ts`、`notify/__tests__/notification.service.test.ts` | `cd backend && npx vitest run src/modules/notify/__tests__/notification.service.test.ts`；阶段二链路 8 |
| D2 | 23:57 现场登记返回 422“预约必须在同一天内完成” | `POST /gate/walk-in`，服务端以 `now` 生成 `now+60m` 到访窗口 | walk-in 复用普通预约的同日规则，日终立即跨日 | `backend/src/modules/visit/internal/domain/rules.ts`、`appointment.service.ts`、`gate.service.ts`、`visit/__tests__/appointment.rules.test.ts` | `cd backend && npx vitest run src/modules/visit/__tests__/appointment.rules.test.ts`；阶段二链路 10 |
| D3 | `docker compose stop backend` 后前端请求长时间挂起，无法出现 COPY-355/356 | `docker compose stop backend; curl -v http://localhost:18081/api/v1/health` | nginx `/api/` 未配置连接/读写超时，使用默认 60 秒等待 | `deploy/nginx.conf` | `docker compose stop backend; time curl --max-time 15 http://localhost:18081/api/v1/health` → 约 2.2 秒返回 504；启动后浏览器重试恢复 |
| D4 | 表格分页上一页/下一页按钮 `aria-label=null` | Playwright：`document.querySelectorAll('.ant-pagination button')` 后读取 aria-label | Ant Design Vue 分页默认图标按钮未注入可访问名称，ConfigProvider 单独配置未覆盖各表分页 | `frontend/src/utils/pagination.ts`、`frontend/src/App.vue` 及 8 个分页页面 | `cd frontend && npm run build`；浏览器读取分页按钮 aria-label 为“上一页/下一页” |
| D5 | `/gate` 异常记录表的“操作”列未固定右侧 | Playwright 读取含“操作”的表头 class，未出现 `ant-table-cell-fix-right` | `incidentColumns` 操作列遗漏 `fixed: 'right'` | `frontend/src/views/visit/GatePage.vue` | 浏览器 a11y 扫描：未固定操作列 0 |
| D6 | 异常说明、台账事由等超长文本换行，未单行省略且无 tooltip | Playwright 测量长文本单元格并 hover 检查 `.ant-tooltip` | 列定义缺少 `ellipsis`，单元格未使用单行截断与 `a-tooltip` | `frontend/src/views/visit/GatePage.vue`、`frontend/src/views/report/LedgerPage.vue` | 浏览器长文本扫描：未单行省略 0；hover 异常说明/事由均显示完整 tooltip |
| D7 | 审核结果通知正文出现“被访人 被访人” | 审核通过后读取访客详情 `messages[0].content` | 通知模板使用默认 `hostName`，审核服务未传入实际被访人姓名 | `backend/src/modules/visit/internal/review.service.ts` | 阶段二链路 8：正文为“被访人 李明” |
| D8 | `/403` 页面渲染裸 HTTP 状态码 `403` | 浏览器打开 `/403` 读取 body 首行 | 页面自行渲染 `.forbidden-code=403`，与已登记 COPY-385/386/387 不一致 | `frontend/src/views/access/ForbiddenPage.vue` | 18 路由文案扫描：findings={}；`/403` 仅渲染无权访问三要素 |

### 自愈结论

- 8 个失败项均已修复，没有以“已知偏差”收口。
- 修复后全量重跑阶段一、阶段二和 UI 质量闸门，均通过。
- 阶段一最终证据：后端 24 文件 / 122 测试、前端 7 文件 / 45 测试、鉴权路由 200/code=0、未登录 401、健康检查 code=0。
- 阶段二最终证据：`ALL_10_CHAINS_PASS`。

阶段通过：缺陷自愈

## 107 条 TC 汇总

汇总文件：[test-results/summary.md](test-results/summary.md)

| 卡片 | TC 数 | 通过 | 部分可达 | 未通过 |
|---|---:|---:|---:|---:|
| VIS-P1-I01 | 13 | 13 | 0 | 0 |
| VIS-P1-I02 | 6 | 5 | 1 | 0 |
| VIS-P1-I03 | 16 | 15 | 1 | 0 |
| VIS-P1-I04 | 14 | 14 | 0 | 0 |
| VIS-P1-I05 | 54 | 53 | 1 | 0 |
| VIS-P1-I06 | 4 | 3 | 1 | 0 |
| 合计 | 107 | 103 | 4 | 0 |

部分可达仅保留契约登记的 O-01…O-04 孤儿断言：`TC-VS-002`、`TC-NT-004`、`TC-SM-005`、`TC-SM-006`。

## 修复文件清单

```text
backend/src/modules/notify/internal/notification.repo.ts
backend/src/modules/notify/internal/notification.service.ts
backend/src/modules/notify/index.ts
backend/src/modules/notify/__tests__/notification.service.test.ts
backend/src/modules/visit/internal/visitor.service.ts
backend/src/modules/visit/internal/domain/rules.ts
backend/src/modules/visit/internal/appointment.service.ts
backend/src/modules/visit/internal/gate.service.ts
backend/src/modules/visit/internal/review.service.ts
backend/src/modules/visit/__tests__/appointment.rules.test.ts
frontend/src/utils/pagination.ts
frontend/src/App.vue
frontend/src/views/visit/AppointmentsPage.vue
frontend/src/views/visit/ReviewsPage.vue
frontend/src/views/visit/GatePage.vue
frontend/src/views/report/LedgerPage.vue
frontend/src/views/notify/NotificationsPage.vue
frontend/src/views/access/UsersPage.vue
frontend/src/views/master/MasterDataPage.vue
frontend/src/views/compliance/AuditLogsPage.vue
frontend/src/views/compliance/PrivacyPage.vue
frontend/src/views/access/ForbiddenPage.vue
deploy/nginx.conf
```

## 回归命令

```bash
cd backend && npm run typecheck
cd backend && npm run build
cd frontend && npm run build
cd backend && npx vitest run
cd frontend && npx vitest run
curl -b admin.txt http://localhost:13030/api/v1/audit-logs
curl http://localhost:13030/api/v1/audit-logs
curl -s http://localhost:13030/api/v1/health
.boss/final-phase2.sh
HOST_BACKEND_PORT=13030 npm run dev -- --port 18082
```

## 剩余风险

- 性能：TC-LG-008 在 10,011 条记录上连续 10 次查询，最大值 51.5 ms、中位数 26.5 ms，低于 2,000 ms 门槛；本次集成未重新制造 1 万条压力数据。
- 兼容性：H5 使用 Chromium headless 覆盖 375×667、320×568；iOS Safari 15+、微信内置浏览器尚未在真机实测。
- 前端体积：主 chunk 约 1.67 MB、gzip 约 524 kB，Vite 给出 chunk-size 警告，不影响本次功能验收。
- 依赖审计：`npm ci` 报告后端 6 个、前端 5 个 npm audit 问题，未在本次集成范围升级依赖。
