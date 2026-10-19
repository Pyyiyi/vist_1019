import { Pool } from 'pg';
import type { PoolClient, QueryResult, QueryResultRow } from 'pg';

let pool: Pool | undefined;

function poolMax(): number {
  const raw = process.env.DB_POOL_MAX?.trim();
  if (!raw) {
    return 10;
  }

  const value = Number(raw);
  if (!Number.isInteger(value) || value <= 0) {
    throw new Error('Environment variable DB_POOL_MAX must be a positive integer');
  }

  return value;
}

export function getPool(): Pool {
  if (pool) {
    return pool;
  }

  const connectionString = process.env.DATABASE_URL?.trim();
  if (!connectionString) {
    throw new Error('Missing required environment variable: DATABASE_URL');
  }

  pool = new Pool({
    connectionString,
    max: poolMax(),
  });

  return pool;
}

export async function query<T extends QueryResultRow = QueryResultRow>(
  sql: string,
  params?: unknown[]
): Promise<QueryResult<T>> {
  return getPool().query<T>(sql, params);
}

export async function withTransaction<T>(fn: (client: PoolClient) => Promise<T>): Promise<T> {
  const client = await getPool().connect();

  try {
    await client.query('BEGIN');
    const result = await fn(client);
    await client.query('COMMIT');
    return result;
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}
