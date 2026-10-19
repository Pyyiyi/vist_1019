import type { DbClient } from './types.js';
import { newUuid } from '../../../shared/utils/ids.js';
import { unprocessable } from '../../../shared/http/errors.js';
import { COPY } from './domain/rules.js';

export type ConsentInput = { safety?: unknown; privacy?: unknown };

export function assertConsents(consent: ConsentInput | undefined): void {
  if (consent?.safety !== true || consent?.privacy !== true) {
    throw unprocessable(COPY.CONSENT, 'consent');
  }
}

export async function insertConsents(
  client: DbClient,
  appointmentId: string,
  channel: 'H5' | '现场登记' | '后台代提',
  now = new Date(),
): Promise<void> {
  const types = ['安全告知', '个人信息授权告知'] as const;
  for (const type of types) {
    await client.query(
      `INSERT INTO consent_records (id, appointment_id, consent_type, confirmed_at, channel)
       VALUES ($1, $2, $3, $4, $5)`,
      [newUuid(), appointmentId, type, now, channel],
    );
  }
}
