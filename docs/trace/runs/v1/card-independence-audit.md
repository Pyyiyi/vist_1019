# 校园访客系统 V1.0 · 卡片独立性检验

> 对象：`docs/trace/runs/v1/issues.yaml`（18 张卡、42 条依赖边、151 点）。
> 前提：每张卡由一个独立 agent 执行；信息只能沿 `blocked_by` 边传递；下游卡可读取已完成上游卡的代码与文件。
> 检验日期：2026-10-19。架构唯一真相：`docs/trace/runs/v1/spac.md`；跨卡文案与约定唯一真相：`conventions.md`。

---

## 一、检验口径

### 1.1 独立性模型

对卡片 `C`，记其**依赖闭包** `closure(C)` 为沿 `blocked_by` 递归可达的全部上游卡（不含 `C` 自身）。

- **合法信息来源**：`C` 自身的任务与验收、`closure(C)` 内的文件与代码、`spac.md` / `conventions.md` / `roles.md` / `schema-shared.sql` / `seed-anchors.sql` / `docs/knowledge/` 等全局权威文档。
- **非法信息来源**：`closure(C)` 之外的任何卡所创建的文件、端点、测试数据、执行期产物。
- **执行期产物不算代码**：上游卡执行时写入数据库的行、生成的 Cookie Jar、`test-results/*.md`，若下游卡需要，必须由下游卡在自身验证段重新生成，不能假定上游执行现场仍在。

### 1.2 两类判定

| 类型 | 定义 | 判定依据 |
|------|------|----------|
| **冗余信息** | 同一事实在卡内被重复陈述，或与权威文档重复，可能漂移但不直接导致失败 | 与 `conventions.md` / `spac.md` / 上游契约逐字比对 |
| **不正确信息** | 引用越出依赖闭包、符号/路径/表列/动作词与权威不一致、验证无法执行、前后自相矛盾 | 机械扫描 + 逐条命令推演 |

### 1.3 检验手段

1. **机械扫描**：抽取每张卡正文中的文件路径与 HTTP 端点，按「创建该文件的卡」「该端点所属上下文」映射到责任卡，若责任卡不在依赖闭包内即标记。
2. **符号比对**：卡内引用的共享内核符号与 `shared-kernel-manifest.yaml`、`docs/knowledge/shared-kernel-api.md` 的 `exports` 逐字比对。
3. **命令推演**：对每条验证命令推演「前置状态是否由本卡或闭包内产生」「中间件顺序是否会让断言命中另一个分支」。
4. **文案比对**：审计动作词、逐字提示语与 `conventions.md` 约定 11 / 约定 12 比对。

---

## 二、结果总览

| 指标 | 数值 |
|------|------|
| 卡片数 | 18 |
| 依赖边 | 42 |
| 依赖闭包平均规模 | 7.6 张卡（含零依赖根卡） |
| 闭包最大的卡 | `VIS-P2-I03`（17 张） |
| 闭包最小的卡 | `VIS-P0-I01`（0 张） |
| 跨闭包文件引用（机械扫描） | 0 |
| 跨闭包端点引用（机械扫描） | 0（修正后；修正前 9 处，均为测试断言借用） |
| 语义级发现（逐卡表） | 89 项 |
| 其中：不正确信息 | 80 项 |
| 其中：冗余信息 | 9 项 |
| 已修复 | 82 项 |
| 保留（6 处设计性冗余 + 1 处契约格式约定） | 7 项 |

> 89 项是逐卡表计数（`grep -c '^| 不正确 |'` = 80、`^| 冗余 |` = 9）；第三节的 14 类系统性根因与逐卡发现重叠，不重复计数。

> 跨闭包引用为 0 不代表卡片独立：多数缺陷属于**同一事实在两张卡各写一遍**（冗余）或**卡内引用了尚未存在的符号/表列**（不正确）。这两类不会在路径扫描中出现。

---

## 三、系统性发现

以下 14 类问题跨多张卡出现，按根因归并。逐卡明细见第四节。

| 编号 | 问题 | 类型 | 影响卡 | 处理 |
|------|------|------|--------|------|
| S1 | `psql $DATABASE_URL` 在宿主机不可用：`DATABASE_URL` 指向 compose 网络主机名 `db`，宿主机无法解析 | 不正确 | P0-I02、P0-I08、P1-I01、P1-I03、P1-I04、P1-I05、P1-I06 | 全部改为 `docker compose exec -T db psql -U visitor -d visitor_system` |
| S2 | Cookie Jar 文件名不统一：access 卡写 `a.txt` / `g.txt`，其余卡用 `admin.txt` / `guard.txt` / `host.txt` | 不正确 | P1-I01…I06、P2-I01 | access 卡新增 `scripts/login-fixtures.sh` 统一产出三个文件名；全部卡改用之 |
| S3 | 种子日期写死 `2026-10-12`，导致「当日视图 / 提醒 / 核验窗口」类验证在别的执行日必然失败 | 不正确 | P0-I08、P1-I02、P1-I03、P1-I05、P1-I06 | `seed-anchors.sql` 全部改为 `CURRENT_DATE` 相对表达式；预约编号按 `D0` 动态生成；卡片验证改用 `$(date …)` / `D1` 变量 |
| S4 | 调度器契约不确定：卡内调用 `registerJob` / `startJobs`，共享内核只导出 `startJob`；定时任务无人启动 | 不正确 | P0-I03、P0-I07、P1-I01、P1-I02、P1-I05、P1-I06 | 统一为 `registerJob` + `startJobs` + `stopAllJobs`；`JobDefinition` 改为 `cron` 字段；补 `node-cron@3` 依赖；各领域卡显式登记 |
| S5 | 写请求验证漏 `X-CSRF-Token`：按中间件顺序会先命中 403 CSRF，而非卡片期望的 405/409/200 | 不正确 | P1-I01、P1-I04、P1-I05 | 全部写命令补 CSRF 头 |
| S6 | 审计动作词与 `conventions.md` 约定 11 的 28 个规范词不一致：出现 `审核`、`失败核验`、`取消`、`异常`、`查询审计` | 不正确 | P1-I05、P1-I06 | 改为 `审核同意`/`审核拒绝`/`核验`+`result='失败'`/`取消预约`/`异常上报`/`异常处置`；删除不存在的 `查询审计` |
| S7 | 测试比对表把下游卡的端点当作本卡证据 | 不正确 | P1-I01、P1-I02、P1-I03 | 结论改标「跨卡验收」，并写明由 `VIS-P2-I01` 执行 |
| S8 | 实时通道路径不一致：`/socket.io` 与命名空间 `/ws` 混用 | 不正确 | P0-I01、P0-I05、P0-I07 | Vite 代理、nginx 代理、客户端连接统一为 `/ws` |
| S9 | 启动序使用 `loadConfig()` / `config`，但没有任何卡创建 `backend/src/config.ts` | 不正确 | P0-I07（使用方） | P0-I01 新增任务 18；`shared-kernel-api.md`、manifest、`spac.md` 目录树同步 |
| S10 | 共享内核 API 清单漏 `responseEnvelope`，而装配序要求它在路由之前 | 不正确 | P0-I03、P0-I07 | 补入 P0-I03 的 API 块与 manifest |
| S11 | 封版卡要求 `git tag`，但项目不是 git 仓库 | 不正确 | P0-I01、P2-I02、P2-I03 | P0-I01 新增任务 19：`git init` + 基线提交 |
| S12 | 第三方依赖无人安装：`bcryptjs`、`socket.io-client`、`dayjs`、`@vue/test-utils`、`exceljs`、`node-cron` | 不正确 | P0-I04、P0-I05、P0-I03、P1-I03 | 在真正 import 它的卡内显式列为安装任务 |
| S13 | 契约/种子摘要被抄进多张卡，存在漂移风险 | 冗余 | P0-I02、P1-I04、P1-I05、P1-I06 | 保留摘要但在标题标注「摘自 …」，并以权威文件为准；不重复定义字段级契约 |
| S14 | 测试证据用相对路径 `/:id/status`、`/:id/read`、`PUT /visitor/.../reschedule`，脱离挂载前缀后无法判定指向哪个资源 | 不正确 | P1-I01、P1-I02、P1-I04、P1-I05 | 全部展开为完整路径（`/master/gates/:id/status`、`/notifications/:id/read`、`/users/:id/status`、`/appointments/:id/reschedule` 等） |

---

## 四、逐卡发现

### VIS-P0-I01 项目脚手架与运行时闭环卡

| 类别 | 发现 | 处理 |
|------|------|------|
| 不正确 | `backend/package.json` 同时声明 `migrate`、`seed` 脚本，与 P0-I02 / P0-I08 的任务归属冲突 | 本卡只留 `dev/build/start/typecheck/test`，`migrate` 归 I02、`seed` 归 I08 |
| 不正确 | Vite 与 nginx 代理 `/socket.io`，而共享内核把命名空间挂在 `/ws` | 两处代理改为 `/ws` |
| 不正确 | 启动序引用 `backend/src/config.ts`，本卡未创建 | 新增任务 18，导出 `loadConfig()` 与 `config`，键集与 `config-contract.md` 一致 |
| 不正确 | 封版卡与状态刷新卡依赖 git，但仓库未初始化 | 新增任务 19：`git init` + `chore: scaffold` 基线提交 |
| 冗余 | 前端依赖清单与本卡任务重复罗列（`vue`、`vite`、`ant-design-vue`） | 保留：本卡负责 `package.json` 初始内容，属必要定义 |

### VIS-P0-I02 数据库 DDL 与迁移执行器卡

| 类别 | 发现 | 处理 |
|------|------|------|
| 不正确 | `\dt` 期望 26 张表，实际含 `_migrations` 为 27 | 改为「27 张（26 业务 + `_migrations`）」 |
| 不正确 | 迁移执行点写作「`app.listen` 之前」，未说明与连接池的先后 | 改为「`getPool` 之后、`app.listen` 之前」 |
| 不正确 | 验证使用 `psql $DATABASE_URL`，宿主机无法解析 `db` | 改为 `docker compose exec -T db psql` |
| 不正确 | `migrate` 脚本由 I01 声明，本卡只创建迁移器；脚本无人注册 | 本卡新增任务：在 `backend/package.json` 注册 `"migrate": "tsx src/shared/db/migrate.ts"` |

### VIS-P0-I03 共享内核卡

| 类别 | 发现 | 处理 |
|------|------|------|
| 不正确 | 验收写「18 个共享文件」，实际 `shared/` 下 19 个 + `realtime/io.ts` 1 个 = 20 | 改为 20 个源文件 |
| 不正确 | API 块声明 `startJob`、`startJobs`、`registerJob` 三者并存，manifest 只有 `startJob` | 统一为 `registerJob` / `startJobs` / `stopAllJobs`；`JobDefinition` 用 `cron` |
| 不正确 | `initRealtime` 卡内返回 `void`，`shared-kernel-api.md` 返回 `SocketServer`，Hub 卡需要 `io.close()` | 统一返回 `SocketServer` |
| 不正确 | API 块缺 `responseEnvelope` | 补入 |
| 不正确 | 验证挂载 `/api/v1/not-exist` 与 `curl /ws` 握手，二者都要求 Hub 卡已装配 | 改为纯单元断言 |
| 不正确 | 定时任务清单只写名称，未写归属卡与 cron | 改为「任务 → 归属卡 → cron」映射，领域卡登记、Hub 卡启动 |
| 冗余 | 掩码规则 F-010 同时出现在本卡与 `shared-kernel-api.md` | 保留：本卡是唯一实现点，重复属可接受的接口摘要 |

### VIS-P0-I04 认证与会话中间件卡

| 类别 | 发现 | 处理 |
|------|------|------|
| 不正确 | 验收含「连续 5 次失败锁定 10 分钟」「登录成功跳转」，账号锁定由 P1-I04 的 `auth.service` 实现，本卡无 `users` 写权限 | 验收改为会话 / CSRF / 权限 / 令牌 / 限流五类 |
| 不正确 | 文案表含「账号或密码错误」「该账号已停用」「账号已锁定」「密码长度不能少于 6 位」，均属 P1-I04 页面 | 从本卡文案表删除，保留在 P1-I04 |
| 不正确 | `bcryptjs` 被 import 但未列安装任务 | 新增安装任务 |
| 不正确 | 写请求验证未带 CSRF，断言会命中 403 而非目标分支 | 改为本地单测 + `tsx -e` 断言 |
| 不正确 | 限流阈值断言用「第 20 次」，与「超过 20 次」语义差一 | 改为第 21 次返回 429 |

### VIS-P0-I05 前端基础卡

| 类别 | 发现 | 处理 |
|------|------|------|
| 不正确 | 验证用 `GET /auth/me`，该端点属 P1-I04，本卡闭包内不存在 | 改为 `vi.mock('axios')` 拦截器单测 |
| 不正确 | 验证用浏览器打开 `/workbench` 观察角色工作台，页面属 P1-I04 | 同上，改为组件级断言 |
| 不正确 | 测试依赖 `@vue/test-utils`、`vitest`、`socket.io-client`、`dayjs` 未安装 | 新增安装任务 |
| 冗余 | `StatusTag` 与 `apiClient` 的断言散落在多个验证条目 | 合并为两个测试文件任务 |

### VIS-P0-I06 前端路由与导航骨架卡

| 类别 | 发现 | 处理 |
|------|------|------|
| 不正确 | 共享路由里重复声明 `/login`、`/403`，与 P1-I04 的 `views/access/routes.ts` 冲突，且 P0 阶段页面不存在会导致构建失败 | 共享路由只留根记录与 `/h5`；两个页面归 P1-I04 |
| 不正确 | 验证用浏览器打开 `/workbench`、`/login`，两路由属下游卡 | 改为路由守卫的桩断言 |

### VIS-P0-I07 Hub 集成补全卡

| 类别 | 发现 | 处理 |
|------|------|------|
| 不正确 | API 块缺 `backend/src/config.ts`、`startJobs`、`initRealtime(...): SocketServer` | 补入三项 |
| 不正确 | 任务 3 写 `initRealtime(...)` 未接返回值，任务 4 却调用 `io.close()` | 改为 `const io = initRealtime(...)` |
| 不正确 | 任务 1 用字面量 `/api/v1/health`，任务 2 又写「health 除外」，两处矛盾 | 统一 `API_PREFIX`，任务 2 只做 `app.use(API_PREFIX, router)` |
| 不正确 | 启动序缺 `ENABLE_JOBS` 守卫，测试环境会启动定时任务 | 改为 `ENABLE_JOBS === 'true' && startJobs()` |
| 不正确 | `connectRealtime` / `disconnectRealtime` 放在 `frontend/src/components/AppLayout`，实际布局在 `frontend/src/layouts/AppLayout.vue` | 改为 `layouts` 路径 |

### VIS-P0-I08 种子锚点与执行器卡

| 类别 | 发现 | 处理 |
|------|------|------|
| 不正确 | 全部时间戳写死 `2026-10-12`，「今日预约 / 在校中 / 到访提醒」类验证在别的执行日失效 | `seed-anchors.sql` 改为 `(CURRENT_DATE + TIME …)` 表达式；文件头声明 `D0 = 执行种子日` |
| 不正确 | 预约编号写死 `AP20261012001`… | 改为 `'AP' \|\| to_char(CURRENT_DATE,'YYYYMMDD') \|\| '001'` |
| 不正确 | 验收写死预约编号，与 D0 变化冲突 | 改为断言编号前缀 `AP` + 当日日期 |
| 不正确 | 验证使用 `psql $DATABASE_URL` | 改为 `docker compose exec -T db psql` |
| 冗余 | 卡片「种子数据来源」摘要与 `seed-anchors.sql` 重复 | 保留：标注「摘自」，且只列实体级摘要，不列列值 |

### VIS-P0-I09 契约冻结卡

| 类别 | 发现 | 处理 |
|------|------|------|
| 不正确 | `symbols.yaml` 验收要求与「实际导出」比对，但此刻业务模块尚未实现，必失败 | 改为「planned 门面 + `status: planned`」；真实比对移交 P2-I03 |
| 冗余 | 验证对同一批文件跑两次 lint | 合并为一次 `npx @redocly/cli lint` |

### VIS-P1-I01 master 主数据全栈卡

| 类别 | 发现 | 处理 |
|------|------|------|
| 不正确 | `system_config` 查询写成 `select value … where key=`，实际列为 `config_value` / `config_key` | 改为 `select config_value … where config_key='entry_url'` |
| 不正确 | `DELETE /master/time-rules/:id` 验证未带 CSRF，会得到 403 而非预期结果 | 补 CSRF 头 |
| 不正确 | 门面 `getConfig` 在 master 内重新查表，与共享 `configService` 重复定义 | 改为只委托 `configService` |
| 不正确 | 审计写入未列动作词，实际需要 `新增主数据`/`修改主数据`/`停用主数据`/`删除黑名单`/`删除时段规则`/`修改参数`/`修改字典` | 任务 8 显式列出 |
| 不正确 | `blacklist-expire` 任务未登记到调度器 | 补 `registerJob` |
| 不正确 | TC-BD-005 引用的配置键 `checkin_buffer_minutes`、`max_visit_minutes` 不存在，实际为 `verification_buffer_minutes`、`max_stay_minutes` | 改为实际键名 |
| 不正确 | TC-BD-001/002/003/008/010 的落点依赖 visit 卡端点 | 结论改标「跨卡验收」 |

### VIS-P1-I02 notify 通知全栈卡

| 类别 | 发现 | 处理 |
|------|------|------|
| 不正确 | 到访提醒条件缺 `now < visit_start`，会补发已开始时段的提醒 | 条件改为 `visit_start - 30min <= now < visit_start` |
| 不正确 | 超时未离任务未定义幂等键，每分钟重复发通知 | 以「存在 `template_type='超时未离'` 且 `business_id` 相同的通知」为幂等条件 |
| 不正确 | 验证期望 admin 看到 3 条通知，实际 seed 中收件人为管理员的只有 1 条 | 期望改为 1 条 |
| 不正确 | `AppLayout` 路径写成 `frontend/src/components/AppLayout` | 改为 `frontend/src/layouts/AppLayout.vue` |
| 不正确 | `reminder` / `overdue` 未登记调度器 | 补两条 `registerJob` |
| 不正确 | TC-NT-001/003、TC-PT-012 的证据在 visit 卡 | 结论改标「跨卡验收」 |

### VIS-P1-I03 report 台账统计全栈卡

| 类别 | 发现 | 处理 |
|------|------|------|
| 不正确 | `page_size=101` 断言「返回 100 行」，但种子仅 11 条预约 | 改为 `page_size=100`、`items` 为 11 |
| 不正确 | guard 日期过滤用固定 `2026-10-12` | 改为单测注入 `now=2026-10-12` + 接口用 `$(date +%F)` |
| 不正确 | TC-AN-003 依赖 notify 卡的 `overdue` 任务产物 | 改为 report 侧直接由 `appointments` 计算超时未离 |
| 不正确 | `exceljs` 被使用但未安装 | 新增安装任务 |

### VIS-P1-I04 access 门户权限全栈卡

| 类别 | 发现 | 处理 |
|------|------|------|
| 不正确 | Cookie Jar 用 `a.txt` / `g.txt`，与其他卡不一致 | 新增任务 11 `scripts/login-fixtures.sh` 统一产出 `admin.txt` / `guard.txt` / `host.txt` |
| 不正确 | `DELETE /users/:id` 断言 405，但缺 CSRF 时中间件先返回 403 | 补 CSRF 头后断言 405 |
| 不正确 | 验证用 `psql $DATABASE_URL` | 改为 `docker compose exec -T db psql` |
| 不正确 | 登录、登出、增改停启、重置密码均未要求写审计，与 REQ-SM-001 冲突 | 任务 6/7 逐项列出 `登录`/`退出登录`/`修改密码`/`新增账号`/`停用账号`/`启用账号`/`重置密码` |
| 不正确 | 验证在 `navigation.ts` 中 grep `/gate?tab=incidents`，该导航项在 `spac.md` §7.5 的权威清单中不存在（门卫项为 `/gate`） | 改为 grep `key: 'gate'` 并断言 `roles` 与 `path` |
| 冗余 | 验证段三次重复登录，与 `scripts/login-fixtures.sh` 重复 | 改为先执行脚本、再复用三个 Jar |

### VIS-P1-I05 visit 来访闭环全栈卡

| 类别 | 发现 | 处理 |
|------|------|------|
| 不正确 | `POST /appointments` 验证缺 CSRF | 补 CSRF 头 |
| 不正确 | 创建预约用固定 `2026-10-20`，执行日不同即失败 | 改为 `D1=$(date -d '+1 day' +%F)` |
| 不正确 | 核验 / 放行 / 离校链路依赖种子预约的真实时段，执行时钟不在窗口内必失败 | 改为「自建预约（明日）→ 核验必得 409 COPY-132」+「现场登记 → 离校 → 再次进校」的时钟无关链路；窗口边界由注入 `now` 的单测覆盖 |
| 不正确 | `POST /gate/depart` 缺 CSRF，再次进校未指明端点 | 补 CSRF；再次进校显式写 `POST /gate/admit` |
| 不正确 | `gate/verify|admit|depart|walk-in|incidents|disposition` 的请求体全未定义 | 任务 3 逐端点给出请求体字段 |
| 不正确 | 再次进校验证用尖括号占位 `<walk-in 返回的短码>` | 改为 `WALKIN=$(...)` + `jq -r .data.short_code` |
| 不正确 | TC-AT-010 引用不存在的表 `review_logs` | 改为 `operation_logs` 过滤 `action in ('审核同意','审核拒绝','改期')` |
| 不正确 | 审核、异常处置未列审计动作 | 任务 7/8 补 `审核同意`/`审核拒绝`/`异常处置`；失败核验明确 `result='失败'` |
| 不正确 | 路由写作 `POST /:id/approve`、`PUT /:id/reschedule`，脱离挂载前缀后不可判定 | 全部改写为完整路径；并注明 `/reviews/assignment` 必须先于 `/reviews/:id` 注册 |
| 不正确 | 访客令牌来源未定义：H5 流程与 P1-I06 的副本接口都需要令牌 | 任务 4 明确提交响应返回 `visitorToken` 并写 `vs.visitor`；新增任务 14 `scripts/visitor-fixture.sh` 产出 `h5.txt` / `h5.token` |
| 冗余 | 「种子数据来源」「本域设计」两段与 `seed-anchors.sql`、`spac.md` 重复 | 保留：均标注「摘自」，且下游以权威文件为准 |

### VIS-P1-I06 compliance 审计隐私全栈卡

| 类别 | 发现 | 处理 |
|------|------|------|
| 不正确 | 目标写「六类敏感操作」，与 REQ-SM-001 的七类（含提交与离校）不符 | 改为七类 |
| 不正确 | 动作词 `审核`、`失败核验`、`取消`、`异常` 不在 `conventions.md` 的 28 个规范值内 | 改为 `审核同意`/`审核拒绝`、`核验`+`result='失败'`、`取消预约`、`异常上报`/`异常处置` |
| 不正确 | 约束允许写 `action='查询审计'`，该值不存在于规范表 | 删除，改为「审计查询不写审计」 |
| 不正确 | 验证 `action=审核` 永远查不到数据 | 改为 `action=审核同意`（URL 编码） |
| 不正确 | 验证 `date_from=2026-10-12` 写死 | 改为 `$(date +%F)` |
| 不正确 | 验证假定库中已有 `VIS-P1-I05` 执行期产生的审核日志 | 改为本卡先执行登录夹具并调用一次审核同意，自造日志 |
| 不正确 | `GET /visitor/privacy/copy` 的令牌来源未定义 | 先执行上游卡的 `scripts/visitor-fixture.sh` |
| 不正确 | `audit-cleanup` 未登记调度器 | 补 `registerJob({name:'audit-cleanup', cron:'10 3 * * *'})` |
| 冗余 | 「上游契约」整段抄录表定义 | 保留：标注「摘自 p1-contracts.md §六」，且不重复列约束 |

### VIS-P2-I01 集成闭环卡

| 类别 | 发现 | 处理 |
|------|------|------|
| 不正确 | 验证写「阶段一五条命令」，任务实际有 6 项检查 | 改为六项 |
| 不正确 | 任务 5「请求任一领域端点，确认非 404」不可判定 | 改为 `GET /api/v1/audit-logs`：带 admin Cookie 返回 `code=0`，未登录返回 401 |
| 不正确 | 验证段使用 `admin.txt`，但未声明夹具来源 | 「在开始改动之前」补 `login-fixtures.sh` 与 `visitor-fixture.sh` |

### VIS-P2-I02 封版归档卡

| 类别 | 发现 | 处理 |
|------|------|------|
| 不正确 | 要求 `git tag v1.0.0-freeze`，依赖 git 仓库存在 | 由 P0-I01 任务 19 保证；本卡「在开始改动之前」未重复声明，依赖链已覆盖 |
| 冗余 | 10 项检查与 `p2-contracts.md` §二重复 | 保留：封版卡是检查执行点，重复属闸门性质 |

### VIS-P2-I03 状态刷新卡

| 类别 | 发现 | 处理 |
|------|------|------|
| 不正确 | `git status --short` 断言只含契约与报告，但执行期会留下 `docs/memory/`、`test-results/` 等未跟踪文件 | 改为 `git status --porcelain \| grep -vE '^(..) (contracts/\|conventions\.md\|docs/trace/runs/v1/state-refresh-report\.md)'` 输出 0 行 |
| 不正确 | `grep -c "^  /" contracts/openapi.yaml` 隐含两空格缩进格式 | 保留：该格式由 P0-I09 冻结，属闭包内约定 |

---

## 五、保留的设计性冗余

以下 7 处**不删除**，因为删除会让卡片失去独立执行所需的上下文：

| # | 卡片 | 保留内容 | 保留理由 |
|---|------|----------|----------|
| 1 | P0-I01 | 前端依赖清单（`vue`、`vite`、`ant-design-vue`） | 本卡负责 `package.json` 初始内容，属必要定义 |
| 2 | P0-I03 | 掩码规则 F-010 | 本卡是唯一实现点，重复属可接受的接口摘要 |
| 3 | P0-I08 | 「种子数据来源」摘要 | 标注「摘自 `seed-anchors.sql`」，只列实体级摘要 |
| 4 | P1-I05 | 「种子数据来源」「本域设计」两段 | 验证需要 UUID 与状态分布；冲突时以 `seed-anchors.sql`、`spac.md` 为准 |
| 5 | P1-I06 | 「上游契约」整段 | 下游 agent 不必逆向阅读上游实现；冲突时以 `p1-contracts.md` 为准 |
| 6 | P2-I02 | 10 项封版检查 | 封版卡是检查执行点，重复属闸门性质 |
| 7 | P2-I03 | `grep -c "^  /"` 的两空格缩进断言 | 该格式由 P0-I09 冻结，属闭包内契约，非冗余缺陷 |

判定标准：摘要只允许出现**实体名、UUID、状态、数量**，不允许出现字段级 DDL 或约束定义。字段级定义一旦复制即视为冗余缺陷。

---

## 六、复核与校验

| 检查项 | 方法 | 结果 |
|--------|------|------|
| YAML 可解析 | PyYAML `safe_load` | 通过 |
| 卡片数 | 解析后计数 | 18 |
| 依赖边 | 解析后求和 | 42 |
| 故事点 | 解析后求和 | 151 |
| 跨闭包文件引用 | 路径 → 创建卡 → 闭包比对 | 0 |
| 跨闭包端点引用 | 端点 → 所属上下文 → 闭包比对 | 0（9 处测试断言已标注「跨卡验收」） |
| 共享内核符号一致 | 卡内 import ↔ manifest `exports` ↔ `shared-kernel-api.md` | 一致（`registerJob`/`startJobs`/`stopAllJobs`/`JobDefinition`、`config`/`loadConfig`、`responseEnvelope`） |
| 审计动作词 | 与 `conventions.md` 约定 11 的 28 个值比对 | 0 处越界 |
| 验证命令可执行 | 逐条推演前置状态与中间件顺序 | 全部由本卡或闭包内产生；写请求均带 CSRF；不用尖括号占位 |
| 术语纪律 | 五个禁用词扫描 | 0 命中 |

**结论**：18 张卡在依赖闭包内自洽；修正后不存在跨闭包的代码/端点依赖，也不存在依赖上游执行现场数据的验证。保留的 7 处中，6 处属摘要或闸门性质、1 处属闭包内格式契约，且均在卡内标注了权威来源。
