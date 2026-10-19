import { getUserByHostId, getFirstAdminUser } from '../../access/index.js';
import { writeAudit } from '../../../shared/audit/writeAudit.js';
import { withTransaction } from '../../../shared/db/pool.js';
import { unprocessable } from '../../../shared/http/errors.js';
import { newUuid } from '../../../shared/utils/ids.js';
import { normalizeTime, isValidTimeRange } from './domain/rules.js';
import type { NewReviewerRule, ReviewerKind, ReviewerRuleDto } from './master.types.js';
import * as reviewerRulesRepo from './reviewer-rules.repo.js';

const REVIEWER_KINDS: readonly ReviewerKind[] = ['host', 'admin', 'designated'];

function nullableTime(value: unknown, field: string): string | null {
  if (value === null || value === undefined || value === '') {
    return null;
  }
  const normalized = normalizeTime(value);
  if (!normalized) {
    throw unprocessable('时间格式不正确', field);
  }
  return normalized;
}

function normalizeRule(rule: Omit<ReviewerRuleDto, 'id'>, index: number): NewReviewerRule {
  if (!REVIEWER_KINDS.includes(rule.reviewerKind)) {
    throw unprocessable('审核人类型不正确', 'reviewer_kind');
  }
  const startTime = nullableTime(rule.startTime, 'start_time');
  const endTime = nullableTime(rule.endTime, 'end_time');
  if ((startTime === null) !== (endTime === null)) {
    throw unprocessable('开始时间和结束时间必须同时填写', 'start_time');
  }
  if (startTime && endTime && !isValidTimeRange(startTime, endTime)) {
    throw unprocessable('开始时间必须早于结束时间', 'start_time');
  }
  if (rule.reviewerKind === 'designated' && !rule.reviewerUserId) {
    throw unprocessable('指定审核人不能为空', 'reviewer_user_id');
  }
  return {
    visitorTypeId: rule.visitorTypeId ?? null,
    gateId: rule.gateId ?? null,
    startTime,
    endTime,
    reviewerKind: rule.reviewerKind,
    reviewerUserId: rule.reviewerUserId ?? null,
    declarationOrder:
      Number.isInteger(rule.declarationOrder) && rule.declarationOrder > 0
        ? rule.declarationOrder
        : index + 1,
    status: rule.status === 'inactive' ? 'inactive' : 'active',
  };
}

export async function upsertReviewerRules(
  rules: Omit<ReviewerRuleDto, 'id'>[],
): Promise<ReviewerRuleDto[]> {
  const normalized = rules.map(normalizeRule);
  return withTransaction(async (client) => {
    const before = await reviewerRulesRepo.listActiveReviewerRules(client);
    const inserted = await reviewerRulesRepo.replaceReviewerRules(
      client,
      normalized.map((rule) => ({ ...rule, id: newUuid() })),
    );
    await writeAudit(client, {
      userId: null,
      userName: '系统',
      objectType: 'reviewer_rules',
      objectId: null,
      action: '修改主数据',
      result: '成功',
      before: { count: before.length },
      after: { count: inserted.length },
    });
    return inserted;
  });
}

function shanghaiTimeSeconds(value: string): number | null {
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) {
    return null;
  }
  const parts = new Intl.DateTimeFormat('en-GB', {
    timeZone: 'Asia/Shanghai',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hour12: false,
  }).formatToParts(parsed);
  const values = Object.fromEntries(parts.map((part) => [part.type, part.value]));
  return Number(values.hour) * 3600 + Number(values.minute) * 60 + Number(values.second);
}

function timeSeconds(value: string | null): number | null {
  if (!value) {
    return null;
  }
  const normalized = normalizeTime(value);
  if (!normalized) {
    return null;
  }
  const [hours, minutes, seconds] = normalized.split(':').map(Number);
  return hours * 3600 + minutes * 60 + seconds;
}

function coversTime(rule: ReviewerRuleDto, visitSeconds: number): boolean {
  const start = timeSeconds(rule.startTime);
  const end = timeSeconds(rule.endTime);
  if (start === null || end === null) {
    return true;
  }
  return visitSeconds >= start && visitSeconds <= end;
}

async function resolveRuleUser(rule: ReviewerRuleDto, hostId: string): Promise<string | null> {
  if (rule.reviewerKind === 'designated') {
    return rule.reviewerUserId;
  }
  if (rule.reviewerKind === 'admin') {
    return (await getFirstAdminUser())?.id ?? null;
  }
  return (await getUserByHostId(hostId))?.id ?? null;
}

export async function resolveReviewer(input: {
  visitorTypeId: string;
  expectedGateId: string | null;
  visitStart: string;
  hostId: string;
}): Promise<string | null> {
  const visitSeconds = shanghaiTimeSeconds(input.visitStart);
  const rules = await reviewerRulesRepo.listActiveReviewerRulesFromPool();
  const ordered = [...rules].sort(
    (left, right) => left.declarationOrder - right.declarationOrder,
  );
  const layers: ReviewerRuleDto[][] = [];

  if (input.expectedGateId) {
    layers.push(
      ordered.filter(
        (rule) =>
          rule.visitorTypeId === input.visitorTypeId &&
          rule.gateId === input.expectedGateId &&
          visitSeconds !== null &&
          rule.startTime !== null &&
          rule.endTime !== null &&
          coversTime(rule, visitSeconds),
      ),
    );
    layers.push(
      ordered.filter(
        (rule) =>
          rule.visitorTypeId === input.visitorTypeId &&
          rule.gateId === input.expectedGateId &&
          rule.startTime === null &&
          rule.endTime === null,
      ),
    );
  }

  if (visitSeconds !== null) {
    layers.push(
      ordered.filter(
        (rule) =>
          rule.visitorTypeId === input.visitorTypeId &&
          rule.gateId === null &&
          rule.startTime !== null &&
          rule.endTime !== null &&
          coversTime(rule, visitSeconds),
      ),
    );
  }
  layers.push(
    ordered.filter(
      (rule) =>
        rule.visitorTypeId === input.visitorTypeId &&
        rule.gateId === null &&
        rule.startTime === null &&
        rule.endTime === null,
    ),
  );
  layers.push(
    ordered.filter(
      (rule) =>
        rule.visitorTypeId === null &&
        rule.gateId === null &&
        rule.startTime === null &&
        rule.endTime === null,
    ),
  );

  for (const layer of layers) {
    if (layer[0]) {
      return resolveRuleUser(layer[0], input.hostId);
    }
  }
  return (await getUserByHostId(input.hostId))?.id ?? null;
}
