import type { QueryResultRow } from 'pg';

import { query } from '../../../shared/db/pool.js';
import type { DictionaryItemDto, Queryable, SoftStatus } from './master.types.js';

type DictionaryRow = QueryResultRow & {
  id: string;
  dict_type: string;
  dict_key: string;
  dict_label: string;
  sort_order: number;
  status: SoftStatus;
  created_at: Date | string;
};

function toDto(row: DictionaryRow): DictionaryItemDto {
  return {
    id: row.id,
    dictType: row.dict_type,
    dictKey: row.dict_key,
    dictLabel: row.dict_label,
    sortOrder: row.sort_order,
    status: row.status,
    createdAt: row.created_at,
  };
}

export async function listDictionary(options: {
  dictType: string;
  includeInactive: boolean;
}): Promise<DictionaryItemDto[]> {
  const values: unknown[] = [];
  const where: string[] = [];
  if (options.dictType) {
    values.push(options.dictType);
    where.push(`dict_type = $${values.length}`);
  }
  if (!options.includeInactive) {
    where.push("status = 'active'");
  }
  const result = await query<DictionaryRow>(
    `SELECT id, dict_type, dict_key, dict_label, sort_order, status, created_at
       FROM data_dictionary
      ${where.length ? `WHERE ${where.join(' AND ')}` : ''}
      ORDER BY dict_type ASC, sort_order ASC, dict_key ASC, id ASC`,
    values,
  );
  return result.rows.map(toDto);
}

export async function findDictionaryById(
  client: Queryable,
  id: string,
  forUpdate = false,
): Promise<DictionaryItemDto | null> {
  const result = await client.query<DictionaryRow>(
    `SELECT id, dict_type, dict_key, dict_label, sort_order, status, created_at
       FROM data_dictionary WHERE id = $1 ${forUpdate ? 'FOR UPDATE' : ''}`,
    [id],
  );
  return result.rows[0] ? toDto(result.rows[0]) : null;
}

export async function findDictionaryByTypeAndKey(
  client: Queryable,
  dictType: string,
  dictKey: string,
): Promise<DictionaryItemDto | null> {
  const result = await client.query<DictionaryRow>(
    `SELECT id, dict_type, dict_key, dict_label, sort_order, status, created_at
       FROM data_dictionary
      WHERE dict_type = $1 AND lower(dict_key) = lower($2)
      LIMIT 1`,
    [dictType, dictKey],
  );
  return result.rows[0] ? toDto(result.rows[0]) : null;
}

export async function insertDictionary(
  client: Queryable,
  row: {
    id: string;
    dictType: string;
    dictKey: string;
    dictLabel: string;
    sortOrder: number;
  },
): Promise<DictionaryItemDto> {
  const result = await client.query<DictionaryRow>(
    `INSERT INTO data_dictionary (id, dict_type, dict_key, dict_label, sort_order, status)
     VALUES ($1, $2, $3, $4, $5, 'active')
     RETURNING id, dict_type, dict_key, dict_label, sort_order, status, created_at`,
    [row.id, row.dictType, row.dictKey, row.dictLabel, row.sortOrder],
  );
  return toDto(result.rows[0]);
}

export async function updateDictionaryStatus(
  client: Queryable,
  id: string,
  status: SoftStatus,
): Promise<void> {
  await client.query(
    'UPDATE data_dictionary SET status = $2, updated_at = now() WHERE id = $1',
    [id, status],
  );
}
