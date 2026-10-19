import type { QueryResultRow } from 'pg';

import { query } from '../../../shared/db/pool.js';
import type {
  NewReviewerRule,
  Queryable,
  ReviewerKind,
  ReviewerRuleDto,
  SoftStatus,
} from './master.types.js';

type ReviewerRuleRow = QueryResultRow & {
  id: string;
  visitor_type_id: string | null;
  gate_id: string | null;
  start_time: string | null;
  end_time: string | null;
  reviewer_kind: ReviewerKind;
  reviewer_user_id: string | null;
  declaration_order: number;
  status: SoftStatus;
};

function toDto(row: ReviewerRuleRow): ReviewerRuleDto {
  return {
    id: row.id,
    visitorTypeId: row.visitor_type_id,
    gateId: row.gate_id,
    startTime: row.start_time ? String(row.start_time).slice(0, 8) : null,
    endTime: row.end_time ? String(row.end_time).slice(0, 8) : null,
    reviewerKind: row.reviewer_kind,
    reviewerUserId: row.reviewer_user_id,
    declarationOrder: row.declaration_order,
    status: row.status,
  };
}

export async function listActiveReviewerRules(client: Queryable): Promise<ReviewerRuleDto[]> {
  const result = await client.query<ReviewerRuleRow>(
    `SELECT id, visitor_type_id, gate_id, start_time, end_time, reviewer_kind,
            reviewer_user_id, declaration_order, status
       FROM reviewer_rules
      WHERE status = 'active'
      ORDER BY declaration_order ASC, id ASC`,
  );
  return result.rows.map(toDto);
}

export async function replaceReviewerRules(
  client: Queryable,
  rules: Array<NewReviewerRule & { id: string }>,
): Promise<ReviewerRuleDto[]> {
  await client.query('DELETE FROM reviewer_rules');
  const inserted: ReviewerRuleDto[] = [];
  for (const rule of rules) {
    const result = await client.query<ReviewerRuleRow>(
      `INSERT INTO reviewer_rules (
         id, visitor_type_id, gate_id, start_time, end_time, reviewer_kind,
         reviewer_user_id, declaration_order, status
       ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
       RETURNING id, visitor_type_id, gate_id, start_time, end_time, reviewer_kind,
                 reviewer_user_id, declaration_order, status`,
      [
        rule.id,
        rule.visitorTypeId,
        rule.gateId,
        rule.startTime,
        rule.endTime,
        rule.reviewerKind,
        rule.reviewerUserId,
        rule.declarationOrder,
        rule.status,
      ],
    );
    inserted.push(toDto(result.rows[0]));
  }
  return inserted;
}

export async function listActiveReviewerRulesFromPool(): Promise<ReviewerRuleDto[]> {
  return listActiveReviewerRules({ query });
}
