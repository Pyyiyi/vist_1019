# 访客系统 V1.0 DDD 基线包

本目录是可独立归档、校验和作为下一版本输入的完整 DDD 基线。

## 跨版本必需输入

- `02-ddd-modeling/`：V1.0 完整领域模型。
- `source-evidence/story-bundle/`：V1.0 累计故事与 AC 证据快照。

生成 V1.1 时，应读取以上两项并叠加 V1.1 增量故事，输出新的 V1.1 完整模型；不得直接覆盖本目录。

## 派生与审计文件

- `confirmation/`：供人工确认的 Stage 2 摘要，不作为下一版本建模输入。
- `reports/`：结构校验、连通性、PRD 覆盖与语义复核留证，不作为领域事实输入。
- `source-evidence/prd-evidence.md`：仅用于重跑包内 PRD 覆盖审计。
- `manifest.json`：版本、契约和包内路径声明。

## 校验

在仓库根目录运行：

```bash
python3 scripts/validate_ddd.py v1.0/DDD/02-ddd-modeling \
  --report v1.0/DDD/reports/ddd-validation.json

python3 scripts/repair_link_density.py v1.0/DDD/02-ddd-modeling \
  --out v1.0/DDD/reports/link-density-report.json

python3 scripts/audit_requirement_coverage.py v1.0/DDD/02-ddd-modeling \
  --ledger v1.0/DDD/reports/requirement-coverage-ledger.json \
  --report v1.0/DDD/reports/requirement-coverage-audit.json \
  --fail-on-open
```
