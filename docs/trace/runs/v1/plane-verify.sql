-- ============================================================
-- 校园访客系统 V1.0 — Plane 插入验证 SQL
-- Project: 2924e784-2228-4087-bec1-43a04de1df6f (VISY1019)
-- Workspace: 6c6a5a06-9043-425a-b19e-0003cd181fe9
-- 预期: issues=18, blocker=42, relation=42, labels=23, issue_labels=45, activities=18
-- ============================================================

-- 1. 卡片总数、状态、编号、描述完整性
SELECT
    count(*)                                                       AS issues,
    count(*) FILTER (WHERE state_id = '6fb41cb9-db51-4196-a359-19f915a20e19') AS backlog,
    min(sequence_id)                                               AS min_seq,
    max(sequence_id)                                               AS max_seq,
    count(DISTINCT sequence_id)                                    AS distinct_seq,
    count(DISTINCT name)                                           AS distinct_names,
    sum(length(description_html))                                  AS html_len,
    sum(CASE WHEN description_html = description_stripped THEN 1 ELSE 0 END) AS html_eq_stripped
FROM issues
WHERE project_id = '2924e784-2228-4087-bec1-43a04de1df6f' AND deleted_at IS NULL;

-- 2. 关联表计数
SELECT
    (SELECT count(*) FROM issue_sequences  WHERE project_id = '2924e784-2228-4087-bec1-43a04de1df6f')                        AS seqs,
    (SELECT count(*) FROM issue_blockers   WHERE project_id = '2924e784-2228-4087-bec1-43a04de1df6f' AND deleted_at IS NULL) AS blockers,
    (SELECT count(*) FROM issue_relations  WHERE project_id = '2924e784-2228-4087-bec1-43a04de1df6f' AND deleted_at IS NULL) AS relations,
    (SELECT count(*) FROM labels           WHERE project_id = '2924e784-2228-4087-bec1-43a04de1df6f' AND deleted_at IS NULL) AS labels,
    (SELECT count(*) FROM issue_labels     WHERE project_id = '2924e784-2228-4087-bec1-43a04de1df6f' AND deleted_at IS NULL) AS issue_labels,
    (SELECT count(*) FROM issue_activities WHERE project_id = '2924e784-2228-4087-bec1-43a04de1df6f' AND deleted_at IS NULL) AS activities;

-- 3. 卡片清单（Plane 页面显示编号 = VISY1019-<sequence_id>）
SELECT sequence_id, name, priority, point, sort_order
FROM issues
WHERE project_id = '2924e784-2228-4087-bec1-43a04de1df6f' AND deleted_at IS NULL
ORDER BY sequence_id;

-- 4. 阻塞关系（下游 <- 上游）
SELECT
    i.sequence_id AS down_seq, i.name AS blocked_issue,
    u.sequence_id AS up_seq,   u.name AS blocker
FROM issue_blockers b
JOIN issues i ON i.id = b.block_id
JOIN issues u ON u.id = b.blocked_by_id
WHERE b.project_id = '2924e784-2228-4087-bec1-43a04de1df6f' AND b.deleted_at IS NULL
ORDER BY i.sequence_id, u.sequence_id;

-- 5. 阻塞关系与 UI 关系表一致性（应为 0）
SELECT count(*) AS missing_relations
FROM issue_blockers b
LEFT JOIN issue_relations r
       ON r.issue_id = b.block_id
      AND r.related_issue_id = b.blocked_by_id
      AND r.relation_type = 'blocked_by'
      AND r.deleted_at IS NULL
WHERE b.project_id = '2924e784-2228-4087-bec1-43a04de1df6f'
  AND b.deleted_at IS NULL
  AND r.id IS NULL;
