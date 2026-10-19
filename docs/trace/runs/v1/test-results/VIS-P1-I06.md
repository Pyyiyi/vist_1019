# VIS-P1-I06 · compliance 审计隐私全栈卡测试结果

- 执行日期：2026-10-19
- 分支：`feature/eaea3ff3-4b13-4e26-be0f-3998ce8df732`
- 代码基线：`05bf5cc` (`origin/main`)
- 运行端口：后端 `13020`、前端 `18080`、数据库宿主端口 `55448`。本机 `3000/3001` 已由 Plane 前端占用，因此使用隔离端口执行；容器内部仍为后端 `3000`、数据库 `5432`。

## 一、自动化门禁

| 检查 | 命令 | 结果 |
|------|------|------|
| 后端类型检查 | `cd backend && npm run typecheck` | 通过，无输出错误 |
| 后端构建 | `cd backend && npm run build` | 通过 |
| compliance 单测 | `cd backend && npx vitest run src/modules/compliance/__tests__` | 通过：2 个文件、5 个测试 |
| 前端构建 | `cd frontend && npm run build` | 通过：`vue-tsc --noEmit && vite build` |
| 前端回归 | `cd frontend && npm test` | 通过：7 个文件、45 个测试 |
| 容器健康 | `docker compose ps` | `db` / `backend` / `frontend` 均运行；后端健康检查通过 |

后端单测原始摘要：

```text
✓ src/modules/compliance/__tests__/audit.rules.test.ts (3 tests)
✓ src/modules/compliance/__tests__/privacy.service.test.ts (2 tests)
Test Files  2 passed (2)
Tests       5 passed (5)
```

## 二、接口与数据库实测

### 1. 审计四维查询

先以被访人账号审核一条预约，再以管理员查询动作 `审核同意` 与当日时间范围：

```bash
bash scripts/login-fixtures.sh
curl -b host.txt -X POST -H "X-CSRF-Token: $(curl -s -b host.txt http://localhost:13020/api/v1/auth/csrf | jq -r .data.csrf_token)" http://localhost:13020/api/v1/reviews/937ef25f-c93c-49e0-a24a-2a0fb3de4687/approve
curl -G -b admin.txt --data-urlencode 'action=审核同意' --data-urlencode "date_from=$(date +%F)" http://localhost:13020/api/v1/audit-logs
```

原始输出摘要：

```json
{
  "code": 0,
  "total": 2,
  "fields": {
    "user_name": "李明",
    "occurred_at": "2026-10-19T15:18:30.754Z",
    "object_type": "appointment",
    "object_id": "937ef25f-c93c-49e0-a24a-2a0fb3de4687",
    "action": "审核同意",
    "result": "成功",
    "before_value": { "status": "待审核" },
    "after_value": { "status": "已通过" }
  }
}
```

四维组合查询（操作人、动作、对象类型、对象 ID、起止日期）返回 `total=1`，最小字段 `user_name/occurred_at/object_type/object_id/action/result/before_value/after_value` 均存在。

越权门禁：

```bash
curl -o /tmp/guard-audit.json -w '%{http_code}' -b guard.txt http://localhost:13020/api/v1/audit-logs
```

```text
403
{"code":40301,"message":"您没有执行该操作的权限","data":null}
```

### 2. 七类敏感操作可追溯

```sql
select action,result,count(*) from operation_logs
where action in (
  '审核同意','审核拒绝','放行','核验','取消预约',
  '异常上报','异常处置','越权拦截','新增预约','离校'
)
group by action,result order by action,result;
```

实测返回 10 行，覆盖审核同意、审核拒绝、放行、失败核验、取消预约、异常上报、异常处置、越权拦截、新增预约、离校。

### 3. 留存配置

```bash
curl -b admin.txt -X PUT \
  -H "X-CSRF-Token: $(curl -s -b admin.txt http://localhost:13020/api/v1/auth/csrf | jq -r .data.csrf_token)" \
  -H 'Content-Type: application/json' \
  -d '{"retention_days":90}' \
  http://localhost:13020/api/v1/privacy/retention
curl -b admin.txt http://localhost:13020/api/v1/privacy/retention
```

```text
PUT: {"code":0,"message":"留存期限已保存","data":{"retention_days":90,"audit_retention_days":365}}
GET: {"code":0,"message":"操作成功","data":{"retention_days":90,"audit_retention_days":365}}
```

非法值 `0` 返回：

```json
{"code":42201,"message":"留存期限必须是大于 0 的整数","data":null,"field":"retention_days"}
```

数据库新增审计：

```text
action=修改留存配置 | user_name=系统管理员 | object_type=system_config | object_id=privacy_retention_days
before_value={"config_value": "90"} | after_value={"config_value": "90"}
```

### 4. 365 天清理边界

写入一条 366 天前日志与一条 180 天前日志，执行 `cleanupAuditLogs(new Date(), 365)`：

```json
{"deleted":1}
```

清理后 SQL：

```text
        id        |          occurred_at
------------------+-------------------------------
 cleanup-keep-i06 | 2026-04-22 23:25:35.794679+08
(1 row)
```

366 天前记录被删除，180 天前记录仍保留；未提供提前删除接口。

### 5. 人工清除

```bash
curl -b admin.txt -X POST \
  -H "X-CSRF-Token: $(curl -s -b admin.txt http://localhost:13020/api/v1/auth/csrf | jq -r .data.csrf_token)" \
  -H 'Content-Type: application/json' \
  -d '{"reason":"本人申请"}' \
  http://localhost:13020/api/v1/privacy/appointments/88888888-8888-4888-8888-888888888805/erase
```

```json
{"code":0,"message":"个人信息已清除","data":{"erased":true}}
```

主记录 SQL：

```text
 visitor_name | visitor_phone | visitor_id_no
--------------+---------------+---------------
              |               |
(1 row)
```

审计与案件 SQL：

```text
  action  | result | before_value
----------+--------+-------------------------------------------------------------------------------------------------
 人工清除 | 成功   | {"visitor_name":"吴倩","visitor_id_no":"310101199002022349","visitor_phone":"13800138000"}

after_value={"visitor_name":null,"visitor_id_no":null,"visitor_phone":null}
case_type=人工清除 | status=已完成 | note=本人申请
```

### 6. 本人信息副本

```bash
bash scripts/visitor-fixture.sh
curl -H "Authorization: Bearer $(cat h5.token)" http://localhost:13020/api/v1/visitor/privacy/copy
```

原始输出摘要：

```json
{
  "code": 0,
  "data": {
    "appointment": {
      "visitor_name": "钱多",
      "visitor_phone": "13700137000",
      "visitor_id_no": "P179***3117",
      "visitor_id_no_masked": "P179***3117"
    },
    "appointments": [ { "appoint_no": "AP20261019019", "status": "待审核" } ],
    "consents": [ { "channel": "H5" } ]
  }
}
```

无令牌请求返回：

```text
403
{"code":40303,"message":"该申请链接已失效，请重新扫码申请","data":null}
```

### 7. 文案与边界检查

```text
grep-correction=0
grep-native-dialog=0
```

即 `grep -rn "更正" backend/src frontend/src` 与 `grep -Rn "alert(\|confirm(" frontend/src/views/compliance` 均无命中。

## 三、浏览器闭环

使用 Playwright + Chromium 在 `http://localhost:18080` 执行：

| 场景 | 实测结果 |
|------|----------|
| 管理员登录并进入 `/system/audit` | 通过，四维筛选、表格与分页可见 |
| 动作筛选“审核同意”并打开改动抽屉 | 通过，抽屉宽度 920px，left/right 两列并排，`status` 修改行黄色高亮 |
| 长值折叠/展开 | 通过，长值行出现 2 个“展开”按钮，点击后 2 个 `.json-value.expanded` 生效 |
| `/system/audit` 请求失败 | 通过，展示 COPY-355 与 COPY-356 重试按钮 |
| `/system/privacy` 留存输入 `0` | 通过，字段下方展示 COPY-353 |
| `/system/privacy` 留存输入 `90` 保存 | 通过，展示 Toast COPY-310 |
| 人工清除确认框 | 通过，COPY-316/317 逐字展示，可取消 |
| `/system/privacy` 双分区请求失败 | 通过，留存与案件分区均显示失败态/重试入口 |
| `/h5/privacy` 无有效令牌 | 通过，展示 COPY-007 与 COPY-396，按钮跳转 `/h5/apply` |
| `/h5/privacy` 有效令牌 | 通过，展示姓名、手机号、掩码证件号与预约列表 |
| H5 移动端 375px | 通过，横向溢出 `false`；三个主要按钮高度均为 `44px` |

截图：

- `docs/trace/runs/v1/screenshots/VIS-P1-I06-audit.png`
- `docs/trace/runs/v1/screenshots/VIS-P1-I06-audit-diff.png`
- `docs/trace/runs/v1/screenshots/VIS-P1-I06-audit-error.png`
- `docs/trace/runs/v1/screenshots/VIS-P1-I06-privacy.png`
- `docs/trace/runs/v1/screenshots/VIS-P1-I06-privacy-error.png`
- `docs/trace/runs/v1/screenshots/VIS-P1-I06-h5-expired.png`
- `docs/trace/runs/v1/screenshots/VIS-P1-I06-h5-copy.png`

## 四、TC 逐条比对

| TC | 测试点 | 已定预期（摘自 `output/v1.0/测试.md`） | 本次实际运行结果 | 比对结论 |
|----|--------|--------------------------------------|------------------|----------|
| TC-SM-001 | 敏感操作写日志 | 审核/放行/失败核验/取消/异常/越权拦截各新增一条，含谁/什么/何时/结果 | SQL 实测 10 个 action 均有记录，覆盖审核同意、审核拒绝、放行、`核验/失败`、取消预约、异常上报、异常处置、越权拦截、新增预约、离校；字段含操作人、对象、时间和结果 | 通过 |
| TC-SM-002 | 日志最小字段与查询维度（含明文例外） | 7 个最小字段；四维可查；before/after PII 明文保留 | `GET /audit-logs` 四维组合查询 `total=1`；返回最小字段齐全；审核日志 before/after 为明文字段值；越权 guard 请求返回 403 | 通过 |
| TC-SM-003 | 日志留存 ≥180 天 | 留存 ≥180；180 天前仍可查；不提前删除 | `audit_retention_days=365`；366 天前测试日志被清理，180 天前日志仍保留；无提前删除端点 | 通过 |
| TC-SM-006 | 人工清除＝物理删除、本人索取更正 | PII 物理删除且不可检索；审计明文保留；本人副本掩码。**O-03**：更正流程无确定接口 | 清除后 `visitor_name/visitor_phone/visitor_id_no` 三列为 NULL；`action=人工清除` 的 before 明文、after 全 NULL；副本返回 `P179***3117`。O-03“更正流程”按裁决不进入 V1.0 验收，未新增更正端点 | 通过（O-03 已显式剔除） |

## 五、O-03 处理结论

依据 `output/v1.0/孤儿测试用例.md` O-03 与 `产品裁决结论.md` ADJ-032：V1.0 只交付本人索取信息副本，不提供“更正”接口或页面入口。本卡没有新增更正端点，TC-SM-006 仅按清除、审计明文和副本三项核心断言判定。

## 六、剩余风险

- 清理任务的实际 cron 触发由集成闭环卡跨日验证；本卡已直接执行同一 handler 的清理函数，确认 365 天边界。
- 共享测试库中 `3000/8080` 被其它服务占用，本卡使用隔离端口完成运行验证；容器网络内端口与生产 compose 配置一致。
