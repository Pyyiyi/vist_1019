import { beforeEach, describe, expect, it, vi } from 'vitest';
import type { PoolClient } from 'pg';

const cryptoMocks = vi.hoisted(() => ({ randomInt: vi.fn() }));

vi.mock('node:crypto', async (importOriginal) => {
  const actual = await importOriginal<typeof import('node:crypto')>();
  return { ...actual, randomInt: cryptoMocks.randomInt };
});

import { generateShortCode, nextAppointmentNo } from '../utils/appointmentNo.js';

type QueryResponse = { rows: Array<Record<string, unknown>>; rowCount: number };

function fakeClient(handler: (sql: string, params?: unknown[]) => QueryResponse): {
  client: PoolClient;
  queryMock: ReturnType<typeof vi.fn>;
} {
  const queryMock = vi.fn((sql: string, params?: unknown[]) => Promise.resolve(handler(sql, params)));
  return { client: { query: queryMock } as unknown as PoolClient, queryMock };
}

describe('appointmentNo', () => {
  beforeEach(() => {
    cryptoMocks.randomInt.mockReset();
  });

  it('formats a same-day appointment number using Asia/Shanghai time', async () => {
    const { client, queryMock } = fakeClient((sql) => {
      if (sql.includes('pg_advisory_xact_lock')) {
        return { rows: [], rowCount: 0 };
      }
      return { rows: [{ last_sequence: 0 }], rowCount: 1 };
    });

    await expect(
      nextAppointmentNo(client, new Date('2026-10-18T16:30:00.000Z'))
    ).resolves.toBe('AP20261019001');
    expect(queryMock.mock.calls[0][0]).toContain('pg_advisory_xact_lock');
    expect(queryMock.mock.calls[0][1]).toEqual(['appointment-no:20261019']);
  });

  it('increments the existing same-day sequence', async () => {
    const { client } = fakeClient((sql) => {
      if (sql.includes('pg_advisory_xact_lock')) {
        return { rows: [], rowCount: 0 };
      }
      return { rows: [{ last_sequence: '41' }], rowCount: 1 };
    });

    await expect(
      nextAppointmentNo(client, new Date('2026-10-19T10:00:00+08:00'))
    ).resolves.toBe('AP20261019042');
  });

  it('returns a six-digit short code when no collision exists', async () => {
    cryptoMocks.randomInt.mockReturnValueOnce(123456);
    const { client } = fakeClient(() => ({ rows: [], rowCount: 0 }));

    await expect(generateShortCode(client)).resolves.toBe('123456');
  });

  it('retries short-code collisions up to 20 attempts', async () => {
    cryptoMocks.randomInt
      .mockReturnValueOnce(111111)
      .mockReturnValueOnce(222222)
      .mockReturnValueOnce(333333);
    let calls = 0;
    const { client } = fakeClient(() => {
      calls += 1;
      return calls < 3 ? { rows: [{ exists: 1 }], rowCount: 1 } : { rows: [], rowCount: 0 };
    });

    await expect(generateShortCode(client)).resolves.toBe('333333');
    expect(calls).toBe(3);
  });

  it('fails after the twentieth short-code collision', async () => {
    cryptoMocks.randomInt.mockReturnValue(999999);
    const { client, queryMock } = fakeClient(() => ({
      rows: [{ exists: 1 }],
      rowCount: 1,
    }));

    await expect(generateShortCode(client)).rejects.toThrow('短码生成失败');
    expect(queryMock).toHaveBeenCalledTimes(20);
  });
});
