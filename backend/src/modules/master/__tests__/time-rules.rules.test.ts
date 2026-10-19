import { describe, expect, it } from 'vitest';

import {
  isValidTimeRange,
  normalizeTime,
  timeRuleDecision,
} from '../internal/domain/rules.js';
import type { TimeRuleDto } from '../internal/master.types.js';

function rule(
  id: string,
  ruleType: TimeRuleDto['ruleType'],
  startTime: string,
  endTime: string,
  weekday = 1,
): TimeRuleDto {
  return {
    id,
    weekday,
    startTime,
    endTime,
    ruleType,
    createdAt: '2026-10-19T00:00:00+08:00',
  };
}

describe('time rule domain rules', () => {
  it('normalizes clock values and requires start < end', () => {
    expect(normalizeTime('07:00')).toBe('07:00:00');
    expect(normalizeTime('18:30:15')).toBe('18:30:15');
    expect(normalizeTime('24:00')).toBeNull();
    expect(isValidTimeRange('07:00:00', '18:00:00')).toBe(true);
    expect(isValidTimeRange('18:00:00', '18:00:00')).toBe(false);
    expect(isValidTimeRange('18:00:01', '18:00:00')).toBe(false);
  });

  it('allows a request fully inside a closed reservation interval', () => {
    const rules = [rule('allow', '可预约', '07:00:00', '18:00:00')];
    expect(timeRuleDecision(rules, { weekday: 1, startTime: '07:00:00', endTime: '18:00:00' })).toEqual({
      allowed: true,
      reason: 'allow',
      matchedRuleId: 'allow',
    });
  });

  it('makes an overlapping deny rule win over an allow rule', () => {
    const rules = [
      rule('allow', '可预约', '07:00:00', '18:00:00'),
      rule('deny', '禁入', '10:00:00', '11:00:00'),
    ];
    expect(timeRuleDecision(rules, { weekday: 1, startTime: '10:30:00', endTime: '10:45:00' })).toEqual({
      allowed: false,
      reason: 'deny',
      matchedRuleId: 'deny',
    });
  });

  it('treats touching deny endpoints as overlap', () => {
    const rules = [
      rule('allow', '可预约', '07:00:00', '18:00:00'),
      rule('deny', '禁入', '10:00:00', '11:00:00'),
    ];
    expect(timeRuleDecision(rules, { weekday: 1, startTime: '11:00:00', endTime: '11:30:00' }).reason).toBe(
      'deny',
    );
  });

  it('rejects requests outside allow rules or belonging to another weekday', () => {
    const rules = [rule('allow', '可预约', '07:00:00', '18:00:00')];
    expect(timeRuleDecision(rules, { weekday: 1, startTime: '18:00:01', endTime: '18:30:00' }).reason).toBe(
      'outside_allowed',
    );
    expect(timeRuleDecision(rules, { weekday: 2, startTime: '10:00:00', endTime: '11:00:00' }).reason).toBe(
      'no_rules',
    );
  });
});
