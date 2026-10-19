import { writeAudit } from '../../../shared/audit/writeAudit.js';
import { withTransaction } from '../../../shared/db/pool.js';
import { conflict, notFound } from '../../../shared/http/errors.js';
import { newUuid } from '../../../shared/utils/ids.js';
import * as dictionaryRepo from './dictionary.repo.js';
import type { Actor, DictionaryItemDto, SoftStatus } from './master.types.js';
import {
  parseIncludeInactive,
  parseInteger,
  parseSoftStatus,
  requiredText,
} from './master.support.js';

export async function listDictionary(query: Record<string, unknown>): Promise<DictionaryItemDto[]> {
  return dictionaryRepo.listDictionary({
    dictType: typeof query.dict_type === 'string' ? query.dict_type.trim() : '',
    includeInactive: parseIncludeInactive(query.include_inactive),
  });
}

export async function createDictionaryItem(
  input: {
    dict_type?: unknown;
    dict_key?: unknown;
    dict_label?: unknown;
    sort_order?: unknown;
  },
  actor: Actor,
  ip: string | null,
): Promise<DictionaryItemDto> {
  const dictType = requiredText(input.dict_type, 'dict_type', '请输入字典类型', 30);
  const dictKey = requiredText(input.dict_key, 'dict_key', '请输入字典键', 30);
  const dictLabel = requiredText(input.dict_label, 'dict_label', '请输入字典名称', 50);
  const sortOrder = parseInteger(input.sort_order, 'sort_order', 0);

  return withTransaction(async (client) => {
    if (await dictionaryRepo.findDictionaryByTypeAndKey(client, dictType, dictKey)) {
      throw conflict('该字典键已存在，请更换');
    }
    const id = newUuid();
    const created = await dictionaryRepo.insertDictionary(client, {
      id,
      dictType,
      dictKey,
      dictLabel,
      sortOrder,
    });
    await writeAudit(client, {
      userId: actor.id,
      userName: actor.displayName,
      objectType: 'data_dictionary',
      objectId: id,
      action: '修改字典',
      result: '成功',
      after: { dict_type: dictType, dict_key: dictKey, dict_label: dictLabel, sort_order: sortOrder },
      ip,
    });
    return created;
  });
}

export async function changeDictionaryStatus(
  id: string,
  input: { status?: unknown },
  actor: Actor,
  ip: string | null,
): Promise<{ id: string; status: SoftStatus }> {
  const status = parseSoftStatus(input.status);
  return withTransaction(async (client) => {
    const before = await dictionaryRepo.findDictionaryById(client, id, true);
    if (!before) {
      throw notFound();
    }
    if (before.status !== status) {
      await dictionaryRepo.updateDictionaryStatus(client, id, status);
      await writeAudit(client, {
        userId: actor.id,
        userName: actor.displayName,
        objectType: 'data_dictionary',
        objectId: id,
        action: status === 'inactive' ? '停用主数据' : '修改字典',
        result: '成功',
        before: { status: before.status },
        after: { status },
        ip,
      });
    }
    return { id, status };
  });
}
