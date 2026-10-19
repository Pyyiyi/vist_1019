import type { PoolClient } from 'pg';

import { writeAudit } from '../audit/writeAudit.js';
import { MESSAGES } from '../constants/messages.js';
import { query, withTransaction } from '../db/pool.js';
import { AppError } from '../http/errors.js';

type ConfigRow = { config_value: string };
const CACHE_TTL_MS = 60_000;
const cache = new Map<string, { value: string; expiresAt: number }>();

function configReadError(): AppError {
  return new AppError(500, 50001, MESSAGES.INTERNAL_ERROR);
}

export async function getConfig(key: string): Promise<string> {
  const cached = cache.get(key);
  if (cached && cached.expiresAt > Date.now()) {
    return cached.value;
  }

  const result = await query<ConfigRow>(
    'SELECT config_value FROM system_config WHERE config_key = $1',
    [key]
  );
  const value = result.rows[0]?.config_value;
  if (typeof value !== 'string') {
    throw configReadError();
  }

  cache.set(key, { value, expiresAt: Date.now() + CACHE_TTL_MS });
  return value;
}

export async function getConfigNumber(key: string): Promise<number> {
  const raw = await getConfig(key);
  const parsed = Number(raw);
  if (raw.trim() === '' || !Number.isFinite(parsed)) {
    throw configReadError();
  }
  return parsed;
}

export async function setConfig(
  key: string,
  value: string,
  actorId: string,
  audit: { userName?: string; ip?: string | null } = {},
): Promise<void> {
  await withTransaction(async (client: PoolClient) => {
    const previousResult = await client.query<ConfigRow>(
      'SELECT config_value FROM system_config WHERE config_key = $1 FOR UPDATE',
      [key]
    );
    const previous = previousResult.rows[0]?.config_value;
    if (previous === undefined) {
      throw configReadError();
    }

    await client.query(
      'UPDATE system_config SET config_value = $2, updated_at = now() WHERE config_key = $1',
      [key, value]
    );

    await writeAudit(client, {
      userId: actorId,
      userName: audit.userName ?? actorId,
      objectType: 'system_config',
      objectId: key,
      action: '修改参数',
      result: '成功',
      before: { config_value: previous },
      after: { config_value: value },
      ip: audit.ip ?? null,
    });
  });

  cache.delete(key);
}
