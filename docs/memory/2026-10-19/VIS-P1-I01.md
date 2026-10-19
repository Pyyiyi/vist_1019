# VIS-P1-I01 · master 主数据全栈卡

## 交付范围

- 后端 `backend/src/modules/master/`：七类主数据仓储/服务/API、时段与黑名单规则、审核人门面、事务审计、定时到期任务。
- 前端 `frontend/src/views/master/`：`/master` 五分区、`/system/settings` 参数与字典、路由、权限常量。
- 共享布局：`frontend/src/layouts/AppLayout.vue` 移除过大的内容最小宽度，保证 1024px 无整页横向滚动。
- 共享权限：新增细粒度 master/system 权限点，并允许权限资源名使用下划线。
- 追溯：`docs/trace/runs/v1/test-results/VIS-P1-I01.md` 与 4 张浏览器截图。

## 关键实现

- 访客类型、校门、教职工均使用 `active/inactive` 软状态；DELETE 固定返回 405 + COPY-009。
- 黑名单新增校验未来有效期与有效重复证件号；DELETE 软删除保留 `deleted_at`；`expireBlacklistEntries` 只把到期前仍有效的记录改为“已过期”，到期当刻仍有效。
- 时段规则使用闭区间判定：先检查禁入，再检查请求是否完整落在可预约区间内；端点相接视为重叠。
- `master/index.ts` 导出 10 个门面；`getConfig/getConfigNumber` 只转调共享 `configService`；`upsertReviewerRules` 整表替换；`resolveReviewer` 按契约层级取 `declaration_order` 最小规则，最后回退绑定 host。
- `blacklist-expire` 使用 `10 0 * * *`、`runOnStart:false`，通过 master 路由加载时执行 `index.ts` 注册。
- 参数写入继续复用 `configService.setConfig` 的事务审计与缓存失效，并补充操作人姓名与 IP。
- 前端每分区独立维护 loading/error/empty/data 四态；写操作后只刷新对应分区。所有停用/启用与危险删除统一使用 `ConfirmDialog`，受限删除直接 COPY-009 Toast。
- 黑名单分页由服务端处理，默认 20、上限 100；名称/长文本列省略并用 tooltip 展示全文；操作列固定右侧；图标按钮 32×32 且均带 aria-label。工号冲突服务端返回字段名，页面将该错误稳定显示在工号输入框下方。

## 验证摘要

```text
backend typecheck/build: passed
backend master tests:    8 passed
backend full tests:      89 passed
frontend typecheck/build: passed
browser: five sections rendered; status confirm + COPY-009; settings save loading; both pages offline retry; one-section empty; 1024px no document overflow
```

## 环境与风险

- 本机 3000 由 Plane Web 占用，运行验证使用后端 3300、前端 5361、隔离数据库 55442。
- 工单示例称家长历史预约为 3；当前共享 seed 实际为 4，停用前后保持 4，说明软状态未改写历史。
- 预约提交、门卫核验、台账检索与通知/异常联动属于 visit/notify 消费点，需在 `VIS-P1-I04` / `VIS-P1-I05` 验收。
