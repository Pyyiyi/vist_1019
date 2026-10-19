import { setConfig } from '../../../shared/config/configService.js';
import { query } from '../../../shared/db/pool.js';
import { notFound, unprocessable } from '../../../shared/http/errors.js';
import * as paramsRepo from './params.repo.js';
import type { Actor, ParamDto, Queryable } from './master.types.js';
import { stringValue } from './master.support.js';

function validateConfigValue(value: string, type: ParamDto['valueType']): void {
  if (!value) {
    throw unprocessable('请输入参数值', 'config_value');
  }
  if (type === 'number' && (!Number.isFinite(Number(value)) || Number(value) < 0)) {
    throw unprocessable('参数值必须是大于或等于 0 的数字', 'config_value');
  }
  if (type === 'boolean' && value !== 'true' && value !== 'false') {
    throw unprocessable('参数值必须是 true 或 false', 'config_value');
  }
  if (type === 'json') {
    try {
      JSON.parse(value);
    } catch {
      throw unprocessable('参数值必须是合法的 JSON', 'config_value');
    }
  }
}

export async function listParams(): Promise<ParamDto[]> {
  return paramsRepo.listParams();
}

export async function updateParam(
  key: string,
  input: { config_value?: unknown },
  actor: Actor,
  ip: string | null,
): Promise<ParamDto> {
  const poolQueryable: Queryable = { query };
  const current = await paramsRepo.findParamByKey(poolQueryable, key);
  if (!current) {
    throw notFound();
  }
  const value = stringValue(input.config_value);
  validateConfigValue(value, current.valueType);
  await setConfig(key, value, actor.id, { userName: actor.displayName, ip });
  const updated = await paramsRepo.findParamByKey(poolQueryable, key);
  if (!updated) {
    throw notFound();
  }
  return updated;
}
