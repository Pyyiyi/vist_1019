import { writeAudit } from '../../../shared/audit/writeAudit.js';
import { withTransaction } from '../../../shared/db/pool.js';
import { notFound, unprocessable } from '../../../shared/http/errors.js';
import { newUuid } from '../../../shared/utils/ids.js';
import type { Actor, TimeRuleDto } from './master.types.js';
import { isRuleType, isValidTimeRange, isValidWeekday, normalizeTime } from './domain/rules.js';
import * as timeRulesRepo from './time-rules.repo.js';

export async function listTimeRules(): Promise<TimeRuleDto[]> {
  return timeRulesRepo.listTimeRules();
}

export async function createTimeRule(
  input: {
    weekday?: unknown;
    start_time?: unknown;
    end_time?: unknown;
    rule_type?: unknown;
  },
  actor: Actor,
  ip: string | null,
): Promise<TimeRuleDto> {
  const weekday = Number(input.weekday);
  if (!isValidWeekday(weekday)) {
    throw unprocessable('请选择星期', 'weekday');
  }
  const startTime = normalizeTime(input.start_time);
  if (!startTime) {
    throw unprocessable('请选择开始时间', 'start_time');
  }
  const endTime = normalizeTime(input.end_time);
  if (!endTime) {
    throw unprocessable('请选择结束时间', 'end_time');
  }
  if (!isValidTimeRange(startTime, endTime)) {
    throw unprocessable('开始时间必须早于结束时间', 'start_time');
  }
  if (!isRuleType(input.rule_type)) {
    throw unprocessable('请选择规则类型', 'rule_type');
  }
  const ruleType = input.rule_type;

  return withTransaction(async (client) => {
    const id = newUuid();
    const created = await timeRulesRepo.insertTimeRule(client, {
      id,
      weekday,
      startTime,
      endTime,
      ruleType,
    });
    await writeAudit(client, {
      userId: actor.id,
      userName: actor.displayName,
      objectType: 'time_rules',
      objectId: id,
      action: '新增主数据',
      result: '成功',
      after: { weekday, start_time: startTime, end_time: endTime, rule_type: ruleType },
      ip,
    });
    return created;
  });
}

export async function deleteTimeRule(
  id: string,
  actor: Actor,
  ip: string | null,
): Promise<void> {
  await withTransaction(async (client) => {
    const before = await timeRulesRepo.findTimeRuleById(client, id, true);
    if (!before) {
      throw notFound();
    }
    await timeRulesRepo.deleteTimeRule(client, id);
    await writeAudit(client, {
      userId: actor.id,
      userName: actor.displayName,
      objectType: 'time_rules',
      objectId: id,
      action: '删除时段规则',
      result: '成功',
      before: {
        weekday: before.weekday,
        start_time: before.startTime,
        end_time: before.endTime,
        rule_type: before.ruleType,
      },
      ip,
    });
  });
}
