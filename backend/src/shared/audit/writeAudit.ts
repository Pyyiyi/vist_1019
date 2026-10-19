import type { PoolClient } from 'pg';

import { logger } from '../logger.js';
import { getPool } from '../db/pool.js';
import { newUuid } from '../utils/ids.js';

export type AuditEntry = {
  userId: string | null;
  userName: string;
  objectType: string;
  objectId: string | null;
  action: string;
  result: '成功' | '失败' | '拒绝';
  before?: unknown;
  after?: unknown;
  ip?: string | null;
  note?: string;
};

type Queryable = Pick<PoolClient, 'query'>;

function isQueryable(value: unknown): value is Queryable {
  return typeof value === 'object' && value !== null && 'query' in value;
}

async function insertAudit(client: Queryable, entry: AuditEntry): Promise<void> {
  const occurredAt = new Date();
  await client.query(
    `INSERT INTO operation_logs (
       id, user_id, user_name, occurred_at, object_type, object_id,
       action, result, before_value, after_value, ip, note
     ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9::jsonb, $10::jsonb, $11, $12)`,
    [
      newUuid(),
      entry.userId,
      entry.userName,
      occurredAt,
      entry.objectType,
      entry.objectId,
      entry.action,
      entry.result,
      entry.before === undefined ? null : JSON.stringify(entry.before),
      entry.after === undefined ? null : JSON.stringify(entry.after),
      entry.ip ?? null,
      entry.note ?? '',
    ]
  );
}

export function writeAudit(client: Queryable, entry: AuditEntry): Promise<void>;
export function writeAudit(entry: AuditEntry): Promise<void>;
export async function writeAudit(
  clientOrEntry: Queryable | AuditEntry,
  suppliedEntry?: AuditEntry
): Promise<void> {
  const entry = suppliedEntry ?? (clientOrEntry as AuditEntry);
  const client = suppliedEntry && isQueryable(clientOrEntry) ? clientOrEntry : getPool();

  try {
    await insertAudit(client, entry);
  } catch (error) {
    logger.error('审计写入失败', {
      action: entry.action,
      objectType: entry.objectType,
      objectId: entry.objectId,
      error: error instanceof Error ? error.message : String(error),
    });
  }
}
