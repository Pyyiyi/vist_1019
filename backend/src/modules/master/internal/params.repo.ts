import type { QueryResultRow } from 'pg';

import { query } from '../../../shared/db/pool.js';
import type { ParamDto, Queryable } from './master.types.js';

type ParamRow = QueryResultRow & {
  config_key: string;
  config_value: string;
  value_type: ParamDto['valueType'];
  description: string;
  updated_at: Date | string;
};

function toDto(row: ParamRow): ParamDto {
  return {
    configKey: row.config_key,
    configValue: row.config_value,
    valueType: row.value_type,
    description: row.description,
    updatedAt: row.updated_at,
  };
}

export async function listParams(): Promise<ParamDto[]> {
  const result = await query<ParamRow>(
    `SELECT config_key, config_value, value_type, description, updated_at
       FROM system_config
      ORDER BY config_key ASC`,
  );
  return result.rows.map(toDto);
}

export async function findParamByKey(
  client: Queryable,
  key: string,
  forUpdate = false,
): Promise<ParamDto | null> {
  const result = await client.query<ParamRow>(
    `SELECT config_key, config_value, value_type, description, updated_at
       FROM system_config WHERE config_key = $1 ${forUpdate ? 'FOR UPDATE' : ''}`,
    [key],
  );
  return result.rows[0] ? toDto(result.rows[0]) : null;
}
