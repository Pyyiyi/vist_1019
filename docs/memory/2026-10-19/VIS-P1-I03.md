# VIS-P1-I03 · report 台账统计全栈卡

## 交付范围

- 后端 `backend/src/modules/report/`：台账、在校清单、CSV/XLSX 导出、来访量统计、异常统计、权限路由与规则测试。
- 前端 `frontend/src/views/report/`：`/ledger`、`/on-campus`、`/statistics`、路由、权限常量、格式化函数与原生 SVG 堆叠图。
- 共享样式 `frontend/src/styles/print.css`：打印隐藏筛选栏、页面操作区与操作列。
- 依赖 `exceljs`：生成真实 XLSX。
- 验证记录：`docs/trace/runs/v1/test-results/VIS-P1-I03.md`。
- 截图：`docs/memory/2026-10-19/i03-screenshots/`。

## 关键实现

- API 边界保持 snake_case：`visit_start`、`visit_end`、`visitor_id_no_masked`、`timeout_count`；内部 DTO 与前端使用 camelCase。
- 台账默认 20、上限 100、`visit_start DESC, appoint_no DESC`；空结果保持 HTTP 200 与 `{items: [], total: 0}`。
- guard 数据范围由服务端强制覆盖为 Asia/Shanghai 当日，不能通过 query 绕过；host/visitor 无权限点，返回 403。
- 非 admin 使用 `id_no` 查询时返回 COPY-208，并写入 `越权拦截` 审计；管理员精确检索仍只回显 `maskIdNo` 结果。
- CSV 与 XLSX 共用一个 11 列常量与同一行映射；CSV 带 UTF-8 BOM，XLSX 由 exceljs 生成并带 `PK\x03\x04`；零行仍生成表头。
- 导出文件名使用 `访客台账_YYYYMMDD_HHmmss.{csv,xlsx}`，同时设置 RFC 5987 `filename*`，前端从 Content-Disposition 读取并在缺失时回退拼接。
- 统计仅纳入 `ATTENDED_STATUSES`，按 `people_count` 求和、按上海本地 `visit_start` 分日/周/月；后端补齐全部周期 × 访客类型组合，缺失维度显式返回 0。
- 异常统计固定输出 4 类并补 0；超时未离直接按 `status='已到访(在校中)' AND visit_end + 60 分钟 < now()` 计算。
- 前端三页共用 LoadingState / ErrorState COPY-355+COPY-356 / EmptyState / 数据态；统计图使用原生 SVG，不引入图表库，图例可隐藏类型，`<title>` 提供每段数值。
- guard 的到访日期固定当日且禁用；导出与打印入口仅 admin 渲染；导出/打印期间按钮 loading 并禁用。

## 验证摘要

```text
backend report tests: 12 passed
mask + report tests:  20 passed
backend full:         93 passed (post-merge)
frontend full:        45 passed (post-merge)
backend typecheck:    passed
backend build:        passed
frontend build:       passed
```

运行验证：

- seed 台账 11 条；`page_size=101` 截断为 100；空查询返回空页结构。
- 10,000 条临时数据连续 10 次查询：最大 51.5ms、中位数 26.5ms，均 HTTP 200；临时数据已删除。
- CSV 头 `efbb bf`，XLSX 头 `504b 0304`；浏览器下载文件名匹配 `访客台账_\d{8}_\d{6}\.csv`。
- guard 请求历史日期仍只返回 D0；完整证件号返回 403 + COPY-208，审计从 0→1。
- host/visitor 请求 `/logs` 均返回 403。
- 在校清单进校入列、离校移出；连续两次进出后最终已离校不在清单，4 条通行记录保留。
- 统计日合计 4 = 数据库已到访成立集 `SUM(people_count)`；周/月空维度显式 0。
- Playwright：admin 台账 11 行、11 个掩码；打印媒体保留 11 列且隐藏侧栏/顶栏/筛选/操作列；SVG 图、图例、4 类异常与超时数可见；三页错误态与重试恢复通过。

## 环境备注

- 本机 `3000` 被 Plane Web 占用，运行验证使用后端 `3400`、前端 `8181`。
- 为隔离验证启动独立 `postgres:15-alpine` 容器与 `visi-i03-db` 数据卷；测试结束后恢复种子数据，不触碰共享数据库。
- TC-SM-005 的 O-02“隐去人像”无对应字段，按卡片要求显式剔除；其余展示层掩码与统计计入断言已实测。
