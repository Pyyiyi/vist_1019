import { writeAudit } from '../../../shared/audit/writeAudit.js';
import { withTransaction } from '../../../shared/db/pool.js';
import { conflict, notFound } from '../../../shared/http/errors.js';
import { newUuid } from '../../../shared/utils/ids.js';
import * as gatesRepo from './gates.repo.js';
import type { Actor, GateDto, SoftStatus } from './master.types.js';
import {
  parseIncludeInactive,
  parseSoftStatus,
  requiredText,
} from './master.support.js';

export async function listGates(query: Record<string, unknown>): Promise<GateDto[]> {
  const status =
    query.status === undefined || query.status === '' ? undefined : parseSoftStatus(query.status);
  return gatesRepo.listGates({
    status,
    includeInactive: parseIncludeInactive(query.include_inactive),
  });
}

export async function createGate(
  input: { name?: unknown },
  actor: Actor,
  ip: string | null,
): Promise<GateDto> {
  const name = requiredText(input.name, 'name', '请输入名称', 30);
  return withTransaction(async (client) => {
    if (await gatesRepo.findGateByName(client, name)) {
      throw conflict('名称已存在，请更换');
    }
    const id = newUuid();
    const created = await gatesRepo.insertGate(client, {
      id,
      code: `gate-${id.slice(0, 8)}`,
      name,
      sortOrder: 0,
    });
    await writeAudit(client, {
      userId: actor.id,
      userName: actor.displayName,
      objectType: 'gates',
      objectId: id,
      action: '新增主数据',
      result: '成功',
      after: { name, status: created.status },
      ip,
    });
    return created;
  });
}

export async function renameGate(
  id: string,
  input: { name?: unknown },
  actor: Actor,
  ip: string | null,
): Promise<GateDto> {
  const name = requiredText(input.name, 'name', '请输入名称', 30);
  return withTransaction(async (client) => {
    const before = await gatesRepo.findGateById(client, id, true);
    if (!before) {
      throw notFound();
    }
    if (await gatesRepo.findGateByName(client, name, id)) {
      throw conflict('名称已存在，请更换');
    }
    const updated = await gatesRepo.updateGateName(client, id, name);
    await writeAudit(client, {
      userId: actor.id,
      userName: actor.displayName,
      objectType: 'gates',
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

export async function changeGateStatus(
  id: string,
  input: { status?: unknown },
  actor: Actor,
  ip: string | null,
): Promise<{ id: string; status: SoftStatus }> {
  const status = parseSoftStatus(input.status);
  return withTransaction(async (client) => {
    const before = await gatesRepo.findGateById(client, id, true);
    if (!before) {
      throw notFound();
    }
    if (before.status !== status) {
      await gatesRepo.updateGateStatus(client, id, status);
      await writeAudit(client, {
        userId: actor.id,
        userName: actor.displayName,
        objectType: 'gates',
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
