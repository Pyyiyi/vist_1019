# VIS-P1-I04 · access 门户权限全栈卡

## 交付范围

- 后端 `backend/src/modules/access/`：认证、用户、角色、工作台、入口二维码路由与服务。
- 前端 `frontend/src/views/access/`：登录、工作台、用户与角色、无权访问、修改密码弹窗、路由、权限常量。
- `frontend/src/layouts/AppLayout.vue`：顶栏增加“修改密码”和“退出登录”。
- `scripts/login-fixtures.sh`：生成 admin/guard/host 三个 Cookie Jar。
- 测试与追溯：`docs/trace/runs/v1/test-results/VIS-P1-I04.md`。

## 关键实现

- 登录用户名同时匹配 `users.username` 和 `hosts.employee_no`；登录成功重置会话，失败计数与锁定写入在事务提交后再返回 401。
- 第五次失败锁定 10 分钟，锁定期保留 `failed_login_count=5`；过期后正确密码登录清零。
- 登录、退出、改密、账号新增/停用/启用/重置密码均在事务内写审计；响应不返回 `password_hash`。
- 用户列表通过 `LEFT JOIN hosts` 返回工号与部门；host 账号绑定名册，编辑部门同步到绑定教职工。
- 自我保护返回 409 COPY-379；降级唯一启用管理员返回 409 COPY-380；DELETE 固定 405 COPY-009。
- 工作台聚合按角色过滤，host 待审核按 `host_id/reviewer_id/created_by` 归属；待核验为当日已通过且未签到。
- 二维码每次生成直接读取 `system_config.entry_url`，绕过 60 秒配置缓存；PNG 由 `qrcode` 生成。
- API 边界保持 snake_case；前端 Axios 拦截器转为 camelCase，`displayName`/`roleCode` 仅存在于前端和内部 DTO。

## 路由与认证要点

- 自动发现路由不能在各模块顶层 `router.use(requireAuth)`：未命中的模块仍会执行该中间件并拦截后续路由。认证必须绑定在具体路由上。
- 共享 `MESSAGES` 只包含 COPY-001…013；access 的 COPY-030/031/379/380 收敛在 `internal/copy.ts`。

## 验证摘要

```text
backend targeted: 10 passed
backend full:     69 passed
frontend tests:   37 passed (含工作台 KPI 2 条)
backend build:    passed
frontend build:   passed
```

运行验证：

- admin/guard/host 登录与 `/auth/me` 角色正确。
- guard `/users` 403 并新增“越权拦截”审计。
- DELETE 405、自我保护 409、唯一管理员降级 409。
- host 工作台待审核 2，登录 loading 期间仅 1 个 POST。
- PNG 文件头 `89504e47`，二维码内容可解码且随 `entry_url` 更新。
- 打印媒体仅保留二维码卡片；host 访问 `/users` 进入 403。
- 改密成功后自动退出，新密码可登录。

## 环境备注

- 本机 3000 被 Plane Web 占用，运行验证使用后端 3300、前端 8081；`login-fixtures.sh` 支持 `BASE_URL` 覆盖。
- 下游业务页面 `/reviews`、`/gate`、`/appointments`、`/on-campus` 由 visit 卡提供；本卡通过组件测试断言 KPI 点击目标，跨卡页面联调留给 visit 卡。
