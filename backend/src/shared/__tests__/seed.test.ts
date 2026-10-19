import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { getPool } from '../db/pool.js';
import { runSeeds } from '../db/seed.js';

type CountRow = { count: number };
type AnchorRow = { appoint_no: string; status: string };
type UserRow = { username: string; role_code: string; password_ok: boolean };

const pool = getPool();

async function countRows(table: string): Promise<number> {
  const result = await pool.query<CountRow>(`SELECT count(*)::int AS count FROM ${table}`);
  return result.rows[0].count;
}

describe('seed anchors', () => {
  beforeAll(async () => {
    await expect(runSeeds()).resolves.toBe(1);
  });

  afterAll(async () => {
    await pool.end();
  });

  it('loads the four backend accounts with the shared password', async () => {
    const result = await pool.query<UserRow>(`
      SELECT username, role_code, crypt('abc@123', password_hash) = password_hash AS password_ok
      FROM users
      ORDER BY username
    `);

    expect(result.rows.map((row) => row.username).sort()).toEqual(['T001', 'T002', 'admin', 'guard01']);
    expect(result.rows.map((row) => row.role_code).sort()).toEqual(['admin', 'guard', 'host', 'host']);
    expect(result.rows.every((row) => row.password_ok)).toBe(true);
  });

  it('loads 11 appointments across the eight business states', async () => {
    const result = await pool.query<AnchorRow>('SELECT appoint_no, status FROM appointments ORDER BY appoint_no');
    const dayResult = await pool.query<{ d0: string }>("SELECT to_char(CURRENT_DATE, 'YYYYMMDD') AS d0");
    const d0 = dayResult.rows[0].d0;
    const expectedNumbers = Array.from(
      { length: 11 },
      (_, index) => `AP${d0}${String(index + 1).padStart(3, '0')}`
    );

    expect(result.rows).toHaveLength(11);
    expect(result.rows.map((row) => row.appoint_no)).toEqual(expectedNumbers);
    expect(new Set(result.rows.map((row) => row.status))).toEqual(
      new Set(['待审核', '已通过', '已拒绝', '已改期', '已过期', '已到访(在校中)', '已离校', '已取消'])
    );
  });

  it('loads the eleven unique six-digit short codes', async () => {
    const result = await pool.query<{ short_code: string }>(
      'SELECT short_code FROM visit_credentials ORDER BY short_code'
    );

    expect(result.rows.map((row) => row.short_code)).toEqual(
      Array.from({ length: 11 }, (_, index) => String(100001 + index))
    );
    expect(new Set(result.rows.map((row) => row.short_code)).size).toBe(11);
  });

  it('loads the dependent anchor records', async () => {
    await expect(countRows('consent_records')).resolves.toBe(22);
    await expect(countRows('passage_records')).resolves.toBe(3);
    await expect(countRows('incidents')).resolves.toBe(3);
    await expect(countRows('notifications')).resolves.toBe(3);

    const audit = await pool.query<CountRow>(`
      SELECT count(*)::int AS count
      FROM operation_logs
      WHERE occurred_at < now() - INTERVAL '180 days'
    `);
    expect(audit.rows[0].count).toBe(1);
  });

  it('can run a second time without changing the anchor counts', async () => {
    const before = await Promise.all([
      countRows('users'),
      countRows('appointments'),
      countRows('visit_credentials'),
      countRows('consent_records'),
    ]);

    await expect(runSeeds()).resolves.toBe(1);

    const after = await Promise.all([
      countRows('users'),
      countRows('appointments'),
      countRows('visit_credentials'),
      countRows('consent_records'),
    ]);

    expect(after).toEqual(before);
  });
});
