import type { QueryResultRow } from 'pg';

import { query } from '../../../shared/db/pool.js';
import type { Queryable, RuleType, TimeRuleDto } from './master.types.js';

type TimeRuleRow = QueryResultRow & {
  id: string;
  weekday: number;
  start_time: string;
  end_time: string;
  rule_type: RuleType;
  created_at: Date | string;
};

function toDto(row: TimeRuleRow): TimeRuleDto {
  return {
    id: row.id,
    weekday: row.weekday,
    startTime: String(row.start_time).slice(0, 8),
    endTime: String(row.end_time).slice(0, 8),
    ruleType: row.rule_type,
    createdAt: row.created_at,
  };
}

export async function listTimeRules(): Promise<TimeRuleDto[]> {
  const result = await query<TimeRuleRow>(
    `SELECT id, weekday, start_time, end_time, rule_type, created_at
       FROM time_rules
      ORDER BY weekday ASC, start_time ASC, id ASC`,
  );
  return result.rows.map(toDto);
}

export async function listActiveTimeRules(client: Queryable): Promise<TimeRuleDto[]> {
  const result = await client.query<TimeRuleRow>(
    `SELECT id, weekday, start_time, end_time, rule_type, created_at
       FROM time_rules
      ORDER BY weekday ASC, start_time ASC, id ASC`,
  );
  return result.rows.map(toDto);
}

export async function findTimeRuleById(
  client: Queryable,
  id: string,
  forUpdate = false,
): Promise<TimeRuleDto | null> {
  const result = await client.query<TimeRuleRow>(
    `SELECT id, weekday, start_time, end_time, rule_type, created_at
       FROM time_rules WHERE id = $1 ${forUpdate ? 'FOR UPDATE' : ''}`,
    [id],
  );
  return result.rows[0] ? toDto(result.rows[0]) : null;
}

export async function insertTimeRule(
  client: Queryable,
  row: {
    id: string;
    weekday: number;
    startTime: string;
    endTime: string;
    ruleType: RuleType;
  },
): Promise<TimeRuleDto> {
  const result = await client.query<TimeRuleRow>(
    `INSERT INTO time_rules (id, weekday, start_time, end_time, rule_type)
     VALUES ($1, $2, $3, $4, $5)
     RETURNING id, weekday, start_time, end_time, rule_type, created_at`,
    [row.id, row.weekday, row.startTime, row.endTime, row.ruleType],
  );
  return toDto(result.rows[0]);
}

export async function deleteTimeRule(client: Queryable, id: string): Promise<void> {
  await client.query('DELETE FROM time_rules WHERE id = $1', [id]);
}
