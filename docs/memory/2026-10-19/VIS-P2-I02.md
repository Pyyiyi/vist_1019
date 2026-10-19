# VIS-P2-I02 · 封版归档卡执行记忆

- 执行日期：2026-10-20（Asia/Shanghai）
- 基线：`origin/main@d02d1f52bc4a43d2b4accbb557709f750bb99ee5`（VIS-P2-I01 集成闭环卡）
- 封版记录：[docs/trace/runs/v1/FREEZE](../../trace/runs/v1/FREEZE)
- 封版 tag：`v1.0.0-freeze`
- 环境：Docker Compose，PostgreSQL 15，Node 20；隔离卷 `visitor_pgdata_freeze_2f123ef6`，主机端口 `23030/28080/25432`。

## 完成结果

- 设计文件齐全：`spac.md`、`README.md`、`conventions.md`、`schema-shared.sql`、`seed-anchors.sql`、`shared-kernel-manifest.yaml`、`roles.md`、`scenes.md`、`docs/knowledge/*` 全部存在。
- 契约七件套：`contracts/openapi.yaml`、`schema.sql`、`events.yaml`、`naming.yaml`、`routes.yaml`、`symbols.yaml`、`cross-context-writes.md` 全部存在。
- 卡片全部关闭：16 张执行卡 Done 且有逐卡记忆；本卡为封版归档卡；P2-I03 为本卡下游并已明确刷新范围。
- 端点逐条可达：89 个方法操作逐条请求，`404` 与 `500` 均为 0（状态分布 200×47、422×34、405×4、403×3、409×1）。
- 权限点逐条生效：49 个 `access: admin` 端点以 `guard01` 会话请求，49/49 返回 403。
- 迁移幂等：全新库连续两次 `npm run migrate`，第一次 6 个文件、第二次 0 个文件。
- 种子幂等：连续两次 `npm run seed` 均为 `种子执行完成，共 1 个文件`，无主键冲突。
- 测试绿：后端 typecheck 退出码 0；后端 24 文件/122 测试通过；前端 build 退出码 0 且 `frontend/dist/index.html` 存在；前端 7 文件/45 测试通过。
- README 可用：三服务 healthy，health `code=0`，前端 200；`admin`、`guard01`、`T001`、`T002` 四账号均登录成功。
- 无伪占位：业务代码与数据 0 处命中六类伪占位标记；仅有规则说明与合法 `user:<id>` 房间命名。
- `docs/trace/runs/v1/test-results/summary.md`：107 行、107 个唯一 TC，通过 103、部分可达 4、未执行 0。

## 工作区恢复

- 工作区初始化标记为 `CHECKOUT_FAILED`，HEAD 无提交，仅设计文件存在。
- 通过 blobless 浅克隆恢复 git 历史（HEAD `d02d1f52`），通过 GitHub codeload 归档恢复 `main` 完整工作树；恢复后 `git status` 干净，未改动业务代码。

## 验证命令

```bash
COMPOSE_PROJECT_NAME=freeze2f123ef6 docker compose -f docker-compose.yml -f /tmp/freeze-volume.yml up -d --build
curl -s http://localhost:23030/api/v1/health
cd backend && npm run typecheck && npx vitest run
cd frontend && npm run build && npx vitest run
python3 /tmp/sweep.py   # 89 端点可达 + 49 adminOnly 403
cd backend && npm run migrate   # 幂等复核
cd backend && npm run seed      # 幂等复核
ls docs/trace/runs/v1/FREEZE
git tag -l v1.0.0-freeze
grep -c "未通过" docs/trace/runs/v1/FREEZE   # 0
```

## 剩余风险

- 下一轮增量前必须执行 VIS-P2-I03 状态刷新卡，以实际代码反写契约七件套并产出 `state-refresh-report.md`。
- 本封版在隔离端口与隔离数据卷验证；默认端口被占用时需按 README 覆盖 `HOST_*`。
- `summary.md` 中 4 条「部分可达」为已批准剔除孤儿断言后的结论，下一轮恢复断言时需重新执行。
- 前端主 chunk 约 1.67 MB（gzip 约 524 kB），仍有 Vite chunk-size 警告。

## 困惑

- 工作区初始化失败导致基线缺失；已按 `origin/main` 恢复，未影响封版结论。
