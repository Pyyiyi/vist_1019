# 校园访客系统 V1.0 · UI 完整性检验报告

- 日期：2026-10-19
- 对象：`docs/trace/runs/v1/issues.yaml` 全部 18 张卡
- 权威基线：`docs/trace/runs/v1/spac.md` §4（路由与页面）、§7（前端结构）、`conventions.md` 约定 10 / 12 / 13
- 结论：18 条路由全部有且仅有一张卡负责；7 张涉及界面的卡全部具备四态、逐字文案、角色可见性、交互保护、移动端与可访问性要求；本轮修复系统性缺陷 20 项，新增文案口径 20 条。

---

## 一、检验方法

逐卡执行六项检查，任一不满足即记为缺陷并回写卡片：

| 维度 | 判定标准 |
|------|----------|
| 页面覆盖 | `spac.md` §4.1 的每条路由都能在唯一一张卡的「任务」段找到创建该页面的条目 |
| 四态 | 每个取数页面显式声明加载中 `LoadingState`、加载失败 `ErrorState`（COPY-355 + COPY-356 重试）、空数据 `EmptyState`、有数据表格/图表 |
| 文案 | 页面上每个用户可见字符串都引用 `conventions.md` 的 COPY 编号，且引用逐字存在 |
| 角色 | 按钮、分区、筛选项的可见性与该端点所需的权限点一致，越权入口不得渲染 |
| 交互 | 异步提交有 `loading` 与禁用；破坏性操作经 `ConfirmDialog`；成功/失败有 Toast；深链可定位；分页变化回到第 1 页 |
| 响应式/可访问性 | H5 视口与安全区、点击区不小于 44px；后台最小宽度 1024px；图标按钮有 `aria-label`；表格列与省略/tooltip 规则完备 |

---

## 二、总览

| 指标 | 数值 |
|------|------|
| 卡片 / 故事点 / 依赖边 | 18 / 151 / 42 |
| `spac.md` §4.1 路由 | 18 |
| 页面组件（`views/<context>/*.vue`） | 20 |
| 共享组件 / 布局壳 | 7 / 2 |
| 涉及 UI 实现的卡 | 8（P0-I05、P0-I06、P1-I01…I06） |
| UI 质量闸门卡 | 1（P2-I01） |
| 引用 COPY 编号的卡 | 9 |
| `issues.yaml` 中 COPY 引用次数 | 273 |
| 本轮修复的系统性缺陷 | 20 |
| 本轮新增登记文案 | COPY-388…396、COPY-397…407，共 20 条 |

---

## 三、路由覆盖矩阵（18/18）

| 路由 | 页面 | 负责卡 | 权限可见性 | 四态 |
|------|------|--------|-----------|------|
| `/login` | `LoginPage.vue` | VIS-P1-I04 | 未登录 | 表单态 + 提交态 + 错误态 |
| `/workbench` | `WorkbenchPage.vue` | VIS-P1-I04 | admin / guard / host | ✓ |
| `/appointments` | `AppointmentsPage.vue` + `AppointmentForm.vue` | VIS-P1-I05 | admin / host | ✓ |
| `/reviews` | `ReviewsPage.vue` | VIS-P1-I05 | admin / host | ✓ |
| `/gate` | `GatePage.vue` | VIS-P1-I05 | admin / guard | ✓ |
| `/h5/apply` | `H5ApplyPage.vue` | VIS-P1-I05 | visitor（无登录） | 三步表单态 + 提交态 + 422 定位 |
| `/h5/my` | `H5MyPage.vue` | VIS-P1-I05 | visitor（令牌） | ✓ |
| `/ledger` | `LedgerPage.vue` | VIS-P1-I03 | admin / guard | ✓ |
| `/on-campus` | `OnCampusPage.vue` | VIS-P1-I03 | admin / guard | ✓ |
| `/statistics` | `StatisticsPage.vue` | VIS-P1-I03 | admin | ✓ |
| `/users` | `UsersPage.vue` | VIS-P1-I04 | admin | ✓ |
| `/master` | `MasterDataPage.vue` | VIS-P1-I01 | admin | ✓（5 个分区各自四态） |
| `/notifications` | `NotificationsPage.vue` | VIS-P1-I02 | admin / guard / host | ✓ |
| `/system/settings` | `SystemSettingsPage.vue` | VIS-P1-I01 | admin | ✓（2 个分区各自四态） |
| `/system/audit` | `AuditLogsPage.vue` | VIS-P1-I06 | admin | ✓ |
| `/system/privacy` | `PrivacyPage.vue` | VIS-P1-I06 | admin | ✓（3 个分区各自四态） |
| `/h5/privacy` | `H5PrivacyPage.vue` | VIS-P1-I06 | visitor（令牌） | ✓ |
| `/403` | `ForbiddenPage.vue` | VIS-P1-I04 | 全部登录角色 | 静态页 + 返回工作台 |

兜底路由由 `VIS-P0-I06` 负责：根级 `/:pathMatch(.*)*` 已登录跳 `/workbench`、未登录跳 `/login`；`/h5/:pathMatch(.*)*` 跳 `/h5/apply`。不存在无主页面，也不存在两张卡重复创建同一页面。

---

## 四、系统性缺陷与处理

### U1 页面文件名与 `spac.md` 目录树不一致
卡内曾使用 `MasterPage.vue`、`NotificationPage.vue`、`AppointmentPage.vue`、`ReviewPage.vue`、`AuditLogPage.vue`，与架构目录树的 `MasterDataPage.vue`、`NotificationsPage.vue`、`AppointmentsPage.vue`、`ReviewsPage.vue`、`AuditLogsPage.vue` 冲突。全部改为目录树名称，`spac.md` 补入 `ForbiddenPage.vue` 与 `ChangePasswordDialog.vue`。

### U2 共享四态组件存在但无人使用
`LoadingState` / `ErrorState` 在 P0-I05 建成，P1 页面卡却只写「加载数据」「空态」。在 P1-I01…I06 的每个取数任务中显式写入四态，并指明 COPY-355 / COPY-356 / 对应空态编号。

### U3 COPY-355 / 356 / 357 成为孤儿口径
三条文案已登记却未被任何卡片引用。P0-I05 任务 17 改为直接渲染这三条文案，P1 卡片统一引用，形成「共享组件定义 → 页面消费」的闭环。

### U4 确认框实现自相矛盾
`conventions.md` 约定 10.1 原文要求「确认框统一使用 `Modal.confirm`」，卡片却统一使用共享 `ConfirmDialog`。改为：确认框统一使用 `ConfirmDialog`（内部为 `a-modal`），必须提供 `title` 与 `content`，禁止直接调用 `Modal.confirm`；P0-I05 与 P2-I01 的验证命令把 `Modal.confirm` 计入失败命中。

### U5 工作台 KPI 与角色不一致
初稿让 guard 看到「待审核」「今日预约」，两者分别指向 guard 无权访问的 `/reviews` 与 `/appointments`。按 `spac.md` §4.2.2 改为：guard 只渲染待核验、异常待处理、在校访客；host 只渲染待审核、今日预约；每个 KPI 的落点与可见角色的权限点一致。

### U6 通知点击跳转到不存在的路由
初稿跳 `/appointments/:id`，而 §4.1 只注册 `/appointments`。改为 `/appointments?appointmentId=<business_id>`；guard 或安全类通知跳 `/gate`；`business_id` 为空时仅标为已读、不跳转。预约页在挂载时读取该参数自动打开详情抽屉，未知 id 提示 COPY-008。

### U7 终态预约仍显示改期/取消
初稿以 `OPEN_STATUSES` 判断操作列，该集合包含 `已到访(在校中)`。按 §4.2.3 改为仅 `待审核`、`已改期`、`已通过` 渲染改期/取消；`已到访(在校中)`、`已离校` 只保留「查看详情」；终态在详情底部显示 COPY-095。

### U8 H5 告知勾选的前端行为与架构相反
初稿在未勾选时禁用「下一步」，`spac.md` §4.2.6 要求提交后由服务端返回 422 再定位。改为前端不拦截，422 时提示 COPY-348、切回第二步并聚焦告知区；现场登记同口径。

### U9 H5 触摸与安全区缺失
`H5Layout.vue` 明确最大宽度 480px、吸底区使用 `env(safe-area-inset-bottom)`；H5 页面按钮与输入项点击区不小于 44×44px；后台布局最小宽度 1024px。以上写入 P0-I05、P1-I05、P1-I06 与约定 10.2。

### U10 导出缺少下载闭环
补齐：携带全部当前筛选条件、`responseType: 'blob'`、从 `Content-Disposition` 取文件名、缺失时拼 `访客台账_YYYYMMDD_HHmmss.{csv,xlsx}`、`URL.createObjectURL` + 临时 `a` 元素 + `revokeObjectURL`、导出期间按钮切 COPY-202 并禁用。

### U11 打印范围未定义
补齐：`window.print()` 前套用 `print.css`，隐藏侧边栏、顶栏、筛选栏、操作列，保留 11 列与 `.print-only`；工作台仅打印二维码卡片；打印触发提示 COPY-205。

### U12 多处用户可见文案未登记
角色显示值（管理员/门卫/被访教职工）、顶栏「退出登录」、密码显示/隐藏切换、预约详情抽屉标题、H5 个人信息说明正文、重新扫码按钮均先登记再引用：COPY-388…396。

### U13 导航菜单标题未登记
侧边栏 11 个菜单项标题此前只存在于 `navigation.ts` 描述中。登记为 COPY-397…407，P0-I06 任务 4 要求逐字引用。

### U14 操作日志改动前后无呈现规则
补齐：左右并排 JSON、键按字母序对齐、差异字段整行高亮、长值折叠前 3 行可展开、空值显示 `—`；查询按钮请求期间 `loading`。

### U15 黑名单命中可被误放行
门卫页黑名单结果只渲染「拦截放行」按钮，调用 `POST /gate/incidents`（`incident_type='黑名单命中'`）并提示 COPY-131，禁止调用 `POST /gate/admit`。该约束写入任务与验证命令。

### U16 统计图表缺少可读性设计
不引入图表库，使用原生 SVG：横轴时间、纵轴人次、按类型堆叠色块、`<title>` 提供每段数值、图例可点击隐藏/显示；空维度计数显式渲染 `0`；无数据 COPY-214。

### U17 用户页出现架构未定义的删除入口
`spac.md` §4.2.9 只定义新增、编辑、停用/启用、重置密码。卡片明确「不渲染删除按钮」；角色权限面板只读、不提供保存按钮。

### U18 403 与未知路径缺少落点
`ForbiddenPage` 使用 COPY-385/386/387，按钮跳 `/workbench`；路由守卫在角色不足时跳 `/403`；两条 catch-all 保证未知路径不出现空白页。

### U19 集成阶段没有 UI 质量闸门
P2-I01 新增「UI 质量闸门」：逐条打开 18 条路由，按本报告六维检查，结果写入 `integration-report.md`。原阶段三任务顺延编号。

### U20 约定编号引用错位
卡内曾出现「约定 1.4 Import 三档」「约定 4 认证」「约定 9 测试与验证」「约定 10 前端交互与视觉」等错位引用。按 `conventions.md` 实际目录改为：1 目录、2 中间件、3 信封、4 认证、5 权限、6 命名、7 时间、8 数据库、9 测试与验证、10 前端交互与视觉、11 审计、12 文案、13 枚举、14 配置、15 文档确定性。

---

## 五、逐卡结论

| 卡 | UI 资产 | 四态 | 文案 | 交互保护 | 角色 | 响应式/可访问性 | 结论 |
|----|---------|------|------|----------|------|-----------------|------|
| VIS-P0-I01 | 无（脚手架、health） | — | — | — | — | — | 不适用 |
| VIS-P0-I02 | 无（DDL、迁移） | — | — | — | — | — | 不适用 |
| VIS-P0-I03 | 无（后端共享内核） | — | — | — | — | — | 不适用 |
| VIS-P0-I04 | 无（认证中间件） | — | — | — | — | — | 不适用 |
| VIS-P0-I05 | 7 组件 + 2 布局 + 3 样式 | ✓ | COPY-023/024、046、280、355…360、364/365、366…376 | 异步按钮双态 | StatusTag 三 kind | 480px / 安全区 / print.css | 通过 |
| VIS-P0-I06 | 路由、守卫、导航、兜底、App.vue | — | COPY-397…407 | — | 三角色菜单过滤 | — | 通过 |
| VIS-P0-I07 | 无（装配） | — | — | — | — | — | 不适用 |
| VIS-P0-I08 | 无（种子） | — | — | — | — | — | 不适用 |
| VIS-P0-I09 | 无（契约冻结） | — | — | — | — | — | 不适用 |
| VIS-P1-I01 | `MasterDataPage.vue`、`SystemSettingsPage.vue` | 7 分区各自四态 | COPY-255…293、381…384 | ConfirmDialog + loading 禁用 | admin | 表格省略 + tooltip + aria-label | 通过 |
| VIS-P1-I02 | `NotificationsPage.vue` | ✓ | COPY-272…288 | 单条与批量均 loading 禁用 | 渠道分区仅 admin | 分页回第 1 页 | 通过 |
| VIS-P1-I03 | `LedgerPage.vue`、`OnCampusPage.vue`、`StatisticsPage.vue` | 3 页各自四态 | COPY-188…205、206/207、214 | 查询/导出 loading；打印 | guard 日期固定、导出仅 admin | SVG `<title>`、零值显式 | 通过 |
| VIS-P1-I04 | `LoginPage.vue`、`WorkbenchPage.vue`、`UsersPage.vue`、`ForbiddenPage.vue`、`ChangePasswordDialog.vue` | 3 个取数页四态 | COPY-002…004、021…049、216…241、379…393 | 提交 loading、防重复、ConfirmDialog | KPI 按角色、二维码仅 admin | 回车提交、aria-label | 通过 |
| VIS-P1-I05 | `AppointmentsPage.vue`、`AppointmentForm.vue`、`ReviewsPage.vue`、`GatePage.vue`、`H5ApplyPage.vue`、`H5MyPage.vue` | 6 页四态 | COPY-010、052…176、191…198、394 | 改期/取消/审核/核验均 loading 禁用 | 终态操作收敛、处置仅 admin、H5 公开 | 44px、安全区、三步表单 | 通过 |
| VIS-P1-I06 | `AuditLogsPage.vue`、`PrivacyPage.vue`、`H5PrivacyPage.vue` | 5 分区四态 | COPY-294…320、353、395、396 | 查询/保存/清除 loading、ConfirmDialog | admin；H5 令牌 | JSON 差异高亮、44px | 通过 |
| VIS-P2-I01 | UI 质量闸门 | 复核 18 路由 | 复核 COPY 引用 | 复核 | 复核 | 复核 | 通过 |
| VIS-P2-I02 | 无（封版归档） | — | — | — | — | — | 不适用 |
| VIS-P2-I03 | 无（状态刷新） | — | — | — | — | — | 不适用 |

---

## 六、文案登记变更

### 6.1 本轮新增

| 编号 | 场景 | 逐字文案 |
|------|------|----------|
| COPY-388 | 角色显示值 · 管理员 | 管理员 |
| COPY-389 | 角色显示值 · 门卫 | 门卫 |
| COPY-390 | 角色显示值 · 被访教职工 | 被访教职工 |
| COPY-391 | 顶栏菜单 · 退出登录 | 退出登录 |
| COPY-392 | 密码显示切换 · 显示密码 | 显示密码 |
| COPY-393 | 密码显示切换 · 隐藏密码 | 隐藏密码 |
| COPY-394 | 预约详情抽屉标题 | 预约详情 |
| COPY-395 | 个人信息说明正文 | 系统收集您的姓名、手机号、证件号及随行人员信息，仅用于本次来访登记与校园安全管理，并按留存期限处理；超过留存期限后，界面与导出中的证件号显示为脱敏信息。 |
| COPY-396 | 重新扫码申请按钮 | 重新扫码申请 |
| COPY-397…407 | 导航 · 11 个菜单项 | 工作台、访客预约、被访人审核、门卫核验、访客台账、在校清单、统计分析、用户与角色、主数据、通知中心、系统管理 |

### 6.2 卡片文案表结构统一

- P0-I05、P0-I06 与 P1-I01…I06 的文案表全部含 `COPY` 列；无编号的枚举行改为引用枚举速查表条目。
- 四态行统一引用 COPY-355（失败）、COPY-356（重试）、COPY-357（加载中）、对应空态编号。

---

## 七、文档同步清单

| 文件 | 变更 |
|------|------|
| `docs/trace/runs/v1/issues.yaml` | 18 张卡的 UI 任务、文案表、验证命令；9 张卡内嵌「UI 完整性检验结论」；P1 各卡必读补齐约定 10/12 与 `spac.md` §4.2；P2-I01 新增 UI 质量闸门；阶段三任务顺延 |
| `conventions.md` | 约定 10.1 确认框改为 `ConfirmDialog` 且禁止 `Modal.confirm`；四态、表格、aria-label、H5 44px、后台 1024px、软状态颜色；新增 COPY-388…407 |
| `docs/trace/runs/v1/spac.md` | 目录树补 `ForbiddenPage.vue`、`ChangePasswordDialog.vue`；§4.1 补深链、角色差异；§4.2.2 角色 KPI；§4.2.3 操作收敛；§4.2.5 黑名单只拦截；§4.2.6 422 定位；§4.2.8 导出与打印；§4.2.9 无删除按钮 |
| `docs/knowledge/shared-kernel-api.md` | 共享组件 props/emit、`nav/icons.ts` 回退、`print.css` 规则 |
| `shared-kernel-manifest.yaml` | `LoadingState.vue`、`ErrorState.vue`、`nav/icons.ts`、`styles/print.css` 归属前端基础卡 |
| `docs/trace/runs/v1/agent_plane.md` | 新增 §十三 UI 完整性检验 |
| `docs/memory/2026-10-19.md` | 追加本轮检验结论 |

---

## 八、机械校验证据

```text
cards: 18
points: 151
edges: 42
unknown deps: []
五词禁列：全部 0 命中
```

- 18 条路由与负责卡一一对应，无重复、无遗漏。
- `issues.yaml` 中全部 `COPY-\d{3}` 引用均能在 `conventions.md` 找到定义，差集为空。
- 旧页面文件名在 `issues.yaml`、`spac.md`、`conventions.md`、`agent_plane.md` 中 0 命中（本报告 U1 作为缺陷记录保留）。
- 全部卡片通过 YAML 解析，依赖边均指向存在的卡号。

---

## 九、保留项与剩余风险

| 项 | 说明 | 处理 |
|----|------|------|
| 卡片独立性检验保留的 6 处设计性冗余 | 上游契约摘要与种子实体摘要 | 保留，判定标准见 `card-independence-audit.md` §12.4 |
| 闭包内格式契约 | `p1-contracts.md` 的字段格式 | 保留 |
| 浏览器实测 | 本报告为设计期静态检验 | 由 P2-I01 UI 质量闸门在真实浏览器逐条执行 |
| 视觉走查 | 设计令牌与组件规则已冻结，像素级效果未截图 | 由 P2-I01 记录截图清单 |
| 图表可访问性 | SVG 已要求 `<title>` 与图例交互 | 由 P2-I01 用键盘逐段验证 |
