# VIS-P0-I05 · 前端基础卡

- 执行日期：2026-10-19
- 卡片：VIS-P0-I05（Plane `9324bf50-22d1-46cf-be45-76c9ceb28fb5`）
- 结果：完成（前端 API、状态、实时、共享组件、布局与设计令牌基础设施）

## 交付文件

### API、状态与实时

- `frontend/src/api/client.ts`、`frontend/src/api/__tests__/client.test.ts`
- `frontend/src/stores/auth.ts`、`frontend/src/stores/notification.ts`
- `frontend/src/realtime/socket.ts`

### 共享组件与布局

- `frontend/src/components/PageHeader.vue`
- `frontend/src/components/StatusTag.vue`、`frontend/src/components/__tests__/StatusTag.test.ts`
- `frontend/src/components/EmptyState.vue`
- `frontend/src/components/LoadingState.vue`
- `frontend/src/components/ErrorState.vue`
- `frontend/src/components/ConfirmDialog.vue`
- `frontend/src/components/CopyButton.vue`
- `frontend/src/layouts/AppLayout.vue`、`frontend/src/layouts/H5Layout.vue`
- `frontend/src/nav/navigation.ts`、`frontend/src/nav/icons.ts`

### 样式与应用装配

- `frontend/src/styles/reset.css`
- `frontend/src/styles/tokens.css`
- `frontend/src/styles/print.css`
- `frontend/src/main.ts`、`frontend/src/App.vue`
- `frontend/index.html`、`frontend/src/env.d.ts`
- `frontend/package.json`、`frontend/package-lock.json`、`frontend/tsconfig.json`、`frontend/vite.config.ts`
- `frontend/src/__tests__/App.test.ts`、`frontend/.gitignore`

### 证据

- `docs/memory/2026-10-19/screenshots/vis-p0-i05-app.png`
- `docs/memory/2026-10-19/screenshots/vis-p0-i05-h5.png`
- `docs/memory/2026-10-19/screenshots/vis-p0-i05-logout-confirm.png`

## 验证证据

| 命令 | 结果 |
|------|------|
| `cd frontend && npm ci` | 退出码 0；按 lockfile 安装 211 packages |
| `cd frontend && npm run build` | 退出码 0；`vue-tsc --noEmit` 通过，Vite 5.4.21 转换 3280 modules |
| `cd frontend && npx vitest run src/components/__tests__ src/api/__tests__` | 2 files / 18 tests 全部通过 |
| `cd frontend && npm test` | 3 files / 19 tests 全部通过 |
| `grep -rn "alert(\|confirm(" frontend/src --include='*.vue' --include='*.ts'` | 0 命中 |
| `grep -rn "Modal.confirm" frontend/src` | 0 命中 |
| `grep -n "zh_CN\|zh-cn" frontend/src/main.ts frontend/src/App.vue` | `zh_CN` 1 处；`zh-cn` import + locale 共 2 处 |
| `ls frontend/src/components/LoadingState.vue frontend/src/components/ErrorState.vue` | 两个文件均存在 |
| `navigation.ts` 图标键与 `iconMap` 对照 | 14 个键（11 主项 + 3 子项）全部登记 |
| 业务页面/路由文件扫描 | 0 个业务页面或路由文件 |
| `git diff --check` | 通过 |

## 运行时与 UI 验证

- `npm run dev` 启动 Vite 5.4.21，监听 `http://localhost:8080/`，无启动错误。
- Headless Chromium 打开首页：`document.title` 与 `h1` 均为「校园访客系统」；侧边栏渲染 13 个可展开/可点击菜单项；console error 0、page error 0。
- 点击用户菜单与退出登录：ConfirmDialog 标题「确认退出登录」、正文「退出后需要重新输入账号和密码才能继续使用，是否退出？」、按钮「确定」「取消」逐字匹配 COPY-023/024/359/360。
- Ant Design Vue 默认会给双汉字按钮插入视觉空格；已在根 `a-config-provider` 设置 `:auto-insert-space-in-button="false"`，保证文案逐字。
- Headless Chromium 390px H5 视口：`.h5-layout` 计算后 `max-width: 480px`，页面 `scrollWidth=390`、`clientWidth=390`，无横向滚动。
- `AppLayout` 铃铛与用户菜单按钮均有 `aria-label`；`iconMap` 未登记键回退 `AppstoreOutlined`。

## 关键修正

- 基线中 `app.use(Antd, { locale })` 被 Ant Design Vue 4 类型系统拒绝；语言包改由 `App.vue` 的 `a-config-provider :locale` 提供。
- 基线 Vite 6 与 Vitest 2 携带的嵌套 Vite 5 类型冲突导致 build 失败；对齐脚手架已有的 Vite 5.4 / Vitest 3 / TypeScript 5.7 工具链。
- 恢复 Vite 开发服务器的 `/api` 与 `/ws` 代理，保留后端端口覆盖能力 `HOST_BACKEND_PORT`。
- `CopyButton` 同时显示默认文案 COPY-045 与进行中文案 COPY-357，并保留成功 COPY-046、失败 COPY-013 的 `message` 反馈。

## 剩余风险

- 本卡仅用合成响应验证深层数组键转换；真实后端响应的字段完整性由后续集成闭环卡覆盖。
- 401 清空 store 与跳转 `/login` 已实现并通过代码审阅，但本卡无可联调的后端会话端点，未做真实 401 浏览器闭环。
- Vite 构建提示主包约 1.64 MB（gzip 510.93 kB）以及 `auth.ts` 动态/静态混合导入警告；不阻塞本卡构建，后续业务路由接入后再做路由级代码分割与依赖整理。
- `npm ci` 出现两条传递依赖 engine warning（`abbrev@5`、`nopt@10` 要求更高 Node 22 补丁版本），当前 Node 22.18.0 下安装、构建、测试均通过。
