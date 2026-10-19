# VIS-P1-I04 access 门户权限全栈卡 · 测试结果

- 执行日期：2026-10-19
- 工作区：`/root/code/symphony-workspaces/project-two/0e1f4737-cea2-497a-9e8d-41e84106c892`
- 基线：`origin/main@819a048` + 本卡工作树
- 后端运行：`http://localhost:3300/api/v1`
- 前端运行：`http://localhost:8081`

## 环境说明

系统环境的本机 `3000` 端口由 Plane Web 开发服务占用，因此运行验证使用 `3300`。`scripts/login-fixtures.sh` 通过 `BASE_URL` 覆盖默认地址：

```bash
BASE_URL=http://localhost:3300/api/v1 OUT_DIR=/tmp bash scripts/login-fixtures.sh
```

业务逻辑、路由、Cookie、CSRF 与数据库访问均使用同一实现，仅主机端口不同。

## 自动测试与构建

```text
$ cd backend && npx vitest run src/modules/access/__tests__
Test Files  2 passed (2)
Tests       10 passed (10)

$ cd frontend && npx vitest run src/views/access/__tests__/workbench.test.ts
Test Files  1 passed (1)
Tests       2 passed (2)

$ cd backend && npm run typecheck
$ cd backend && npm run build
$ cd frontend && npm run typecheck
$ cd frontend && npm run build
全部通过
```

全量后端回归使用本卡隔离数据库（临时覆盖 `vitest.setup.ts` 的数据库端口，执行后已还原）：

```text
Test Files  11 passed (11)
Tests       69 passed (69)
```

## 验收命令与原始输出摘要

### 登录夹具和身份

```text
已生成: /tmp/admin.txt /tmp/guard.txt /tmp/host.txt
admin {"code":0,"username":"admin","role":"admin"}
guard {"code":0,"username":"guard01","role":"guard"}
host  {"code":0,"username":"T001","role":"host"}
```

### 锁定、停用和密码长度

```text
wrong-1 {"code":40101,"message":"账号或密码错误，请重新输入"}
...
wrong-5 {"code":40101,"message":"密码错误次数过多，账号已锁定，请在 10 分钟后重试"}
locked-correct {"code":40101,"message":"密码错误次数过多，账号已锁定，请在 10 分钟后重试"}
db-while-locked 5|t
after-expiry {"code":0,"role":"guard"}
db-after-success 0|t

five-chars {"code":42201,"message":"密码长度不能少于 6 位","field":"password"}
six-chars {"code":0,"data":{"reset":true}}

disabled-login {"code":40101,"message":"该账号已停用，请联系管理员"}
sid-cookie-count 0
record-still-exists 1
```

### 越权、405 与自我保护

```text
guard-users {"code":40301,"message":"您没有执行该操作的权限"}
audit-before=1 audit-after=2

delete-405 {"code":40501,"message":"该数据不支持删除，请使用停用功能"}
self-409 {"code":40901,"message":"不能停用或删除当前登录账号"}
last-admin-409 {"code":40901,"message":"系统至少保留一个启用中的管理员"}
```

### 工作台和二维码

```text
host {"role":"host","todo":{"pending_review":2,"pending_verify":0,"pending_incident":0},"kpi":{"today_appointments":7,"on_campus":0},"todos":2}

download=访客入口二维码.png
png-header 89504e470d0a1a0a
decoded-default http://localhost/h5/apply
api-entry {"entry_url":"https://x.example/h5/apply","qr_prefix":"data:image/png;base64,"}
decoded-changed https://x.example/h5/apply
print-display {"sidebar":"none","header":"none","main":"none","qr":"block","pageHeader":"none"}
```

### 退出登录

```text
logout {"code":0,"message":"操作成功","data":{"logged_out":true}}
me-after {"code":40101,"message":"请先登录"}
audit 登录|38 退出登录|4
```

### 前端交互

```text
password-toggle: 显示密码 / 隐藏密码 均可切换
loadingVisible=true disabled=true loginPostCount=1
authenticatedLoginRedirect=http://localhost:8081/workbench
用户新增: posts=1 disabled=true rowVisible=true
改密成功: 自动退出 -> /login -> 新密码可重新登录
403: host 访问 /users -> 无权访问 / 您没有访问该页面的权限 / 返回工作台
```

## 14 条 TC 逐条比对

| TC | 测试点 | 已定预期 | 本次实际运行结果 | 比对结论 |
|----|--------|----------|------------------|----------|
| TC-PT-001 | 后台账号登录成功 | 200；`role=admin`；进入管理员工作台 | `admin` 登录返回 `code=0`、`role_code=admin`；浏览器进入 `/workbench`，显示全量 KPI 与二维码卡片；命令：`bash scripts/login-fixtures.sh`、`GET /auth/me`、Playwright admin walkthrough | 通过 |
| TC-PT-002 | 工号（host）登录识别身份 | 200；`role=host`；教职工工作台 | `T001` 登录返回 `role_code=host`；浏览器欢迎语“您好，李明”，显示待审核 2、今日预约 7，不显示门卫 KPI 与二维码；命令：fixture + `GET /workbench/summary` + Playwright | 通过 |
| TC-PT-003 | 连续失败 5 次锁定 10 分钟 | 第 5 次后锁定 10 分钟；锁定期正确密码 401；自动解锁；按账号计数；成功清零 | 前 4 次 COPY-002；第 5 次 COPY-004；数据库锁定中为 `5|t`；正确密码在锁定期返回 COPY-004；将 `locked_until` 回拨后成功登录，数据库恢复 `0|t`；命令：`/tmp/i04-runtime-evidence.sh` | 通过 |
| TC-PT-004 | 密码长度 <6 拒绝 | `abc12` 422 `field=password`；`abcdef` 放行 | `PUT /users/:id/password` 返回 `42201`、COPY-031、`field=password`；六位密码返回 `code=0, data.reset=true`；命令见 `i04-runtime-evidence.log` | 通过 |
| TC-PT-005 | 停用账号登录 401 | 401；不建会话；记录仍存在 | T002 停用后登录返回 COPY-003；Cookie Jar 无 `vs.sid`；数据库账号行仍为 1；恢复后状态为 `active`；命令：status API + login + psql | 通过 |
| TC-PT-007 | 访客不占后台账号体系 | 无后台入口；直接访问后台路由 403 | 数据库 `users.role_code='visitor'` 为 0；未登录 `/users` 返回 COPY-001，host 访问返回 COPY-005；导航无 visitor 角色；浏览器 host 访问 `/users` 显示 403 页 | 通过（H5 业务页由访客卡承载） |
| TC-PT-008 | 角色工作台路由 | admin/guard/host 各自工作台；visitor→H5 | `/workbench/summary` 返回 `admin/guard/host` 对应聚合；浏览器分别验证管理员全量、门卫仅待核验/异常/在校、教职工待审核/今日预约；visitor 无后台账号 | 通过 |
| TC-PT-009 | 非授权角色访问受限模块 403 | 导航不显示；接口 403；写越权审计 | guard 导航无用户与角色；`GET /users` 返回 COPY-005；`越权拦截` 审计由 1 增至 2；命令：guard fixture + psql | 通过 |
| TC-PT-010 | 我的待办聚合与跳转 | 待审核、待核验、异常待处理徽标；处理后递减；跳 AT/GV/GV | host 聚合为待审核 2、待办 2；admin 为 3/2/1；组件测试验证五张 KPI 的点击目标依次为 `/reviews`、`/gate`、`/gate`、`/appointments`、`/on-campus`；下游业务页不在本卡分支内 | 通过（API + 组件目标；联调由 visit 卡验收） |
| TC-PT-013 | 生成/下载/打印入口二维码 | PNG 文件头 `\x89PNG`；解码=入口 URL；打印含同一码 | PNG 前 8 字节 `89504e470d0a1a0a`；jsQR 解码默认值为 `http://localhost/h5/apply`；浏览器下载文件名逐字 `访客入口二维码.png`；print media 下仅二维码卡片 `display=block` | 通过 |
| TC-PT-014 | 入口 URL 可配生效 | 修改后新二维码指向新 URL | 数据库改为 `https://x.example/h5/apply` 后，`/system/entry-qr` 返回新地址，PNG 解码结果逐字一致；执行后恢复默认值 | 通过 |
| TC-OR-001 | 账号开通/停用软状态 | 创建成功；DELETE 405；停用 `inactive` | 创建、编辑、列表回读均成功；DELETE 返回 405/COPY-009；停用后列表 `status=inactive`；未提供前端删除按钮 | 通过 |
| TC-OR-002 | 停用后 401、历史留痕、可恢复 | 停用 401；历史可查；恢复后登录成功 | 停用账号登录 COPY-003；账号记录保留；审计新增停用/启用记录；恢复后使用原密码登录成功 | 通过 |
| TC-OR-005 | 前端 adminOnly 仅体验层且与基线一致 | 清单与 `/users*`、`/roles*`、`/master/*`、`/system/*` 一致 | `/users` 路由与导航均仅 `admin`；后端 `/users*` 为 `access:user:manage`、`/roles*` 为 `access:role:read`、二维码为 `requireAdmin`；guard 接口 403 且写审计 | 通过 |

## 修复记录

### 1. 失败登录计数被事务回滚

- 现象：连续错误密码返回 50001；正确密码未受锁定限制。
- 根因：预期 401 在事务内抛出，导致失败计数和审计一并 ROLLBACK；锁定参数在 `CASE` 中也缺少时间类型显式转换。
- 修复文件：`backend/src/modules/access/internal/auth.service.ts`
- 回归命令：`cd backend && npx vitest run src/modules/access/__tests__`；`bash /tmp/i04-runtime-evidence.sh`

### 2. 自动发现路由的认证中间件串扰

- 现象：全量测试中 `/api/v1/ping` 与不存在路由返回 401。
- 根因：每个文件顶层 `router.use(requireAuth)` 在未命中本模块路由时仍会拦截父 Router 后续模块。
- 修复文件：`backend/src/modules/access/api/{users,roles,workbench,entry-qr}.routes.ts`
- 回归命令：`cd backend && npx vitest run src/__tests__/assembly.test.ts`

### 3. access 文案常量不在共享 MESSAGES 表

- 现象：COPY-030/031/379/380 返回空 message 或通用 409。
- 根因：共享 `MESSAGES` 仅收敛 COPY-001…013。
- 修复文件：`backend/src/modules/access/internal/copy.ts` 及 auth/users service。
- 回归命令：`npx vitest run src/modules/access/__tests__` + 运行时 curl。

## UI 走查证据

截图已生成并由 Playwright 断言：登录页、host/guard/admin 工作台、修改密码字段错误、403、用户列表、角色权限只读弹窗、新增账号 loading、登录 loading。最终截图随 PR 评论 `### Screenshots` 上传。

## 剩余风险

- 工作台待办的业务落点页面由 visit 卡提供；本卡已验证聚合、徽标和前端目标路径，跨卡页面联调需在 visit 卡复验。
- 本分支只包含 access 页面；`/reviews`、`/gate`、`/appointments`、`/on-campus` 的最终页面渲染由对应业务卡合并后联合验收。
