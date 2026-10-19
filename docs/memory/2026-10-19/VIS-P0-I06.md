# VIS-P0-I06 · 前端路由与导航骨架卡

- 执行日期：2026-10-19
- 卡片：VIS-P0-I06（Plane `c8ad6233-7a8f-41c3-b2d9-ba2858513520`）
- 结果：完成（两阶段路由注册、根容器、全局守卫、唯一导航来源、布局选择与回归测试）

## 交付文件

- `frontend/src/components/RouterContainer.vue`
- `frontend/src/router/shared.routes.ts`
- `frontend/src/router/index.ts`
- `frontend/src/router/route-meta.d.ts`
- `frontend/src/router/__tests__/guard.test.ts`
- `frontend/src/nav/navigation.ts`
- `frontend/src/nav/__tests__/navigation.test.ts`
- `frontend/src/App.vue`
- `frontend/src/__tests__/App.test.ts`
- `frontend/src/main.ts`

## 实现摘要

- `sharedRoutes` 仅包含 `root` 与 `/h5` 两条顶级记录；根记录与 H5 记录各自包含 `:pathMatch(.*)*` 子级兜底。
- `router/index.ts` 先逐条注册共享路由，再以 `import.meta.glob('@/views/*/routes.ts', { eager: true })` 自动发现领域路由，并通过 `router.addRoute('root', record)` 挂载。
- 守卫工厂 `createAuthGuard()` 使用闭包保证 `fetchMe()` 每个应用实例只执行一次；刷新成功后保留受保护路由，登录页、403 与 H5 路由按规则豁免。
- `navigation.ts` 保持 11 个后台菜单标题逐字匹配 COPY-397…407；递归过滤会移除无可见子级的父项，14 个图标键均由 `iconMap` 解析。
- `App.vue` 按 `route.meta.layout` 在 `AppLayout`、`H5Layout` 与空布局之间选择，`main.ts` 安装 Pinia 后安装 Router。

## 验证证据

| 命令 | 结果 |
|------|------|
| `cd frontend && npx vitest run src/router/__tests__/guard.test.ts src/nav/__tests__/navigation.test.ts src/__tests__/App.test.ts` | 3 files / 17 tests 通过 |
| `cd frontend && npm run build` | 退出码 0；`vue-tsc --noEmit` 与 Vite build 通过 |
| `cd frontend && npm test` | 5 files / 35 tests 通过 |
| `grep -rn "addRoute" frontend/src/router/index.ts` | 命中 `router.addRoute('root', record)` |
| `grep -rn "menu" frontend/src/views 2>/dev/null` | 0 命中 |
| `grep -n "pathMatch" frontend/src/router/shared.routes.ts` | 根级与 H5 两条兜底均命中 |
| `grep -n "fetchMe" frontend/src/router/index.ts` | 守卫初始化调用命中 |
| `npm run dev` | Vite 5.4.21 于 `http://localhost:8080/` 正常启动；`/`、`/src/main.ts`、`/src/router/index.ts` 均返回 200 |
| `git diff --check` | 通过 |

守卫测试关键断言：

- 未登录访问 `/workbench` → `/login?redirect=/workbench`。
- 已登录访问 `/login` → `/workbench`。
- guard 角色访问 admin 路由 → `/403`。
- `/h5/apply` 未登录放行；继续导航至受保护路由时 `fetchMe()` 仍只调用一次。
- `sharedRoutes` 严格包含 2 条顶级记录，根级与 H5 各含一条 `:pathMatch(.*)*` 子级兜底。
- 刷新时 `fetchMe()` 恢复 host 会话后，`/workbench` 不被弹回登录页。
- 根级未知路径在恢复 admin 会话后落到 `/workbench`，H5 未知路径落到 `/h5/apply`。

## UI 与运行时证据

使用临时领域路由与临时页面启动真实 Vite + Headless Chromium 验证，验证后已全部删除；最终提交不包含任何业务页面。

- admin 会话打开 `/workbench`：`.app-layout` 正常渲染，菜单含 11 个顶级标题与系统管理 3 个子项。
- guard 会话打开 `/users`：跳转 `/403`；随后打开 `/workbench` 仅显示工作台、门卫核验、访客台账、在校清单、通知中心。
- 匿名会话打开 `/users`：跳转 `/login?redirect=/users`。
- 根级未知路径：admin 会话最终落到 `/workbench`。
- H5 未知路径：最终落到 `/h5/apply`。
- 390px 视口打开 `/h5/apply`：`.h5-layout` 渲染，`clientWidth=390`、`scrollWidth=390`，无横向滚动。
- 浏览器 console error 与 page error 均为 0。

截图：

- `docs/memory/2026-10-19/screenshots/vis-p0-i06-app-admin.png`
- `docs/memory/2026-10-19/screenshots/vis-p0-i06-app-guard.png`
- `docs/memory/2026-10-19/screenshots/vis-p0-i06-login-redirect.png`
- `docs/memory/2026-10-19/screenshots/vis-p0-i06-h5.png`

## 剩余风险

- 六个领域的业务页面与 `views/*/routes.ts` 尚未由各全栈卡提供；当前构建只有 `root`、两条兜底与 `/h5` 壳记录，`/login`、`/403` 及 18 条业务路由需由 access 与领域卡补齐后形成完整页面闭环。
- `package.json` 未配置 `lint` 脚本，因此全局门禁以现有 `test`、`typecheck`（包含在 build）与 Vite build 为准。
- 构建保留既有警告：主包超过 500 kB，以及 `auth.ts` 同时被静态与 `api/client.ts` 动态导入；不阻塞本卡。
- 未登录 `/auth/me` 若由后端返回 401，既有 `api/client.ts` 拦截器会先触发 `window.location.assign('/login')`，可能覆盖守卫生成的 `redirect` 查询参数；该行为属于既有客户端拦截策略，需在 access/登录联调卡以真实 401 闭环确认。
