# VIS-P1-I03 report 台账统计全栈卡 · 测试结果

- 执行日期：2026-10-19
- 工作区：`/root/code/symphony-workspaces/project-two/0b8c0e07-3bf6-44b2-9a84-93d6f1cb081f`
- 基线：`origin/main@a0e5ec7` + 本卡工作树
- 后端运行：`http://localhost:3400/api/v1`
- 前端运行：`http://localhost:8181`
- 数据库：独立 PostgreSQL 15 容器 `visi-i03-db`，种子落点 D0 = 2026-10-19，共 11 条预约

## 自动测试与构建

```text
$ cd backend && npx vitest run src/modules/report/__tests__
Test Files  3 passed (3)
Tests       12 passed (12)

$ cd backend && npx vitest run src/shared/__tests__/mask.test.ts src/modules/report/__tests__
Test Files  4 passed (4)
Tests       20 passed (20)

$ cd backend && npm run typecheck && npm run build
passed

$ cd frontend && npm run build
vue-tsc --noEmit && vite build passed

$ cd backend && npx vitest run   # fresh visitor_system_test database, post-merge
Test Files  16 passed (16)
Tests       93 passed (93)

$ cd frontend && npm test           # post-merge
Test Files  7 passed (7)
Tests       45 passed (45)
```

## 环境说明

- 系统 `3000` 端口由 Plane Web 占用，因此本卡运行验证使用后端 `3400`、前端 `8181`。
- `scripts/login-fixtures.sh` 通过 `BASE_URL=http://localhost:3400/api/v1` 覆盖登录地址。
- 性能与范围测试使用独立数据库中的临时记录；每个场景结束后均删除临时记录并恢复种子状态。

## TC-LG-001 台账数据范围

- 已定预期：A1 见全校；G1 只见本地当日；H1/V1 返回 403。
- 执行命令：
  ```bash
  curl -b /tmp/i03/admin.txt 'http://localhost:3400/api/v1/logs?page_size=101'
  curl -b /tmp/i03/admin.txt 'http://localhost:3400/api/v1/logs?date_from=2026-10-18&date_to=2026-10-18'
  curl -b /tmp/i03/guard.txt 'http://localhost:3400/api/v1/logs?date_from=2026-10-18&date_to=2026-10-18'
  curl -b /tmp/i03/host.txt 'http://localhost:3400/api/v1/logs'
  # 临时 visitor 账号登录后请求 /logs，执行后删除账号
  ```
- 实际输出：
  ```text
  admin all: total=11
  admin historical fixture: total=1, names=[历史访客]
  guard with historical query: total=11, contains_historical=false, first_visit_start=2026-10-19T08:00:00.000Z
  host: HTTP 403, message=您没有执行该操作的权限
  visitor: HTTP 403, message=您没有执行该操作的权限
  ```
- 结论：通过
- 失败处理：无

## TC-LG-002 分页默认 20 上限 100、倒序

- 已定预期：默认 page=1、20 条；100 条；101 静默截断为 100；按 `visit_start` 倒序。
- 执行命令：
  ```bash
  # 临时插入 10,000 条 PERF* 记录后执行，随后删除
  curl -b /tmp/i03/admin.txt 'http://localhost:3400/api/v1/logs'
  curl -b /tmp/i03/admin.txt 'http://localhost:3400/api/v1/logs?page_size=100'
  curl -b /tmp/i03/admin.txt 'http://localhost:3400/api/v1/logs?page_size=101'
  curl -b /tmp/i03/admin.txt 'http://localhost:3400/api/v1/logs?page_size=5'
  ```
- 实际输出：
  ```text
  default: page=1, page_size=20, count=20, total=10011
  page_size=100: page_size=100, count=100, total=10011
  page_size=101: HTTP 200, page_size=100, count=100, total=10011
  order sample: 08:00, 07:00, 06:00, 06:00, 05:00; descending=true
  restored_row_count=11
  ```
- 结论：通过
- 失败处理：无

## TC-LG-003 空数据返回结构

- 已定预期：HTTP 200，`{items: [], total: 0}`，不返回 404。
- 执行命令：
  ```bash
  curl -b /tmp/i03/admin.txt 'http://localhost:3400/api/v1/logs?name=不存在的人'
  ```
- 实际输出：
  ```json
  {"code":0,"data":{"items":[],"total":0,"page":1,"page_size":20}}
  ```
- 结论：通过
- 失败处理：无

## TC-LG-004 在校清单进校入列、离校移出

- 已定预期：P2 进校后入列；刷新可查；离校后移出；下一次查询即反映。
- 执行命令：
  ```bash
  # 独立库将 P2 更新为已到访(在校中)并写进校通行记录
  curl -b /tmp/i03/admin.txt 'http://localhost:3400/api/v1/logs/on-campus'
  # 将 P2 更新为已离校并写离校通行记录，再查询
  ```
- 实际输出：
  ```text
  enter: count=2, names=[刘洋, 孙浩]
  leave: count=1, names=[孙浩]
  ```
- 结论：通过
- 失败处理：无

## TC-LG-005 在校清单按最后状态取数

- 已定预期：最后一次为已离校则不在在校清单；台账最后状态为已离校；每次进出记录保留。
- 执行命令：
  ```bash
  # P2 连续完成 进校→离校→进校→离校，并写 4 条通行记录
  curl -b /tmp/i03/admin.txt 'http://localhost:3400/api/v1/logs/on-campus'
  curl -b /tmp/i03/admin.txt 'http://localhost:3400/api/v1/logs?name=刘洋&date_from=2026-10-19&date_to=2026-10-19'
  # 查询 passage_records 并恢复 P2 原状态
  ```
- 实际输出：
  ```text
  on-campus: count=1, names=[孙浩]
  ledger: total=1, statuses=[已离校]
  passage_records: 进校:10:05, 离校:10:30, 进校:11:00, 离校:11:30
  ```
- 结论：通过
- 失败处理：无

## TC-LG-006 多条件组合检索命中

- 已定预期：返回同时满足全部条件的子集；与台账同源；停用访客类型仍可作为历史检索筛选项。
- 执行命令：
  ```bash
  curl -b /tmp/i03/admin.txt 'http://localhost:3400/api/v1/logs?name=孙浩&type=家长&host=李明&status=已到访(在校中)&date_from=2026-10-19&date_to=2026-10-19'
  # 将“家长”临时置为 inactive 后按 type=家长 检索，随后恢复 active
  ```
- 实际输出：
  ```text
  combined: total=1, visitor_name=孙浩, visitor_type=家长, host_name=李明, status=已到访(在校中)
  inactive type search: total=4, types=[家长,家长,家长,家长]
  ```
- 结论：通过
- 失败处理：无

## TC-LG-007 脱敏后仅 admin 精确命中不回显

- 已定预期：A1 命中但仍返回掩码；G1 返回 403 并写“越权拦截”审计。
- 执行命令：
  ```bash
  curl -b /tmp/i03/admin.txt 'http://localhost:3400/api/v1/logs?id_no=320101198803034566'
  before=$(psql ... "select count(*) from operation_logs where action='越权拦截'")
  curl -b /tmp/i03/guard.txt 'http://localhost:3400/api/v1/logs?id_no=320101198803034566'
  after=$(psql ... "select count(*) from operation_logs where action='越权拦截'")
  ```
- 实际输出：
  ```text
  admin: total=1, id=3201**********4566, name=韩梅
  guard: HTTP 403, message=您无权使用完整证件号检索
  audit-before=0 audit-after=1
  audit: 门卫张师傅|越权拦截|拒绝|非管理员使用完整证件号检索
  ```
- 结论：通过
- 失败处理：无

## TC-LG-008 台账 1 万条 <2s

- 已定预期：连续 10 次查询每次 <2000ms，记录最大值与中位数。
- 执行命令：
  ```bash
  for i in $(seq 1 10); do
    curl -sS -o /tmp/i03-perf-$i.json -w '%{time_total}\n' \
      -b /tmp/i03/admin.txt 'http://localhost:3400/api/v1/logs?page=1&page_size=20&date_from=2026-10-19&date_to=2026-10-19'
  done
  ```
- 实际输出：
  ```text
  row_count=10011
  0.051499, 0.018768, 0.037177, 0.021330, 0.040596,
  0.025193, 0.027770, 0.028218, 0.019030, 0.020350 seconds
  max=51.5ms, median=26.5ms, all HTTP 200
  restored_row_count=11
  ```
- 结论：通过
- 失败处理：无

## TC-LG-009 导出列固定

- 已定预期：11 列固定顺序：预约编号/姓名/访客类型/手机号/证件号(脱敏)/被访人/到访时段/进校时刻/离校时刻/状态/事由。
- 执行命令：
  ```bash
  cd backend && npx vitest run src/modules/report/__tests__/mask-export.test.ts
  ```
- 实际输出：
  ```text
  CSV header: 预约编号,姓名,访客类型,手机号,证件号,被访人,到访时段,进校时刻,离校时刻,状态,事由
  XLSX row 1 values: 11 columns, exact same order
  Tests 4 passed
  ```
- 结论：通过
- 失败处理：无

## TC-LG-010 脱敏分段掩码、导出检索同口径

- 已定预期：18 位→前 4 + 10 `*` + 后 4；8 位→前 1 + 6 `*` + 后 1；5 位→前 1 + 3 `*` + 后 1；任何情况不回显完整号码；导出与检索同口径。
- 执行命令：
  ```bash
  cd backend && npx vitest run src/shared/__tests__/mask.test.ts
  curl -b /tmp/i03/admin.txt 'http://localhost:3400/api/v1/logs?page_size=100'
  ```
- 实际输出：
  ```text
  18: 1101**********1233
  11: 3201***9880
  8:  3******9
  5:  3***0
  API raw_full_ids=[], all 11 rows returned masked IDs
  mask.test.ts: 8 passed
  ```
- 结论：通过
- 失败处理：无

## TC-LG-011 导出命名与 CSV BOM

- 已定预期：文件名 `访客台账_YYYYMMDD_HHmmss.{csv,xlsx}`；CSV `EF BB BF`；XLSX `PK\x03\x04` 且 MIME 为 xlsx。
- 执行命令：
  ```bash
  curl -D /tmp/i03-final-csv.headers -b /tmp/i03/admin.txt -o /tmp/i03-final.csv 'http://localhost:3400/api/v1/logs/export?format=csv'
  xxd -l 3 /tmp/i03-final.csv
  curl -D /tmp/i03-xlsx.headers -b /tmp/i03/admin.txt -o /tmp/i03-l.xlsx 'http://localhost:3400/api/v1/logs/export?format=xlsx'
  xxd -l 4 /tmp/i03-l.xlsx
  ```
- 实际输出：
  ```text
  Content-Disposition: attachment; filename="visitor-ledger_20261019_213225.csv"; filename*=UTF-8''%E8%AE%BF%E5%AE%A2%E5%8F%B0%E8%B4%A6_20261019_213225.csv
  CSV bytes: efbb bf
  XLSX bytes: 504b 0304
  browser download name: 访客台账_20261019_213735.csv
  零行 CSV: BOM + 仅表头，120 bytes
  零行 XLSX: PK\x03\x04，6703 bytes
  ```
- 结论：通过
- 失败处理：无

## TC-LG-012 打印沿用导出口径

- 已定预期：打印预览为 11 列固定顺序；证件号掩码与导出逐字一致。
- 执行命令：
  ```bash
  # Playwright: 打开 /ledger，切换 print media，读取计算样式和表头数量
  page.emulateMedia({ media: 'print' })
  ```
- 实际输出：
  ```text
  sidebar=none, header=none, filters=none, actionCells=none
  visibleHeaders=11
  maskedIdCells=11
  print() call count=1
  Toast=正在准备打印...
  ```
- 结论：通过
- 失败处理：无

## TC-AN-001 按日/周/月 × 类型统计

- 已定预期：返回对应粒度与类型的来访量；空维度返回 0，不返回空对象。
- 执行命令：
  ```bash
  curl -b /tmp/i03/admin.txt 'http://localhost:3400/api/v1/stats/visits?granularity=day&date_from=2026-10-19&date_to=2026-10-19'
  curl -b /tmp/i03/admin.txt 'http://localhost:3400/api/v1/stats/visits?granularity=week&type=家长&date_from=2026-10-12&date_to=2026-10-25'
  curl -b /tmp/i03/admin.txt 'http://localhost:3400/api/v1/stats/visits?granularity=month&date_from=2026-09-01&date_to=2026-10-31'
  ```
- 实际输出：
  ```text
  day: 3 type buckets, counts 家长=1, 外来人员=1, 公务来访=2
  week + 家长: 2026-10-12 count=0, 2026-10-19 count=1
  month: periods=[2026-09-01, 2026-10-01], sum=4
  zero dimension: explicit {type:家长,count:0}, not omitted
  ```
- 结论：通过
- 失败处理：无

## TC-AN-002 统计口径与台账同源（到访人次）

- 已定预期：只计状态 ∈ {已通过,已到访(在校中),已离校}；按 `people_count` 计人次；按到访日归属；与台账子集相等；台账仍列全部记录。
- 执行命令：
  ```bash
  curl -b /tmp/i03/admin.txt 'http://localhost:3400/api/v1/stats/visits?granularity=day&date_from=2026-10-19&date_to=2026-10-19'
  psql ... "select sum(people_count) from appointments where status in (...) and visit_start ..."
  curl -b /tmp/i03/admin.txt 'http://localhost:3400/api/v1/logs?page_size=100'
  ```
- 实际输出：
  ```text
  stats day sum=4
  DB attended people_count sum=4
  ledger total=11（仍返回全部状态）
  P1 待审核 people_count=2 未计入统计
  ```
- 结论：通过
- 失败处理：无

## TC-AN-003 异常统计

- 已定预期：返回 4 类异常各自数量与超时未离数量；与异常记录同源；总数相等。
- 执行命令：
  ```bash
  curl -b /tmp/i03/admin.txt 'http://localhost:3400/api/v1/stats/incidents'
  psql ... "select incident_type,count(*) from incidents group by incident_type"
  psql ... "select count(*) from appointments where status='已到访(在校中)' and visit_end + interval '60 minutes' < now()"
  ```
- 实际输出：
  ```text
  API types: 黑名单命中=1, 信息不符=1, 强行闯入=1, 超时未离=0
  API timeout_count=1
  DB incidents total=3; DB direct timeout=1
  ```
- 结论：通过
- 失败处理：无

## TC-SM-005 留存 90 天到期自动脱敏（展示层）

- 已定预期：展示层证件号掩码；底层保留、不回显；统计仍计入该记录。O-02“隐去人像”无对应字段，已显式剔除。
- 执行命令：
  ```bash
  # 插入 2026-06-01 的历史记录，证件号 320101198803034566，people_count=2
  curl -b /tmp/i03/admin.txt 'http://localhost:3400/api/v1/logs?id_no=320101198803034566&date_from=2026-06-01&date_to=2026-06-01'
  curl -b /tmp/i03/admin.txt 'http://localhost:3400/api/v1/stats/visits?granularity=month&date_from=2026-06-01&date_to=2026-06-30'
  # 删除历史临时记录
  ```
- 实际输出：
  ```text
  display: total=1, id_masked=3201**********4566
  stats June: sum=2, nonzero=[{period:2026-06-01,type:家长,count:2}]
  数据模型无肖像字段，O-02 不纳入实现或断言
  ```
- 结论：部分可达（O-02 已按要求剔除；掩码、底层保留、统计计入均通过）
- 失败处理：无；孤儿断言 O-02 不实现、不测试

## 自动化界面证据

- admin 台账：11 行、11 个掩码证件号、导出/打印可见、无 403：`docs/memory/2026-10-19/i03-screenshots/ledger-admin.png`
- 打印媒体：侧栏/顶栏/筛选栏/操作列隐藏，保留 11 列：`docs/memory/2026-10-19/i03-screenshots/ledger-print.png`
- guard 台账：日期固定当日且禁用，无导出/打印，无 403：`docs/memory/2026-10-19/i03-screenshots/ledger-guard.png`
- 在校清单：`docs/memory/2026-10-19/i03-screenshots/on-campus-admin.png`
- 统计：原生 SVG、图例、零值、4 类异常：`docs/memory/2026-10-19/i03-screenshots/statistics-admin.png`
- 三页错误态与重试恢复：`ledger-error.png`、`on-campus-error.png`、`statistics-error.png`
- host 越权页：`docs/memory/2026-10-19/i03-screenshots/ledger-host-403.png`
