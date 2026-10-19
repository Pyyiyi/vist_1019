import type { RuleType, TimeRuleDto } from '../master.types.js';

export const WEEKDAYS = [1, 2, 3, 4, 5, 6, 7] as const;
export const RULE_TYPES: readonly RuleType[] = ['可预约', '禁入'];

export type TimeRuleInput = {
  weekday: number;
  startTime: string;
  endTime: string;
  ruleType: RuleType;
};

export type TimeRuleDecision = {
  allowed: boolean;
  reason: 'allow' | 'deny' | 'outside_allowed' | 'no_rules';
  matchedRuleId: string | null;
};

function parseTime(value: string): number | null {
  const match = /^(\d{2}):(\d{2})(?::(\d{2}))?$/.exec(value.trim());
  if (!match) {
    return null;
  }
  const hours = Number(match[1]);
  const minutes = Number(match[2]);
  const seconds = Number(match[3] ?? '0');
  if (hours > 23 || minutes > 59 || seconds > 59) {
    return null;
  }
  return hours * 3600 + minutes * 60 + seconds;
}

export function isValidWeekday(value: unknown): value is number {
  return typeof value === 'number' && Number.isInteger(value) && value >= 1 && value <= 7;
}

export function isRuleType(value: unknown): value is RuleType {
  return value === '可预约' || value === '禁入';
}

export function normalizeTime(value: unknown): string | null {
  if (typeof value !== 'string') {
    return null;
  }
  const seconds = parseTime(value);
  if (seconds === null) {
    return null;
  }
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  const remainingSeconds = seconds % 60;
  return [hours, minutes, remainingSeconds]
    .map((part) => String(part).padStart(2, '0'))
    .join(':');
}

export function isValidTimeRange(startTime: string, endTime: string): boolean {
  const start = parseTime(startTime);
  const end = parseTime(endTime);
  return start !== null && end !== null && start < end;
}

function overlaps(
  startA: number,
  endA: number,
  startB: number,
  endB: number,
): boolean {
  return startA <= endB && startB <= endA;
}

export function timeRuleDecision(
  rules: TimeRuleDto[],
  request: { weekday: number; startTime: string; endTime: string },
): TimeRuleDecision {
  const requestStart = parseTime(request.startTime);
  const requestEnd = parseTime(request.endTime);
  if (
    !isValidWeekday(request.weekday) ||
    requestStart === null ||
    requestEnd === null ||
    requestStart >= requestEnd
  ) {
    return { allowed: false, reason: 'no_rules', matchedRuleId: null };
  }

  const dailyRules = rules.filter((rule) => rule.weekday === request.weekday);
  if (dailyRules.length === 0) {
    return { allowed: false, reason: 'no_rules', matchedRuleId: null };
  }

  for (const rule of dailyRules) {
    if (rule.ruleType !== '禁入') {
      continue;
    }
    const start = parseTime(rule.startTime);
    const end = parseTime(rule.endTime);
    if (start !== null && end !== null && overlaps(requestStart, requestEnd, start, end)) {
      return { allowed: false, reason: 'deny', matchedRuleId: rule.id };
    }
  }

  const allowedRule = dailyRules.find((rule) => {
    if (rule.ruleType !== '可预约') {
      return false;
    }
    const start = parseTime(rule.startTime);
    const end = parseTime(rule.endTime);
    return start !== null && end !== null && requestStart >= start && requestEnd <= end;
  });

  return allowedRule
    ? { allowed: true, reason: 'allow', matchedRuleId: allowedRule.id }
    : { allowed: false, reason: 'outside_allowed', matchedRuleId: null };
}
