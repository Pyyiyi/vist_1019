import { writeAudit } from '../../../shared/audit/writeAudit.js';
import { withTransaction } from '../../../shared/db/pool.js';
import { conflict, notFound, unprocessable } from '../../../shared/http/errors.js';
import { parsePagination } from '../../../shared/http/pagination.js';
import { newUuid } from '../../../shared/utils/ids.js';
import * as blacklistRepo from './blacklist.repo.js';
import { normalizeBlacklistIdNos } from './domain/blacklist.rules.js';
import type { Actor, BlacklistEntryDto, BlacklistStatus } from './master.types.js';
import { requiredText, requireFutureDate, nullableString } from './master.support.js';

export async function listBlacklist(query: Record<string, unknown>): Promise<{
  items: BlacklistEntryDto[];
  total: number;
  page: number;
  pageSize: number;
}> {
  const pagination = parsePagination(query, 20, 100);
  const status = query.status;
  if (status !== undefined && status !== '' && !['有效', '已过期', '已删除'].includes(String(status))) {
    throw unprocessable('状态值不正确', 'status');
  }
  const result = await blacklistRepo.listBlacklist({
    pageSize: pagination.pageSize,
    offset: pagination.offset,
    keyword: typeof query.keyword === 'string' ? query.keyword.trim() : '',
    status: status === undefined || status === '' ? null : (String(status) as BlacklistStatus),
  });
  return { ...result, page: pagination.page, pageSize: pagination.pageSize };
}

export async function createBlacklist(
  input: { id_no?: unknown; name?: unknown; reason?: unknown; expire_at?: unknown },
  actor: Actor,
  ip: string | null,
): Promise<BlacklistEntryDto> {
  const idNo = normalizeBlacklistIdNos([requiredText(input.id_no, 'id_no', '请输入证件号', 20)])[0];
  if (!idNo) {
    throw unprocessable('请输入证件号', 'id_no');
  }
  const name = nullableString(input.name) ?? '';
  if (Array.from(name).length > 50) {
    throw unprocessable('姓名不能超过 50 个字符', 'name');
  }
  const reason = requiredText(input.reason, 'reason', '请输入原因', 200);
  const expireAt = requireFutureDate(input.expire_at, 'expire_at');

  return withTransaction(async (client) => {
    if (await blacklistRepo.findEffectiveBlacklistByIdNo(client, idNo, new Date())) {
      throw conflict('该证件号已在有效黑名单中');
    }
    const id = newUuid();
    const created = await blacklistRepo.insertBlacklist(client, {
      id,
      idNo,
      name,
      reason,
      expireAt,
    });
    await writeAudit(client, {
      userId: actor.id,
      userName: actor.displayName,
      objectType: 'blacklist_entries',
      objectId: id,
      action: '新增主数据',
      result: '成功',
      after: { id_no: idNo, name, reason, expire_at: expireAt.toISOString() },
      ip,
    });
    return created;
  });
}

export async function deleteBlacklist(
  id: string,
  actor: Actor,
  ip: string | null,
): Promise<void> {
  await withTransaction(async (client) => {
    const before = await blacklistRepo.findBlacklistById(client, id, true);
    if (!before || before.status === '已删除') {
      throw notFound();
    }
    await blacklistRepo.softDeleteBlacklist(client, id);
    await writeAudit(client, {
      userId: actor.id,
      userName: actor.displayName,
      objectType: 'blacklist_entries',
      objectId: id,
      action: '删除黑名单',
      result: '成功',
      before: { status: before.status, id_no: before.idNo },
      after: { status: '已删除' },
      ip,
    });
  });
}

export async function expireBlacklistEntries(now: Date): Promise<number> {
  return blacklistRepo.expireBlacklistRows(now);
}

export async function checkBlacklist(idNos: string[], now = new Date()): Promise<{
  hit: boolean;
  matchedIdNos: string[];
}> {
  const matchedIdNos = await blacklistRepo.findMatchingEffectiveBlacklist(
    normalizeBlacklistIdNos(idNos),
    now,
  );
  return { hit: matchedIdNos.length > 0, matchedIdNos };
}
