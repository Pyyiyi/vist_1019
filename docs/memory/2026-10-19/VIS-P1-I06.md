# VIS-P1-I06 · compliance 审计隐私全栈卡

## 目标

交付操作日志四维查询、365 天审计留存、个人信息留存配置、人工清除、本人信息副本与隐私案件记录。

## 实现落点

- 后端：`backend/src/modules/compliance/`
  - `api/audit.routes.ts`：管理员四维审计查询与分页。
  - `api/privacy.routes.ts`：留存读取/更新、人工清除、案件分页。
  - `api/visitor-privacy.routes.ts`：访客令牌保护的本人副本。
  - `internal/audit.service.ts`：筛选归一化、SQL 查询、日志字段映射、365 天清理。
  - `internal/privacy.service.ts`：留存配置、清除调用 visit 门面、案件记录、副本组装与证件号掩码。
  - `index.ts`：门面导出与 `audit-cleanup`（`10 3 * * *`）注册。
- 前端：`frontend/src/views/compliance/`
  - `AuditLogsPage.vue`：COPY-294…306、四态、四维筛选、20 条分页、并排 JSON 差异抽屉。
  - `PrivacyPage.vue`：留存、人工清除、隐私案件三分区，COPY-307…320。
  - `H5PrivacyPage.vue`：COPY-187/395/185/186/007/396，只读副本与 44px 触控目标。
  - `routes.ts` / `permissions.ts`：后台与 H5 路由、命名权限点。

## 关键决策

- 审计查询为只读，不写入 `operation_logs`；敏感行为由业务动作写入。
- 人工清除只调用 visit 门面 `eraseAppointmentPii`，compliance 不直接写 `appointments`；清除后的 `privacy_cases` 记录由 compliance 写入。
- 留存更新在 compliance 内单独事务写入 `修改留存配置` 审计，避免共享 `setConfig` 固定写 `修改参数`。
- 审计列表展示时通过 `users.display_name` 补齐操作人显示名；原始 `user_name` 仍保留在审计表。
- 本人副本只返回掩码证件号，不提供更正接口；令牌失效返回 COPY-007。
- 审计清理固定按 365 天边界删除，不读取可修改的展示配置作为提前删除依据。

## 验证

- compliance 单测：2 文件 / 5 测试通过。
- 后端 typecheck/build 通过；前端 test 45 条、build 通过。
- 运行验证：四维查询、403 门禁、留存 90、非法 0、清理 365 边界、人工清除 NULL、audit 明文、副本掩码、浏览器截图与移动端 44px 均通过。
- 详细证据：`docs/trace/runs/v1/test-results/VIS-P1-I06.md`。

## 风险

- cron 跨日触发留给集成闭环卡；本卡已验证 handler 调用的清理函数边界。
- 现有 `views/visit/H5PrivacyPage.vue` 保留同名路径的旧占位页；Vite 路由按模块顺序加载 compliance 页面并已在浏览器实测命中。后续清理该占位页时可删除旧路由，避免重复路径。
- 共享 `configService` 的 60 秒缓存未由本卡改动；留存配置的 compliance GET 直接读库，但其它消费方读取仍受既有缓存 TTL 约束。
