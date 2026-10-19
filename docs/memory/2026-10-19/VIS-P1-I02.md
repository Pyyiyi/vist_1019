# VIS-P1-I02 notify 通知全栈卡

## 交付

- 后端 `backend/src/modules/notify/`：`api/notifications.routes.ts`、`api/channels.routes.ts`、`internal/notification.service.ts`、`internal/notification.repo.ts`、`internal/domain/templates.ts`、`index.ts`。
- 迁移 `backend/db/migrations/006-notify-idempotency.sql`：超时未离按 `business_id + recipient_id + 上海日期` 唯一，保证每日每接收人幂等。
- 前端 `frontend/src/views/notify/`：`NotificationsPage.vue`、`routes.ts`、`permissions.ts`、组件测试。
- 复用共享 `useNotificationStore`、`realtime/socket.ts`、`AppLayout.vue` 铃铛；未改共享内核代码。

## 关键实现

- 四个后台端点 + 两个渠道端点，分页默认 20，`unread_only` 过滤，单条/全部已读按本人范围更新。
- 7 类模板标题逐字；到访提醒 T-30min，`UPDATE ... WHERE reminder_sent_at IS NULL` 条件更新；超时未离 `visit_end + 60min`，事务 + advisory lock + 每日唯一索引防重。
- 安全通知强制 `is_security=true` 且始终写站内；短信/企微只持久化开关，无发送器。
- 前端四态复用共享组件；标题单行省略 + tooltip；行级/批量已读有 loading 禁用；admin-only 渠道配置；按角色跳预约详情或 `/gate`。

## 验证

- notify 单测 12/12；后端全量（排除 seed 环境测试）76/76；前端全量 45/45。
- 后端/前端 `npm run build` 通过；前端 `vue-tsc` 通过。
- API：unread 1 → read-all → 0，重新登录仍 0；guard 渠道 403；站内关闭请求 422；安全通知无视站内关闭仍写入。
- Socket：`notification:new` 2 秒内到达，unread +1。
- 定时任务：reminder/overdue 连续两次执行不重复，overdue 给 admin+guard 各 1 条。
- 截图：`VIS-P1-I02-notifications-admin.png`、`VIS-P1-I02-notifications-guard.png`、`VIS-P1-I02-notifications-error.png`。

## 风险与后续

- visit 卡的预约提交/审核/改期调用点、`/gate` 落地页、异常记录写入需跨卡验收。
- issue 中的旧权限名 `notify:notification:update`、`system:channel:*` 与冻结契约冲突；实现采用 `notify:notification:read`、`notify:channel:manage`。
- `vitest.setup.ts` 固定 DB 端口 55432，导致 seed 测试在本工作区无法直接运行；已用隔离库手动 migrate/seed 替代验证。
