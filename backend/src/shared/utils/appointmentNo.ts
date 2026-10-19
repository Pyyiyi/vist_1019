import { randomInt } from 'node:crypto';
import type { PoolClient } from 'pg';

type Queryable = Pick<PoolClient, 'query'>;
type SequenceRow = { last_sequence: number | string | null };

function shanghaiDayKey(now: Date): string {
  if (Number.isNaN(now.getTime())) {
    throw new RangeError('无效日期');
  }

  const parts = new Intl.DateTimeFormat('en-GB', {
    timeZone: 'Asia/Shanghai',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(now);
  const values = Object.fromEntries(parts.map((part) => [part.type, part.value]));
  return `${values.year}${values.month}${values.day}`;
}

export async function nextAppointmentNo(client: Queryable, now = new Date()): Promise<string> {
  const dayKey = shanghaiDayKey(now);
  const lockKey = `appointment-no:${dayKey}`;

  await client.query('SELECT pg_advisory_xact_lock(hashtext($1))', [lockKey]);

  const result = await client.query<SequenceRow>(
    `SELECT COALESCE(MAX(RIGHT(appoint_no, 3)::integer), 0) AS last_sequence
       FROM appointments
      WHERE appoint_no LIKE $1`,
    [`AP${dayKey}%`]
  );

  const previous = Number(result.rows[0]?.last_sequence ?? 0);
  const sequence = (Number.isFinite(previous) ? previous : 0) + 1;
  if (sequence > 999) {
    throw new Error('当日预约编号已达到上限');
  }

  return `AP${dayKey}${String(sequence).padStart(3, '0')}`;
}

export async function generateShortCode(client: Queryable): Promise<string> {
  for (let attempt = 0; attempt < 20; attempt += 1) {
    const code = String(randomInt(100000, 1000000));
    const existing = await client.query(
      'SELECT 1 FROM visit_credentials WHERE short_code = $1 LIMIT 1',
      [code]
    );

    if (existing.rows.length === 0) {
      return code;
    }
  }

  throw new Error('短码生成失败');
}
