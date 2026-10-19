# 访客系统 V1.0 DDD 语义复核

- 复核日期：2026-10-12
- 直接证据：`source-evidence/story-bundle/`
- 补充证据：`source-evidence/prd-evidence.md`
- 输入适配：原仓库无规范 StoryBundle；本包逐字保留 49 条故事的 110 条 AC，未改写源 AC。

## 复核结论

- 110/110 条源 AC 在 `traceabilityMatrix` 中各出现一次，原值及顺序未改写。
- 逐条区分 Given、When 与 Then，共形成 134 个场景。
- 复合 AC 已按独立动作或互斥分支拆分。
- 查询均为只读；导航、展示、导出和打印建模为应用交互。
- 8 个状态机均由真实聚合拥有并与命令守卫联动；生命周期 AC 共 19 个。
- `Left`（已离校）不是绝对终态，同一自然日允许再次进校。
- 预约状态与凭证状态分开建模，非法调用使用拒绝后的 `NoChange` 表达。
- 无 pending 场景或 pending 生命周期决定。

## PRD 交叉审计

- 覆盖台账包含 45 个 PRD REQ 原子及 2 个状态补充原子。
- 45 项为 `mapped`，2 项为 `equivalent`，无 `missing`、`conflict` 或 `pending`。
- 审计脚本只证明证据存在、台账完整及引用有效，不代表软件运行验收通过。

## 质量门禁

- DDD v2 契约：`valid`
- AC：110；场景：134；mapped：134；pending：0
- 聚合：10；命令：37；领域事件：37；查询：19；状态机：8
- 连通性缺口：0；开放问题：0
- PRD 覆盖审计：`passed`
