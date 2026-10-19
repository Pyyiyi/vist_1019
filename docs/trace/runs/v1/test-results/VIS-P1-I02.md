# VIS-P1-I02 notify 通知全栈卡 · 实际执行结果

环境：`iZbp1jdwoiyoucb8ui6cmgZ:/root/code/symphony-workspaces/project-two/775f4dc5-7114-4e0e-80e7-2631822f16c1@a0e5ec7`

隔离验证栈：Postgres 15（`127.0.0.1:55444`，临时容器 `notify-i02-db`）、后端 `127.0.0.1:3003`、前端 Vite `127.0.0.1:5175`。

## 测试用例与结果比对

| TC | 测试点 | 已定预期（摘自 output/v1.0/测试.md） | 本次实际运行结果 | 比对结论 |
|----|--------|--------------------------------------|------------------|----------|
| TC-NT-001 | 提交/审核结果/改期流转通知 | 提交→审核人；通过/拒绝→访客；改期提议→访客；确认结果→审核人 | `npx vitest run src/modules/notify/__tests__`：2 文件 12 测试通过；`publishNotification`/`publishSecurityNotification` 写入并推送 socket；模板标题与正文逐字断言通过。visit 卡调用点未在本仓库 main 上合入，本卡只验证 notify 门面与模板。 | notify 侧通过；跨卡调用点由 visit 卡验收 |
| TC-NT-002 | 到访提醒＝时段起前 30 分钟 | T-30min 发 1 条；T-29min 不重复 | 插入 `visit_start=now()+10min`、`status='已通过'`、`reminder_sent_at IS NULL` 的预约；`runReminderJob()` 第一次 `reminder=1, reminderSent=true`；第二次 `reminder=1, reminderSent=true`。 | 通过 |
| TC-NT-003 | 异常提醒通知相关方 | 站内关闭时安全通知仍送达管理员/门卫；黑名单另写异常 | 插入 `visit_end=now()-2h`、`status='已到访(在校中)'` 的预约；`runOverdueJob()` 第一次生成 2 条 `超时未离`（admin/guard），第二次仍为 2 条；将 `notification_channels.站内=false` 后调用 `publishSecurityNotification`，写入行 `is_security=true` 成功。 | 通过（异常记录由 visit 卡写入，本卡只验证通知） |
| TC-NT-004 | 通知渠道双向验收 | 站内启用必达；短信/企微关闭无外发；安全类不受开关影响。**O-04**：「开启短信/企微后按渠道发送」与 PRD 冲突 | `GET /system/notification-channels` 返回 3 行；`PUT` 将短信 true 后持久化，再恢复 false；尝试 `in_app=false` 返回 422 COPY-286；无短信/企微发送器，安全通知无视站内关闭仍写入。 | 部分可达：剔除 O-04 孤儿断言「开启后按渠道发送」，保留「关闭态无外发」「安全类不受开关影响」 |
| TC-PT-011 | 消息红点与已读持久 | 未读红点；已读消失；刷新与重新登录保持 | 登录 admin 后 `unread-count=1`；`PUT /notifications/read-all` 返回 `updated=1`；再次查询 `unread_count=0`；重新登录后仍为 `0`。guard 单条已读后 `unread_count=0`。socket 发布后 `unread_count=1`。 | 通过 |
| TC-PT-012 | 消息点击进入业务对象 | 打开对应预约详情，`appointmentId` 与 `ref` 一致 | 组件测试：admin 行点击先 `PUT /notifications/:id/read`，再 `router.push('/appointments?appointmentId=appointment-1')`；guard 行点击 `router.push('/gate')`；`grep -n 'appointmentId=' frontend/src/views/notify/NotificationsPage.vue` 命中。落地页由 visit 卡实现。 | 通过；跨卡落地页由 visit 卡验收 |

## 命令与原始输出摘要

```text
cd backend && npx vitest run src/modules/notify/__tests__
✓ src/modules/notify/__tests__/notification.service.test.ts (9 tests)
✓ src/modules/notify/__tests__/templates.test.ts (3 tests)
Test Files  2 passed (2) | Tests  12 passed (12)

cd backend && npx vitest run --exclude src/shared/__tests__/seed.test.ts
Test Files  12 passed (12) | Tests  76 passed (76)

cd frontend && npx vitest run
Test Files  7 passed (7) | Tests  45 passed (45)

cd backend && npm run build        → tsc 通过
cd frontend && npm run build       → vue-tsc + vite build 通过
```

API 实测：

```text
GET  /api/v1/notifications/unread-count   → {unread_count:1}
GET  /api/v1/notifications?page=1&page_size=20 → total=1, title=黑名单人员提交预约
GET  /api/v1/system/notification-channels → [站内=true, 短信=false, 企微=false]
PUT  /api/v1/notifications/read-all       → {updated:1}
GET  /api/v1/notifications/unread-count   → {unread_count:0}
重新登录后 GET unread-count                → {unread_count:0}
guard GET /system/notification-channels    → HTTP 403 COPY-005
guard PUT /notifications/<admin-id>/read   → HTTP 403 COPY-006
PUT  /system/notification-channels {in_app:false} → HTTP 422 COPY-286
```

Socket 实测（同进程启动 app + realtime，已登录 admin 连接 `/ws`）：

```text
publishNotification → {"id":"570599de-612a-4129-9f89-401b9d4b16e1"}
notification:new   → {"id":"570599de-612a-4129-9f89-401b9d4b16e1","title":"您有一条新的访客预约","templateType":"提交通知","createdAt":"2026-10-19T13:17:27.627Z"}
unread-count       → 1
```

定时任务幂等实测：

```text
第一次 runReminderJob/runOverdueJob → {"reminder":1,"overdue":2,"reminderSent":true}
第二次 runReminderJob/runOverdueJob → {"reminder":1,"overdue":2,"reminderSent":true}
```

## 浏览器与静态检查

- Playwright 截图：`docs/memory/2026-10-19/VIS-P1-I02-notifications-admin.png`、`VIS-P1-I02-notifications-guard.png`、`VIS-P1-I02-notifications-error.png`。
- admin 页面显示通知列表、未读筛选、全部已读、渠道配置；guard 页面不渲染渠道配置。
- `grep -Rn 'alert(\|confirm(' frontend/src/views/notify` 无输出。
- `grep -rn '/visitor/notifications' backend/src frontend/src` 无输出。
- `frontend/src/layouts/AppLayout.vue` 铃铛绑定 `notificationStore.unreadCount`，`aria-label="未读消息"`；socket `notification:new` 调用 `receiveNotification`。

## 环境限制

- `src/shared/__tests__/seed.test.ts` 的 `vitest.setup.ts` 固定连接 `localhost:55432`，本工作区该端口被其他项目占用；本卡改用隔离库 `55444` 手动执行 `npm run migrate` + `npm run seed`，种子执行成功（3 条站内消息）。
- 本卡未实现 visit 卡的预约提交/审核/改期调用点、`/gate` 落地页与异常记录写入；这些属于跨卡验收项。
- O-04 孤儿断言「开启短信/企微后按渠道发送」已在 TC-NT-004 中显式剔除。
