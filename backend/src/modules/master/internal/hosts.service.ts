import { writeAudit } from '../../../shared/audit/writeAudit.js';
import { withTransaction } from '../../../shared/db/pool.js';
import { conflict, notFound, unprocessable } from '../../../shared/http/errors.js';
import { newUuid } from '../../../shared/utils/ids.js';
import * as hostsRepo from './hosts.repo.js';
import type { Actor, HostDto, SoftStatus } from './master.types.js';
import {
  nullableString,
  parseIncludeInactive,
  parseSoftStatus,
  requiredText,
} from './master.support.js';

type HostInput = {
  name?: unknown;
  employee_no?: unknown;
  department?: unknown;
  phone?: unknown;
};

function parseHostInput(input: HostInput) {
  const name = requiredText(input.name, 'name', '请输入名称', 30);
  const employeeNo = requiredText(input.employee_no, 'employee_no', '请输入工号', 30);
  const department = nullableString(input.department) ?? '';
  if (Array.from(department).length > 100) {
    throw unprocessable('部门不能超过 100 个字符', 'department');
  }
  const phone = nullableString(input.phone);
  if (phone && phone.length > 20) {
    throw unprocessable('联系电话不能超过 20 个字符', 'phone');
  }
  return { name, employeeNo, department, phone };
}

export async function listHosts(query: Record<string, unknown>): Promise<HostDto[]> {
  const status =
    query.status === undefined || query.status === '' ? undefined : parseSoftStatus(query.status);
  return hostsRepo.listHosts({
    status,
    includeInactive: parseIncludeInactive(query.include_inactive),
  });
}

export async function createHost(
  input: HostInput,
  actor: Actor,
  ip: string | null,
): Promise<HostDto> {
  const parsed = parseHostInput(input);
  return withTransaction(async (client) => {
    if (await hostsRepo.findHostByEmployeeNo(client, parsed.employeeNo)) {
      throw conflict('该工号已存在，请更换', 'employee_no');
    }
    const id = newUuid();
    const created = await hostsRepo.insertHost(client, { id, ...parsed });
    await writeAudit(client, {
      userId: actor.id,
      userName: actor.displayName,
      objectType: 'hosts',
      objectId: id,
      action: '新增主数据',
      result: '成功',
      after: {
        name: created.name,
        employee_no: created.employeeNo,
        department: created.department,
        phone: created.phone,
      },
      ip,
    });
    return created;
  });
}

export async function updateHost(
  id: string,
  input: HostInput,
  actor: Actor,
  ip: string | null,
): Promise<HostDto> {
  const parsed = parseHostInput(input);
  return withTransaction(async (client) => {
    const before = await hostsRepo.findHostById(client, id, true);
    if (!before) {
      throw notFound();
    }
    if (await hostsRepo.findHostByEmployeeNo(client, parsed.employeeNo, id)) {
      throw conflict('该工号已存在，请更换', 'employee_no');
    }
    const updated = await hostsRepo.updateHost(client, id, parsed);
    await writeAudit(client, {
      userId: actor.id,
      userName: actor.displayName,
      objectType: 'hosts',
      objectId: id,
      action: '修改主数据',
      result: '成功',
      before: {
        name: before.name,
        employee_no: before.employeeNo,
        department: before.department,
        phone: before.phone,
      },
      after: {
        name: updated.name,
        employee_no: updated.employeeNo,
        department: updated.department,
        phone: updated.phone,
      },
      ip,
    });
    return updated;
  });
}

export async function changeHostStatus(
  id: string,
  input: { status?: unknown },
  actor: Actor,
  ip: string | null,
): Promise<{ id: string; status: SoftStatus }> {
  const status = parseSoftStatus(input.status);
  return withTransaction(async (client) => {
    const before = await hostsRepo.findHostById(client, id, true);
    if (!before) {
      throw notFound();
    }
    if (before.status !== status) {
      await hostsRepo.updateHostStatus(client, id, status);
      await writeAudit(client, {
        userId: actor.id,
        userName: actor.displayName,
        objectType: 'hosts',
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
