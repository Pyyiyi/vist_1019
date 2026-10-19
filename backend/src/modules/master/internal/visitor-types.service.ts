import { writeAudit } from '../../../shared/audit/writeAudit.js';
import { withTransaction } from '../../../shared/db/pool.js';
import { conflict, notFound } from '../../../shared/http/errors.js';
import { newUuid } from '../../../shared/utils/ids.js';
import type { Actor, SoftStatus, VisitorTypeDto } from './master.types.js';
import {
  parseIncludeInactive,
  parseSoftStatus,
  requiredText,
  stringValue,
} from './master.support.js';
import * as visitorTypesRepo from './visitor-types.repo.js';

export type MasterQuery = Record<string, unknown>;

export async function listVisitorTypes(query: MasterQuery): Promise<VisitorTypeDto[]> {
  const status =
    query.status === undefined || query.status === '' ? undefined : parseSoftStatus(query.status);
  return visitorTypesRepo.listVisitorTypes({
    status,
    includeInactive: parseIncludeInactive(query.include_inactive),
  });
}

export async function createVisitorType(
  input: { name?: unknown },
  actor: Actor,
  ip: string | null,
): Promise<VisitorTypeDto> {
  const name = requiredText(input.name, 'name', '请输入名称', 30);
  return withTransaction(async (client) => {
    if (await visitorTypesRepo.findVisitorTypeByName(client, name)) {
      throw conflict('名称已存在，请更换');
    }
    const id = newUuid();
    const created = await visitorTypesRepo.insertVisitorType(client, {
      id,
      code: `vt-${id.slice(0, 8)}`,
      name,
      sortOrder: 0,
    });
    await writeAudit(client, {
      userId: actor.id,
      userName: actor.displayName,
      objectType: 'visitor_types',
      objectId: id,
      action: '新增主数据',
      result: '成功',
      after: { name, status: created.status },
      ip,
    });
    return created;
  });
}

export async function renameVisitorType(
  id: string,
  input: { name?: unknown },
  actor: Actor,
  ip: string | null,
): Promise<VisitorTypeDto> {
  const name = requiredText(input.name, 'name', '请输入名称', 30);
  return withTransaction(async (client) => {
    const before = await visitorTypesRepo.findVisitorTypeById(client, id, true);
    if (!before) {
      throw notFound();
    }
    if (await visitorTypesRepo.findVisitorTypeByName(client, name, id)) {
      throw conflict('名称已存在，请更换');
    }
    const updated = await visitorTypesRepo.updateVisitorTypeName(client, id, name);
    await writeAudit(client, {
      userId: actor.id,
      userName: actor.displayName,
      objectType: 'visitor_types',
      objectId: id,
      action: '修改主数据',
      result: '成功',
      before: { name: before.name },
      after: { name: updated.name },
      ip,
    });
    return updated;
  });
}

export async function changeVisitorTypeStatus(
  id: string,
  input: { status?: unknown },
  actor: Actor,
  ip: string | null,
): Promise<{ id: string; status: SoftStatus }> {
  const status = parseSoftStatus(input.status);
  return withTransaction(async (client) => {
    const before = await visitorTypesRepo.findVisitorTypeById(client, id, true);
    if (!before) {
      throw notFound();
    }
    if (before.status !== status) {
      await visitorTypesRepo.updateVisitorTypeStatus(client, id, status);
      await writeAudit(client, {
        userId: actor.id,
        userName: actor.displayName,
        objectType: 'visitor_types',
        objectId: id,
        action: status === 'inactive' ? '停用主数据' : '修改主数据',
        result: '成功',
        before: { status: before.status },
        after: { status },
        ip,
      });
    }
    return { id, status };
  });
}

export function requestedName(value: unknown): string {
  return stringValue(value);
}
